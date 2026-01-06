import 'dart:io';

import 'package:flutter/material.dart';
import '../services/model_service.dart';
import '../services/disease_repository.dart';
import '../models/disease_info.dart';
import 'home_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  final AnalyzingArgs args;
  const AnalyzingScreen({super.key, required this.args});

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  bool step1 = false;
  bool step2 = false;
  bool step3 = false;
  bool step4 = false;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  Future<void> _startAnalysis() async {
    final file = widget.args.imageFile;

    setState(() => step1 = true);

    final prediction =
        await ModelService.instance.predict(file);
    setState(() => step2 = true); // detecting leaf features

    final info = await DiseaseRepository.instance
        .getByLabel(prediction.labelId);
    setState(() => step3 = true); // identifying diseases

    setState(() => step4 = true); // generating recommendations

    // sedikit delay biar user sempat lihat status
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    Navigator.pushReplacementNamed(
      context,
      '/result',
      arguments: ResultArgs(
        imageFile: file,
        prediction: prediction,
        diseaseInfo: info,
      ),
    );
  }

  Widget _buildStep(String text, bool done) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          color: done ? Colors.green : Colors.grey,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: done ? Colors.green : Colors.grey.shade400,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.args.imageFile;

    return Scaffold(
      backgroundColor: Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Analyzing Image',
          style: TextStyle(fontSize: 16, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  file,
                  height: 200,
                  width: 200,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                "Menganalisis Daun Padi",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                "Sedang menganalisis gambar Anda untuk identifikasi penyakit dan rekomendasi pengobatan...",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 24),
              _buildStep("Processing image...", step1),
              const SizedBox(height: 10),
              _buildStep("Detecting leaf features...", step2),
              const SizedBox(height: 10),
              _buildStep("Identifying diseases...", step3),
              const SizedBox(height: 10),
              _buildStep("Generating recommendations...", step4),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultArgs {
  final File imageFile;
  final PredictionResult prediction;
  final DiseaseInfo? diseaseInfo;

  ResultArgs({
    required this.imageFile,
    required this.prediction,
    required this.diseaseInfo,
  });
}
