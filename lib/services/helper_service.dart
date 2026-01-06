import 'package:image/image.dart' as img;

bool isRiceLeaf(img.Image image) {
  // Konversi ke HSV manual (karena package image tidak punya HSV built-in)
  int greenCount = 0;
  int total = image.width * image.height;

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      // Konversi RGB ke HSV sederhana
      final max = [r, g, b].reduce((a, b) => a > b ? a : b);
      final min = [r, g, b].reduce((a, b) => a < b ? a : b);
      final v = max;
      final s = max == 0 ? 0 : 255 * (max - min) / max;
      num h = 0;

      if (max == min)
        h = 0;
      else if (max == r)
        h = 60 * ((g - b) / (max - min));
      else if (max == g)
        h = 60 * (2 + (b - r) / (max - min));
      else if (max == b) h = 60 * (4 + (r - g) / (max - min));

      if (h < 0) h += 360;

      // Hijau daun padi: hue 35–85, saturasi & value tinggi
      if (h >= 35 && h <= 85 && s >= 70 && v >= 60) {
        greenCount++;
      }
    }
  }

  final ratio = greenCount / total;
  print("Green ratio: ${(ratio * 100).toStringAsFixed(2)}%");
  return ratio > 0.25; // minimal 25% hijau daun padi
}
