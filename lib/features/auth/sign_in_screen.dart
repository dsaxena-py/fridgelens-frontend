import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/logo.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key, this.signUp = false});

  final bool signUp;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.signUp;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    final auth = ref.read(authProvider);
    try {
      if (_signUp) {
        final needsConfirmation = await auth.signUp(_email.text, _password.text, displayName: _name.text);
        if (needsConfirmation && mounted) {
          setState(() {
            _signUp = false;
            _notice = 'Check your inbox for a confirmation link, then sign in here.';
          });
        }
      } else {
        await auth.signIn(_email.text, _password.text);
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: context.canPop()
            ? IconButton(icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Back', onPressed: () => context.pop())
            : null,
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Space.xl),
            children: [
              const Align(alignment: Alignment.centerLeft, child: PlateFocusMark(size: 40)),
              const SizedBox(height: Space.xl),
              Text(_signUp ? 'Create your account' : 'Welcome back', style: theme.textTheme.headlineLarge),
              const SizedBox(height: Space.sm),
              Text(
                _signUp ? 'Your fridge and saved recipes stay with your account.' : 'Sign in to see your fridge and recipes.',
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: Space.xxl),
              if (_signUp) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  decoration: const InputDecoration(labelText: 'First name (optional)'),
                ),
                const SizedBox(height: Space.lg),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => v != null && RegExp(r'^\S+@\S+\.\S+$').hasMatch(v.trim()) ? null : 'Enter your email address',
              ),
              const SizedBox(height: Space.lg),
              TextFormField(
                controller: _password,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: [_signUp ? AutofillHints.newPassword : AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: _signUp ? 'At least 8 characters' : null,
                  suffixIcon: IconButton(
                    tooltip: _showPassword ? 'Hide password' : 'Show password',
                    icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) => (v ?? '').length < (_signUp ? 8 : 1)
                    ? (_signUp ? 'Use at least 8 characters' : 'Enter your password')
                    : null,
              ),
              if (_error != null || _notice != null) ...[
                const SizedBox(height: Space.lg),
                InlineBanner(text: _error ?? _notice!, isError: _error != null),
              ],
              const SizedBox(height: Space.xl),
              FilledButton(
                onPressed: _busy ? null : _submit,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: _busy
                    ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_signUp ? 'Create account' : 'Sign in'),
              ),
              const SizedBox(height: Space.md),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _signUp = !_signUp;
                          _error = null;
                          _notice = null;
                        }),
                child: Text(_signUp ? 'I already have an account' : 'Create an account instead'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
