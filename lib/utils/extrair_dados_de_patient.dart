// [1] Seu arquivo: /home/tharlissampaio/Documentos/git/webcam_doc/webcam_doc/lib/utils/extrair_dados_de_patient.dart
import 'package:webcam_doc/models/patient_model.dart';

mixin ExtrairDadosDePatient {
  // Função para remover caracteres não numéricos (você já deve ter algo similar)
  static String _onlyDigits(String text) {
    return text.replaceAll(RegExp(r'[^\d]'), '');
  }

  static PatientModel analisarTextoParaPaciente(String texto) { // Alterar o tipo de retorno
    String? cpf; // Usar tipos nullable para os campos de Patient
    String? nome;
    String? dataNascimento;

    // 1. Encontrar o CPF
    final cpfRegex = RegExp(r'\d{3}[.\s]?\d{3}[.\s]?\d{3}[-.\s]?\d{2}');
    final cpfMatch = cpfRegex.firstMatch(texto);

    if (cpfMatch != null) {
      String cpfLimpo = _onlyDigits(cpfMatch.group(0)!);
      if (cpfLimpo.length == 11) {
        cpf = cpfLimpo; // Atribui à variável local
      }
    }

    // 2. Encontrar Data de Nascimento (DD/MM/AAAA)
    final dataNascimentoRegex = RegExp(r'\d{2}[/\- ]\d{2}[/\- ]\d{4}');
    final dataMatch = dataNascimentoRegex.firstMatch(texto);

    if (dataMatch != null) {
      String dataNormalizada = dataMatch.group(0)!.replaceAll(RegExp(r'[\- ]'), '/');
      // Adicionar validação se a data é plausível (opcional, mas recomendado)
      dataNascimento = dataNormalizada; // Atribui à variável local
    }

    // 3. Encontrar o Nome
    final List<String> linhas = texto.split('\n');
    for (String linha in linhas) {
      String linhaTrimmed = linha.trim();

      // Ignora linhas que parecem títulos ou contêm muitos números
      // Ajuste: Apenas permitir alguns dígitos se for parte de um nome (ex: "João Carlos II")
      // ou se for um campo que não seja o nome principal.
      // Para o nome, geralmente queremos evitar linhas que são SÓ números.
      if (linhaTrimmed.isEmpty || (_onlyDigits(linhaTrimmed).length > 4 && _onlyDigits(linhaTrimmed).length == linhaTrimmed.replaceAll(" ", "").length) ) {
        continue;
      }

      final palavrasNaLinha = linhaTrimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();

      // Se tiver 2 ou mais palavras (ajustado de 3 para ser um pouco mais flexível)
      // e a primeira palavra começar com maiúscula, e não parecer ser um CPF ou data.
      // A condição de "começar com maiúscula" pode ser falha com OCR,
      // então pode ser necessário relaxar ou melhorar a lógica.
      if (palavrasNaLinha.length >= 2 &&
          palavrasNaLinha.first.isNotEmpty && // Garantir que não está vazio
          // palavrasNaLinha.first[0] == palavrasNaLinha.first[0].toUpperCase() && // OCR pode falhar aqui
          !cpfRegex.hasMatch(linhaTrimmed) && // Não é um CPF
          !dataNascimentoRegex.hasMatch(linhaTrimmed.replaceAll("/", ""))) { // Não é uma data (removendo barras para o regex da data)

        // Lógica para evitar pegar campos como "NOME DO PAI" ou "NOME DA MÃE" se houver um campo "NOME:" explícito.
        // Esta parte pode ficar bem complexa e específica para o layout do documento.
        // Uma abordagem simples: se a linha contiver "NOME" e não for "NOME DO PAI/MÃE", priorize.
        if (linhaTrimmed.toUpperCase().contains("NOME:") && !linhaTrimmed.toUpperCase().contains("PAI") && !linhaTrimmed.toUpperCase().contains("MÃE")) {
          nome = linhaTrimmed.substring(linhaTrimmed.toUpperCase().indexOf("NOME:") + 5).trim(); // Pega o que vem depois de "NOME:"
          break;
        } else {
          nome ??= linhaTrimmed;
        }
      }
    }
    // Se após o loop um nome genérico foi pego, e depois um "NOME:" foi encontrado,
    // o "NOME:" terá substituído o genérico. Se não, o último candidato a nome é usado.

    // Construir e retornar o objeto Patient
    return PatientModel(
      cpf: cpf!,
      nome: nome!,
      dataNascimento: dataNascimento!,
    );
  }
}
    