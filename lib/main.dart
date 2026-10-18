import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'chat_screen.dart';
import 'duo_widgets.dart';
import 'info_screen.dart';
import 'quiz_screen.dart';
import 'translations.dart';

void main() {
  runApp(const MindSparkApp());
}

/// Built once at startup so no theme work happens per-frame.
final ThemeData kSparkLightTheme = _buildSparkTheme(Brightness.light);
final ThemeData kSparkDarkTheme = _buildSparkTheme(Brightness.dark);

/// Kid-friendly "Spark" theme (target ages 10–15) — inspired by a reference
/// screenshot in `images/`.
///
/// Palette extracted from the reference image: near-black charcoal surfaces,
/// golden-orange primary (≈#FEB03C), pink secondary (≈#FE6C8F) and light-blue
/// tertiary (≈#6F9EFD), with a subtle teal cast on dark backgrounds.
///
/// Kept deliberately lightweight for performance: hand-picked colors, no
/// custom fonts, no images, no extra packages and no runtime animation-heavy
/// decorations. Chunky rounded buttons keep the playful learning-app feel.
ThemeData _buildSparkTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFEB03C),
    brightness: brightness,
  ).copyWith(
    primary: const Color(0xFFFEB03C),
    onPrimary: const Color(0xFF241A00),
    primaryContainer:
        isLight ? const Color(0xFFFFE8C7) : const Color(0xFF573C00),
    onPrimaryContainer:
        isLight ? const Color(0xFF7A3C00) : const Color(0xFFFFDFA6),
    secondary: const Color(0xFFFE6C8F),
    onSecondary: const Color(0xFF3B091A),
    secondaryContainer:
        isLight ? const Color(0xFFFFE2EA) : const Color(0xFF5C1030),
    onSecondaryContainer:
        isLight ? const Color(0xFF8E0F3C) : const Color(0xFFFFD9E1),
    tertiary: const Color(0xFF6F9EFD),
    onTertiary: const Color(0xFF0D2547),
    tertiaryContainer:
        isLight ? const Color(0xFFD9E5FF) : const Color(0xFF1E3F73),
    onTertiaryContainer:
        isLight ? const Color(0xFF0F3D80) : const Color(0xFFD9E5FF),
    surface: isLight ? const Color(0xFFFFFBF9) : const Color(0xFF14171A),
    onSurface: isLight ? const Color(0xFF201A14) : const Color(0xFFECE7DF),
    onSurfaceVariant:
        isLight ? const Color(0xFF514A40) : const Color(0xFFABA396),
    surfaceContainerHighest:
        isLight ? const Color(0xFFF1EBE4) : const Color(0xFF1E2226),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isLight ? const Color(0xFFFFFBF9) : const Color(0xFF0B0E10),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class MindSparkApp extends StatefulWidget {
  const MindSparkApp({super.key});

  @override
  State<MindSparkApp> createState() => _MindSparkAppState();
}

class _MindSparkAppState extends State<MindSparkApp> {
  final AppState _appState = AppState();

  @override
  void dispose() {
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _appState,
      builder: (context, _) {
        return MaterialApp(
          title: 'MindSpark AI',
          debugShowCheckedModeBanner: false,
          locale: _appState.locale,
          supportedLocales: supportedLanguages.map((l) => Locale(l.code)).toList(),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: kSparkLightTheme,
          darkTheme: kSparkDarkTheme,
          themeMode: _appState.themeMode,
          home: HomeScreen(appState: _appState),
        );
      },
    );
  }
}

/// Home screen: simple header + section cards.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  _buildLanguageMenu(theme),
                ],
              ),
            ),
            // ---- Sections ----
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'MindSpark AI',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.t('appTagline'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _buildSectionCard(
                      theme: theme,
                      icon: Icons.chat_bubble_rounded,
                      color: theme.colorScheme.secondary,
                      label: appState.t('chat'),
                      onTap: () => _openChat(context),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      theme: theme,
                      icon: Icons.quiz_rounded,
                      color: theme.colorScheme.primary,
                      label: appState.t('quiz'),
                      onTap: () => _openQuiz(context),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      theme: theme,
                      icon: Icons.lightbulb_rounded,
                      color: theme.colorScheme.tertiary,
                      label: appState.t('infoOfDay'),
                      onTap: () => _openInfo(context),
                    ),
                    const SizedBox(height: 28),
                    _buildThemeToggle(theme),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChat(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(appState: appState)),
    );
  }

  void _openQuiz(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => QuizSetupScreen(appState: appState)),
    );
  }

  void _openInfo(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InfoOfTheDayScreen(appState: appState),
      ),
    );
  }

  /// Plain Material card for a home-screen section.
  Widget _buildSectionCard({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Language selector showing a flag; opens a menu with all flags.
  Widget _buildLanguageMenu(ThemeData theme) {
    return PopupMenuButton<String>(
      tooltip: appState.t('language'),
      onSelected: (code) => appState.setLocale(code),
      initialValue: appState.languageCode,
      itemBuilder: (context) => [
        for (final lang in supportedLanguages)
          PopupMenuItem(
            value: lang.code,
            child: Row(
              children: [
                Text(lang.flag, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Text(lang.name),
                if (lang.code == appState.languageCode) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 18, color: theme.colorScheme.primary),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DuoColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              appState.currentLanguage.flag,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Light/dark theme toggle button.
  Widget _buildThemeToggle(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    return Center(
      child: FilledButton.tonalIcon(
        icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
        label: Text(appState.t('darkMode')),
        onPressed: () => appState.setThemeMode(
          isDark ? ThemeMode.light : ThemeMode.dark,
        ),
      ),
    );
  }
}
