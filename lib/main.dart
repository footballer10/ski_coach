import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/app_controller.dart';
import 'services/ai_coach.dart';
import 'config/ai_config.dart';
import 'config/ai_prompts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable wakelock to keep app running when screen is off
  await WakelockPlus.enable();

  await AIPreferences.load();
  getAICoach().setSystemPrompt(systemPrompt);

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
