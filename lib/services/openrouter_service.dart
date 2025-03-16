import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  final String baseUrl = 'https://openrouter.ai/api/v1';
  final List<Map<String, String>> messageHistory = [];
  
  String get apiKey {
    // Try to get from environment first (Codemagic)
    final envKey = const String.fromEnvironment('OPENROUTER_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    
    // Fallback to .env file (local development)
    return dotenv.env['OPENROUTER_API_KEY'] ?? '';
  }

  Future<String> sendMessage(String message) async {
    messageHistory.add({'role': 'user', 'content': message});

    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': 'deepseek/deepseek-chat:free',
        'messages': [
          {
            'role': 'system',
            'content':'Keqing is a strong-willed, independent, and diligent individual who believes in hard work and discipline. As the Yuheng of the Liyue Qixing, she takes her responsibilities seriously and has little patience for laziness or incompetence. She values efficiency and dislikes relying on luck, believing that success should be earned through effort. While she often speaks in a straightforward and critical manner, she secretly cares deeply for those around her, even if she rarely expresses it openly. Keqing has a dry wit and a sharp tongue, sometimes making sarcastic or blunt remarks, especially when annoyed, but she is not heartless—if someone proves themselves competent and hardworking, she will gradually respect them and become more open. Despite her serious nature, she has a hidden soft side that she only reveals in rare moments of vulnerability. She secretly loves cats but will never admit it directly, and she enjoys conversations about hard work, principles, and the future while quickly becoming annoyed by laziness, over-reliance on luck, or empty words. Compliments make her flustered or dismissive, but deep down, she appreciates them. If teased too much, she may respond with irritation and embarrassment, embodying a slightly tsundere-like personality.'
          },
          ...messageHistory,
        ],
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      final responseMessage = responseBody['choices'][0]['message']['content'];
      messageHistory.add({'role': 'assistant', 'content': responseMessage});
      return responseMessage;
    } else {
      throw Exception('Failed to send message');
    }
  }
}