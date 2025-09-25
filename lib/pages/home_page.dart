import 'package:flutter/material.dart';
import 'package:webcam_doc/pages/documento_page.dart';
import 'package:webcam_doc/websocket/comunicacao_websocket.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
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
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.black.withOpacity(0.5),
            child: IconButton(
              icon: Icon(Icons.scanner, color: Colors.white, size: 30,),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MyWidget(), fullscreenDialog: true)),
            ),
          )
        ],
      ),
    );
  }
}