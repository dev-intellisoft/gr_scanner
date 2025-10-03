import 'dart:async'; // Importe o dart:async para usar o Timer
import 'package:flutter/material.dart';

enum DialogType { success, error }

class AppAlertDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String content,
    required DialogType type,
    String confirmButtonText = 'OK',
    String? retryButtonText,
    VoidCallback? onConfirm,
    VoidCallback? onRetry,
    Duration? autoCloseDuration, // Novo parâmetro para o fechamento automático
  }) async {
    // Determina a cor com base no tipo de diálogo
    final Color titleColor = (type == DialogType.success)
        ? Colors.green.shade700
        : Colors.red.shade700;

    // Constrói a lista de ações (botões)
    final List<Widget> actions = [];

    // Adiciona o botão de "Tentar Novamente" se o texto for fornecido
    if (retryButtonText != null && onRetry != null) {
      actions.add(
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetry();
          },
          child: Text(retryButtonText),
        ),
      );
    }

    // Adiciona o botão de confirmação principal
    actions.add(
      TextButton(
        onPressed: () {
          Navigator.of(context).pop();
          onConfirm?.call();
        },
        child: Text(confirmButtonText),
      ),
    );

    // Inicia o timer para fechar o diálogo automaticamente, se a duração for fornecida
    if (autoCloseDuration != null) {
      // Usamos um Timer.run para garantir que o código seja executado após a renderização do frame atual
      Timer(autoCloseDuration, () {
        // Verifica se o diálogo ainda está na tela antes de tentar fechá-lo
        if (Navigator.of(context, rootNavigator: true).canPop()) {
          Navigator.of(context, rootNavigator: true).pop();
          // Executa a ação de confirmação ao fechar automaticamente, se houver
          onConfirm?.call();
        }
      });
    }

    // Exibe o diálogo
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: TextStyle(color: titleColor)),
          content: SingleChildScrollView(
            child: Text(content),
          ),
          actions: actions,
        );
      },
    );
  }
}
