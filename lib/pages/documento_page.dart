import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
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
  final _channel = WebSocketChannel.connect(
    Uri.parse('') // endereço do websocket
  );

  List<CameraDescription> cameras = [];
  CameraController? controller;
  XFile? imagem;
  Size? size;
  String? textoExtraido;

  bool _isScanning = false;

  _init() async {
    await _loadCameras();

    _channel.stream.listen((message) {
      Map<String, dynamic> data = jsonDecode(message);
      if (data['data'] == 'scanner') {
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
      // Tratar erro, talvez mostrar um SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar câmera: ${error.description}')),
        );
      }
      return; // Sai se a inicialização falhar
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
          // if (textoExtraido != null)
          //   Padding(
          //     padding: const EdgeInsets.all(16.0),
          //     child: Text('${ExtrairDadosDePatient.analisarTextoParaPaciente(textoExtraido!).toString()}}')
          //   ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : tirarFoto, // Desabilita enquanto processa
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
        // Mostra a câmera se a imagem for nula ou se _isProcessing for falso (para voltar à preview)
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
      // return Stack(
      //   alignment: AlignmentDirectional.bottomCenter,
      //   children: [
      //     CameraPreview(controller!),
      //     _botaoCapturarWidget()],
      // );
      return CameraPreview(controller!);
    }
  }

  Future<void> tirarFoto() async {
    if (_isScanning) return; // Não tira outra foto se já estiver processando

    CameraController? cameraController = controller;

    if (cameraController != null && cameraController.value.isInitialized) {
      if (cameraController.value.isTakingPicture) {
        return;
      }

      setState(() {
        _isScanning = true; // Define que está processando
        imagem = null; // Limpa a imagem anterior para garantir que a preview seja mostrada
        // ou para evitar mostrar a imagem antiga rapidamente antes da nova.
        textoExtraido = null; // Limpa o texto anterior
      });

      try {
        XFile file = await cameraController.takePicture();

        if (mounted) {
          setState(() {
          imagem = file;
          });
        }

        // Chame a função para processar a imagem e extrair o texto
        await processarImagem(file);
      } on CameraException catch (e) {
        debugPrint('Erro ao tirar foto: ${e.description}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao tirar foto: ${e.description}')),
          );
        }
        // Mesmo com erro, reseta o _isProcessing
        if (mounted) {
          setState(() {
            _isScanning = false;
            imagem = null; // Opcional: limpar a imagem em caso de erro na captura
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
        from: 'documentoPage',
        to: 'postman',
        event: 'CUSTOM_EVENT',
        data: dadosPaciente,
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

  void sendMessage(Map<String, dynamic> dadosPaciente) {
    final String data = '{"from":"documentoPage", "to":"postman", "event":"CUSTOM_EVENT", "data":"$dadosPaciente"}';

    _channel.sink.add(data);
  }

  @override
  void dispose() {
    _channel.sink.close();
    controller?.dispose();
    super.dispose();
  }
}
