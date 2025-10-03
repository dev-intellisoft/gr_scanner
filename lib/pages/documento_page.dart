import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:webcam_doc/models/massege_model.dart';
import 'package:webcam_doc/services/web_socket_service.dart';
import 'package:webcam_doc/utils/extrair_dados_de_patient.dart';

import '../shared/alert_dialog.dart';


class DocumentoPage extends StatefulWidget {
  const DocumentoPage({super.key});

  @override
  State<DocumentoPage> createState() => _DocumentoPageState();
}

class _DocumentoPageState extends State<DocumentoPage> {
  static const String _from = 'app_scanner';

  final WebSocketService _webSocketService = WebSocketService();
  StreamSubscription? _webSocketSubscription;

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

    _webSocketService.connect();
    _webSocketSubscription = _webSocketService.messages.listen((data) {
      if (data['event'] == 'CUSTOM_EVENT') {
        to = data['from'];
        if (!_isScanning) tirarFoto();
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
      if (mounted) {
        AppAlertDialog.show(
          context: context,
          title: 'Erro na Câmera',
          content: 'Não foi possível iniciar a câmera. Por favor, verifique as permissões do aplicativo e tente novamente.',
          type: DialogType.error,
          autoCloseDuration: Duration(seconds: 2),
        );
      }
      return;
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
        AppAlertDialog.show(
          context: context,
          title: 'Erro na Câmera',
          content: 'Não foi possível iniciar a câmera. Por favor, verifique as permissões do aplicativo e tente novamente.',
          type: DialogType.error,
          autoCloseDuration: Duration(seconds: 5),);
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
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        backgroundColor: Theme.of(context).primaryColor,
        centerTitle: true,
        title: const Text('Scanner de Documentos', style: TextStyle(color: Colors.white),),
        actions: [
          StreamBuilder<bool>(
            stream: _webSocketService.connectionStatus, // Ouvindo o novo stream
            initialData: _webSocketService.isConnected, // Estado inicial
            builder: (context, snapshot) {
              final isConnected = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Tooltip(
                  message: isConnected ? 'Conectado' : 'Desconectado',
                  child: Icon(
                    Icons.circle,
                    color: isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            _cameraPreviewWidget(),
            if (_isScanning) _buildScanningOverlay(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isScanning ? null : tirarFoto,
        backgroundColor: _isScanning ? Colors.grey : Theme.of(context).primaryColor,
        child: _isScanning
            ? const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        )
            : const Icon(Icons.camera_alt, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              imagem == null
                  ? 'Capturando imagem...'
                  : 'Processando e extraindo dados...',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
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
          // Chamada ao novo diálogo com opção de tentar novamente
          AppAlertDialog.show(
            context: context,
            title: 'Erro na Captura',
            content: 'Ocorreu um problema ao capturar a imagem. Por favor, tente novamente.',
            type: DialogType.error,
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

      _webSocketService.sendMessage(message);

      debugPrint('Dados enviados via WebSocket: ${jsonEncode(message.toJson())}');
      await AppAlertDialog.show(
        context: context,
        title: 'Sucesso!',
        content: 'Os dados do documento foram extraídos e enviados.',
        type: DialogType.success,
        autoCloseDuration: const Duration(seconds: 5),
        onConfirm: () {
          if (mounted) {
            setState(() {
              imagem = null;
            });
          }
        },
      );

    } catch (e) {
      debugPrint('Erro ao processar a imagem: $e');
      if (mounted) {
        await AppAlertDialog.show(
          context: context,
          title: 'Erro no Processamento',
          content: 'Não foi possível extrair os dados. Tente uma imagem mais nítida.',
          type: DialogType.error,
          autoCloseDuration: Duration(seconds: 5),
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
    _webSocketSubscription?.cancel();
    _webSocketService.dispose();
    controller?.dispose();
    super.dispose();
  }
}
