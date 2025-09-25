import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/utils/validadores.dart';

class ExbicaoTextoExtraido extends StatefulWidget {
  final List<String>? textoExtraido;

  const ExbicaoTextoExtraido(this.textoExtraido, {super.key});

  @override
  State<ExbicaoTextoExtraido> createState() => _ExbicaoTextoExtraidoState();
}

class _ExbicaoTextoExtraidoState extends State<ExbicaoTextoExtraido> {
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://192.168.18.246:3001/ws/documentoPage')
  );

  late String nomeCompleto;
  late String cpf;
  late String dataNascimento = '';

  @override
  void initState() {
    super.initState();
    _extrairDados(widget.textoExtraido!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Dados'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          Padding(padding: EdgeInsets.all(8.0),
          child: Text('nome $nomeCompleto'),),
          Padding(padding: EdgeInsets.all(8.0),
          child: Text('Data de Nascimento $dataNascimento'),),
          Padding(padding: EdgeInsets.all(8.0),
          child: Text('CPF: $cpf'),),
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: Icon(Icons.send, color: Colors.white, size: 30),
              onPressed: () => sendMessage({
                "nome": nomeCompleto,
                "cpf": cpf,
                "dataNascimento": dataNascimento
              }),
            ),
          )
        ],
      ),
    );
  }



  void _extrairDados(List<String> palavras) {

    for (int i = 0; i < palavras.length; i++) {
      if (Validadores.validarCPF(palavras[i])) {
        cpf = palavras[i];
      }

      if (Validadores.validarDataNascimento(palavras[i]) && palavras[i].toLowerCase().contains('nasc')){
        dataNascimento = palavras[i];
      }

      if (palavras[i].contains('NOME')) {
        nomeCompleto = palavras[i + 1];
      }
    }
  }
  void sendMessage(Map<String, dynamic> dadosCliente) {
    final String data = '{"from":"documentoPage", "to":"postman", "event":"CUSTOM_EVENT", "data":"$dadosCliente"}';

    _channel.sink.add(data);
  }
}
