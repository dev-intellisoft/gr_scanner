import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/models/massege_model.dart';

class WebSocketService {
  static const String _from = 'app_scanner';

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  bool _isConnected = false;

  // Stream para que a UI possa ouvir as mensagens recebidas
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  void connect() {
    // Evita múltiplas conexões simultâneas
    if (_isConnected && _channel != null) {
      debugPrint("WebSocket já está conectado.");
      return;
    }
    debugPrint("Tentando conectar ao WebSocket...");
    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(
        Uri.parse('${dotenv.env['WEBSOCKET_URL_TEST']}/$_from'),
      );
      _isConnected = true;

      _channelSubscription?.cancel();
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      debugPrint("Conexão WebSocket estabelecida.");
    } catch (e) {
      debugPrint("Falha ao tentar conectar ao WebSocket: $e");
      _reconnect();
    }
  }

  void _onMessage(dynamic message) {
    debugPrint("Mensagem recebida no serviço: $message");
    final data = jsonDecode(message) as Map<String, dynamic>;
    _messageController.add(data); // Adiciona a mensagem ao stream para a UI
  }

  void _onError(error) {
    debugPrint("Erro no WebSocket: $error");
    _isConnected = false;
    _reconnect();
  }

  void _onDone() {
    debugPrint("WebSocket desconectado. Tentando reconectar...");
    _isConnected = false;
    _reconnect();
  }

  void _reconnect() {
    debugPrint("Agendando reconexão em 5 segundos...");
    Future.delayed(const Duration(seconds: 5), connect);
  }

  void sendMessage(MassegeModel message) {
    if (_isConnected && _channel != null) {
      final jsonMessage = jsonEncode(message.toJson());
      _channel!.sink.add(jsonMessage);
      debugPrint('Dados enviados via WebSocket: $jsonMessage');
    } else {
      debugPrint('Não foi possível enviar a mensagem: WebSocket não conectado.');
      // Opcional: Adicionar a mensagem a uma fila para enviar após a reconexão
    }
  }

  void dispose() {
    _channelSubscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _isConnected = false;
    debugPrint("WebSocketService foi descartado.");
  }
}
