class PatientModel {
  String nome;
  String cpf;
  String dataNascimento;
  List<String> guesses = <String>[];

  PatientModel({
    required this.nome,
    required this.cpf,
    required this.dataNascimento,
    required this.guesses
  });

  factory PatientModel.fromJson(Map<String, dynamic> json){
    return PatientModel(
      nome: json['nome'],
      cpf: json['cpf'],
      dataNascimento: json['dataNascimento'],
      guesses: json['guesses']
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'cpf': cpf,
      'dataNascimento': dataNascimento,
      'guesses': guesses
    };
  }
}