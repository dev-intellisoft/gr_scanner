import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webcam_doc/pages/documento_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final _channel = WebSocketChannel.connect(
        Uri.parse('ws://192.168.1.18:3001/ws/documentoPage')
    );


    _channel.stream.listen((data) {
      try {
        Map<String, dynamic> message = jsonDecode(data);
        if(message["data"] == "scanner"){
          Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentoPage(), fullscreenDialog: true));
        }
      } catch(e) {
        debugPrint(e.toString());
      }
    });

    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: Icon(Icons.camera_alt, color: Colors.white, size: 30),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DocumentoPage(), fullscreenDialog: true)),
            ),
          ),
        ],
      ),
    );
  }
}