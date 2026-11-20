import 'package:flutter/material.dart';

import 'app_state.dart';
import 'auth_service.dart';
import 'neu_widgets.dart';

/// One screen with two tabs: sign in and sign up (Firebase email/password).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.appState, required this.auth});

  final AppState appState;
  final AuthService auth;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  String _t(String key) => widget.appState.t(key);

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (_error != null) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isSignUp = _tabs.index == 1;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = _t('invalidEmail'));
      return;
    }
    if (password.length < 6) {
      setState(() => _error = _t('passwordTooShort'));
      return;
    }
    if (isSignUp && password != _confirmController.text) {
      setState(() => _error = _t('passwordsDontMatch'));
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      if (isSignUp) {
        await widget.auth.signUp(
          email: email,
          password: password,
          displayName: _nameController.text,
        );
      } else {
        await widget.auth.signIn(email: email, password: password);
      }
      // On success `AuthGate` swaps this screen for the home screen.
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = _messageFor(failure.code));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Turns Firebase's error code into a friendly, localized message.
  String _messageFor(String rawCode) {
    final code = rawCode.toUpperCase();
    if (code.contains('EMAIL_EXISTS')) return _t('authEmailInUse');
    if (code.contains('INVALID_PASSWORD') ||
        code.contains('INVALID_LOGIN_CREDENTIALS') ||
        code.contains('EMAIL_NOT_FOUND')) {
      return _t('authWrongCredentials');
    }
    if (code.contains('OPERATION_NOT_ALLOWED')) {
      return _t('authProviderDisabled');
    }
    if (code.contains('NETWORK_REQUEST_FAILED')) return _t('authNetworkError');
    if (code.contains('INVALID_EMAIL')) return _t('invalidEmail');
    if (code.contains('WEAK_PASSWORD')) return _t('passwordTooShort');
    return _t('authGenericError');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_t('account'))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'MindSpark AI',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _t('authTagline'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              NeuSurface(
                pressed: true,
                radius: 18,
                padding: const EdgeInsets.all(5),
                child: TabBar(
                  controller: _tabs,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: theme.colorScheme.onSurface,
                  unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700),
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                  tabs: [
                    Tab(text: _t('signIn')),
                    Tab(text: _t('signUp')),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildForm(isSignUp: false),
                    _buildForm(isSignUp: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isSignUp}) {
    final theme = Theme.of(context);

    return AutofillGroup(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          if (isSignUp) ...[
            _buildField(
              controller: _nameController,
              label: _t('displayName'),
              hint: _t('optional'),
              icon: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: 12),
          ],
          _buildField(
            controller: _emailController,
            label: _t('email'),
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _passwordController,
            label: _t('password'),
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            textInputAction:
                isSignUp ? TextInputAction.next : TextInputAction.done,
            autofillHints: [
              isSignUp ? AutofillHints.newPassword : AutofillHints.password,
            ],
            onSubmitted: isSignUp ? null : (_) => _submit(),
            suffix: IconButton(
              tooltip: _t('password'),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          if (isSignUp) ...[
            const SizedBox(height: 12),
            _buildField(
              controller: _confirmController,
              label: _t('confirmPassword'),
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onSubmitted: (_) => _submit(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          NeuButton(
            label: isSignUp ? _t('signUp') : _t('signIn'),
            icon: isSignUp
                ? Icons.person_add_alt_1_rounded
                : Icons.login_rounded,
            accent: theme.colorScheme.primary,
            onPressed: _submitting ? null : _submit,
          ),
          if (_submitting) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Iterable<String>? autofillHints,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Theme.of(context);

    return NeuSurface(
      pressed: true,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autofillHints: autofillHints,
        obscureText: obscure,
        onSubmitted: onSubmitted,
        style: theme.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }
}
