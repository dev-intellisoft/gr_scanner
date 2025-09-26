import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/models/massege_model.dart';
import 'package:webcam_doc/models/patient_model.dart';
import 'package:webcam_doc/utils/extrair_dados_de_patient.dart';


class DocumentoPage extends StatefulWidget {
  const DocumentoPage({super.key});

  @override
  State<DocumentoPage> createState() => _DocumentoPageState();
}

class _DocumentoPageState extends State<DocumentoPage> {
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://192.168.1.18:3001/ws/documentoPage')
  );

  List<CameraDescription> cameras = [];
  CameraController? controller;
  XFile? imagem;
  Size? size;
  String? textoExtraido;
  List<String>? palavras;

  _init() async {
    await _loadCameras();
    // Future.delayed(Duration(seconds: 3), () {
    //   tirarFoto();
    // });
  }

  @override
  void initState() {
    super.initState();
    _init();
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
              child: Text('${ExtrairDadosDePatient.analisarTextoParaPaciente(textoExtraido!).toString()}}')
            ),
        ],
      ),
    );
  }

  Widget _arquivoWidget() {
    return SizedBox(
      width: size!.width - 50,
      height: size!.height - (size!.height / 3),
      child: imagem != null
        ? Image.file(File(imagem!.path), fit: BoxFit.contain)
        : _cameraPreviewWidget(),
    );
  }

  Widget _cameraPreviewWidget() {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
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
        backgroundColor: Colors.black.withValues(),
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
          setState(() {
          imagem = file;
          });
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
    final InputImage inputImage = InputImage.fromFile(File(file.path));
    final textRecognizer = TextRecognizer();

    try {
      final RecognizedText recognizedText = await textRecognizer.processImage(
        inputImage,
      );

      String dadosTexto = recognizedText.text;
      // palavras = dadosTexto.split('\n');

      // 1. Armazene o texto extraído para exibição
      setState(() {
        textoExtraido = dadosTexto;
      });

      // 2. Chame a função de parsing para estruturar os dados
      final dadosPaciente = ExtrairDadosDePatient.analisarTextoParaPaciente(dadosTexto);

      // 3. Verifique se encontramos algo e envie
      // Note o uso de jsonEncode para o corpo da mensagem
      final MassegeModel message = MassegeModel(
        from: 'documentoPage',
        to: 'postman',
        event: 'CUSTOM_EVENT',
        data: dadosPaciente,
      );

      print('ola meu chapa');
      print(message.toString());

      // Envia o JSON completo via WebSocket
      _channel.sink.add(jsonEncode(message));

      debugPrint('Dados enviados via WebSocket: ${jsonEncode(dadosPaciente)}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dados de documento extraídos e enviados!')),
      );


    } catch (e) {
      debugPrint('Erro ao processar a imagem: $e');
    } finally {
      textRecognizer.close();
      controller!.dispose();
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
    controller?.dispose();
  }
}
