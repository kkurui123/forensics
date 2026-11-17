import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';
import 'forgot_password_screen.dart';
import 'guard_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.role,
  });

  final String role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _background = Color(0xFF000000);
  static const Color _inputBackground = Color(0xFF191919);
  static const Color _red = Color(0xFFEF0033);
  static const Color _mutedText = Color(0xFFBDBDBD);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _identifierController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _hidePassword = true;

  String? _errorMessage;

  bool get _isAdmin => widget.role.toUpperCase() == 'ADMIN';

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
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
      final user = await ApiService.instance.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
        expectedRole: widget.role.toUpperCase(),
      );

      if (!mounted) {
        return;
      }

      final Widget dashboard;

      if (user['role'] == 'ADMIN') {
        dashboard = AdminDashboardScreen(user: user);
      } else if (user['role'] == 'GUARD') {
        dashboard = GuardDashboardScreen(user: user);
      } else {
        throw const ApiException(
          'This account has an unsupported role.',
        );
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (_) => dashboard,
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error is ApiException
            ? error.message
            : 'Unable to log in. Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRegistration() async {
    if (_isLoading) {
      return;
    }

    final registered = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const RegisterScreen(),
      ),
    );

    if (!mounted || registered != true) {
      return;
    }

    setState(() {
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Your Guard account has been created. Please log in.',
        ),
      ),
    );
  }

  Future<void> _openForgotPassword() async {
    if (_isLoading) {
      return;
    }

    final reset = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const ForgotPasswordScreen(),
      ),
    );

    if (!mounted || reset != true) {
      return;
    }

    _passwordController.clear();

    setState(() {
      _errorMessage = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password reset successfully. Please log in.',
        ),
      ),
    );
  }

  void _showSupport() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _inputBackground,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text(
            'SecureChat Support',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'For help accessing your account, email:',
                style: TextStyle(
                  color: _mutedText,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              SelectableText(
                'kkurui951@gmail.com',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Do not share your password or password-reset code.',
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: _red,
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String? _validateIdentifier(String? value) {
    final identifier = value?.trim() ?? '';

    if (identifier.isEmpty) {
      return _isAdmin
          ? 'Enter your email address.'
          : 'Enter your email or phone number.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Enter your password.';
    }

    return null;
  }

  InputDecoration _inputDecoration({
    required String hint,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: _mutedText,
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: _inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 23,
      ),
      suffixIcon: suffixIcon,
      suffixIconConstraints: const BoxConstraints(
        minWidth: 58,
        minHeight: 58,
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
        const SizedBox(height: 34),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: _isAdmin
                    ? 'Manage your workspace.\n'
                    : 'Connect with your team.\n',
              ),
              TextSpan(
                text: _isAdmin
                    ? 'Review incidents securely.'
                    : 'Keep every conversation secure.',
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
          _isAdmin ? 'Administrator sign in' : 'Guard sign in',
          style: const TextStyle(
            color: _mutedText,
            fontSize: 13,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _identifierController,
            enabled: !_isLoading,
            keyboardType:
                _isAdmin ? TextInputType.emailAddress : TextInputType.text,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: _red,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            decoration: _inputDecoration(
              hint: _isAdmin ? 'Email address' : 'Email or phone number',
            ),
            validator: _validateIdentifier,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _passwordController,
            enabled: !_isLoading,
            obscureText: _hidePassword,
            autocorrect: false,
            enableSuggestions: false,
            cursorColor: _red,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
            decoration: _inputDecoration(
              hint: 'Password',
              suffixIcon: IconButton(
                tooltip: _hidePassword ? 'Show password' : 'Hide password',
                onPressed: _isLoading
                    ? null
                    : () {
                        setState(() {
                          _hidePassword = !_hidePassword;
                        });
                      },
                icon: Icon(
                  _hidePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _mutedText,
                  size: 25,
                ),
              ),
            ),
            validator: _validatePassword,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _openForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: _red,
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
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
            ),
          ],
          const SizedBox(height: 34),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _isLoading ? null : _login,
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF86152D),
                disabledForegroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 19,
                          height: 19,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Logging in…',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Log in',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
          if (!_isAdmin) ...[
            const SizedBox(height: 28),
            Center(
              child: TextButton(
                onPressed: _isLoading ? null : _openRegistration,
                style: TextButton.styleFrom(
                  foregroundColor: _red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Trouble logging in?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          "Having issues accessing your account? We're happy to help.",
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedText,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _showSupport,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: _mutedText,
              side: const BorderSide(
                color: Colors.white,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 26,
                vertical: 14,
              ),
              shape: const StadiumBorder(),
            ),
            child: const Text(
              'Email Support',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
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
                  const SizedBox(height: 42),
                  _buildLoginForm(),
                  const SizedBox(height: 48),
                  _buildSupportSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
