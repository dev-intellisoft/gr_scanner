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
    String? nome;
    String? dataNascimento;
    List<String> posibilities = [];

    final cpfRegex = RegExp(r'\b\d{3}[.\s]?\d{3}[.\s]?\d{3}[-.\s]?\d{2}\b');
    final cpfMatch = cpfRegex.firstMatch(texto);
    if (cpfMatch != null) {
      String cpfLimpo = _onlyDigits(cpfMatch.group(0)!);
      if (cpfLimpo.length == 11) {
        cpf = cpfLimpo;
      }
    }

    dataNascimento = encontrarMenorData(texto);

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
          nome = linhaTrimmed; // Nome encontrado, sai do loop
          break;
        }
        proximaLinhaENome = false;
      }

      if (linhaUpper == 'NOME' || linhaUpper.contains("NOME:")) {

        if (linhaUpper.contains("NOME:") && !linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE")) {
          String nomeExtraido = linhaTrimmed.substring(linhaUpper.indexOf("NOME:") + 5).trim();
          if (nomeExtraido.split(RegExp(r'\s+')).length >= 2) {
            nome = nomeExtraido; // Nome encontrado, sai do loop
            break;
          }
        }

        if (nome == null) { // Só ativa a flag se o nome ainda não foi encontrado
          proximaLinhaENome = true;
        }
        continue;
      }

      // Lógica para adicionar candidatos à lista posibilities
      final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
      if (palavrasNaLinha.length >= 2 && palavrasNaLinha.length <= 8) {
        if (!linhaUpper.contains("PAI") && !linhaUpper.contains("MÃE") && !linhaUpper.contains("FILIAÇÃO")) {
          // Adiciona à lista posibilities se não for um nome de pai/mãe
          // e se ainda não foi definido como o nome principal
          if (nome == null && !posibilities.contains(linhaTrimmed)) {
            posibilities.add(linhaTrimmed);
          }
          nomeCandidato ??= linhaTrimmed; // Define como candidato se nomeCandidato for nulo
        } else if (nomeCandidato == null && nome == null && !posibilities.contains(linhaTrimmed)) {
          // Adiciona à lista posibilities se for uma linha de filiação,
          // o nome principal e o nomeCandidato ainda não foram definidos.
          posibilities.add(linhaTrimmed);
          nomeCandidato = linhaTrimmed;
        }
      }
    }



    return PatientModel(
      cpf: cpf ?? '',
      name: nome ?? '',
      birthDate: dataNascimento ?? '',
      posibilities: posibilities.map((e) => e.toString()).toList(),
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
      'TERRITORIO', 'NACIONAL', '.', '/', '-', ':', ',',
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

  static String? encontrarMenorData(String texto) {
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

    return formatoEntrada.format(datasEncontradas.first);
  }

}