import 'package:shared_preferences/shared_preferences.dart';

class ModelService {
  static const String _key = 'selected_model';
  
  static const Map<String, String> models = {
    'deepseek-chat': 'DeepSeek V3',
    'gemini-2.0-flash-lite': 'Gemini 2.0 Flash Lite',
  };

  Future<String> getSelectedModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) ?? 'deepseek-chat';
  }

  Future<void> setSelectedModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, model);
  }
}