import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'duo_widgets.dart';
import 'neu_widgets.dart';

/// Endpoint of the Cloudflare Worker proxy (same backend as the chat screen).
/// The OpenRouter API key stays server-side inside the worker, and the worker
/// owns the model chain (primary + fallbacks), so the app never carries either.
const String kProxyUrl = 'https://mindspark-ai-proxy.adamed135.workers.dev';

/// Quiz AI generation settings.
///
/// One five-question batch takes the model roughly 25–90 s, so asking for all
/// ten questions at once is what used to blow past the proxy's cap. The quiz is
/// therefore generated in two batches, both requested together, and play
/// starts as soon as the first one lands: waiting for ten questions and then
/// for a retry is what made the spinner look like it never stopped.
const int kQuizQuestionCount = 10;
const int kQuizBatchCount = 2;
const int kQuizBatchSize = kQuizQuestionCount ~/ kQuizBatchCount;

/// Output budget per batch (five questions plus the model's reasoning tokens).
const int kQuizMaxTokens = 2048;

/// A batch that takes longer than this is abandoned rather than left spinning.
const Duration kQuizRequestTimeout = Duration(seconds: 75);

/// Only the upstream `503 content safety screening is temporarily unavailable`
/// (and connection errors) are retried. A timeout means the model itself was
/// too slow, so retrying would just double the wait.
const int kQuizRequestAttempts = 2;

enum QuizSubject { science, physics, math, geography }

extension QuizSubjectInfo on QuizSubject {
  String get translationKey => switch (this) {
        QuizSubject.science => 'science',
        QuizSubject.physics => 'physics',
        QuizSubject.math => 'math',
        QuizSubject.geography => 'geography',
      };

  IconData get icon => switch (this) {
        QuizSubject.science => Icons.science_rounded,
        QuizSubject.physics => Icons.bolt_rounded,
        QuizSubject.math => Icons.calculate_rounded,
        QuizSubject.geography => Icons.public_rounded,
      };

  /// Picture used on the subject card and on the level screen.
  String get imagePath => 'assets/images/subjects/$translationKey.jpg';

  List<Color> get colors => switch (this) {
        QuizSubject.science => const [Color(0xFF26A69A), Color(0xFF66BB6A)],
        QuizSubject.physics => const [Color(0xFF42A5F5), Color(0xFF7E57C2)],
        QuizSubject.math => const [Color(0xFF5C6BC0), Color(0xFF29B6F6)],
        QuizSubject.geography => const [Color(0xFFEF6C00), Color(0xFFD4E157)],
      };
}

enum QuizDifficulty { easy, medium, hard }

extension QuizDifficultyInfo on QuizDifficulty {
  String get translationKey => switch (this) {
        QuizDifficulty.easy => 'easy',
        QuizDifficulty.medium => 'medium',
        QuizDifficulty.hard => 'hard',
      };

  List<Color> get colors => switch (this) {
        QuizDifficulty.easy => const [Color(0xFF66BB6A), Color(0xFF9CCC65)],
        QuizDifficulty.medium => const [Color(0xFFFFB300), Color(0xFFFF7043)],
        QuizDifficulty.hard => const [Color(0xFFEF5350), Color(0xFF7E57C2)],
      };

  String get labelEn => switch (this) {
        QuizDifficulty.easy => 'easy',
        QuizDifficulty.medium => 'medium',
        QuizDifficulty.hard => 'hard',
      };
}

/// Non-200 reply from the quiz proxy, carrying the HTTP status so callers can
/// tell a transient [503] from a permanent failure.
class QuizServerException implements Exception {
  QuizServerException(this.statusCode);

  final int statusCode;

  @override
  String toString() => 'Server error $statusCode';
}

class QuizQuestion {
  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  bool isCorrect(int selectedIndex) => selectedIndex == correctIndex;
}

/// First screen: pick a subject, which opens the level screen.
class QuizSetupScreen extends StatelessWidget {
  const QuizSetupScreen({super.key, required this.appState});

  final AppState appState;

