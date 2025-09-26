class PatientModel {
  String nome;
  String cpf;
  String dataNascimento;

  PatientModel({
    required this.nome,
    required this.cpf,
    required this.dataNascimento
  });

  factory PatientModel.fromJson(Map<String, dynamic> json){
    return PatientModel(
      nome: json['nome'],
      cpf: json['cpf'],
      dataNascimento: json['dataNascimento']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'cpf': cpf,
      'dataNascimento': dataNascimento
    };
  }
}