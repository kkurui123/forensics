import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';
import 'guard_dashboard_screen.dart';
import 'role_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _background = Color(0xFF121820);
  static const Color _surface = Color(0xFF1B242E);
  static const Color _accent = Color(0xFFFF6B7A);
  static const Color _accentDark = Color(0xFFE4485C);
  static const Color _muted = Color(0xFFA9B7C4);

  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final token = await ApiService.instance.getAccessToken();

      if (token == null || token.isEmpty) {
        _openRoleScreen();
        return;
      }

      final user = await ApiService.instance.getCurrentUser();

      if (!mounted) {
        return;
      }

      final role = (user['role'] ?? '').toString().toUpperCase();

      if (role == 'ADMIN') {
        _openDashboard(
          AdminDashboardScreen(user: user),
        );
      } else if (role == 'GUARD') {
        _openDashboard(
          GuardDashboardScreen(user: user),
        );
      } else {
        await ApiService.instance.logout();
        _openRoleScreen();
      }
    } catch (error) {
      await ApiService.instance.logout();

      if (!mounted) {
        return;
      }

      _openRoleScreen();
    }
  }

  void _openRoleScreen() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => const RoleScreen(),
      ),
    );
  }

  void _openDashboard(Widget dashboard) {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => dashboard,
      ),
    );
  }

  Widget _featureChip({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: const Color(0xFF2C3945),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: _accent,
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF151C25),
              Color(0xFF121820),
              Color(0xFF0E141B),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -110,
                right: -90,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accent.withValues(alpha: 0.20),
                        _accent.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -130,
                left: -100,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _accentDark.withValues(alpha: 0.14),
                        _accentDark.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(),
                    Container(
                      width: 138,
                      height: 138,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF243141),
                            Color(0xFF182230),
                          ],
                        ),
                        border: Border.all(
                          color: _accent.withValues(alpha: 0.35),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.22),
                            blurRadius: 38,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        size: 66,
                        color: _accent,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'SecureChat',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Secure communication\nfor Guards',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        color: _muted,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 9,
                      runSpacing: 9,
                      children: [
                        _featureChip(
                          icon: Icons.lock_rounded,
                          label: 'Encrypted',
                        ),
                        _featureChip(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Secure Chat',
                        ),
                        _featureChip(
                          icon: Icons.shield_outlined,
                          label: 'Guard Safety',
                        ),
                      ],
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              _isCheckingSession ? null : _openRoleScreen,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: const Color(0xFF201014),
                            disabledBackgroundColor:
                                _accent.withValues(alpha: 0.45),
                            disabledForegroundColor: const Color(0xFF3A2227),
                            minimumSize: const Size.fromHeight(58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 0,
                          ),
                          child: _isCheckingSession
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF201014),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Get Started',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    SizedBox(width: 9),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 21,
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isCheckingSession
                          ? 'Checking your session…'
                          : 'Tap Get Started to continue',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: 132,
                      child: LinearProgressIndicator(
                        value: _isCheckingSession ? null : 1,
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(10),
                        backgroundColor: const Color(0xFF26313C),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          _accent,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
