import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_drawer.dart';
import 'app_state.dart';
import 'auth_screen.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'firebase_config.dart';
import 'info_screen.dart';
import 'neu_widgets.dart';
import 'quiz_screen.dart';
import 'translations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: FirebaseConfig.apiKey,
      authDomain: FirebaseConfig.authDomain,
      projectId: FirebaseConfig.projectId,
      storageBucket: FirebaseConfig.storageBucket,
      messagingSenderId: FirebaseConfig.messagingSenderId,
      appId: FirebaseConfig.appId,
    ),
  );
  runApp(const MindSparkApp());
}

/// Built once at startup so no theme work happens per-frame.
final ThemeData kSparkLightTheme = _buildSparkTheme(Brightness.light);
final ThemeData kSparkDarkTheme = _buildSparkTheme(Brightness.dark);

/// Kid-friendly "Spark" theme (target ages 10–15) in a neumorphic style.
///
/// Brand accents are unchanged (golden-orange ≈#FEB03C, pink ≈#FE6C8F,
/// light-blue ≈#6F9EFD), but every surface is now the same flat tone per theme
/// and depth comes only from the soft double shadows in `neu_widgets.dart`.
/// Borders and Material elevation are deliberately absent — outlines and hard
/// shadows are what break the soft-UI look.
ThemeData _buildSparkTheme(Brightness brightness) {
  final isLight = brightness == Brightness.light;
  final base = isLight ? NeuColors.lightBase : NeuColors.darkBase;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFFEB03C),
    brightness: brightness,
  ).copyWith(
    primary: const Color(0xFFFEB03C),
    onPrimary: const Color(0xFF241A00),
    primaryContainer:
        isLight ? const Color(0xFFFFE8C7) : const Color(0xFF57410F),
    onPrimaryContainer:
        isLight ? const Color(0xFF7A3C00) : const Color(0xFFFFDFA6),
    secondary: const Color(0xFFFE6C8F),
    onSecondary: const Color(0xFF3B091A),
    secondaryContainer:
        isLight ? const Color(0xFFFFE2EA) : const Color(0xFF5C2436),
    onSecondaryContainer:
        isLight ? const Color(0xFF8E0F3C) : const Color(0xFFFFD9E1),
    tertiary: const Color(0xFF6F9EFD),
    onTertiary: const Color(0xFF0D2547),
    tertiaryContainer:
        isLight ? const Color(0xFFDDE7FA) : const Color(0xFF243B5E),
    onTertiaryContainer:
        isLight ? const Color(0xFF0F3D80) : const Color(0xFFD9E5FF),
    surface: base,
    onSurface: isLight ? const Color(0xFF2C3037) : const Color(0xFFDEE5EE),
    onSurfaceVariant:
        isLight ? const Color(0xFF6B7280) : const Color(0xFF9BA6B4),
    surfaceContainerHighest: base,
    surfaceContainerHigh: base,
    surfaceContainer: base,
    surfaceContainerLow: base,
    surfaceContainerLowest: base,
    outline: isLight ? const Color(0xFFCBD4E1) : const Color(0xFF39414B),
    outlineVariant: isLight ? const Color(0xFFDCE3ED) : const Color(0xFF2C333C),
    errorContainer: isLight ? const Color(0xFFFBDDE1) : const Color(0xFF3B1F26),
    onErrorContainer:
        isLight ? const Color(0xFF7A1B2C) : const Color(0xFFFFD5DC),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    // Screens are see-through so the app-wide photo in `AppBackground` shows.
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: base,
    splashFactory: NoSplash.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: base,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: base,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: base,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _authService.attach();
  }

  @override
  void dispose() {
    _authService.dispose();
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
          builder: (context, child) =>
              AppBackground(child: child ?? const SizedBox.shrink()),
          home: AuthGate(appState: _appState, auth: _authService),
        );
      },
    );
  }
}

/// The app's entry screen: shows the home screen when Firebase reports a
/// signed-in user, otherwise the combined sign-in/sign-up screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.appState, required this.auth});

  final AppState appState;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.signedIn) return HomeScreen(appState: appState, auth: auth);
        return AuthScreen(appState: appState, auth: auth);
      },
    );
  }
}

/// Home screen: a header + one extruded picture card per section
/// (Chat, Quiz, Info).
///
/// Each card shows a picture from `assets/images/` in a rounded banner with its
/// title and subtitle underneath. Pictures are optional: a card whose file
/// isn't there yet shows a tinted gradient with its icon instead.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.appState, required this.auth});

  final AppState appState;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      drawer: AppDrawer(appState: appState, auth: auth),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(
                children: [
                  // Opens the settings drawer (language + theme).
                  Builder(
                    builder: (context) => NeuIconButton(
                      icon: Icons.menu_rounded,
                      tooltip: MaterialLocalizations.of(context)
                          .openAppDrawerTooltip,
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
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
                      subtitle: appState.t('chatSubtitle'),
                      imagePath: 'assets/images/chat.jpg',
                      onTap: () => _openChat(context),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      theme: theme,
                      icon: Icons.quiz_rounded,
                      color: theme.colorScheme.primary,
                      label: appState.t('quiz'),
                      subtitle: appState.t('quizSubtitle'),
                      imagePath: 'assets/images/quiz.jpg',
                      onTap: () => _openQuiz(context),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      theme: theme,
                      icon: Icons.lightbulb_rounded,
                      color: theme.colorScheme.tertiary,
                      label: appState.t('infoOfDay'),
                      subtitle: appState.t('infoSubtitle'),
                      imagePath: 'assets/images/info.jpg',
                      onTap: () => _openInfo(context),
                    ),
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

  /// Extruded picture card for a home-screen section: a picture banner on top,
  /// then the icon, title, subtitle and arrow underneath.
  Widget _buildSectionCard({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required String imagePath,
    required VoidCallback onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return NeuTappable(
      onTap: onTap,
      radius: 26,
      glow: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SectionPicture(
                  imagePath: imagePath,
                  icon: icon,
                  color: color,
                ),
                // Fades the picture into the card body so both read as one shape.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        color.withValues(alpha: 0),
                        color.withValues(alpha: isDark ? 0.28 : 0.14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Row(
              children: [
                NeuSurface(
                  pressed: true,
                  radius: 21,
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 23),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                NeuSurface(
                  pressed: true,
                  radius: 17,
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}

/// The picture at the top of a home card, filling its banner.
///
/// When the picture file isn't bundled yet (the default until real artwork is
/// added to `assets/images/`) it renders a tinted gradient with the section
/// icon, so the card still looks finished.
class _SectionPicture extends StatelessWidget {
  const _SectionPicture({
    required this.imagePath,
    required this.icon,
    required this.color,
  });

  final String imagePath;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0.10),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            icon,
            size: 52,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}
