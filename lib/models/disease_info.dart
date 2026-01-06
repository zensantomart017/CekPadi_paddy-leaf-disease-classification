class DiseaseInfo {
  final int id;
  final String name;
  final String labelsName;
  final String? description;
  final List<String> prevention;
  final List<String> treatment;
  final String normalizedName;

  DiseaseInfo({
    required this.id,
    required this.name,
    required this.labelsName,
    this.description,
    required this.prevention,
    required this.treatment,
    String? normalizedName,
  }) : normalizedName = normalizedName ?? labelsName.toLowerCase().trim();

  factory DiseaseInfo.fromJson(Map<String, dynamic> json) {
    return DiseaseInfo(
      id: json['id'],
      name: json['name'] ?? '',
      labelsName: json['labelsName'] ??
          json['name'].toString().toLowerCase().replaceAll(' ', '_'),
      description: json['description'],
      prevention: (json["prevention"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      treatment: (json["treatment"] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
