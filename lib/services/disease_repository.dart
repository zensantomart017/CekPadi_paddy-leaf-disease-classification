import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/disease_info.dart';

class DiseaseRepository {
  DiseaseRepository._internal();
  static final DiseaseRepository instance = DiseaseRepository._internal();

  bool _loaded = false;
  List<DiseaseInfo> _diseases = [];

  Future<void> _load() async {
    if (_loaded) return;

    final jsonStr = await rootBundle.loadString('assets/data/response.json');
    final List data = json.decode(jsonStr);

    _diseases = data.map((e) {
      final temp = DiseaseInfo.fromJson(e);

      // Tambahkan normalizedName tanpa bikin object baru
      return DiseaseInfo(
        id: temp.id,
        name: temp.name,
        labelsName: temp.labelsName,
        description: temp.description,
        prevention: temp.prevention,
        treatment: temp.treatment,
        normalizedName: temp.labelsName
            .toLowerCase()
            .trim(),
      );
    }).toList();

    _loaded = true;
  }

  // BARU: Cari berdasarkan label dari model
  Future<DiseaseInfo?> getByLabel(String labelFromModel) async {
    await _load();

    final normalized = labelFromModel.toLowerCase().trim();

    try {
      return _diseases .firstWhere((d) =>
          d.labelsName.toLowerCase().trim() == normalized ||
          d.name.toLowerCase().trim() == normalized);
    } catch (e) {
      return null;
    }
  }

  // Tetap pertahankan getById kalau perlu
  Future<DiseaseInfo?> getById(int id) async {
    await _load();
    try {
      return _diseases.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}
