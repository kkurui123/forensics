import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import 'create_incident_screen.dart';

class GuardProfileScreen extends StatefulWidget {
  const GuardProfileScreen({
    super.key,
    required this.guard,
    required this.conversationId,
  });

  final Map<String, dynamic> guard;
  final String conversationId;

  @override
  State<GuardProfileScreen> createState() => _GuardProfileScreenState();
}

class _GuardProfileScreenState extends State<GuardProfileScreen> {
  static const Color _background = Color(0xFF17212B);
  static const Color _card = Color(0xFF232F3D);
  static const Color _cardDivider = Color(0xFF2E3D4D);
  static const Color _accent = Color(0xFF5EB5F7);
  static const Color _muted = Color(0xFF8FA3B4);
  static const Color _danger = Color(0xFFEF5350);

  String get _fullName {
    final name = widget.guard['full_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'Guard' : name;
  }

  String get _email {
    return widget.guard['email']?.toString().trim() ?? '';
  }

  String get _phone {
    return widget.guard['phone']?.toString().trim() ?? '';
  }

  String get _zone {
    return widget.guard['zone']?.toString().trim() ?? '';
  }

  String get _profilePhotoUrl {
    return widget.guard['profile_photo_url']?.toString().trim() ?? '';
  }

  String get _initial {
    final name = _fullName.trim();

    return name.isEmpty ? 'G' : name[0].toUpperCase();
  }

  void _backToConversation() {
    Navigator.of(context).pop();
  }

  void _reportGuard() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateIncidentScreen(
          reportedGuard: widget.guard,
        ),
      ),
    );
  }

  void _reportConversation() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CreateIncidentScreen(
          conversationId: widget.conversationId,
        ),
      ),
    );
  }

  Widget _avatar() {
    final fallback = Center(
      child: Text(
        _initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      width: 136,
      height: 136,
      decoration: BoxDecoration(
        color: const Color(0xFF3D6E8F),
        shape: BoxShape.circle,
        border: Border.all(
          color: _background,
          width: 5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _profilePhotoUrl.isEmpty
          ? fallback
          : Image.network(
              _profilePhotoUrl.startsWith('http')
                  ? _profilePhotoUrl
                  : '${ApiService.baseUrl}$_profilePhotoUrl',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _cardDivider,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _muted,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = _accent,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _cardDivider,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Icon(
          icon,
          color: iconColor,
          size: 26,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: _muted,
        ),
        onTap: onTap,
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
        title: const Text(
          'Guard Profile',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          const SizedBox(height: 8),
          Center(child: _avatar()),
          const SizedBox(height: 18),
          Text(
            _fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _zone.isEmpty ? 'Guard' : _zone,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          _section(
            title: 'Account',
            children: [
              _row(
                icon: Icons.person_outline_rounded,
                label: 'Full name',
                value: _fullName,
              ),
              _row(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _email,
              ),
              _row(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value: _phone,
              ),
              _row(
                icon: Icons.location_on_outlined,
                label: 'Zone',
                value: _zone,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _section(
            title: 'Messaging',
            children: [
              _actionRow(
                icon: Icons.arrow_back_rounded,
                title: 'Back to conversation',
                subtitle: 'Return to your encrypted chat',
                onTap: _backToConversation,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _section(
            title: 'Safety',
            children: [
              _actionRow(
                icon: Icons.person_off_outlined,
                title: 'Report Guard',
                subtitle: 'Report inappropriate Guard behaviour',
                iconColor: _danger,
                onTap: _reportGuard,
              ),
              _actionRow(
                icon: Icons.report_outlined,
                title: 'Report Conversation',
                subtitle: 'Report an issue in this conversation',
                iconColor: _danger,
                onTap: _reportConversation,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
