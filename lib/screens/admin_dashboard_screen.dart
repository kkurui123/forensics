import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import '../widgets/dashboard_components.dart';
import 'forensic_reconstruction_screen.dart';
import 'guard_management_screen.dart';
import 'incident_requests_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const AdminDashboardScreen({super.key, required this.user});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  List<Map<String, dynamic>> _users = [];

  bool _isLoading = true;
  String? _errorMessage;

  String get _email => (widget.user['email'] ?? '').toString();

  String get _fullName =>
      (widget.user['full_name'] ?? widget.user['name'] ?? 'Admin').toString();

  String get _profilePhotoUrl =>
      (widget.user['profile_photo_url'] ?? '').toString();

  String get _initial {
    final name = _fullName.trim();

    return name.isEmpty ? 'A' : name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await ApiService.instance.getAdminUsers();

      if (!mounted) {
        return;
      }

      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not load users. Please try again.';

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  void _openGuardManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const GuardManagementScreen(),
      ),
    );
  }

  void _openIncidentRequests() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IncidentRequestsScreen(),
      ),
    );
  }

  void _openForensicReconstruction() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ForensicReconstructionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F9FE),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 88,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              backgroundImage: _profilePhotoUrl.isEmpty
                  ? null
                  : NetworkImage(
                      _profilePhotoUrl.startsWith('http')
                          ? _profilePhotoUrl
                          : '${ApiService.baseUrl}$_profilePhotoUrl',
                    ),
              child: _profilePhotoUrl.isEmpty
                  ? Text(
                      _initial,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: dashboardBlue,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Admin Console',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0D47A1),
                Color(0xFF1E88E5),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => logoutFromDashboard(context),
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              color: dashboardBlue,
              onRefresh: _loadUsers,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  DashboardWelcome(
                    role: 'ADMIN',
                    title: 'Manage. Review. Investigate.',
                    subtitle: 'Manage user accounts and review reported '
                        'incidents from your administration workspace.',
                    email: _email,
                    fullName: _fullName,
                    profilePhotoUrl: _profilePhotoUrl,
                    icon: Icons.admin_panel_settings_outlined,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(
                          color: dashboardBlue,
                        ),
                      ),
                    )
                  else if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF5350),
                            size: 40,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF37474F),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _loadUsers,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Row(
                      children: [
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.people_rounded,
                            title: 'Total users',
                            value: '${_users.length}',
                            color: dashboardBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.admin_panel_settings_rounded,
                            title: 'Admins',
                            value: '${_countAdmins()}',
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.person_outline,
                            title: 'Guards',
                            value: '${_countGuards()}',
                            color: const Color(0xFF1E88E5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _AdminStatCard(
                            icon: Icons.block_rounded,
                            title: 'Suspended',
                            value: '${_countSuspended()}',
                            color: const Color(0xFFEF5350),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 28),
                  const Text(
                    'Administration',
                    style: TextStyle(
                      color: dashboardInk,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your management and incident-review tools.',
                    style: TextStyle(color: dashboardMuted),
                  ),
                  const SizedBox(height: 18),
                  DashboardFeatureGrid(
                    children: [
                      DashboardFeatureCard(
                        title: 'User Management',
                        description:
                            'View users, suspend or activate accounts, '
                            'change roles, and delete users.',
                        icon: Icons.manage_accounts_rounded,
                        onTap: _openGuardManagement,
                      ),
                      DashboardFeatureCard(
                        title: 'Incident Requests',
                        description: 'Review submitted incidents and approve '
                            'or reject requests.',
                        icon: Icons.inbox_outlined,
                        iconColor: const Color(0xFFEF5350),
                        iconBackground: const Color(0xFFFFEBEE),
                        onTap: _openIncidentRequests,
                      ),
                      DashboardFeatureCard(
                        title: 'Forensic Reconstruction',
                        description: 'Review approved incidents and request '
                            'authorized message recovery.',
                        icon: Icons.manage_search_rounded,
                        onTap: _openForensicReconstruction,
                      ),
                      DashboardFeatureCard(
                        title: 'Evidence & Report',
                        description: 'Reserved for reconstructed evidence '
                            'and incident reports.',
                        icon: Icons.description_outlined,
                        onTap: () => showFeaturePending(
                          context,
                          'Evidence & Report',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _countAdmins() {
    return _users
        .where(
          (user) => (user['role'] ?? '').toString().toUpperCase() == 'ADMIN',
        )
        .length;
  }

  int _countGuards() {
    return _users
        .where(
          (user) => (user['role'] ?? '').toString().toUpperCase() == 'GUARD',
        )
        .length;
  }

  int _countSuspended() {
    return _users
        .where(
          (user) => user['is_suspended'] == true,
        )
        .length;
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78909C),
            ),
          ),
        ],
      ),
    );
  }
}
