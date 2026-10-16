import 'package:flutter/material.dart';
import '../config/ai_config.dart';

/// Asks for an OpenAI API key and saves it on the device.
/// Returns true if a key is set when the dialog closes.
Future<bool> showApiKeyDialog(BuildContext context) async {
  final controller = TextEditingController(text: AIPreferences.apiKey);

  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('OpenAI API key'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Only needed to generate new coaching. The sample runs already '
            'include coaching. The key is saved only on this device.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'sk-...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (AIPreferences.hasApiKey)
          TextButton(
            onPressed: () async {
              await AIPreferences.setApiKey('');
              if (context.mounted) Navigator.pop(context, false);
            },
            child: const Text('Remove key'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            await AIPreferences.setApiKey(controller.text);
            if (context.mounted) Navigator.pop(context, true);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  controller.dispose();
  return (saved ?? false) && AIPreferences.hasApiKey;
}
