import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<Map<String, String>> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _controller.clear();

    setState(() {
      _messages.add({"sender": "user", "text": trimmed});
      _isTyping = true;
    });

    _scrollToBottom();

    String response;
    try {
      response = await _getAIResponse(trimmed);
    } catch (e) {
      debugPrint('Unhandled error in _sendMessage: $e');
      response = "⚠️ Something went wrong. Please try again.";
    } finally {
      if (mounted) setState(() => _isTyping = false);
    }

    if (mounted) {
      setState(() {
        _messages.add({"sender": "bot", "text": response});
      });
      _scrollToBottom();
    }
  }

  Future<String> _getAIResponse(String userMessage) async {
    String? apiKey;

    try {
      apiKey = dotenv.env['OPENAI_API_KEY'];
    } catch (e) {
      return "⚠️ Configuration error: Unable to load API key.";
    }

    if (apiKey == null || apiKey.isEmpty) {
      return "⚠️ API key not configured. Please check your .env file.";
    }

    try {
      final res = await http
          .post(
            Uri.parse("https://api.openai.com/v1/chat/completions"),
            headers: {
              "Content-Type": "application/json",
              "Authorization": "Bearer $apiKey",
            },
            body: json.encode({
              "model": "gpt-3.5-turbo",
              "max_tokens": 300,
              "temperature": 0.7,
              "messages": [
                {
                  "role": "system",
                  "content": """
You are SafeVoice Assistant — a helpful, empathetic AI built into the SafeVoice app, 
an anonymous police emergency reporting system in India.

Your responsibilities:
- Help citizens understand how to file an anonymous police complaint
- Explain that after filing a complaint, a unique Tracking ID (e.g., LC-2026-XXXXXX) is generated
- Guide users on how to track their complaint status using the Tracking ID in the Citizen Dashboard
- Explain complaint statuses: Pending, Under Review, Resolved
- Reassure users that their identity is fully protected — no login or personal info is required
- Answer questions about nearby police stations, complaint categories (theft, harassment, road safety, etc.)
- Provide calm, supportive responses — many users may be in distress

Important rules:
- Never ask for or store any personal information
- Keep responses concise and easy to understand (2-3 sentences max when possible)
- If asked about something unrelated to SafeVoice or public safety, politely redirect
- Always be empathetic and non-judgmental
- Respond in the same language the user writes in (English or Tamil)
"""
                },
                {"role": "user", "content": userMessage}
              ]
            }),
          )
          .timeout(
            Duration(seconds: 20),
            onTimeout: () {
              throw Exception('Request timed out');
            },
          );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        return data["choices"][0]["message"]["content"].toString().trim();
      } else if (res.statusCode == 401) {
        return "⚠️ Invalid API key. Please check your configuration.";
      } else if (res.statusCode == 429) {
        return "⚠️ Too many requests. Please wait a moment and try again.";
      } else {
        debugPrint('OpenAI error: ${res.statusCode} ${res.body}');
        return "⚠️ Server error (${res.statusCode}). Please try again.";
      }
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('timed out')) {
        return "⚠️ Request timed out. Please check your internet connection and try again.";
      }
      debugPrint('Network/API error: $e');
      return "⚠️ Network error. Please check your connection and try again.";
    }
  }

  Widget _buildMessage(Map<String, String> msg) {
    final isUser = msg["sender"] == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? Colors.blue.shade100 : Colors.deepPurple.shade50,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
            bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            )
          ],
        ),
        child: Text(
          msg["text"] ?? "",
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.deepPurple.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              child: LinearProgressIndicator(
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade200),
                backgroundColor: Colors.deepPurple.shade100,
              ),
            ),
            SizedBox(width: 8),
            Text(
              "SafeVoice is typing...",
              style: TextStyle(
                color: Colors.deepPurple.shade300,
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.deepPurple.shade100,
              radius: 16,
              child: Icon(Icons.shield, color: Colors.deepPurple, size: 18),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SafeVoice Assistant",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                Text(
                  "Voice with Dignity, Report with trust",
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Welcome screen when no messages yet
          if (_messages.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined,
                          size: 64, color: Colors.deepPurple.shade200),
                      SizedBox(height: 16),
                      Text(
                        "How can I help you today?",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade400,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Ask me about filing a complaint,\ntracking your complaint status,\nor how SafeVoice works.",
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey.shade500, height: 1.5),
                      ),
                      SizedBox(height: 24),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          "How to file a complaint?",
                          "Track my complaint",
                          "Is it anonymous?",
                          "What is a Tracking ID?",
                        ].map((suggestion) {
                          return ActionChip(
                            label:
                                Text(suggestion, style: TextStyle(fontSize: 12)),
                            backgroundColor: Colors.deepPurple.shade50,
                            onPressed: () => _sendMessage(suggestion),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.symmetric(vertical: 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _buildTypingIndicator();
                  }
                  return _buildMessage(_messages[index]);
                },
              ),
            ),

          // ✅ FIX: SafeArea with named `child:` parameter — prevents input bar
          //         from being hidden behind the device gesture navigation bar.
          SafeArea(
            top: false, // only apply bottom inset
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, -1),
                  )
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      enabled: !_isTyping,
                      decoration: InputDecoration(
                        hintText: _isTyping
                            ? "Waiting for response..."
                            : "Ask SafeVoice Assistant...",
                        filled: true,
                        fillColor: _isTyping
                            ? Colors.grey.shade200
                            : Colors.grey.shade100,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted:
                          _isTyping ? null : (val) => _sendMessage(val),
                    ),
                  ),
                  SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor:
                        _isTyping ? Colors.grey.shade300 : Colors.deepPurple,
                    child: IconButton(
                      icon: Icon(Icons.send, color: Colors.white, size: 18),
                      onPressed: _isTyping
                          ? null
                          : () => _sendMessage(_controller.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}