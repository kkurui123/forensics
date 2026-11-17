import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const Color _background = Color(0xFF000000);
  static const Color _inputBackground = Color(0xFF191919);
  static const Color _red = Color(0xFFEF0033);
  static const Color _mutedText = Color(0xFFBDBDBD);

  static const TextStyle _inputStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
  );

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSendingCode = false;
  bool _isResettingPassword = false;
  bool _codeSent = false;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;

  String? _errorMessage;

  bool get _isBusy => _isSendingCode || _isResettingPassword;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendResetCode() async {
    if (_isBusy) {
      return;
    }

    final email = _emailController.text.trim();
    final emailError = _validateEmail(email);

    if (emailError != null) {
      setState(() {
        _errorMessage = emailError;
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    try {
      final response = await ApiService.instance.forgotPassword(email);

      if (!mounted) {
        return;
      }

      setState(() {
        _codeSent = true;
        _codeController.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                'If this email is registered, a reset code has been sent.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Could not send the reset code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_isBusy || !_codeSent) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isResettingPassword = true;
      _errorMessage = null;
    });

    try {
      await ApiService.instance.resetPassword(
        email: _emailController.text.trim(),
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Could not reset your password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResettingPassword = false;
        });
      }
    }
  }

  void _changeEmail() {
    if (_isBusy) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _codeSent = false;
      _errorMessage = null;
      _codeController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _hidePassword = true;
      _hideConfirmPassword = true;
    });
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your email address.';
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validateCode(String? value) {
    final code = value?.trim() ?? '';

    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return 'Enter the 6-digit reset code.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Enter a new password.';
    }

    if (password.length < 8 || password.length > 128) {
      return 'Use 8–128 characters.';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your new password.';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  InputDecoration _decoration({
    required String hint,
    Widget? suffixIcon,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _mutedText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 22,
      ),
      helperText: helperText,
      helperStyle: const TextStyle(
        color: _mutedText,
        fontSize: 12,
      ),
      helperMaxLines: 2,
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 56,
        minHeight: 56,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: _red,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xFFFF7B94),
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(
          color: Color(0xFFFF7B94),
          width: 1.4,
        ),
      ),
      errorStyle: const TextStyle(
        color: Color(0xFFFF9AAF),
        fontSize: 12,
      ),
      errorMaxLines: 2,
    );
  }

  Widget _passwordToggle({
    required bool hidden,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: hidden ? 'Show password' : 'Hide password',
      onPressed: _isBusy ? null : onPressed,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _mutedText,
        size: 24,
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'SecureChat',
                style: TextStyle(
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: ' Forensics',
                style: TextStyle(
                  color: _red,
                ),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 33,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.1,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 32),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _codeSent
                    ? 'Check your inbox.\n'
                    : 'Forgot your password?\n',
              ),
              TextSpan(
                text: _codeSent
                    ? 'Choose a new password.'
                    : "Let's get you back in.",
                style: const TextStyle(
                  color: _red,
                ),
              ),
            ],
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _codeSent
              ? 'If your email is registered, a 6-digit code has been '
                  'sent. Enter it below with your new password.'
              : 'Enter your registered email address to request '
                  'a 6-digit password-reset code.',
          style: const TextStyle(
            color: _mutedText,
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        TextFormField(
          controller: _codeController,
          enabled: !_isBusy,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          enableSuggestions: false,
          cursorColor: _red,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 6,
            fontWeight: FontWeight.w600,
          ),
          decoration: _decoration(
            hint: '6-digit reset code',
          ),
          validator: _validateCode,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _passwordController,
          enabled: !_isBusy,
          obscureText: _hidePassword,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          cursorColor: _red,
          style: _inputStyle,
          decoration: _decoration(
            hint: 'New password',
            helperText: 'Use 8–128 characters.',
            suffixIcon: _passwordToggle(
              hidden: _hidePassword,
              onPressed: () {
                setState(() {
                  _hidePassword = !_hidePassword;
                });
              },
            ),
          ),
          validator: _validatePassword,
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _confirmPasswordController,
          enabled: !_isBusy,
          obscureText: _hideConfirmPassword,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          cursorColor: _red,
          style: _inputStyle,
          onFieldSubmitted: (_) => _resetPassword(),
          decoration: _decoration(
            hint: 'Confirm new password',
            suffixIcon: _passwordToggle(
              hidden: _hideConfirmPassword,
              onPressed: () {
                setState(() {
                  _hideConfirmPassword = !_hideConfirmPassword;
                });
              },
            ),
          ),
          validator: _validateConfirmPassword,
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B1018),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF652032),
        ),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: Color(0xFFFFA5B7),
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final String label;

    if (_isSendingCode) {
      label = 'Sending code…';
    } else if (_isResettingPassword) {
      label = 'Resetting password…';
    } else {
      label = _codeSent ? 'Reset password' : 'Send reset code';
    }

    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed:
            _isBusy ? null : (_codeSent ? _resetPassword : _sendResetCode),
        style: FilledButton.styleFrom(
          backgroundColor: _red,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF86152D),
          disabledForegroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isBusy) ...[
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_isBusy && !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      cursorColor: _red,
                      style: _inputStyle,
                      decoration: _decoration(
                        hint: 'Email address',
                      ),
                      validator: _validateEmail,
                      onFieldSubmitted: (_) {
                        if (!_codeSent) {
                          _sendResetCode();
                        }
                      },
                    ),
                    if (_codeSent) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _isBusy ? null : _changeEmail,
                          style: TextButton.styleFrom(
                            foregroundColor: _red,
                          ),
                          child: const Text('Change email'),
                        ),
                      ),
                      _buildPasswordFields(),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      _buildErrorMessage(),
                    ],
                    const SizedBox(height: 32),
                    _buildPrimaryButton(),
                    if (_codeSent) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _isBusy ? null : _sendResetCode,
                        style: TextButton.styleFrom(
                          foregroundColor: _red,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        child: const Text(
                          'Send a new code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _isBusy
                          ? null
                          : () {
                              Navigator.of(context).pop();
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: _mutedText,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      child: const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'Remember your password? ',
                            ),
                            TextSpan(
                              text: 'Log in',
                              style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
