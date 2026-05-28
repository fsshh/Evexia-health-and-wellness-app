import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/auth_widgets.dart';
import 'onboarding_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameCtrl = TextEditingController();
  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _loading        = false;
  bool _obscure        = true;
  bool _obscureC       = true;
  bool _checkingUser   = false;
  String? _error;
  String? _usernameError;

  // Debounce username check
  Future<void> _checkUsername(String value) async {
    final formatErr = DatabaseService.validateUsername(value);
    if (formatErr != null) {
      setState(() => _usernameError = formatErr);
      return;
    }
    setState(() { _checkingUser = true; _usernameError = null; });
    final available = await DatabaseService.isUsernameAvailable(value);
    if (!mounted) return;
    setState(() {
      _checkingUser  = false;
      _usernameError = available ? null : 'Username is already taken.';
    });
  }

  Future<void> _signUp() async {
    final username = _usernameCtrl.text.trim();
    final name     = _nameCtrl.text.trim();        // optional
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    // Validate required fields
    final usernameErr = DatabaseService.validateUsername(username);
    if (usernameErr != null) {
      setState(() => _usernameError = usernameErr);
      return;
    }
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all required fields.');
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

    // Check username availability one more time before committing
    final available = await DatabaseService.isUsernameAvailable(username);
    if (!available) {
      if (!mounted) return;
      setState(() { _loading = false; _usernameError = 'Username was just taken. Please choose another.'; });
      return;
    }

    // Display name falls back to username if name is blank
    final displayName = name.isEmpty ? username : name;

    final err = await AuthService.signUp(
        email: email, password: password, displayName: displayName);

    if (err != null) {
      if (!mounted) return;
      setState(() { _loading = false; _error = err; });
      return;
    }

    if (!mounted) return;

    final uid = AuthService.currentUid!;
    await DatabaseService.createUserProfile(
      uid:         uid,
      email:       email,
      displayName: displayName,
      username:    username,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final bg       = isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF1EFEE);
    final txt      = isDark ? Colors.white : const Color(0xFF454D6E);
    final subTxt   = isDark ? Colors.grey[400]! : Colors.grey[500]!;
    final hintTxt  = isDark ? Colors.grey[500]! : Colors.grey[500]!;
    final btnBg    = isDark ? const Color(0xFF5C6491) : const Color(0xFF454D6E);
    final linkTxt  = isDark ? const Color(0xFF9BA3D4) : const Color(0xFF454D6E);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              IconButton(
                icon: Icon(Icons.arrow_back_ios, size: 18, color: txt),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),

              Text('Create account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: txt)),
              const SizedBox(height: 6),
              Text('Start your personalised health journey.',
                  style: TextStyle(fontSize: 15, color: subTxt)),
              const SizedBox(height: 40),

              if (_error != null) ...[
                ErrorBanner(message: _error!),
                const SizedBox(height: 20),
              ],

              // ── Username (required) ──────────────────
              const FieldLabel('Username'),
              const SizedBox(height: 4),
              Text('Letters, numbers, "." and "_" only. No spaces.',
                  style: TextStyle(fontSize: 11, color: hintTxt)),
              const SizedBox(height: 8),
              InputField(
                controller: _usernameCtrl,
                hint: 'e.g. jane_doe',
                suffix: _checkingUser
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)))
                    : (_usernameError == null && _usernameCtrl.text.isNotEmpty)
                        ? const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 20)
                        : null,
                onChanged: (v) {
                  if (v.length >= 3) {
                    _checkUsername(v);
                  } else {
                    setState(() => _usernameError = null);
                  }
                },
              ),
              if (_usernameError != null) ...[
                const SizedBox(height: 6),
                Text(_usernameError!,
                    style: TextStyle(fontSize: 12, color: Colors.red.shade400)),
              ],
              const SizedBox(height: 20),

              // ── Full Name (optional) ──────────────────
              Row(children: [
                const FieldLabel('Full Name'),
                const SizedBox(width: 6),
                Text('(optional)',
                    style: TextStyle(fontSize: 11, color: Colors.grey[400],
                        fontStyle: FontStyle.italic)),
              ]),
              const SizedBox(height: 8),
              InputField(controller: _nameCtrl, hint: 'Jane Doe'),
              const SizedBox(height: 20),

              // ── Email ────────────────────────────────
              const FieldLabel('Email'),
              const SizedBox(height: 8),
              InputField(
                controller: _emailCtrl,
                hint: 'you@example.com',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              // ── Password ─────────────────────────────
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

              // ── Confirm Password ──────────────────────
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
                    backgroundColor: btnBg,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
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
                      style: TextStyle(color: subTxt, fontSize: 14),
                      children: [
                        TextSpan(text: 'Sign in',
                            style: TextStyle(color: linkTxt, fontWeight: FontWeight.w700)),
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
    _usernameCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }
}