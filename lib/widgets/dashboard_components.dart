import 'package:material_ui/material_ui.dart';

import '../screens/role_screen.dart';
import '../services/api_service.dart';

// Shared dashboard colors.
const Color dashboardInk = Color(0xFF153B56);
const Color dashboardMuted = Color(0xFF617F94);
const Color dashboardBlue = Color(0xFF218FD0);

/// Removes the local session and returns to role selection.
Future<void> logoutFromDashboard(BuildContext context) async {
  try {
    await ApiService.instance.logout();

    if (!context.mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const RoleScreen()),
      (route) => false,
    );
  } catch (_) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to log out. Please try again.'),
      ),
    );
  }
}

/// Displays a notice for a feature that is not connected yet.
void showFeaturePending(BuildContext context, String feature) {
  final messenger = ScaffoldMessenger.of(context);

  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      content: Text('$feature is not connected yet.'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Light-blue welcome panel shared by both dashboards.
class DashboardWelcome extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;
  final String email;
  final IconData icon;
  final String? fullName;
  final String? profilePhotoUrl;

  const DashboardWelcome({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.email,
    required this.icon,
    this.fullName,
    this.profilePhotoUrl,
  });

  String get _initial {
    final name = (fullName ?? email).trim();

    return name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  Widget _buildAvatar() {
    final photoUrl = (profilePhotoUrl ?? '').trim();

    if (photoUrl.isEmpty) {
      return Text(
        _initial,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: dashboardBlue,
        ),
      );
    }

    final fullUrl = photoUrl.startsWith('http')
        ? photoUrl
        : '${ApiService.baseUrl}$photoUrl';

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Text(
          _initial,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: dashboardBlue,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0D47A1),
            Color(0xFF1E88E5),
            Color(0xFF42A5F5),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: _buildAvatar(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName ?? 'Welcome back',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.30),
                  ),
                ),
                child: Text(
                  role,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// A clickable dashboard action card.
class DashboardFeatureCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBackground;

  const DashboardFeatureCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.iconBackground,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = this.iconColor ?? dashboardBlue;
    final iconBackground = this.iconBackground ?? const Color(0xFFEAF6FF);

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFFDCECF7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      icon,
                      color: iconColor,
                      size: 26,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  color: dashboardInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(
                  color: dashboardMuted,
                  height: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Arranges cards in one or two columns according to available width.
class DashboardFeatureGrid extends StatelessWidget {
  final List<Widget> children;

  const DashboardFeatureGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 16;

        final int columns = constraints.maxWidth >= 640 ? 2 : 1;

        final double cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((child) {
            return SizedBox(width: cardWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}
