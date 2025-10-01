import 'dart:convert';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class DocumentController extends GetxController {
  final _channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.39:3001/ws/documento_page')
  );

  RxBool isScanning = false.obs;
  RxList<CameraDescription> cameras = <CameraDescription>[].obs;
  Rx<CameraController?> cameraController = Rx<CameraController?>(null);
  Rx<XFile?> imagem = Rx<XFile?>(null);
  Rx<Size?> size = Rx<Size?>(null);
  RxString textoExtraido = ''.obs;

  Future<void> init() async {
    await loadCameras();

    _channel.stream.listen((message) {
      final data = jsonDecode(message);
      debugPrint('Dados recebidos via WebSocket: $data');
      if (data['data'] == 'scanner') {
        Future.delayed(const Duration(milliseconds: 500), () {
          tirarFoto();
        });
      }
    }, onDone: () {
    });
  }


  Future<void> loadCameras() async {
    try {
      cameras.value = await availableCameras();
      if (cameras.isEmpty) {
        Get.snackbar('Erro', 'Nenhuma câmera disponível');
        return;
      }

      startCamera();
    } on CameraException catch (error) {
      Get.snackbar('Erro', 'Erro ao carregar a câmera: ${error.toString()}');
    }
  }

  Future<void> startCamera() async {
    _previewCamera(cameras.first);
  }

  Future<void> tirarFoto() async {
    if (isScanning.isTrue) return; // Não tira outra foto se já estiver processando

    //

    // if (cameraController != null && cameraController.value.isInitialized) {
    //   if (cameraController.value.isTakingPicture) {
    //     return;
    //   }

    isScanning.value = true;
    imagem.value = null;
    textoExtraido.value = null;

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

}