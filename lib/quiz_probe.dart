import 'package:flutter/material.dart';

import 'app_state.dart';
import 'quiz_screen.dart';

/// TEMPORARY diagnostic entrypoint — deleted after the investigation.
/// Opens the real quiz screen directly, skipping the Firebase login gate.
void main() {
  final appState = AppState();
  debugPrint('PROBE: launching quiz screen');
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: QuizScreen(
        appState: appState,
        subject: QuizSubject.science,
        difficulty: QuizDifficulty.easy,
      ),
    ),
  );
}
