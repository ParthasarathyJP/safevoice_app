import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('About')),
      body: Center(child: Text('About SafeVoice: This app is designed to help users quickly contact emergency services and share their location in case of danger. It also provides an AI chatbot for support and guidance.')),
    );
  }
}