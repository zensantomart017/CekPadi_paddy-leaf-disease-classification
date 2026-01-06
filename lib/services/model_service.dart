import 'dart:io';
import 'dart:typed_data';
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
  static const double minConfidenceThreshold =
      0.35; // Naikkan untuk filter junk

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

    print("✅ Model loaded with ${_labels.length} classes: $_labels");
    _initialized = true;
  }

  Future<PredictionResult> predict(File imageFile) async {
    await init();

    final bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);
    if (image == null) {
      throw Exception("Cannot decode image");
    }

    // Multi-stage validation
    print("\n🔍 Starting validation...");

    // Stage 1: Basic image check
    final basicCheck = _checkBasicImage(image);
    if (!basicCheck.isValid) {
      print("❌ Stage 1 FAILED: ${basicCheck.reason}");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: 0.0,
        isValid: false,
      );
    }
    print("✅ Stage 1 PASSED: Basic image valid");

    // Stage 2: Organic/natural check
    final organicCheck = _checkOrganic(image);
    if (!organicCheck.isValid) {
      print("❌ Stage 2 FAILED: ${organicCheck.reason}");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: 0.0,
        isValid: false,
      );
    }
    print("✅ Stage 2 PASSED: Has organic features");

    // Resize untuk model
    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.linear,
    );

    // Prepare input tensor
    final input = _prepareInputTensor(resized);

    // Prepare output
    final output =
        List<double>.filled(_labels.length, 0).reshape([1, _labels.length]);

    // Run inference
    print("\n🤖 Running model inference...");
    _interpreter.run(
      input.reshape([1, inputSize, inputSize, 3]),
      output,
    );

    // Process results
    final scores = (output[0] as List).cast<double>();

    print("\n📊 Model Output:");
    for (int i = 0; i < scores.length; i++) {
      print("  ${_labels[i]}: ${(scores[i] * 100).toStringAsFixed(2)}%");
    }

    // Find top prediction
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final maxIndex = scores.indexOf(maxScore);
    final predictedLabel = _labels[maxIndex];

    print(
        "\n🎯 Top Prediction: $predictedLabel (${(maxScore * 100).toStringAsFixed(1)}%)");

    // Stage 3: Confidence check
    if (maxScore < minConfidenceThreshold) {
      print(
          "❌ Stage 3 FAILED: Confidence too low (${(maxScore * 100).toStringAsFixed(1)}% < ${(minConfidenceThreshold * 100).toStringAsFixed(0)}%)");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: maxScore,
        isValid: false,
      );
    }
    print("✅ Stage 3 PASSED: Confidence sufficient");

    // Stage 4: Sanity check - apakah top 2 scores terlalu dekat?
    final sortedScores = [...scores]..sort((a, b) => b.compareTo(a));
    final gap = sortedScores[0] - sortedScores[1];

    print("\n🔬 Sanity Check:");
    print("  Top score: ${(sortedScores[0] * 100).toStringAsFixed(1)}%");
    print("  2nd score: ${(sortedScores[1] * 100).toStringAsFixed(1)}%");
    print("  Gap: ${(gap * 100).toStringAsFixed(1)}%");

    if (gap < 0.10 && maxScore < 0.60) {
      print("⚠️  Warning: Scores too close, might be uncertain");
      return PredictionResult(
        labelId: "not_rice_leaf",
        confidence: maxScore,
        isValid: false,
      );
    }

    print("✅ All checks PASSED - Valid prediction!\n");

    return PredictionResult(
      labelId: predictedLabel,
      confidence: maxScore,
      isValid: true,
    );
  }

  /// Prepare input tensor
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

  /// Stage 1: Basic image validation
  ValidationResult _checkBasicImage(img.Image image) {
    final width = image.width;
    final height = image.height;

    int veryBright = 0;
    int veryDark = 0;
    int colored = 0;

    final step = 3;
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

        if (avg > 240)
          veryBright++;
        else if (avg < 15) veryDark++;

        if (range > 12) colored++;

        total++;
      }
    }

    final brightRatio = veryBright / total;
    final darkRatio = veryDark / total;
    final colorRatio = colored / total;

    print("  🎨 Basic stats:");
    print("    Very bright: ${(brightRatio * 100).toStringAsFixed(1)}%");
    print("    Very dark: ${(darkRatio * 100).toStringAsFixed(1)}%");
    print("    Has color: ${(colorRatio * 100).toStringAsFixed(1)}%");

    if (brightRatio > 0.75) {
      return ValidationResult(false,
          "Too much white/bright (${(brightRatio * 100).toStringAsFixed(0)}%)");
    }

    if (darkRatio > 0.75) {
      return ValidationResult(false,
          "Too much black/dark (${(darkRatio * 100).toStringAsFixed(0)}%)");
    }

    if (colorRatio < 0.12) {
      return ValidationResult(false,
          "Insufficient color variation (${(colorRatio * 100).toStringAsFixed(1)}%)");
    }

    return ValidationResult(true);
  }

  /// Stage 2: Organic/natural texture check
  ValidationResult _checkOrganic(img.Image image) {
    final width = image.width;
    final height = image.height;

    int naturalGreen = 0;
    int naturalYellow = 0;
    int naturalBrown = 0;
    int artificialColor = 0;
    int skinTone = 0;

    final step = 2;
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

    print("  🍃 Organic analysis:");
    print("    Natural green: ${(greenRatio * 100).toStringAsFixed(1)}%");
    print("    Natural yellow: ${(yellowRatio * 100).toStringAsFixed(1)}%");
    print("    Natural brown: ${(brownRatio * 100).toStringAsFixed(1)}%");
    print("    Total organic: ${(organicRatio * 100).toStringAsFixed(1)}%");
    print("    Artificial: ${(artificialRatio * 100).toStringAsFixed(1)}%");
    print("    Skin tone: ${(skinRatio * 100).toStringAsFixed(1)}%");

    // Reject jika terlalu banyak artificial color
    if (artificialRatio > 0.40) {
      return ValidationResult(false,
          "Too much artificial color (${(artificialRatio * 100).toStringAsFixed(0)}%)");
    }

    // Reject jika terlalu banyak skin tone (jari, tangan)
    if (skinRatio > 0.30) {
      return ValidationResult(false,
          "Too much skin tone detected (${(skinRatio * 100).toStringAsFixed(0)}%)");
    }

    // Minimal harus ada organic color
    if (organicRatio < 0.15) {
      return ValidationResult(false,
          "Insufficient organic features (${(organicRatio * 100).toStringAsFixed(1)}%)");
    }

    return ValidationResult(true);
  }

  /// Classify pixel untuk deteksi organic vs artificial
  PixelType _classifyPixel(img.Pixel p) {
    final r = p.r.toDouble();
    final g = p.g.toDouble();
    final b = p.b.toDouble();

    // HSV calculation
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

    // Skin tone detection (reject jari/tangan)
    if (h >= 0 && h <= 50 && s >= 15 && s <= 50 && v >= 40 && v <= 90) {
      if (r > g && g > b && r - b > 15) {
        return PixelType.skin;
      }
    }

    // Terlalu gelap atau terang
    if (v < 10 || v > 95) return PixelType.other;

    // Tidak ada saturasi = gray
    if (s < 6) return PixelType.other;

    // Natural green (70-150°, moderate saturation)
    if (h >= 70 && h <= 150) {
      // Cek apakah "natural" green atau artificial neon green
      if (s > 80 && v > 70) {
        return PixelType.artificial; // Terlalu saturated = plastic/neon
      }
      return PixelType.naturalGreen;
    }

    // Natural yellow (45-70°)
    if (h >= 45 && h < 70 && s >= 15 && s <= 75) {
      return PixelType.naturalYellow;
    }

    // Natural brown (15-45°, low value)
    if (h >= 15 && h < 45 && v < 65) {
      return PixelType.naturalBrown;
    }

    // Artificial colors (too saturated or weird hues)
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
