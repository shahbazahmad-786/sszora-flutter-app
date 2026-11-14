import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ssz_ora_flutter/core/api.dart';
import 'package:ssz_ora_flutter/core/theme.dart';
import 'package:ssz_ora_flutter/state/app_state.dart';
import 'package:ssz_ora_flutter/widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _codeStep = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() => _busy = true);
    try {
      final message = await context.read<AppState>().requestLoginCode(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeStep = true);
      showMessage(context, message ?? 'Check your email for a sign-in code.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final message = await context.read<AppState>().loginWithCode(_email.text.trim(), _code.text.trim());
      if (!mounted) return;
      showMessage(context, message ?? 'Signed in.');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: Text(_codeStep ? 'Enter code' : 'Log in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(app.storeName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            _codeStep
                ? 'Enter the 6-digit code we sent to ${_email.text.trim()}.'
                : 'Enter your email. We will send a sign-in code. No password needed.',
            style: const TextStyle(color: AppColors.navy500),
          ),
          const SizedBox(height: 20),
          if (!_codeStep) ...[
            const GoogleAuthButton(),
            const SizedBox(height: 16),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 16),
            BrandButton(label: 'Email me a code', busy: _busy, onPressed: _sendCode),
            const SizedBox(height: 8),
            BrandButton(label: 'Create account', outline: true, onPressed: () => Navigator.pushReplacementNamed(context, '/register')),
          ] else ...[
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
            ),
            const SizedBox(height: 16),
            BrandButton(label: 'Sign in', busy: _busy, onPressed: _verify),
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Resend code')),
            TextButton(onPressed: () => setState(() => _codeStep = false), child: const Text('Use a different email')),
          ],
          TextButton(onPressed: () => showServerDialog(context, app.api.baseUrl, app.setBaseUrl), child: Text('Server: ${app.api.baseUrl}', style: const TextStyle(color: AppColors.navy400, fontSize: 12))),
        ],
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _codeStep = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  Map<String, dynamic> _selectedCountry(AppState app) {
    for (final item in app.countries) {
      final map = asMap(item);
      if (str(map['code']) == app.api.country) return map;
    }
    return app.countries.isEmpty ? {} : asMap(app.countries.first);
  }

  Future<void> _sendCode() async {
    final app = context.read<AppState>();
    setState(() => _busy = true);
    try {
      final message = await app.requestRegisterCode({
        'first_name': _first.text.trim(),
        'last_name': _last.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'country': app.api.country,
      });
      if (!mounted) return;
      setState(() => _codeStep = true);
      showMessage(context, message ?? 'Check your email for a code.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    try {
      final message = await context.read<AppState>().registerWithCode(_email.text.trim(), _code.text.trim());
      if (!mounted) return;
      showMessage(context, message ?? 'Account created.');
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final country = _selectedCountry(app);
    final dial = str(country['phone_label']);
    final example = str(country['phone_example']);
    return Scaffold(
      appBar: AppBar(title: Text(_codeStep ? 'Confirm email' : 'Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (!_codeStep) ...[
            const GoogleAuthButton(),
            const SizedBox(height: 16),
            TextField(controller: _first, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'First name')),
            const SizedBox(height: 10),
            TextField(controller: _last, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Last name')),
            const SizedBox(height: 10),
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 10),
            if (app.countries.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: app.countries.any((item) => str(asMap(item)['code']) == app.api.country) ? app.api.country : str(asMap(app.countries.first)['code']),
                decoration: const InputDecoration(labelText: 'Country'),
                items: [
                  for (final raw in app.countries)
                    DropdownMenuItem(
                      value: str(asMap(raw)['code']),
                      child: Text('${str(asMap(raw)['name'])} (${str(asMap(raw)['phone_label'])})'),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) context.read<AppState>().setCountry(value);
                },
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone (optional)',
                prefixText: dial.isEmpty ? null : '$dial ',
                helperText: example.isEmpty ? 'Optional' : 'Example: $dial $example',
              ),
            ),
            const SizedBox(height: 16),
            BrandButton(label: 'Email me a code', busy: _busy, onPressed: _sendCode),
            TextButton(onPressed: () => Navigator.pushReplacementNamed(context, '/login'), child: const Text('Already have an account? Log in')),
          ] else ...[
            const Text('Enter the 6-digit code from your email to create the account.', style: TextStyle(color: AppColors.navy500)),
            const SizedBox(height: 12),
            Text(_email.text.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
            ),
            const SizedBox(height: 16),
            BrandButton(label: 'Create account', busy: _busy, onPressed: _verify),
            TextButton(onPressed: _busy ? null : _sendCode, child: const Text('Resend code')),
            TextButton(onPressed: () => setState(() => _codeStep = false), child: const Text('Edit details')),
          ],
        ],
      ),
    );
  }
}

class GoogleAuthButton extends StatefulWidget {
  const GoogleAuthButton({super.key});

  @override
  State<GoogleAuthButton> createState() => _GoogleAuthButtonState();
}

class _GoogleAuthButtonState extends State<GoogleAuthButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      final message = await context.read<AppState>().loginWithGoogle();
      if (!mounted || message == null) return;
      showMessage(context, message);
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      showMessage(context, error.display);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
          onPressed: _busy ? null : _signIn,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.navy800,
            backgroundColor: Colors.white,
            side: const BorderSide(color: AppColors.navy200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleMark(),
                    SizedBox(width: 10),
                    Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: Divider()),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('OR', style: TextStyle(color: AppColors.navy400, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Divider()),
          ],
        ),
      ],
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(color: Color(0xFF4285F4), fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}
