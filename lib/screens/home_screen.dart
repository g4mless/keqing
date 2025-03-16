import 'package:flutter/material.dart';
import '../models/conversation.dart';
import '../services/chat_history_service.dart';
import 'chat_screen.dart';
import '../services/model_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChatHistoryService _historyService = ChatHistoryService();
  final ModelService _modelService = ModelService();
  List<Conversation> conversations = [];
  String _selectedModel = 'deepseek-chat';

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _loadSelectedModel();
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
      conversations = loaded;
    });
  }

  void _newChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          conversation: Conversation.create(),
          onConversationUpdated: _loadConversations,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keqing'),
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
      body: conversations.isEmpty
          ? Center(
              child: Text(
                'No conversations yet',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.builder(
              itemCount: conversations.length,
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                return ListTile(
                  title: Text(conversation.title),
                  subtitle: Text(
                    conversation.messages.isNotEmpty
                        ? conversation.messages.last['content']!
                        : 'No messages',
                    maxLines: 2,
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          conversation: conversation,
                          onConversationUpdated: _loadConversations,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newChat,
        child: const Icon(Icons.add),
      ),
    );
  }
}