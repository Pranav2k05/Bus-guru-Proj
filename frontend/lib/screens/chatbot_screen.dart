// FINAL CHATBOT SCREEN — MULTILINGUAL + HINTS + RETRIES + CLEAN UI

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatMessage {
  final String text;
  final bool isUser;
  final String? meta;
  ChatMessage({required this.text, this.isUser = false, this.meta});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({Key? key}) : super(key: key);
  @override
  _ChatbotScreenState createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;
  String _detectedLang = "unknown";

  // For Flutter Web running on Chrome
  static const String BASE_URL = 'http://localhost:5000';
  
  static const String CHAT_PATH = "/api/chatbot/chat";

  Future<Map<String, dynamic>> sendToBackend(
      String text, String? replyLang,
      {int maxRetries = 3}) async {
    final url = Uri.parse("$BASE_URL$CHAT_PATH");

    final Map<String, dynamic> payload = {
      "text": text,
      if (replyLang != null) "reply_lang": replyLang
    };

    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      try {
        final response = await http
            .post(url,
                headers: {"Content-Type": "application/json"},
                body: jsonEncode(payload))
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          return {"ok": true, "data": jsonDecode(response.body)};
        }

        if (response.statusCode == 429 ||
            response.statusCode == 503) {
          await Future.delayed(Duration(milliseconds: attempt * 300));
          continue;
        }

        return {
          "ok": false,
          "status": response.statusCode,
          "body": response.body
        };
      } catch (e) {
        if (attempt < maxRetries) {
          await Future.delayed(Duration(milliseconds: attempt * 300));
          continue;
        }
        return {"ok": false, "error": e.toString()};
      }
    }
    return {"ok": false, "error": "max retries exceeded"};
  }

  Future<void> _sendMessage() async {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return;

    String? hintLang;
    String message = raw;

    if (raw.contains("||")) {
      final parts = raw.split("||").map((e) => e.trim()).toList();
      if (parts.length >= 2) {
        message = parts[0];
        hintLang = parts[1];
      }
    }

    setState(() {
      _messages.insert(0, ChatMessage(text: message, isUser: true));
      _controller.clear();
      _loading = true;
    });

    final reply = await sendToBackend(message, hintLang);
    setState(() => _loading = false);

    if (reply["ok"] == true) {
      final d = reply["data"];
      final botReply = d["reply"] ?? "";
      final lang = d["detected_lang"] ?? "unknown";

      setState(() {
        _detectedLang = lang;
        _messages.insert(
            0,
            ChatMessage(
                text: botReply, isUser: false, meta: "lang: $lang"));
      });
    } else {
      setState(() {
        _messages.insert(
            0,
            ChatMessage(
                text: "(error) ${reply["error"] ?? reply["body"]}",
                isUser: false,
                meta: "error"));
      });
    }
  }

  Widget _bubble(ChatMessage m) {
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: Row(
        mainAxisAlignment:
            m.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: m.isUser ? Colors.blue : Colors.grey[200],
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.text,
                  style: TextStyle(
                      color: m.isUser ? Colors.white : Colors.black),
                ),
                if (m.meta != null)
                  Text(
                    m.meta!,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Assistant"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
                child: Text("Lang: $_detectedLang",
                    style: const TextStyle(fontSize: 14))),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("Say Hi to start chatting"))
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    itemBuilder: (c, i) => _bubble(_messages[i]),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                        hintText:
                            'Type message (add "|| kn", "|| ta", "|| te", "|| hi")',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14))),
                  ),
                ),
                const SizedBox(width: 8),
                _loading
                    ? const CircularProgressIndicator()
                    : IconButton(
                        onPressed: _sendMessage,
                        icon: const CircleAvatar(
                          child: Icon(Icons.send, color: Colors.white),
                        ),
                      )
              ],
            ),
          )
        ],
      ),
    );
  }
}
