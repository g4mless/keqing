import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/openrouter_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final OpenRouterService _service = OpenRouterService();
  final List<Map<String, String>> _messages = [];
  final ScrollController _scrollController = ScrollController();

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
        _scrollToBottom();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildMessageBubble(Map<String, String> message) {
    final isUser = message['role'] == 'user';
    final text = message['content']!;
    
    // Process LaTeX and roleplay text
    final processedText = text.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$|\$(.*?)\$', dotAll: true),
      (match) {
        final isBlock = match.group(1) != null;
        final formula = (isBlock ? match.group(1) : match.group(2))?.trim() ?? '';
        return isBlock ? '\n\n!math[$formula]\n\n' : '!math[$formula]';
      },
    );

    final formattedText = !isUser && processedText.contains('"')
        ? processedText.replaceAllMapped(
            RegExp(r'(?:^|\n)_?([^"]+?)_?\n?"'),
            (match) => '_${match[1]?.trim()}_\n"'
          )
        : processedText;
    
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
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message copied to clipboard')),
            );
          },
          child: MarkdownBody(
            data: formattedText,
            builders: {
              'math': MathBuilder(),
            },
            styleSheet: MarkdownStyleSheet(
              p: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.4,
                letterSpacing: 0.2,
              ),
              em: const TextStyle(
                color: Colors.white70,
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
            ),
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
              controller: _scrollController,
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

class MathBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Math.tex(
        element.textContent,
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
        mathStyle: MathStyle.text,
      ),
    );
  }
}