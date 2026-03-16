import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_storage.dart';
import 'homepage.dart';

// ─────────────────────────────────────────────
//  RegisterScreen
//
//  Register flow:
//    1. POST /auth/register
//    2. Save token + user to AuthStorage
//    3. Navigate to HomePage immediately
//
//  No plan sync here — happens in background
//  when SelectTrainingPlanScreen opens.
// ─────────────────────────────────────────────

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _fullNameCtrl  = TextEditingController();
  final _usernameCtrl  = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  bool    _obscurePassword = true;
  bool    _obscureConfirm  = true;
  bool    _loading         = false;
  String? _error;

  Future<void> _register() async {
    final fullName = _fullNameCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm  = _confirmCtrl.text;

    if (fullName.isEmpty || username.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill out all fields');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final result = await ApiService.register(
      username: username,
      fullName: fullName,
      password: password,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() { _loading = false; _error = 'Could not reach server. Check your connection.'; });
      return;
    }

    final token = result['token'] as String?;
    final user  = result['user']  as Map<String, dynamic>?;

    if (token == null || user == null) {
      setState(() { _loading = false; _error = result['error'] as String? ?? 'Registration failed.'; });
      return;
    }

    await AuthStorage.save(token: token, user: user);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (r) => false,
    );
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_run, size: 48, color: Colors.black87),
                  const SizedBox(height: 24),
                  const Text('Create Account',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 8),
                  const Text('Please fill out all fields',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 32),

                  _field('Full Name',        _fullNameCtrl),
                  const SizedBox(height: 16),
                  _field('Username',         _usernameCtrl),
                  const SizedBox(height: 16),
                  _passwordField('Password',         _passwordCtrl, _obscurePassword,
                          () => setState(() => _obscurePassword = !_obscurePassword)),
                  const SizedBox(height: 16),
                  _passwordField('Confirm Password',  _confirmCtrl,  _obscureConfirm,
                          () => setState(() => _obscureConfirm  = !_obscureConfirm)),
                  const SizedBox(height: 32),

                  if (_error != null) ...[
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity, height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87, foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Register', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(foregroundColor: Colors.black87),
                      child: const Text('Back to Login'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 8),
      TextFormField(
        controller: ctrl,
        decoration: const InputDecoration(
          border:         UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          enabledBorder:  UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          focusedBorder:  UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
          contentPadding: EdgeInsets.only(bottom: 8),
        ),
      ),
    ],
  );

  Widget _passwordField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
          const SizedBox(height: 8),
          TextFormField(
            controller: ctrl,
            obscureText: obscure,
            decoration: InputDecoration(
              border:         const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
              enabledBorder:  const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
              focusedBorder:  const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
              contentPadding: const EdgeInsets.only(bottom: 8),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: Colors.black54),
                onPressed: toggle,
              ),
            ),
          ),
        ],
      );
}