import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyBlMg2y3POMfizWk4-MdffYARBXCIW0Ahg';

  Future<void> testModel(String name) async {
    print('Testing $name...');
    try {
      final model = GenerativeModel(model: name, apiKey: apiKey);
      final response = await model.generateContent([Content.text('Hi')]);
      print('SUCCESS: $name works!');
    } catch (e) {
      print('FAILURE: $name failed. Error: $e');
    }
  }

  await testModel('gemini-1.5-flash');
  await testModel('gemini-1.5-flash-001');
  await testModel('gemini-pro');
  await testModel('gemini-1.0-pro');
}
