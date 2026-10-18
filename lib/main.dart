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

/// On a computer, shows the web demo as an iPhone: the app is always laid out
/// at iPhone Pro Max size, and the whole phone is scaled to fit the window,
/// so every screen looks exactly as it does on the phone.
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  static const _screen = Size(430, 932); // iPhone Pro Max, in points
  static const _bezel = 12.0;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // On a phone in portrait, just fill the screen.
    if (media.size.width < 600 && media.size.height > media.size.width) {
      return child;
    }

    return ColoredBox(
      color: const Color(0xFFE8E8E8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FittedBox(
          child: Container(
            width: _screen.width + 2 * _bezel,
            height: _screen.height + 2 * _bezel,
            padding: const EdgeInsets.all(_bezel),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(56),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(44),
              child: MediaQuery(
                data: media.copyWith(
                  size: _screen,
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  viewPadding: const EdgeInsets.only(top: 20, bottom: 12),
                ),
                child: SizedBox.fromSize(size: _screen, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
