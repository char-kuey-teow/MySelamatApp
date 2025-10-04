import 'package:flutter/material.dart';
import 'text_chatbot.dart';
import 'config_helper.dart';

void main() {
  // Print configuration status on startup
  ConfigHelper.printConfigStatus();
  runApp(const LexTestApp());
}

class LexTestApp extends StatelessWidget {
  const LexTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Amazon Lex Chatbot Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Public Sans',
      ),
      home: const TextChatbotScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
