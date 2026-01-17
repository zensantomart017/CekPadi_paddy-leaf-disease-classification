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

    _diseases = data.map((e) => DiseaseInfo.fromJson(e)).toList();
    _loaded = true;
  }

  Future<DiseaseInfo?> getByLabel(String labelFromModel) async {
    await _load();

    final normalized = labelFromModel.toLowerCase().trim();

    try {
      return _diseases.firstWhere((d) =>
          d.labelsName.toLowerCase().trim() == normalized ||
          d.name.toLowerCase().trim() == normalized);
    } catch (e) {
      return null;
    }
  }

  Future<DiseaseInfo?> getById(int id) async {
    await _load();
    try {
      return _diseases.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }
}
