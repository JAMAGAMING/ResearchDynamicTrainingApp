import 'package:flutter/material.dart';
import 'api_service.dart';
import 'auth_storage.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew     = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _resetPassword() async {
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      setState(() { _errorMessage = 'Please fill in all fields'; _successMessage = null; });
      return;
    }
    if (newPass != confirm) {
      setState(() { _errorMessage = 'New passwords do not match'; _successMessage = null; });
      return;
    }
    if (newPass.length < 6) {
      setState(() { _errorMessage = 'New password must be at least 6 characters'; _successMessage = null; });
      return;
    }

    setState(() { _loading = true; _errorMessage = null; _successMessage = null; });

    final token = await AuthStorage.getToken();
    if (token == null) {
      setState(() { _loading = false; _errorMessage = 'Not logged in'; });
      return;
    }

    final result = await ApiService.resetPassword(
      token:           token,
      currentPassword: current,
      newPassword:     newPass,
    );

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _loading      = false;
        _errorMessage = 'Could not connect to server. Check your connection.';
      });
      return;
    }

    if (result['ok'] == true) {
      setState(() {
        _loading        = false;
        _successMessage = 'Password updated successfully';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    } else {
      setState(() {
        _loading      = false;
        _errorMessage = result['error'] as String? ?? 'Password reset failed';
      });
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
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

                  // Title
                  const Text(
                    'Password Reset',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Current Password
                  _buildPasswordField(
                    label: 'Current Password',
                    controller: _currentPasswordController,
                    obscure: _obscureCurrent,
                    toggle: () {
                      setState(() {
                        _obscureCurrent = !_obscureCurrent;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // New Password
                  _buildPasswordField(
                    label: 'New Password',
                    controller: _newPasswordController,
                    obscure: _obscureNew,
                    toggle: () {
                      setState(() {
                        _obscureNew = !_obscureNew;
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  // Confirm Password
                  _buildPasswordField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    obscure: _obscureConfirm,
                    toggle: () {
                      setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      });
                    },
                  ),

                  const SizedBox(height: 40),

                  // Feedback messages
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],
                  if (_successMessage != null) ...[
                    Text(_successMessage!,
                        style: const TextStyle(color: Colors.green, fontSize: 13),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],

                  // Reset Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _resetPassword,
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
                              'Reset Password',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Back Button
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Back',
                      style: TextStyle(color: Colors.black87),
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback toggle,
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
          obscureText: obscure,
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
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility : Icons.visibility_off,
                color: Colors.black54,
              ),
              onPressed: toggle,
            ),
          ),
        ),
      ],
    );
  }
}