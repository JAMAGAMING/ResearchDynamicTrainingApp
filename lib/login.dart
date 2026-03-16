import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_storage.dart';
import 'plan_storage.dart';
import 'homepage.dart';
import 'register.dart';

// ─────────────────────────────────────────────
//  LoginScreen
//
//  Login flow:
//    1. POST /auth/login
//    2. Save token + user to AuthStorage
//    3. Navigate to HomePage immediately
//
//  Plan sync happens in the background when
//  SelectTrainingPlanScreen opens — NOT here.
//
//  Guest mode:
//    Clears any stored token so SyncService
//    becomes a no-op for the session.
// ─────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool    _obscurePassword = true;
  bool    _loading         = false;
  String? _error;

  // ── Login ─────────────────────────────────────────────────────────────────
  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter both username and password');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final result = await ApiService.login(username: username, password: password);

    if (!mounted) return;

    // null = network error / timeout
    if (result == null) {
      setState(() { _loading = false; _error = 'Could not reach server. Check your connection.'; });
      return;
    }

    final status = result['_status'] as int? ?? 200;
    final token  = result['token']   as String?;
    final user   = result['user']    as Map<String, dynamic>?;

    if (token == null || user == null) {
      setState(() {
        _loading = false;
        _error   = status == 401
            ? 'Incorrect username or password.'
            : result['error'] as String? ?? 'Login failed.';
      });
      return;
    }

    // Save credentials and go — plan sync happens in SelectTrainingPlanScreen.
    await AuthStorage.save(token: token, user: user);

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (r) => false,
    );
  }

  // ── Guest / Offline mode ──────────────────────────────────────────────────
  Future<void> _enterGuestMode() async {
    // Clear any lingering token so SyncService skips all network calls.
    await AuthStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
          (r) => false,
    );
  }

  // ── Dev dialog: change server URL ─────────────────────────────────────────
  void _showDevDialog() {
    final ctrl = TextEditingController(text: ApiService.baseUrl);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Row(children: [
          Icon(Icons.build, size: 16, color: Colors.black54),
          SizedBox(width: 8),
          Text('Dev: Server URL', style: TextStyle(fontSize: 15, color: Colors.black87)),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(fontSize: 13, color: Colors.black87),
          decoration: const InputDecoration(
            hintText: 'http://192.168.x.x:3000',
            hintStyle: TextStyle(color: Colors.black38),
            border: UnderlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () async {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                await ApiService.setBaseUrl(url);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('URL set: $url', style: const TextStyle(fontSize: 12)),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.black87,
                  ));
                }
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Apply',
                style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.directions_run, size: 48, color: Colors.black87),
                      const SizedBox(height: 24),
                      const Text('Welcome Back',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 8),
                      const Text('Sign in to your account',
                          style: TextStyle(fontSize: 16, color: Colors.black54)),
                      const SizedBox(height: 32),

                      // Username
                      _field('Username', _usernameController),
                      const SizedBox(height: 24),

                      // Password
                      _passwordField(),
                      const SizedBox(height: 40),

                      // Error
                      if (_error != null) ...[
                        Text(_error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                      ],

                      // Log In
                      _primaryButton('Log In', _loading ? null : _login),
                      const SizedBox(height: 12),

                      // Create Account
                      _primaryButton('Create Account', () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterScreen()),
                      )),
                      const SizedBox(height: 24),

                      Row(children: [
                        Expanded(child: Divider(color: Colors.black12)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text('or', style: TextStyle(color: Colors.black38, fontSize: 13)),
                        ),
                        Expanded(child: Divider(color: Colors.black12)),
                      ]),
                      const SizedBox(height: 16),

                      // Continue Offline
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _enterGuestMode,
                          icon: const Icon(Icons.wifi_off, size: 18, color: Colors.black54),
                          label: const Text('Continue Offline',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text("Local plans only — changes won't sync to server",
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, color: Colors.black38)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Dev button — tiny wrench, bottom-right
          Positioned(
            bottom: 12, right: 14,
            child: GestureDetector(
              onTap: _showDevDialog,
              child: const Icon(Icons.build, size: 14, color: Color(0x33FFFFFF)),
            ),
          ),
        ],
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
          border:        UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
          contentPadding: EdgeInsets.only(bottom: 8),
        ),
      ),
    ],
  );

  Widget _passwordField() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87)),
      const SizedBox(height: 8),
      TextFormField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          border:        const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black54)),
          focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.black87, width: 2)),
          contentPadding: const EdgeInsets.only(bottom: 8),
          suffixIcon: IconButton(
            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: Colors.black54),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ),
    ],
  );

  Widget _primaryButton(String label, VoidCallback? onPressed) => SizedBox(
    width: double.infinity,
    height: 48,
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
      ),
      child: onPressed == null && label == 'Log In'
          ? const SizedBox(height: 20, width: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}