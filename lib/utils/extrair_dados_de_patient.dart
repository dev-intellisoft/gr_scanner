import 'package:flutter/cupertino.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';
import 'package:webcam_doc/models/patient_model.dart';

mixin ExtrairDadosDePatient {
  static String _onlyDigits(String text) {
    return text.replaceAll(RegExp(r'[^\d]'), '');
  }

  static PatientModel analisarTextoParaPaciente(RecognizedText recognizedText) {
    String texto = recognizedText.text;
    String? cpf;
    String? name;
    DateTime? birthDate;
    List<String> posibilities = [];

    final cpfRegex = RegExp(r'\b\d{3}[.\s]?\d{3}[.\s]?\d{3}[-.\s]?\d{2}\b');
    final cpfMatch = cpfRegex.firstMatch(texto);
    if (cpfMatch != null) {
      String cpfLimpo = _onlyDigits(cpfMatch.group(0)!);
      if (cpfLimpo.length == 11) {
        cpf = cpfLimpo;
      }
    }

    birthDate = encontrarMenorData(texto);

    final List<String> linhas = eliminarRuidos(recognizedText);
    String? nameCandidato;
    bool proximaLinhaEname = false;

    for (String linha in linhas) {
      String linhaTrimmed = linha.trim();
      String linhaUpper = linhaTrimmed.toUpperCase();

      if (!proximaLinhaEname && name != null) break;

      if (linhaTrimmed.isEmpty || linhaTrimmed.contains(RegExp(r'\d'))) {
        proximaLinhaEname = false;
        continue;
      }

      if (proximaLinhaEname) {
        final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

        if (palavrasNaLinha.length >= 2 && !linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE") && !linhaUpper.contains("FILIAÇÃO")) {
          name = linhaTrimmed; // name encontrado, sai do loop
          break;
        }
        proximaLinhaEname = false;
      }

      if (linhaUpper == 'NOME' || linhaUpper.contains("NOME:")) {

        if (linhaUpper.contains("NOME:") && !linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE")) {
          String nomeExtraido = linhaTrimmed.substring(linhaUpper.indexOf("NOME:") + 5).trim();
          if (nomeExtraido.split(RegExp(r'\s+')).length >= 2) {
            name = nomeExtraido;
            break;
          }
        }

        if (name == null) { // Só ativa a flag se o name ainda não foi encontrado
          proximaLinhaEname = true;
        }
        continue;
      }

      // Lógica para adicionar candidatos à lista posibilities
      final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (palavrasNaLinha.length >= 2 && palavrasNaLinha.length <= 8) {
        if (!linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE") && !linhaUpper.contains("FILIAÇÃO")) {
          // Adiciona à lista posibilities se não for um name de pai/mãe
          // e se ainda não foi definido como o name principal
          if (name == null && !posibilities.contains(linhaTrimmed)) {
            posibilities.add(linhaTrimmed);
          }
          nameCandidato ??= linhaTrimmed; // Define como candidato se nameCandidato for nulo
        } else if (nameCandidato == null && name == null && !posibilities.contains(linhaTrimmed)) {
          // Adiciona à lista posibilities se for uma linha de filiação,
          // o name principal e o nameCandidato ainda não foram definidos.
          posibilities.add(linhaTrimmed);
          nameCandidato = linhaTrimmed;
        }
      }
    }

    name = nameCandidato ?? posibilities.first;

    return PatientModel(
      cpf: cpf ?? '',
      name: name ?? '',
      birthDate: birthDate,
      posibilities: posibilities.map((e) => e.toString()).toList(),
    );
  }

  static List<String> eliminarRuidos(RecognizedText recognizedText){
    List<String> semRuido = [];

    const palavrasDescarte = [
      'INSTITUTO', 'EXPEDIÇÃO', 'VIA', 'DOC', 'MINISTERIO', 'MINISTÉRIO', 'MINISTÈRIO',
      'EMPREGO', 'CARTEIRA', 'TRABALHO', 'DIRETOR', 'INFRAESTRUTURA', 'TRANSITO'
      'IDENTIFICAÇÃO', 'REPÚBLICA', 'FEDERATIVA', 'DOCUMENTO', 'HAB', 'NACIONAL',
      'ASSINATURA', 'VALIDADE', 'DISTRITO', 'DETRAN', 'ESTADO', 'PERMISSÃO',
      'PROCURADOR', 'PROPRIETÁRIO', 'GOVERNO', 'FEDERAL', 'SOCIAL', 'DATA',
      'SEXO', 'SEX', 'NACIONALIDADE', 'NATURALIDADE', 'SECRETARIA', 'HABILTAÇAO',
      'DATE', 'REGISTRO', 'PERSONAL', 'OF', 'BIRTH', 'TODO',
      'TERRITORIO', 'TERRITÓRIO', 'CNH', 'DOCUMENTO', 'NACIONAL', '.', '/', '-', ':', ',',
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

    return semRuido;
  }

  static DateTime? encontrarMenorData(String texto) {
    final dataRegex = RegExp(r'\b(\d{2}[/\- ]\d{2}[/\- ]\d{4})\b');
    final matches = dataRegex.allMatches(texto);  if (matches.isEmpty) {
      return null;
    }

    List<DateTime> datasEncontradas = [];
    final DateFormat formatoEntrada = DateFormat('dd/MM/yyyy');

    for (final Match m in matches) {
      String dataString = m.group(1)!;
      String dataNormalizada = dataString.replaceAll(RegExp(r'[\- ]'), '/');
      try {
        DateTime data = formatoEntrada.parseStrict(dataNormalizada);
        datasEncontradas.add(data);
      } catch (e) {
        debugPrint("Formato de data inválido encontrado e ignorado: $dataNormalizada");
      }
    }

    if (datasEncontradas.isEmpty) {
      return null;
    }

    datasEncontradas.sort((a, b) => a.compareTo(b));

    return datasEncontradas.first;
  }

}