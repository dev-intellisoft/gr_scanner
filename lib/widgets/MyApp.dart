import 'package:flutter/material.dart';
import 'package:webcam_doc/pages/documento_page.dart';
import 'package:webcam_doc/pages/home_page.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Scanner'),
          backgroundColor: Colors.indigo,
        ),
        body: const DocumentoPage(),
      ),
    );
  }
}
