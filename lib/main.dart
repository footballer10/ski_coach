import 'package:flutter/material.dart';
import 'pages/app_controller.dart';
import 'services/ai_coach.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize AI coach singleton on app startup
  final aiCoach = getAICoach();
  await aiCoach.initialize();
  
  // Set system prompt (currently blank, can be customized later)
  // aiCoach.setSystemPrompt("Your custom system prompt here");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ski Coach',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const AppController(),
    );
  }
}
