import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/auth_widgets.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _loading  = false;
  bool _obscure  = true;
  bool _obscureC = true;
  String? _error;

  Future<void> _signUp() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final err = await AuthService.signUp(
        email: email, password: password, displayName: name);

    if (err != null) {
      if (!mounted) return;
      setState(() { _loading = false; _error = err; });
      return;
    }

    final uid = AuthService.currentUid!;
    await DatabaseService.createUserProfile(
        uid: uid, email: email, displayName: name);
    // AuthGate StreamBuilder handles navigation automatically
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18, color: Color(0xFF1A1A2E)),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              const Text('Create account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 6),
              Text('Start your personalised health journey.',
                  style: TextStyle(fontSize: 15, color: Colors.grey[500])),
              const SizedBox(height: 40),

              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 20),
              ],

              const FieldLabel('Full Name'),
              const SizedBox(height: 8),
              InputField(controller: _nameCtrl, hint: 'Jane Doe'),
              const SizedBox(height: 20),

              const FieldLabel('Email'),
              const SizedBox(height: 8),
              InputField(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              const FieldLabel('Password'),
              const SizedBox(height: 8),
              InputField(
                controller: _passwordCtrl,
                hint: '••••••••',
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20, color: Colors.grey[400],
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 20),

              const FieldLabel('Confirm Password'),
              const SizedBox(height: 8),
              InputField(
                controller: _confirmCtrl,
                hint: '••••••••',
                obscure: _obscureC,
                suffix: IconButton(
                  icon: Icon(
                    _obscureC ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 20, color: Colors.grey[400],
                  ),
                  onPressed: () => setState(() => _obscureC = !_obscureC),
                ),
              ),
              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      children: const [
                        TextSpan(text: 'Sign in',
                            style: TextStyle(
                                color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}
