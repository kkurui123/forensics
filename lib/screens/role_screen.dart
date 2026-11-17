import 'package:material_ui/material_ui.dart';

import 'login_screen.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  static const Color _background = Color(0xFF000000);
  static const Color _panelBackground = Color(0xFF191919);
  static const Color _red = Color(0xFFEF0033);
  static const Color _mutedText = Color(0xFFBDBDBD);

  void _openLogin(BuildContext context, String role) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(role: role),
      ),
    );
  }

  Widget _buildBrand() {
    return const Text.rich(
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
    );
  }

  Widget _buildIntroduction() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Your team.\nYour conversations.\n',
              ),
              TextSpan(
                text: 'One secure workspace.',
                style: TextStyle(
                  color: _red,
                ),
              ),
            ],
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: 29,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        SizedBox(height: 18),
        Text(
          'Sign in to message your team or manage incident reports.',
          style: TextStyle(
            color: _mutedText,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _panelBackground,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF32101A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: _red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _mutedText,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: _mutedText,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choose your role',
          style: TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Select how you want to access SecureChat.',
          style: TextStyle(
            color: _mutedText,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildRoleCard(
          icon: Icons.shield_outlined,
          title: 'Guard',
          subtitle: 'Message your team and report incidents.',
          onTap: () => _openLogin(context, 'GUARD'),
        ),
        const SizedBox(height: 16),
        _buildRoleCard(
          icon: Icons.admin_panel_settings_outlined,
          title: 'Administrator',
          subtitle: 'Manage users and review incident reports.',
          onTap: () => _openLogin(context, 'ADMIN'),
        ),
        const SizedBox(height: 32),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: () => _openLogin(context, 'GUARD'),
            style: FilledButton.styleFrom(
              backgroundColor: _red,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
            ),
            child: const Text(
              'Continue as Guard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: () => _openLogin(context, 'ADMIN'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(
                color: Colors.white,
                width: 1.2,
              ),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
            ),
            child: const Text(
              'Continue as Admin',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        Icon(
          Icons.forum_outlined,
          color: _red,
          size: 25,
        ),
        SizedBox(height: 12),
        Text(
          'Communication. Incident reporting. Forensic review.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _mutedText,
            fontSize: 13,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              24,
              36,
              24,
              36,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildBrand(),
                  const SizedBox(height: 40),
                  _buildIntroduction(),
                  const SizedBox(height: 42),
                  _buildRoleSelection(context),
                  const SizedBox(height: 42),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
