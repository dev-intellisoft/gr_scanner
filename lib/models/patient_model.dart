class PatientModel {
  String name;
  String cpf;
  DateTime? birthDate;
  List<String> posibilities = <String>[];

  PatientModel({
    required this.name,
    required this.cpf,
    required this.birthDate,
    required this.posibilities
  });

  factory PatientModel.fromJson(Map<String, dynamic> json){
    return PatientModel(
      name: json['name'],
      cpf: json['cpf'],
      birthDate: json['birthDate'],
      posibilities: json['posibilities']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'cpf': cpf,
      'birthDate': birthDate?.toIso8601String(),
      'posibilities': posibilities
    };
  }
}