import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const Color _background = Color(0xFF000000);
  static const Color _inputBackground = Color(0xFF191919);
  static const Color _red = Color(0xFFEF0033);
  static const Color _mutedText = Color(0xFFBDBDBD);

  static const TextStyle _inputStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
  );

  static const List<String> _zones = [
    'Gate A',
    'Gate B',
    'Gate C',
    'Gate D',
    'Gate E',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmationController = TextEditingController();

  String? _selectedZone;
  String? _errorMessage;

  bool _isLoading = false;
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) {
      return;
    }

    final form = _formKey.currentState;

    if (form == null || !form.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.instance.register(
        fullName: _nameController.text.trim().replaceAll(
              RegExp(r'\s+'),
              ' ',
            ),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        zone: _selectedZone!,
        password: _passwordController.text,
        confirmPassword: _confirmationController.text,
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
            : 'Unable to create your account. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: _mutedText,
        size: 24,
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
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
        SizedBox(height: 32),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Join your team.\n',
              ),
              TextSpan(
                text: 'Create your Guard account.',
                style: TextStyle(
                  color: _red,
                ),
              ),
            ],
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Enter your details and choose your assigned gate to get started.',
          style: TextStyle(
            color: _mutedText,
            fontSize: 14,
            height: 1.6,
          ),
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

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _nameController,
            enabled: !_isLoading,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            cursorColor: _red,
            style: _inputStyle,
            decoration: _decoration(
              hint: 'Full name',
            ),
            validator: (value) {
              final name = (value ?? '').trim().replaceAll(
                    RegExp(r'\s+'),
                    ' ',
                  );

              if (name.length < 2 || name.length > 120) {
                return 'Enter a name of 2–120 characters.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _emailController,
            enabled: !_isLoading,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: _red,
            style: _inputStyle,
            decoration: _decoration(
              hint: 'Email address',
            ),
            validator: (value) {
              final email = value?.trim() ?? '';

              if (!RegExp(
                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
              ).hasMatch(email)) {
                return 'Enter a valid email address.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            enabled: !_isLoading,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            cursorColor: _red,
            style: _inputStyle,
            decoration: _decoration(
              hint: 'Phone number, e.g. 0712345678',
            ),
            validator: (value) {
              if (!RegExp(r'^[0-9]{10}$').hasMatch(value ?? '')) {
                return 'Enter exactly 10 digits.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            isExpanded: true,
            dropdownColor: _inputBackground,
            style: _inputStyle,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _mutedText,
            ),
            decoration: _decoration(
              hint: 'Select your gate',
            ),
            hint: const Text(
              'Select your gate',
              style: TextStyle(
                color: _mutedText,
                fontSize: 16,
              ),
            ),
            items: _zones.map((zone) {
              return DropdownMenuItem<String>(
                value: zone,
                child: Text(
                  zone,
                  style: _inputStyle,
                ),
              );
            }).toList(),
            onChanged: _isLoading
                ? null
                : (value) {
                    setState(() {
                      _selectedZone = value;
                    });
                  },
            validator: (value) {
              if (value == null) {
                return 'Select your zone.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: _hidePassword,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            cursorColor: _red,
            style: _inputStyle,
            decoration: _decoration(
              hint: 'Password',
              helperText: 'Use 12–128 characters.',
              suffixIcon: _passwordToggle(
                hidden: _hidePassword,
                onPressed: () {
                  setState(() {
                    _hidePassword = !_hidePassword;
                  });
                },
              ),
            ),
            validator: (value) {
              final password = value ?? '';

              if (password.length < 12 || password.length > 128) {
                return 'Use 12–128 characters.';
              }

              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmationController,
            enabled: !_isLoading,
            obscureText: _hideConfirmation,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            cursorColor: _red,
            style: _inputStyle,
            onFieldSubmitted: (_) => _register(),
            decoration: _decoration(
              hint: 'Confirm password',
              suffixIcon: _passwordToggle(
                hidden: _hideConfirmation,
                onPressed: () {
                  setState(() {
                    _hideConfirmation = !_hideConfirmation;
                  });
                },
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Confirm your password.';
              }

              if (value != _passwordController.text) {
                return 'Passwords do not match.';
              }

              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 20),
            _buildErrorMessage(),
          ],
          const SizedBox(height: 32),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _register,
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
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Creating account…',
                            style: TextStyle(
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Create Guard account',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 22),
          TextButton(
            onPressed: _isLoading
                ? null
                : () {
                    Navigator.of(context).pop();
                  },
            style: TextButton.styleFrom(
              foregroundColor: _red,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 14,
              ),
            ),
            child: const Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(
                      color: _mutedText,
                      fontWeight: FontWeight.w400,
                    ),
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
            padding: const EdgeInsets.fromLTRB(
              24,
              12,
              24,
              40,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 36),
                  _buildRegistrationForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
