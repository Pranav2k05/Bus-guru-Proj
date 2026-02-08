// lib/widgets/chatbot_fab.dart
import 'package:flutter/material.dart';
import '../screens/chatbot_screen.dart';

class ChatbotFab extends StatelessWidget {
  @override Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: Theme.of(context).colorScheme.secondary,
      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
    );
  }
}