  void _openLevels(BuildContext context, QuizSubject subject) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizLevelScreen(appState: appState, subject: subject),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(appState.t('quiz'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text(
              appState.t('chooseSubject'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.92,
              children: [
                for (final subject in QuizSubject.values)
                  _QuizSubjectCard(
                    subject: subject,
                    label: appState.t(subject.translationKey),
                    onTap: () => _openLevels(context, subject),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Second screen: choose the level for the picked subject, then start.
class QuizLevelScreen extends StatefulWidget {
  const QuizLevelScreen({
    super.key,
    required this.appState,
    required this.subject,
  });

  final AppState appState;
  final QuizSubject subject;

  @override
  State<QuizLevelScreen> createState() => _QuizLevelScreenState();
}

class _QuizLevelScreenState extends State<QuizLevelScreen> {
  QuizDifficulty _difficulty = QuizDifficulty.easy;

  AppState get appState => widget.appState;

  void _startQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          appState: appState,
          subject: widget.subject,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(appState.t(widget.subject.translationKey))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                height: 150,
                width: double.infinity,
                child: _SubjectPicture(subject: widget.subject),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appState.t('chooseDifficulty'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (final difficulty in QuizDifficulty.values) ...[
                  if (difficulty != QuizDifficulty.easy)
                    const SizedBox(width: 10),
                  Expanded(
                    child: _QuizDifficultyChip(
                      difficulty: difficulty,
                      label: appState.t(difficulty.translationKey),
                      selected: _difficulty == difficulty,
                      onTap: () => setState(() => _difficulty = difficulty),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
            DuoButton(
              label: appState.t('startQuiz'),
              icon: Icons.play_arrow_rounded,
              onPressed: _startQuiz,
            ),
          ],
        ),
      ),
    );
  }
}

/// The subject artwork, with a gradient fallback if the asset is missing.
class _SubjectPicture extends StatelessWidget {
  const _SubjectPicture({required this.subject});

  final QuizSubject subject;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      subject.imagePath,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: subject.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Icon(subject.icon, color: Colors.white, size: 40),
        ),
      ),
    );
  }
}

class _QuizSubjectCard extends StatelessWidget {
  const _QuizSubjectCard({
    required this.subject,
    required this.label,
    required this.onTap,
  });

  final QuizSubject subject;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Neu.base(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: Neu.raised(context, glow: subject.colors.first),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _SubjectPicture(subject: subject),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x00000000),
                      Color(0x33000000),
                      Color(0xB3000000),
                    ],
                    stops: [0.45, 0.7, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 8,
                bottom: 8,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          shadows: [
                            Shadow(color: Color(0x80000000), blurRadius: 6),
                          ],
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizDifficultyChip extends StatelessWidget {
  const _QuizDifficultyChip({
    required this.difficulty,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final QuizDifficulty difficulty;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: selected
            ? (isDark ? DuoColors.darkSelectedBg : DuoColors.blueLight)
            : Neu.base(context),
        borderRadius: BorderRadius.circular(14),
        boxShadow: selected
            ? Neu.raised(context, glow: DuoColors.blue)
            : Neu.raised(context),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < difficulty.index + 1; i++) ...[
                    if (i > 0) const SizedBox(width: 4),
                    Icon(
                      Icons.circle_rounded,
                      size: 8,
                      color: selected
                          ? DuoColors.blue
                          : (isDark
                              ? const Color(0xFFAFAFAF)
                              : DuoColors.border),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? DuoColors.blueText
                      : (isDark ? const Color(0xFFF1EFEA) : DuoColors.text),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Second screen: generates the questions with the AI, then runs the quiz.
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.appState,
    required this.subject,
    required this.difficulty,
  });

  final AppState appState;
  final QuizSubject subject;
  final QuizDifficulty difficulty;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _QuizPhase { loading, playing, done, error }

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion>? _questions;
  _QuizPhase _phase = _QuizPhase.loading;

  int _currentIndex = 0;
  int? _selectedIndex;
  int _score = 0;

  /// Live counter shown while generating: the model needs a minute or more, so
  /// a ticking number makes it clear the screen is still working.
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  /// Identifies the current generation so a late batch from an abandoned run
  /// (the player already pressed "Try again") cannot reopen the quiz.
  int _generation = 0;

  AppState get appState => widget.appState;

  @override
  void initState() {
    super.initState();
    _generateQuestions();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    super.dispose();
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedSeconds = 0;
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
  }

  Future<void> _generateQuestions() async {
    final generation = ++_generation;
    _startElapsedTimer();
    setState(() {
      _phase = _QuizPhase.loading;
      _questions = null;
      _currentIndex = 0;
      _selectedIndex = null;
      _score = 0;
    });

    try {
      await generateQuiz(
        subject: widget.subject,
        difficulty: widget.difficulty,
        uiLanguageCode: appState.languageCode,
        onQuestions: (questions) {
          _elapsedTimer?.cancel();
          if (!mounted || generation != _generation) return;
          // The quiz is over, so a batch arriving late must not reopen it.
          if (_phase == _QuizPhase.done) return;
          setState(() {
            _questions = questions;
            _phase = _QuizPhase.playing;
          });
        },
      );
    } catch (_) {
      _elapsedTimer?.cancel();
      if (!mounted || generation != _generation) return;
      setState(() => _phase = _QuizPhase.error);
    }
  }

  void _selectOption(int index) {
    if (_selectedIndex != null) return; // already answered
    final question = _questions![_currentIndex];
    setState(() {
      _selectedIndex = index;
      if (question.isCorrect(index)) _score++;
    });
  }

  void _goNext() {
    if (_currentIndex + 1 >= _questions!.length) {
      setState(() => _phase = _QuizPhase.done);
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedIndex = null;
    });
  }

  String _resultMessage(int score, int total) {
    final ratio = score / total;
    if (ratio >= 0.8) return appState.t('quizResultGreat');
    if (ratio >= 0.5) return appState.t('quizResultGood');
    return appState.t('quizResultKeepTrying');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(widget.subject.icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '${appState.t(widget.subject.translationKey)} · ${appState.t(widget.difficulty.translationKey)}',
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: switch (_phase) {
          _QuizPhase.loading => _buildLoading(colorScheme),
          _QuizPhase.error => _buildError(colorScheme),
          _QuizPhase.playing => _buildQuiz(),
          _QuizPhase.done => _buildResults(colorScheme),
        },
      ),
    );
  }

  Widget _buildLoading(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            appState.t('generatingQuiz'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              appState.t('generatingHint'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          if (_elapsedSeconds >= 10) ...[
            const SizedBox(height: 12),
            Text(
              '${_elapsedSeconds}s',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              appState.t('quizLoadError'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generateQuestions,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(appState.t('tryAgain')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuiz() {
    final questions = _questions!;
    final question = questions[_currentIndex];
    final answered = _selectedIndex != null;
    final isLast = _currentIndex + 1 == questions.length;
    final wasCorrect = _selectedIndex == question.correctIndex;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFAFAFAF),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DuoProgressBar(
                  value:
                      (_currentIndex + (answered ? 1 : 0)) / questions.length,
                ),
              ),
              const SizedBox(width: 12),
              const DuoStat(
                icon: Icons.star_rounded,
                value: '500',
                color: DuoColors.orange,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                  child: Text(
                    question.question,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                  ),
                ),
                for (var i = 0; i < question.options.length; i++)
                  _buildOptionTile(question, i, answered),
              ],
            ),
          ),
        ),
        if (answered)
          DuoFeedbackBanner(
            correct: wasCorrect,
            message: wasCorrect ? appState.t('correct') : appState.t('wrong'),
            detail: question.explanation,
            buttonLabel: isLast ? appState.t('finish') : appState.t('next'),
            onPressed: _goNext,
          ),
      ],
    );
  }

  Widget _buildOptionTile(
    QuizQuestion question,
    int index,
    bool answered,
  ) {
    final isSelected = _selectedIndex == index;
    final isCorrect = index == question.correctIndex;

    final DuoOptionState state;
    if (!answered) {
      state = isSelected ? DuoOptionState.selected : DuoOptionState.normal;
    } else if (isCorrect) {
      state = DuoOptionState.correct;
    } else if (isSelected) {
      state = DuoOptionState.incorrect;
    } else {
      state = DuoOptionState.muted;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DuoOptionTile(
        label: question.options[index],
        state: state,
        onTap: answered ? null : () => _selectOption(index),
      ),
    );
  }

  Widget _buildResults(ColorScheme colorScheme) {
    final total = _questions!.length;
    final ratio = _score / total;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: ratio >= 0.5
                      ? const [Color(0xFF58CC02), Color(0xFF4CB900)]
                      : const [Color(0xFFFF4B4B), Color(0xFFFF7043)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: Neu.raised(
                  context,
                  glow: ratio >= 0.5
                      ? DuoColors.green
                      : DuoColors.red,
                ),
              ),
              child: Center(
                child: Text(
                  '$_score/$total',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              appState.t('quizComplete'),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${appState.t('yourScore')}: ${(_score / total * 100).round()}%',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              _resultMessage(_score, total),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            DuoButton(
              label: appState.t('tryAgain'),
              icon: Icons.refresh_rounded,
              onPressed: _generateQuestions,
            ),
            const SizedBox(height: 14),
            DuoButton(
              label: appState.t('newQuiz'),
              icon: Icons.arrow_back_rounded,
              color: DuoColors.blue,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks the AI (via the Cloudflare Worker proxy) to generate quiz questions.
///
/// [onQuestions] is called as soon as the first playable batch has arrived and
/// again whenever another batch lands, so the quiz screen can start playing
/// while the rest is still being generated.
Future<void> generateQuiz({
  required QuizSubject subject,
  required QuizDifficulty difficulty,
  required String uiLanguageCode,
  required ValueChanged<List<QuizQuestion>> onQuestions,
}) async {
  final languageName = switch (uiLanguageCode) {
    'ar' => 'Arabic',
    'fr' => 'French',
    _ => 'English',
  };

  final questions = <QuizQuestion>[];
  final seen = <String>{};
  Object? lastError;

  // A batch that fails is skipped instead of aborting the quiz: one full batch
  // still makes a playable quiz.
  Future<List<QuizQuestion>> safeBatch(int batchIndex) async {
    try {
      return await _requestQuizBatch(
        subject: subject,
        difficulty: difficulty,
        languageName: languageName,
        batchIndex: batchIndex,
        count: kQuizBatchSize,
      );
    } catch (error) {
      lastError = error;
      debugPrint('Quiz batch $batchIndex failed: $error');
      return const <QuizQuestion>[];
    }
  }

  // Both batches are requested together and reported as each one lands, so the
  // player starts on the first playable batch instead of waiting for the
  // slower one. That is what previously kept the screen spinning for minutes.
  await for (final batch in Stream.fromFutures([
    for (var i = 0; i < kQuizBatchCount; i++) safeBatch(i),
  ])) {
    final added = <QuizQuestion>[];
    for (final question in batch) {
      final key = question.question
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
          .trim();
      if (seen.add(key)) {
        questions.add(question);
        added.add(question);
      }
    }
    if (added.isNotEmpty) {
      debugPrint('QUIZ READY with ${questions.length} questions');
      onQuestions(List<QuizQuestion>.unmodifiable(questions));
    }
  }

  if (questions.length < kQuizBatchSize) {
    throw Exception('Quiz generation failed: $lastError');
  }
}

/// Requests [kQuizBatchSize] questions from the model, retrying a transient
/// failure once.
Future<List<QuizQuestion>> _requestQuizBatch({
  required QuizSubject subject,
  required QuizDifficulty difficulty,
  required String languageName,
  required int batchIndex,
  required int count,
}) async {
  // Pushes the two batches towards different material so the merged quiz is
  // less likely to contain near-duplicate questions.
  final batchHint = batchIndex == 0
      ? '- Prefer questions about key concepts, definitions and how things work.\n'
      : '- Prefer questions about real-world examples, comparisons and '
          'why something happens.\n';

  final prompt =
      'Create exactly $count multiple-choice quiz questions about '
      '${subject.name} at ${difficulty.labelEn} difficulty level, suitable for '
      'students aged 10 to 15. '
      'Write every question and every answer option in $languageName.\n'
      'Rules:\n'
      '- Each question has exactly 4 answer options, and exactly one is correct.\n'
      '- Questions must be factually accurate and varied, not repeated.\n'
      '- Use simple, age-appropriate vocabulary and clear wording that a '
      '10–15 year old understands.\n'
      '- Questions must be answerable by children anywhere in the world: do '
      'NOT rely on one specific country’s curriculum or local examples '
      '(no US states, Canadian provinces, local money, local sports or '
      'local brands). World capitals, planets and universal facts are fine.\n'
      '- Optionally add a short one-sentence "explanation" for the correct answer.\n'
      '$batchHint'
      'Return ONLY valid JSON with no markdown, no code fences and no commentary, '
      'as a JSON array of objects, each shaped like: '
      '{"question": "...", "options": ["...", "...", "...", "..."], '
      '"correct_index": 0, "explanation": "..."} '
      'where correct_index is the 0-based index of the correct option in "options".';

  Object? lastError;
  for (var attempt = 1; attempt <= kQuizRequestAttempts; attempt++) {
    try {
      final response = await http
          .post(
            Uri.parse(kProxyUrl),
            body: jsonEncode({
              'max_tokens': kQuizMaxTokens,
              'temperature': 0.7,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are an expert quiz creator writing for children aged 10–15 '
                          'worldwide. You reply ONLY with valid JSON. '
                          'You never add explanations, markdown or any text outside the JSON.\n'
                          'Every question must use simple, age-appropriate vocabulary and '
                          'must be answerable by children anywhere in the world, without '
                          'relying on any single country’s curriculum or local examples.',
                },
                {'role': 'user', 'content': prompt},
              ],
            }),
            headers: const {'Content-Type': 'application/json'},
          )
          .timeout(kQuizRequestTimeout);

      if (response.statusCode != 200) {
        throw QuizServerException(response.statusCode);
      }

      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final content = choices?[0]?['message']?['content'] as String?;
      if (content == null || content.isEmpty) {
        throw Exception('Empty response from AI');
      }

      return parseQuizQuestions(content, minQuestions: count);
    } catch (error) {
      lastError = error;
      // 429 is the free model's shared upstream pool being saturated, which is
      // as temporary as a 503, so it gets the same single retry.
      final transient = error is QuizServerException
          ? error.statusCode == 503 || error.statusCode == 429
          : error is! FormatException && error is! TimeoutException;
      if (!transient || attempt >= kQuizRequestAttempts) break;
      await Future.delayed(const Duration(seconds: 2));
    }
  }

  throw Exception('Quiz batch failed: $lastError');
}
/// Parses the model reply into [QuizQuestion]s, tolerating code fences and
/// slightly different key names.
List<QuizQuestion> parseQuizQuestions(
  String raw, {
  int minQuestions = kQuizQuestionCount - 2,
}) {
  var text = raw.trim();

  // Strip markdown code fences if the model added them.
  final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(text);
  if (fenceMatch != null) text = fenceMatch.group(1)!.trim();

  // Keep only the JSON array/object part.
  final start = text.indexOf('[');
  final objectStart = text.indexOf('{');
  if (objectStart != -1 && (start == -1 || objectStart < start)) {
    final objectEnd = text.lastIndexOf('}');
    final decodedObject = _tryDecode(text.substring(objectStart, objectEnd + 1));
    if (decodedObject is Map) {
      final questions =
          _parseQuestionList(decodedObject['questions'], minQuestions);
      if (questions.isNotEmpty) return questions;
    }
  }
  if (start != -1) {
    final end = text.lastIndexOf(']');
    final decodedArray = _tryDecode(text.substring(start, end + 1));
    if (decodedArray is List) {
      final questions = _parseQuestionList(decodedArray, minQuestions);
      if (questions.isNotEmpty) return questions;
    }
  }

  throw const FormatException('AI did not return valid quiz JSON');
}

dynamic _tryDecode(String text) {
  try {
    return jsonDecode(text);
  } catch (_) {
    return null;
  }
}

List<QuizQuestion> _parseQuestionList(dynamic list, int minQuestions) {
  if (list is! List) return const [];

  final questions = <QuizQuestion>[];
  for (final item in list) {
    if (item is! Map) continue;
    final questionText =
        (item['question'] ?? item['text'])?.toString().trim() ?? '';
    final optionsRaw = item['options'] ?? item['choices'];
    if (questionText.isEmpty || optionsRaw is! List) continue;
    final options = optionsRaw
        .map((o) => o.toString().trim())
        .where((o) => o.isNotEmpty)
        .toList();
    if (options.length != 4) continue;

    final correctIndex = _parseCorrectIndex(item, options);
    if (correctIndex == null) continue;

    final explanation = item['explanation']?.toString().trim();
    questions.add(QuizQuestion(
      question: questionText,
      options: options,
      correctIndex: correctIndex,
      explanation: (explanation == null || explanation.isEmpty)
          ? null
          : explanation,
    ));
  }
  // Require most of the questions to be valid so a broken generation fails
  // loudly instead of showing a nearly empty quiz.
  if (questions.length < minQuestions) {
    throw const FormatException('Not enough valid questions in AI response');
  }
  return questions;
}

int? _parseCorrectIndex(Map item, List<String> options) {
  final value = item['correct_index'] ?? item['correctIndex'] ?? item['answer'];
  if (value is int) {
    if (value >= 0 && value < options.length) return value;
  } else if (value is num) {
    final index = value.toInt();
    if (index >= 0 && index < options.length) return index;
  } else if (value is String) {
    final trimmed = value.trim();
    // "A"–"D" style answers.
    if (trimmed.length == 1 &&
        trimmed.toUpperCase().codeUnitAt(0) >= 65 &&
        trimmed.toUpperCase().codeUnitAt(0) <= 68) {
      return trimmed.toUpperCase().codeUnitAt(0) - 65;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed != null && parsed >= 0 && parsed < options.length) return parsed;
    // Full text answer: find the matching option.
    for (var i = 0; i < options.length; i++) {
      if (options[i].toLowerCase() == trimmed.toLowerCase()) return i;
    }
  }
  return null;
}
