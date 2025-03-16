import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../services/openrouter_service.dart';

class ChatScreen extends StatefulWidget{
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final OpenRouterService _service = OpenRouterService();
  final List<Map<String, String>> _messages = [];

  Future<void> _sendMessage() async {
    if (_controller.text.isEmpty) return;
    
    final userMessage = _controller.text;
    setState(() {
      _messages.add({'role': 'user', 'content': userMessage});
    });
    _controller.clear();

    try {
      setState(() {
        _messages.add({'role': 'assistant', 'content': ''});
      });

      await for (final response in _service.sendMessageStream(userMessage)) {
        setState(() {
          _messages.last['content'] = response;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final text = message['content']!;
    
    // Format roleplay text with italics for assistant messages
    final formattedText = !isUser && text.contains('"')
        ? text.replaceAllMapped(
            RegExp(r'^([^"]+)|("\n\n[^"]+)'),
            (match) => '_${match.group(0)}_'
          )
        : text;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF673AB7) : const Color(0xFF4A148C),
          borderRadius: BorderRadius.circular(12),
        ),
        child: MarkdownBody(
          data: formattedText,
          styleSheet: MarkdownStyleSheet(
            p: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
              letterSpacing: 0.2,
            ),
            em: const TextStyle(
              color: Colors.white70,  // Slightly dimmed italic text
              fontSize: 16,
              height: 1.4,
              fontStyle: FontStyle.italic,
            ),
            code: const TextStyle(
              color: Colors.white,
              backgroundColor: Colors.black26,
              fontSize: 14,
              fontFamily: 'monospace',
            ),
            codeblockDecoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            blockquote: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              height: 1.4,
            ),
            listBullet: const TextStyle(color: Colors.white),
            strong: const TextStyle(color: Colors.white),
            // em style is already defined for descriptive text
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keqing'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) => _buildMessageBubble(_messages[index]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}