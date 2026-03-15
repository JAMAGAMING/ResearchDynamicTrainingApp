import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_storage.dart';
import 'sync_service.dart';
import 'homepage.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscurePassword        = true;
  bool _obscureConfirmPassword = true;
  bool _loading                = false;
  String? _errorMessage;

  Future<void> _register() async {
    final fullName = _fullNameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm  = _confirmPasswordController.text;

    if (fullName.isEmpty || username.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Please fill out all fields');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters');
      return;
    }

    setState(() { _loading = true; _errorMessage = null; });

    final result = await ApiService.register(
      username: username,
      fullName: fullName,
      password: password,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _loading      = false;
        _errorMessage = 'Could not connect to server. Check your connection.';
      });
      return;
    }

    final token = result['token'] as String?;
    final user  = result['user']  as Map<String, dynamic>?;

    if (token == null || user == null) {
      setState(() {
        _loading      = false;
        _errorMessage = result['error'] as String? ?? 'Registration failed';
      });
      return;
    }

    await AuthStorage.save(token: token, user: user);
    SyncService.fullSync(); // push any local plans in background

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
      (r) => false,
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Running icon
                  const Icon(
                    Icons.directions_run,
                    size: 48,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 24),

                  // Welcome text
                  const Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle
                  const Text(
                    'Please Fill Out the Required Fields',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Full Name field
                  _buildTextField(
                    label: 'Full Name',
                    controller: _fullNameController,
                  ),
                  const SizedBox(height: 16),

                  // Username field
                  _buildTextField(
                    label: 'Username',
                    controller: _usernameController,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  _buildTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    toggleObscure: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password field
                  _buildTextField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    toggleObscure: () {
                      setState(() {
                        _obscureConfirmPassword = !_obscureConfirmPassword;
                      });
                    },
                  ),
                  const SizedBox(height: 32),

                  // Error message
                  if (_errorMessage != null) ...[
                    Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Register button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20, width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text(
                              'Register',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.only(top: 16.0), // adds space above the button
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black87, // text color
                      ),
                      child: const Text('Back to Login'),
                    ),
                  )

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper to create text fields with optional password toggle
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    VoidCallback? toggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            border: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black54),
            ),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black54),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black87, width: 2),
            ),
            contentPadding: const EdgeInsets.only(bottom: 8),
            suffixIcon: toggleObscure != null
                ? IconButton(
              icon: Icon(
                obscureText ? Icons.visibility : Icons.visibility_off,
                color: Colors.black54,
              ),
              onPressed: toggleObscure,
            )
                : null,
          ),
        ),
      ],
    );
  }
}