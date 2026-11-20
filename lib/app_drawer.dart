import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'neu_widgets.dart';
import 'profile_screen.dart';
import 'translations.dart';

/// Side panel holding the app's settings: language and light/dark theme.
///
/// Opened from the menu button on the home screen. Every option is a pressed-in
/// neumorphic row when selected, matching the rest of the UI.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.appState, required this.auth});

  final AppState appState;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([appState, auth]),
          builder: (context, _) {
            final accent = theme.colorScheme.primary;

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
              children: [
                _buildHeader(theme),
                const SizedBox(height: 20),
                _buildAccountTile(theme, context),
                const SizedBox(height: 28),
                _buildSectionLabel(theme, appState.t('language')),
                const SizedBox(height: 10),
                for (final lang in supportedLanguages) ...[
                  _buildOption(
                    theme: theme,
                    selected: lang.code == appState.languageCode,
                    accent: accent,
                    onTap: () => appState.setLocale(lang.code),
                    child: Row(
                      children: [
                        Text(
                          lang.flag,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            lang.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
                _buildSectionLabel(theme, appState.t('theme')),
                const SizedBox(height: 10),
                for (final option in _themeOptions) ...[
                  _buildOption(
                    theme: theme,
                    selected: appState.themeMode == option.mode,
                    accent: theme.colorScheme.tertiary,
                    onTap: () => appState.setThemeMode(option.mode),
                    child: Row(
                      children: [
                        Icon(
                          option.icon,
                          size: 21,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            appState.t(option.labelKey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static const List<({ThemeMode mode, IconData icon, String labelKey})>
      _themeOptions = [
    (
      mode: ThemeMode.system,
      icon: Icons.brightness_auto_rounded,
      labelKey: 'themeSystem',
    ),
    (
      mode: ThemeMode.light,
      icon: Icons.light_mode_rounded,
      labelKey: 'themeLight',
    ),
    (
      mode: ThemeMode.dark,
      icon: Icons.dark_mode_rounded,
      labelKey: 'themeDark',
    ),
  ];

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        NeuSurface(
          radius: 16,
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(
            Icons.auto_awesome_rounded,
            size: 22,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MindSpark AI',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                appState.t('appTagline'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The signed-in user; tapping it opens the profile screen.
  Widget _buildAccountTile(ThemeData theme, BuildContext context) {
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();

    final accent = theme.colorScheme.primary;

    return NeuTappable(
      onTap: () => _openProfile(context),
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          NeuSurface(
            pressed: true,
            radius: 19,
            width: 38,
            height: 38,
            alignment: Alignment.center,
            child: Text(
              user.initial,
              style: theme.textTheme.titleMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  void _openProfile(BuildContext context) {
    final navigator = Navigator.of(context);
    navigator.pop(); // Close the drawer first.
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProfileScreen(appState: appState, auth: auth),
      ),
    );
  }

  Widget _buildSectionLabel(ThemeData theme, String label) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  /// Selectable row: sunk in when [selected], raised otherwise.
  Widget _buildOption({
    required ThemeData theme,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return NeuTappable(
      onTap: onTap,
      radius: 16,
      pressed: selected,
      glow: selected ? accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          Expanded(child: child),
          if (selected)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Icon(Icons.check_rounded, size: 18, color: accent),
            ),
        ],
      ),
    );
  }
}
