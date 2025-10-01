import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/models/massege_model.dart';
import 'package:webcam_doc/utils/extrair_dados_de_patient.dart';

import '../controllers/document_controller.dart';


class DocumentoPage extends GetView<DocumentController> {

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

    // controller = cameraController;

    try {
      await cameraController.initialize();
    } on CameraException catch (error) {
      debugPrint('Erro ao inicializar câmera: ${error.description}');
      // Tratar erro, talvez mostrar um SnackBar
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('Erro ao iniciar câmera: ${error.description}')),
      //   );
      // }
      return; // Sai se a inicialização falhar
    }

    // if (mounted) {
    //   setState(() {});
    // }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.init());
    // size = MediaQuery.of(context).size;

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
      floatingActionButton: Obx(() => FloatingActionButton(
        onPressed: controller.isScanning.value ? null : tirarFoto, // Desabilita enquanto processa
        child: controller.isScanning.value
            ? const CircularProgressIndicator(color: Colors.white)
            : const Icon(Icons.camera_alt),
      ),),
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
        from: 'documento_page',
        to: 'patient_add_page',
        data: 'dadosPaciente',
        event: 'scan',
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
