import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class PredictionResult {
  final String labelId;
  final double confidence;
  final bool isValid;

  PredictionResult({
    required this.labelId,
    required this.confidence,
    this.isValid = true,
  });
}

class ModelService {
  ModelService._internal();
  static final ModelService instance = ModelService._internal();

  static const int inputSize = 480;
  static const double minConfidenceThreshold = 0.35;

  late Interpreter _interpreter;
  late List<String> _labels;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    _interpreter = await Interpreter.fromAsset(
      'assets/models/efficientnetv2m_paddy_final.tflite',
      options: InterpreterOptions()..threads = 4,
    );

    final labelsRaw = await rootBundle.loadString('assets/models/labels.txt');
    _labels = labelsRaw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    debugPrint("Model loaded with ${_labels.length} classes");
    _initialized = true;
  }

  Future<PredictionResult> predict(File imageFile) async {
    await init();

    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception("Cannot decode image");
    }

    debugPrint("\nStarting validation...");

    final basicCheck = _checkBasicImage(image);
    if (!basicCheck.isValid) {
      debugPrint("Stage 1 FAILED: ${basicCheck.reason}");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: 0.0,
        isValid: false,
      );
    }
    debugPrint("Stage 1 PASSED: Basic image valid");

    final organicCheck = _checkOrganic(image);
    if (!organicCheck.isValid) {
      debugPrint("Stage 2 FAILED: ${organicCheck.reason}");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: 0.0,
        isValid: false,
      );
    }
    debugPrint("Stage 2 PASSED: Has organic features");

    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    final input = _prepareInputTensor(resized);
    final output =
        List<double>.filled(_labels.length, 0).reshape([1, _labels.length]);

    debugPrint("\nRunning model inference...");
    _interpreter.run(
      input.reshape([1, inputSize, inputSize, 3]),
      output,
    );

    final scores = (output[0] as List).cast<double>();

    debugPrint("\nModel Output:");
    for (int i = 0; i < scores.length; i++) {
      debugPrint("  ${_labels[i]}: ${(scores[i] * 100).toStringAsFixed(2)}%");
    }

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);
    final predictedLabel = _labels[maxIndex];

    debugPrint(
        "\nTop Prediction: $predictedLabel (${(maxScore * 100).toStringAsFixed(1)}%)");

    if (maxScore < minConfidenceThreshold) {
      debugPrint("Stage 3 FAILED: Confidence too low");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: maxScore,
        isValid: false,
      );
    }
    debugPrint("Stage 3 PASSED: Confidence sufficient");

    final sortedScores = [...scores]..sort((a, b) => b.compareTo(a));
    final gap = sortedScores[0] - sortedScores[1];

    debugPrint("\nSanity Check:");
    debugPrint("  Top score: ${(sortedScores[0] * 100).toStringAsFixed(1)}%");
    debugPrint("  2nd score: ${(sortedScores[1] * 100).toStringAsFixed(1)}%");
    debugPrint("  Gap: ${(gap * 100).toStringAsFixed(1)}%");

    if (gap < 0.10 && maxScore < 0.60) {
      debugPrint("Warning: Scores too close, might be uncertain");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: maxScore,
        isValid: false,
      );
    }

    debugPrint("All checks PASSED - Valid prediction!\n");

    return PredictionResult(
      labelId: predictedLabel,
      confidence: maxScore,
      isValid: true,
    );
  }

  Uint8List _prepareInputTensor(img.Image image) {
    final input = Uint8List(inputSize * inputSize * 3);
    int idx = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = image.getPixel(x, y);
        input[idx++] = pixel.r.toInt();
        input[idx++] = pixel.g.toInt();
        input[idx++] = pixel.b.toInt();
      }
    }

    return input;
  }

  ValidationResult _checkBasicImage(img.Image image) {
    final width = image.width;
    final height = image.height;

    int veryBright = 0;
    int veryDark = 0;
    int colored = 0;

    const step = 3;
    int total = 0;

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final p = image.getPixel(x, y);
        final r = p.r.toDouble();
        final g = p.g.toDouble();
        final b = p.b.toDouble();

        final avg = (r + g + b) / 3;
        final range = [r, g, b].reduce((a, b) => a > b ? a : b) -
            [r, g, b].reduce((a, b) => a < b ? a : b);

        if (avg > 240) {
          veryBright++;
        } else if (avg < 15) {
          veryDark++;
        }

        if (range > 12) colored++;

        total++;
      }
    }

    final brightRatio = veryBright / total;
    final darkRatio = veryDark / total;
    final colorRatio = colored / total;

    debugPrint("  Basic stats:");
    debugPrint("    Very bright: ${(brightRatio * 100).toStringAsFixed(1)}%");
    debugPrint("    Very dark: ${(darkRatio * 100).toStringAsFixed(1)}%");
    debugPrint("    Has color: ${(colorRatio * 100).toStringAsFixed(1)}%");

    if (brightRatio > 0.85) {
      return ValidationResult(false, "Too much white/bright");
    }

    if (darkRatio > 0.75) {
      return ValidationResult(false, "Too much black/dark");
    }

    if (colorRatio < 0.08) {
      return ValidationResult(false, "Insufficient color variation");
    }

    return ValidationResult(true);
  }

  ValidationResult _checkOrganic(img.Image image) {
    final width = image.width;
    final height = image.height;

    int naturalGreen = 0;
    int naturalYellow = 0;
    int naturalBrown = 0;
    int artificialColor = 0;
    int skinTone = 0;

    const step = 2;
    int total = 0;

    for (int y = 0; y < height; y += step) {
      for (int x = 0; x < width; x += step) {
        final p = image.getPixel(x, y);
        final colorType = _classifyPixel(p);

        switch (colorType) {
          case PixelType.naturalGreen:
            naturalGreen++;
            break;
          case PixelType.naturalYellow:
            naturalYellow++;
            break;
          case PixelType.naturalBrown:
            naturalBrown++;
            break;
          case PixelType.artificial:
            artificialColor++;
            break;
          case PixelType.skin:
            skinTone++;
            break;
          default:
            break;
        }

        total++;
      }
    }

    final greenRatio = naturalGreen / total;
    final yellowRatio = naturalYellow / total;
    final brownRatio = naturalBrown / total;
    final organicRatio = greenRatio + yellowRatio + brownRatio;
    final artificialRatio = artificialColor / total;
    final skinRatio = skinTone / total;

    debugPrint("  Organic analysis:");
    debugPrint("    Natural green: ${(greenRatio * 100).toStringAsFixed(1)}%");
    debugPrint(
        "    Natural yellow: ${(yellowRatio * 100).toStringAsFixed(1)}%");
    debugPrint("    Natural brown: ${(brownRatio * 100).toStringAsFixed(1)}%");
    debugPrint(
        "    Total organic: ${(organicRatio * 100).toStringAsFixed(1)}%");
    debugPrint(
        "    Artificial: ${(artificialRatio * 100).toStringAsFixed(1)}%");
    debugPrint("    Skin tone: ${(skinRatio * 100).toStringAsFixed(1)}%");

    if (artificialRatio > 0.40) {
      return ValidationResult(false, "Too much artificial color");
    }

    if (skinRatio > 0.30) {
      return ValidationResult(false, "Too much skin tone detected");
    }

    if (organicRatio < 0.10) {
      return ValidationResult(false, "Insufficient organic features");
    }

    return ValidationResult(true);
  }

  PixelType _classifyPixel(img.Pixel p) {
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();

    final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
    final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
    final delta = maxC - minC;

    final v = (maxC / 255) * 100;
    final s = maxC == 0 ? 0 : (delta / maxC) * 100;

    double h = 0;
    if (delta != 0) {
      if (maxC == r) {
        h = 60 * (((g - b) / delta) % 6);
      } else if (maxC == g) {
        h = 60 * (((b - r) / delta) + 2);
      } else {
        h = 60 * (((r - g) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    if (h >= 0 && h <= 50 && s >= 15 && s <= 50 && v >= 40 && v <= 90) {
      if (r > g && g > b && r - b > 15) {
        return PixelType.skin;
      }
    }

    if (v < 10 || v > 95) return PixelType.other;
    if (s < 6) return PixelType.other;

    if (h >= 70 && h <= 150) {
      if (s > 80 && v > 70) {
        return PixelType.artificial;
      }
      return PixelType.naturalGreen;
    }

    if (h >= 45 && h < 70 && s >= 15 && s <= 75) {
      return PixelType.naturalYellow;
    }

    if (h >= 15 && h < 45 && v < 65) {
      return PixelType.naturalBrown;
    }

    if (s > 75 || (h < 15 || h > 150)) {
      return PixelType.artificial;
    }

    return PixelType.other;
  }

  void dispose() {
    _interpreter.close();
  }
}

enum PixelType {
  naturalGreen,
  naturalYellow,
  naturalBrown,
  artificial,
  skin,
  other,
}

class ValidationResult {
  final bool isValid;
  final String? reason;

  ValidationResult(this.isValid, [this.reason]);
}
