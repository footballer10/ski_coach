import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'pages/app_controller.dart';
import 'services/ai_coach.dart';
import 'config/ai_config.dart';
import 'config/ai_prompts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enable wakelock to keep app running when screen is off. Browsers refuse
  // it without a user gesture, and the web demo doesn't record anyway.
  if (!kIsWeb) await WakelockPlus.enable();

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
      builder: (context, child) =>
          kIsWeb ? _PhoneFrame(child: child!) : child!,
    );
  }
}

/// On a wide browser window, shows the web demo inside an iPhone-sized
/// frame instead of stretching it across the screen.
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  static const _phone = Size(430, 932); // iPhone Pro Max, in points

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 600) return child; // already on a phone

    final height = (media.size.height - 48).clamp(560.0, _phone.height);
    final size = Size(_phone.width, height);
    return ColoredBox(
      color: const Color(0xFFE8E8E8),
      child: Center(
        child: Container(
          width: size.width + 24,
          height: size.height + 24,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(56),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(44),
            child: MediaQuery(
              data: media.copyWith(
                size: size,
                padding: const EdgeInsets.only(top: 20, bottom: 12),
                viewPadding: const EdgeInsets.only(top: 20, bottom: 12),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
