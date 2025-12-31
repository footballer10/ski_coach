import 'package:flutter/material.dart';
import 'pages/app_controller.dart';
import 'services/ai_coach.dart';
import 'config/ai_prompts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final aiCoach = getAICoach();
  await aiCoach.initialize();

  aiCoach.setSystemPromptLocal(localSystemPrompt);
  aiCoach.setSystemPromptAPI(localSystemPrompt);

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
