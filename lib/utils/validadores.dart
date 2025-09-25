mixin Validadores{
  static bool validarDataNascimento(String data) {
    // 1. Verifica o formato usando a regex
    final RegExp dataRegex = RegExp(r'^\d{2}/\d{2}/\d{4}$');
    if (!dataRegex.hasMatch(data)) {
      return false; // O formato não é válido
    }

    // 2. Tenta converter a string para um objeto DateTime
    try {
      List<String> partes = data.split('/');
      int dia = int.parse(partes[0]);
      int mes = int.parse(partes[1]);
      int ano = int.parse(partes[2]);

      final DateTime dataNascimento = DateTime(ano, mes, dia);

      // 3. Verifica se a data é válida e não está no futuro
      final DateTime hoje = DateTime.now();
      return dataNascimento.year == ano && 
            dataNascimento.month == mes && 
            dataNascimento.day == dia &&
            !dataNascimento.isAfter(hoje);

    } catch (e) {
      // A conversão falhou (ex: 31/02/2000)
      return false;
    }
  }

  static bool validarCPF(String cpf) {
    // Remove caracteres não numéricos
    String numerosCPF = cpf.replaceAll(RegExp(r'\D'), '');

    // 1. Verifica se a string tem 11 dígitos após a limpeza
    if (numerosCPF.length != 11) {
      return false;
    }
    
    // 2. Verifica se todos os dígitos são iguais, como '11111111111'
    if (RegExp(r'^(\d)\1*$').hasMatch(numerosCPF)) {
      return false;
    }

    // 3. Calcula e verifica o primeiro dígito verificador
    int soma = 0;
    for (int i = 0; i < 9; i++) {
      soma += int.parse(numerosCPF[i]) * (10 - i);
    }
    int resto = soma % 11;
    int digitoVerificador1 = resto < 2 ? 0 : 11 - resto;

    if (int.parse(numerosCPF[9]) != digitoVerificador1) {
      return false;
    }

    // 4. Calcula e verifica o segundo dígito verificador
    soma = 0;
    for (int i = 0; i < 10; i++) {
      soma += int.parse(numerosCPF[i]) * (11 - i);
    }
    resto = soma % 11;
    int digitoVerificador2 = resto < 2 ? 0 : 11 - resto;

    if (int.parse(numerosCPF[10]) != digitoVerificador2) {
      return false;
    }

    // Se todas as verificações passarem, o CPF é válido
    return true;
  }
}