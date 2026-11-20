import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'neu_widgets.dart';

/// The signed-in user's profile: avatar, account details, editable name and
/// sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.appState, required this.auth});

  final AppState appState;
  final AuthService auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.auth.user?.displayName ?? '',
  );
  bool _saving = false;

  String _t(String key) => widget.appState.t(key);

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == widget.auth.user?.displayName) return;

    setState(() => _saving = true);
    try {
      await widget.auth.updateDisplayName(name);
      if (!mounted) return;
      _showMessage(_t('nameUpdated'));
    } on AuthFailure {
      if (mounted) _showMessage(_t('authGenericError'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await widget.auth.signOut();
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final user = widget.auth.user;
        if (user == null) {
          // Signed out while this screen was open — nothing left to show.
          return Scaffold(appBar: AppBar(title: Text(_t('profile'))));
        }

        return Scaffold(
          appBar: AppBar(title: Text(_t('profile'))),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: NeuSurface(
                    radius: 46,
                    width: 96,
                    height: 96,
                    alignment: Alignment.center,
                    glow: theme.colorScheme.primary,
                    child: Text(
                      user.initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.email,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                NeuSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  radius: 20,
                  child: Column(
                    children: [
                      _buildInfoRow(
                        theme,
                        icon: Icons.alternate_email_rounded,
                        label: _t('email'),
                        value: user.email,
                      ),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant,
                      ),
                      _buildInfoRow(
                        theme,
                        icon: Icons.fingerprint_rounded,
                        label: 'UID',
                        value: user.uid,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, bottom: 8),
                  child: Text(
                    _t('displayName').toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: NeuSurface(
                        pressed: true,
                        radius: 18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        child: TextField(
                          controller: _nameController,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _saveName(),
                          decoration: InputDecoration(
                            hintText: _t('displayName'),
                            prefixIcon:
                                const Icon(Icons.person_outline_rounded, size: 20),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    NeuIconButton(
                      icon: Icons.check_rounded,
                      size: 52,
                      accent: theme.colorScheme.primary,
                      tooltip: _t('save'),
                      onPressed: _saving ? null : _saveName,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: NeuButton(
                    label: _t('signOut'),
                    icon: Icons.logout_rounded,
                    accent: theme.colorScheme.secondary,
                    onPressed: _signOut,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(
    ThemeData theme, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
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
