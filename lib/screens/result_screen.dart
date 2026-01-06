import 'package:flutter/material.dart';
import '../models/disease_info.dart';
import 'analyzing_screen.dart';

class ResultScreen extends StatelessWidget {
  final ResultArgs args;
  const ResultScreen({super.key, required this.args});

  String formatLabel(String raw) {
    return raw
        .replaceAll("_", " ")
        .split(" ")
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(" ");
  }

  static const labelMap = {
    "bacterial_leaf_blight": "Hawar Daun Bakteri",
    "brown_spot": "Bercak Coklat",
    "healthy": "Daun Sehat",
    "leaf_blast": "Blas Daun",
    "narrow_brown_spot": "Bercak Daun Coklat Sempit",
    "sheath_blight": "Hawar Pelepah Daun",
  };

  @override
  Widget build(BuildContext context) {
    final DiseaseInfo? info = args.diseaseInfo;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("Analysis Results",
            style: TextStyle(fontSize: 16, color: Colors.white)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  args.imageFile,
                  fit: BoxFit.cover,
                  height: 200,
                  width: double.infinity,
                ),
              ),

              const SizedBox(height: 16),

              // Main Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.eco_rounded,
                            color: Colors.green, size: 22),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            info?.name ??
                                (labelMap[args.prediction.labelId] ??
                                    formatLabel(args.prediction.labelId)),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
                      ],
                    ),
                    // const SizedBox(height: 12),
                    // Container(
                    //   padding: const EdgeInsets.symmetric(
                    //       horizontal: 10, vertical: 4),
                    //   decoration: BoxDecoration(
                    //     color: Colors.green.withOpacity(0.12),
                    //     borderRadius: BorderRadius.circular(20),
                    //   ),
                    //   child: Text(
                    //     "${confPercent.toStringAsFixed(0)}% Confidence",
                    //     style:
                    //         const TextStyle(color: Colors.green, fontSize: 12),
                    //   ),
                    // ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        info?.description ??
                            "Tidak ada deskripsi yang tersedia",
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              _sectionTitle("Pencegahan"),
              info?.prevention != null
                  ? _boxList(info!.prevention)
                  : _box("Tidak ada data Pencegahan"),

              const SizedBox(height: 16),

              _sectionTitle("Pengobatan"),
              info?.treatment != null
                  ? _boxList(info!.treatment)
                  : _box("Tidak ada data Pengobatan"),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/home',
                          (route) => false,
                        );
                      },
                      child: const Text(
                        "Analisis yang lain",
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {},
                      child: const Text(
                        "Save Results",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _box(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }


  Widget _boxList(List<String> items) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF181818),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        items.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            "${index + 1}. ${items[index]}",
            style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
          ),
        ),
      ),
    ),
  );
}
}
