import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/models/massege_model.dart';
import 'package:webcam_doc/utils/extrair_dados_de_patient.dart';


class DocumentoPage extends StatefulWidget {
  const DocumentoPage({super.key});

  @override
  State<DocumentoPage> createState() => _DocumentoPageState();
}

class _DocumentoPageState extends State<DocumentoPage> {
  static const String _from = 'app_scanner';

  final _channel = WebSocketChannel.connect(
    Uri.parse('${dotenv.env['WEBSOCKET_URL_TEST']}/$_from')
  );

  List<CameraDescription> cameras = [];
  CameraController? controller;
  XFile? imagem;
  Size? size;
  String? textoExtraido;

  String? to;
  String? from;

  bool _isScanning = false;

  _init() async {
    await _loadCameras();

    _channel.stream.listen((message) {
      Map<String, dynamic> data = jsonDecode(message);
      if (data['event'] == 'CUSTOM_EVENT') {
        to = data['from'];
        Future.delayed(const Duration(milliseconds: 500), () {
          tirarFoto();
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  _loadCameras() async {
    try {
      cameras = await availableCameras();
      if (cameras.isNotEmpty){
        _startCamera();
      } else {
        debugPrint('Nenhuma câmera disponível');
      }
    } on CameraException catch (error) {
      debugPrint('Erro ao carregar a câmera: ${error.toString()}');
    }
  }

  _startCamera() {
    _previewCamera(cameras.first);
  }

  _previewCamera(CameraDescription camera) async {
    if(controller != null) {
      await controller!.dispose();
    }
    final CameraController cameraController = CameraController(
      camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    controller = cameraController;

    try {
      await cameraController.initialize();
    } on CameraException catch (error) {
      debugPrint('Erro ao inicializar câmera: ${error.description}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar câmera: ${error.description}')),
        );
      }
      return;
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
          Expanded(child: Center(child: _arquivoWidget())),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : tirarFoto,
        child: _isScanning
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _arquivoWidget() {
    return SizedBox(
        width: size!.width - 50,
        height: size!.height - (size!.height / 3),
        child: imagem == null || !_isScanning
            ? _cameraPreviewWidget()
            : Image.file(File(imagem!.path), fit: BoxFit.contain)
    );
  }

  Widget _cameraPreviewWidget() {
    final cameraController = controller;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    } else {
      return CameraPreview(controller!);
    }
  }

  Future<void> tirarFoto() async {
    if (_isScanning) return;

    CameraController? cameraController = controller;

    if (cameraController != null && cameraController.value.isInitialized) {
      if (cameraController.value.isTakingPicture) {
        return;
      }

      setState(() {
        _isScanning = true;
        imagem = null;
        textoExtraido = null;
      });

      try {
        XFile file = await cameraController.takePicture();

        if (mounted) {
          setState(() {
          imagem = file;
          });
        }

        await processarImagem(file);
      } on CameraException catch (e) {
        debugPrint('Erro ao tirar foto: ${e.description}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao tirar foto: ${e.description}')),
          );
        }
        if (mounted) {
          setState(() {
            _isScanning = false;
            imagem = null;
          });
        }
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

      final dadosPaciente = ExtrairDadosDePatient.analisarTextoParaPaciente(recognizedText);

      if (mounted) {
        setState(() {
          textoExtraido = recognizedText.text;
        });
      }

      final MassegeModel message = MassegeModel(
        from: _from,
        to: to ?? 'app_server',
        data: 'dadosPaciente',
        event: 'CUSTOM_EVENT',
        patient: dadosPaciente,
      );

      _channel.sink.add(jsonEncode(message.toJson()));

      debugPrint('Dados enviados via WebSocket: ${jsonEncode(message.toJson())}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados de documento extraídos e enviados!')),
        );
      }
    } catch (e) {
      debugPrint('Erro ao processar a imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao processar imagem: $e')),
        );
      }
    } finally {
      await textRecognizer.close();
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _channel.sink.close();
    controller?.dispose();
    super.dispose();
  }
}
