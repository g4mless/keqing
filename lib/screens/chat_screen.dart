import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:markdown/markdown.dart' as md;
import '../services/openrouter_service.dart';
import '../services/chat_history_service.dart';
import '../services/model_service.dart';
import '../models/conversation.dart';

class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback onConversationUpdated;

  const ChatScreen({
    super.key,
    required this.conversation,
    required this.onConversationUpdated,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final List<Map<String, String>> _messages;
  final TextEditingController _controller = TextEditingController();
  final OpenRouterService _service = OpenRouterService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final ModelService _modelService = ModelService();
  final ScrollController _scrollController = ScrollController();
  
  String _selectedModel = 'deepseek-chat';
  List<Conversation> _conversations = [];

  @override
  void initState() {
    super.initState();
    _messages = widget.conversation.messages;
    _loadSelectedModel();
    _loadConversations();
  }

  Future<void> _loadSelectedModel() async {
    final model = await _modelService.getSelectedModel();
    setState(() {
      _selectedModel = model;
    });
  }

  Future<void> _loadConversations() async {
    final loaded = await _historyService.loadConversations();
    setState(() {
      _conversations = loaded;
    });
  }

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

      if (_messages.length == 2) {
        final title = _messages.first['content']!;
        widget.conversation.title = title.length > 30 
            ? '${title.substring(0, 27)}...' 
            : title;
      }

      await _historyService.saveConversation(widget.conversation);
      _loadConversations();
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
        title: Text(widget.conversation.title),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Select Model',
            initialValue: _selectedModel,
            onSelected: (String model) async {
              await _modelService.setSelectedModel(model);
              setState(() {
                _selectedModel = model;
              });
            },
            itemBuilder: (BuildContext context) {
              return ModelService.models.entries.map((entry) {
                return PopupMenuItem<String>(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(
                        _selectedModel == entry.key
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        size: 20,
                        color: _selectedModel == entry.key
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(entry.value),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              height: kToolbarHeight, // Standard AppBar height
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              alignment: Alignment.centerLeft,
              child: const Text(
                'Conversations',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _conversations.length,
                itemBuilder: (context, index) {
                  final conversation = _conversations[index];
                  return ListTile(
                    title: Text(conversation.title),
                    subtitle: Text(
                      conversation.messages.isNotEmpty
                          ? conversation.messages.last['content']!
                          : 'No messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    leading: const Icon(Icons.chat_outlined),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await _historyService.deleteConversation(conversation.id);
                        _loadConversations();
                      },
                    ),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            conversation: conversation,
                            onConversationUpdated: widget.onConversationUpdated,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('New Chat'),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      conversation: Conversation.create(),
                      onConversationUpdated: widget.onConversationUpdated,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.newline,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(right: 4),
                          child: IconButton(
                            icon: const Icon(Icons.send),
                            onPressed: _sendMessage,
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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