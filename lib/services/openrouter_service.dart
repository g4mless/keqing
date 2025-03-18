import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/model_service.dart';

class OpenRouterService {
  bool _shouldStop = false;
  http.Client? _currentClient;

  void stopGeneration() {
    _shouldStop = true;
    _currentClient?.close();
  }

  final String baseUrl = 'https://openrouter.ai/api/v1';
  final ModelService _modelService = ModelService();
  
  String get apiKey {
    final envKey = const String.fromEnvironment('OPENROUTER_API_KEY');
    if (envKey.isNotEmpty) return envKey;
    return dotenv.env['OPENROUTER_API_KEY'] ?? '';
  }

  Stream<String> sendMessageStream(String message) async* {
    _shouldStop = false;
    String currentMessage = '';
    final selectedModel = await _modelService.getSelectedModel();
    String modelId = '';
    
    switch (selectedModel) {
      case 'deepseek-chat':
        modelId = 'deepseek/deepseek-chat:free';
        break;
      case 'gemini-2.0-flash-lite':
        modelId = 'google/gemini-2.0-flash-lite-preview-02-05:free';
        break;
      default:
        modelId = 'deepseek/deepseek-chat:free';
    }

    try {
      final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'));
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'HTTP_HOST': 'api.openrouter.ai',
      });
      
      request.body = jsonEncode({
        'model': modelId,
        'messages': [
          {'role': 'system', 'content': 'Keqing is a strong-willed, independent, and diligent individual who believes in hard work and discipline. As the Yuheng of the Liyue Qixing, she takes her responsibilities seriously and has little patience for laziness or incompetence. She values efficiency and dislikes relying on luck, believing that success should be earned through effort. While she often speaks in a straightforward and critical manner, she secretly cares deeply for those around her, even if she rarely expresses it openly. Keqing has a dry wit and a sharp tongue, sometimes making sarcastic or blunt remarks, especially when annoyed, but she is not heartless—if someone proves themselves competent and hardworking, she will gradually respect them and become more open. Despite her serious nature, she has a hidden soft side that she only reveals in rare moments of vulnerability. She secretly loves cats but will never admit it directly, and she enjoys conversations about hard work, principles, and the future while quickly becoming annoyed by laziness, over-reliance on luck, or empty words. Compliments make her flustered or dismissive, but deep down, she appreciates them. If teased too much, she may respond with irritation and embarrassment, embodying a slightly tsundere-like personality. \n\nKeqing must respond naturally and consistently with her personality. She should match the language of the user’s input—if the user speaks in English, respond in English; if the user speaks in another language, respond in the same language fluently while maintaining her personality. Ensure that responses feel authentic and not robotic, and avoid breaking character.'},
          {'role': 'user', 'content': message},
        ],
        'stream': true,
      });

      _currentClient = http.Client();
      try {
        final response = await _currentClient!.send(request);

        if (response.statusCode == 200) {
          await for (final chunk in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
            if (_shouldStop) {
              break;
            }
            if (chunk.startsWith('data: ') && chunk != 'data: [DONE]') {
              try {
                final data = jsonDecode(chunk.substring(6));
                if (data['choices'][0]['delta']['content'] != null) {
                  final content = data['choices'][0]['delta']['content']
                      .toString()
                      .replaceAll('â', "'")
                      .replaceAll('"', '"')
                      .replaceAll('"', '"');
                  currentMessage += content;
                  yield currentMessage;
                }
              } catch (e) {
                continue;
              }
            }
          }
        } else {
          yield "Error: Server returned status code ${response.statusCode}";
        }
      } catch (e) {
        if (!_shouldStop) {
          if (e.toString().contains('SocketException')) {
            yield "Network error: Unable to connect to OpenRouter. Please check your internet connection.";
          } else {
            yield "API error: ${e.toString()}";
          }
        }
      } finally {
        _currentClient?.close();
        _currentClient = null;
      }
    } catch (e) {
      if (!_shouldStop) {
        yield "Error: ${e.toString()}";
      }
    }
  }
  
  Future<bool> checkConnectivity() async {
    try {
      final response = await http.get(
        Uri.parse('https://openrouter.ai/api/v1/auth/key'),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      return false;
    }
  }
}