import 'package:flutter/material.dart';
import 'package:ski_coach/services/ai_coach.dart';

class AIPromptTester extends StatefulWidget {
  const AIPromptTester({super.key});

  @override
  State<AIPromptTester> createState() => _AIPromptTesterState();
}

class _AIPromptTesterState extends State<AIPromptTester> {
  final _systemPromptController = TextEditingController();
  final _userPromptController = TextEditingController();
  final _outputController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load existing prompts if any
    final aiCoach = getAICoach();
    _systemPromptController.text = aiCoach.getSystemPrompt() ?? '';
    _userPromptController.text = aiCoach.getUserPrompt() ?? '';
  }

  Future<void> _sendPrompts() async {
    final aiCoach = getAICoach();
    
    // Set the prompts
    if (_systemPromptController.text.isNotEmpty) {
      aiCoach.setSystemPrompt(_systemPromptController.text);
    }
    if (_userPromptController.text.isNotEmpty) {
      aiCoach.setUserPrompt(_userPromptController.text);
    }
    
    setState(() => _isLoading = true);
    
    try {
      // Generate coaching advice (will use custom prompts if set)
      final response = await aiCoach.generateCoachingAdvice(
        edgeAngleScore: 0.5,
        parallelScore: 0.6,
        turnShapeScore: 0.7,
        durationScore: 0.8,
        runScore: 0.65,
        categoryScores: {
          'Duration': 0.8,
          'Edge Angle': 0.5,
          'Parallel': 0.6,
          'Turn Shape': 0.7,
        },
      );
      
      _outputController.text = response;
    } catch (e) {
      _outputController.text = 'Error: $e';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _clearAll() {
    _systemPromptController.clear();
    _userPromptController.clear();
    _outputController.clear();
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _userPromptController.dispose();
    _outputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI Prompt Tester'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // System Prompt Input
            const Text(
              'System Prompt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _systemPromptController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste your system prompt here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // User Prompt Input
            const Text(
              'User Prompt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _userPromptController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Paste your user prompt here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _sendPrompts,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_isLoading ? 'Sending...' : 'Send Prompts'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Output
            const Text(
              'Response',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade50,
              ),
              child: TextField(
                controller: _outputController,
                maxLines: 10,
                readOnly: true,
                decoration: const InputDecoration(
                  hintText: 'Response will appear here...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ℹ️ How to use:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '1. Paste your system prompt in the first field\n'
                    '2. Paste your user prompt in the second field\n'
                    '3. Click "Send Prompts" to test\n'
                    '4. Response appears below\n\n'
                    'The model file is loaded from assets/models/\n'
                    'Ready for llama.cpp integration!',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Current model: llama-3.2-3b-instruct-q4_k_m.gguf',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
