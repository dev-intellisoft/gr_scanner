import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/pages/exibicao_texto_extraido.dart';
import '../utils/validadores.dart';

class Patient {
  String? name;
  String? cpf;
  String? dob;

  Patient({
    this.name,
    this.cpf,
    this.dob
  });
}

class DocumentoPage extends StatefulWidget {
  const DocumentoPage({super.key});

  @override
  State<DocumentoPage> createState() => _DocumentoPageState();
}

class _DocumentoPageState extends State<DocumentoPage> {
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://192.168.18.246:3001/ws/documentoPage')
  );
  late String nomeCompleto;
  late String cpf;
  late String dataNascimento;
  
  List<CameraDescription> cameras = [];
  CameraController? controller;
  XFile? imagem;
  Size? size;
  String? textoExtraido;
  List<String>? palavras;

  @override
  void initState() {
    super.initState();
    _loadCameras();
  }

  _loadCameras() async {
    try {
      cameras = await availableCameras();
      _startCamera();
    } on CameraException catch (error) {
      debugPrint(error.toString());
    }
  }

  _startCamera() {
    if (cameras.isEmpty) {
      throw Exception('error em iniciar camera');
    } else {
      _previewCamera(cameras.first);
    }
  }

  _previewCamera(CameraDescription camera) async {
    final CameraController cameraController = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    try {
      await cameraController.initialize();
    } catch (error) {
      debugPrint(error.toString());
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Scanner'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          // Widget que mostra a câmera ou a imagem
          Expanded(child: Center(child: _arquivoWidget())),
          // Exibe o texto extraído, se disponível
          if (textoExtraido != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: IconButton(
                icon: Icon(Icons.send_and_archive),
                onPressed: () => sendMessage({
                  "nome": nomeCompleto,
                  "cpf": cpf,
                  "dataNascimento": dataNascimento
                }),
              ),
            ),
          StreamBuilder(stream: _channel.stream,
            builder: (context, snapshot) {
            print(snapshot.data);
            if (snapshot.data == null){
              return Text('erro');
            } else {
              Map<String, dynamic> message = jsonDecode(snapshot.data);
              if(message['data'] == 'scanner documento'){
                tirarFoto();
                _channel.sink.close();
                Navigator.pop(context);
              } else {
                return Text('comando invalido');
              }
              return Text(message['data']);
            }
            }
          ),
        ],
      ),
    );
  }

  Widget _arquivoWidget() {
    return Container(
      width: size!.width - 50,
      height: size!.height - (size!.height / 3),
      child: imagem != null
          ? Image.file(File(imagem!.path), fit: BoxFit.contain)
          : _cameraPreviewWidget(),
    );
  }

  Widget _cameraPreviewWidget() {
    final CameraController? cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Text('camera não está disponivel');
    } else {
      return Stack(
        alignment: AlignmentDirectional.bottomCenter,
        children: [
          CameraPreview(controller!), 
          _botaoCapturarWidget()],
      );
    }
  }

  Widget _botaoCapturarWidget() {
    return Padding(
      padding: EdgeInsets.only(),
      child: CircleAvatar(
        radius: 32,
        backgroundColor: Colors.black.withOpacity(0.5),
        child: IconButton(
          icon: Icon(Icons.camera_alt, color: Colors.white, size: 30),
          onPressed: tirarFoto,
        ),
      ),
    );
  }

  Future<void> tirarFoto() async {
    CameraController? cameraController = controller;

    if (cameraController != null && cameraController.value.isInitialized) {
      try {
        XFile file = await cameraController.takePicture();

        if (mounted) {
          // setState(() {
          imagem = file;
          // });
        }

        // Chame a função para processar a imagem e extrair o texto
        await processarImagem(file);
      } catch (error) {
        debugPrint(error.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar a foto: $error')),
        );
      }
    }
  }

  Future<void> processarImagem(XFile file) async {
    // Crie um InputImage a partir do arquivo capturado
    final InputImage inputImage = InputImage.fromFile(File(file.path));

    // Crie uma instância do TextRecognizer
    final textRecognizer = TextRecognizer();

    try {
      // Processe a imagem e extraia o texto
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String dados = recognizedText.text;
      palavras = dados.split('\n');

      // Armazene o texto extraído na variável

      textoExtraido = recognizedText.text;


      // Imprima ou use o texto como desejar
      // sendMessage({
      //   "textoExtraido": textoExtraido,
      // });
      debugPrint('Texto extraído: $textoExtraido');
      _extrairDados(palavras!);
    } catch (e) {
      debugPrint('Erro ao processar a imagem: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao extrair texto: $e')));
    } finally {
      // Feche o TextRecognizer para liberar recursos
      textRecognizer.close();
    }
  }

  String onlyDigits(String s) {
    return s.replaceAll(RegExp(r'\D'), '');
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

  void sendMessage(Map<String, dynamic> dadosPaciente) {
    final String data = '{"from":"documentoPage", "to":"postman", "event":"CUSTOM_EVENT", "data":"$dadosPaciente"}';

    _channel.sink.add(data);
  }

  @override
  void dispose() {
    super.dispose();
    _channel.sink.close();
  }
}
