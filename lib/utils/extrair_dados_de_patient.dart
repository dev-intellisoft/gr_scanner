import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:webcam_doc/models/patient_model.dart';

mixin ExtrairDadosDePatient {
  static String _onlyDigits(String text) {
    return text.replaceAll(RegExp(r'[^\d]'), '');
  }

  static PatientModel analisarTextoParaPaciente(RecognizedText recognizedText) {
    String texto = recognizedText.text;
    String? cpf;
    String? nome;
    String? dataNascimento;
    List<String> guesses = [];

    final cpfRegex = RegExp(r'\b\d{3}[.\s]?\d{3}[.\s]?\d{3}[-.\s]?\d{2}\b');
    final dataNascimentoRegex = RegExp(r'\d{2}[/\- ]\d{2}[/\- ]\d{4}');

    final cpfMatch = cpfRegex.firstMatch(texto);
    if (cpfMatch != null) {
      String cpfLimpo = _onlyDigits(cpfMatch.group(0)!);
      if (cpfLimpo.length == 11) {
        cpf = cpfLimpo;
      }
    }

    final dataContextualRegex = RegExp(r'(DATA\s+DE\s+NASCIMENTO|NASCIMENTO|DT\.?)\s*[:\s]?\s*(\d{2}[/\- ]\d{2}[/\- ]\d{4})', caseSensitive: false);
    final dataContextualMatch = dataContextualRegex.firstMatch(texto);

    if (dataContextualMatch != null && dataContextualMatch.group(2) != null) {
      dataNascimento = dataContextualMatch.group(2)!.replaceAll(RegExp(r'[\- ]'), '/');
    } else {
      final dataMatch = dataNascimentoRegex.firstMatch(texto);
      if (dataMatch != null) {
        dataNascimento = dataMatch.group(0)!.replaceAll(RegExp(r'[\- ]'), '/');
      }
    }

    final List<String> linhas = eliminarRuidos(recognizedText);
    String? nomeCandidato;
    bool proximaLinhaENome = false;

    for (String linha in linhas) {
      String linhaTrimmed = linha.trim();
      String linhaUpper = linhaTrimmed.toUpperCase();

      if (!proximaLinhaENome && nome != null) break;

      if (linhaTrimmed.isEmpty || linhaTrimmed.contains(RegExp(r'\d'))) {
        proximaLinhaENome = false;
        continue;
      }

      if (proximaLinhaENome) {
        final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

        if (palavrasNaLinha.length >= 2 && !linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE") && !linhaUpper.contains("FILIAÇÃO")) {
          nome = linhaTrimmed;
          break;
        }
        proximaLinhaENome = false;
      }

      if (linhaUpper == 'NOME' || linhaUpper.contains("NOME:")) {

        if (linhaUpper.contains("NOME:") && !linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE")) {
          String nomeExtraido = linhaTrimmed.substring(linhaUpper.indexOf("NOME:") + 5).trim();
          if (nomeExtraido.split(RegExp(r'\s+')).length >= 2) {
            nome = nomeExtraido;
            break;
          }
        }

        if (nome == null) {
          proximaLinhaENome = true;
        }
        continue;
      }

      final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (palavrasNaLinha.length >= 2 && palavrasNaLinha.length <= 8) {

        if (!linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE") && !linhaUpper.contains("FILIAÇÃO")) {
          nomeCandidato = linhaTrimmed;
        } else if (nomeCandidato == null) {
          nomeCandidato = linhaTrimmed;
        }
      }
    }

    nome ??= nomeCandidato;

    eliminarRuidos(recognizedText);

    return PatientModel(
      cpf: cpf ?? '',
      nome: nome ?? '',
      dataNascimento: dataNascimento ?? '',
      guesses: guesses.map((e) => e.toString()).toList(),
    );
  }

  static List<String> eliminarRuidos(RecognizedText recognizedText){
    List<String> semRuido = [];

    const palavrasDescarte = [
      'INSTITUTO', 'EXPEDIÇÃO', 'VIA', 'DOC', 'MINISTERIO',
      'EMPREGO', 'CARTEIRA', 'TRABALHO', 'DIRETOR',
      'IDENTIFICAÇÃO', 'REPÚBLICA', 'FEDERATIVA', 'DOCUMENTO',
      'ASSINATURA', 'VALIDADE', 'DISTRITO', 'DETRAN', 'ESTADO',
      'PROCURADOR', 'PROPRIETÁRIO', 'GOVERNO', 'FEDERAL', 'SOCIAL',
      'SEXO', 'SEX', 'NACIONALIDADE', 'NATURALIDADE', 'SECRETARIA', 'HABILTAÇAO'
      'DATA', 'DATE', 'REGISTRO', 'PERSONAL', 'OF', 'BIRTH', 'TODO',
      'TERRITORIO', 'NACIONAL'
    ];

    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        String linhaTextoUpper = line.text.toUpperCase();
        bool contemPalavraDescarte = false;
        for (String palavra in palavrasDescarte) {
          if (linhaTextoUpper.contains(palavra.toUpperCase())) {
            contemPalavraDescarte = true;
            break;
          }
        }
        if (!contemPalavraDescarte) {
          semRuido.add(line.text);
        }
      }
    }

    print('semrido');
    print(semRuido);
    return semRuido;
  }
}