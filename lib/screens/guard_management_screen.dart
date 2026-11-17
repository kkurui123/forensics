import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class GuardManagementScreen extends StatefulWidget {
  const GuardManagementScreen({super.key});

  @override
  State<GuardManagementScreen> createState() => _GuardManagementScreenState();
}

class _GuardManagementScreenState extends State<GuardManagementScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  bool _isLoading = true;
  String? _errorMessage;

  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        _filteredUsers = List<Map<String, dynamic>>.from(users);
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

  void _filterUsers(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List<Map<String, dynamic>>.from(_users);
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['full_name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          final phone = (user['phone'] ?? '').toString().toLowerCase();
          final zone = (user['zone'] ?? '').toString().toLowerCase();
          final role = (user['role'] ?? '').toString().toLowerCase();

          return name.contains(query) ||
              email.contains(query) ||
              phone.contains(query) ||
              zone.contains(query) ||
              role.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _updateUser(
    Map<String, dynamic> user,
    Future<Map<String, dynamic>> Function() action,
  ) async {
    final userId = (user['id'] ?? '').toString();

    setState(() {
      _busyUserId = userId;
    });

    try {
      final updated = await action();

      if (!mounted) {
        return;
      }

      setState(() {
        final index = _users.indexWhere(
          (item) => (item['id'] ?? '').toString() == userId,
        );

        if (index != -1) {
          _users[index] = updated;
        }

        _filterUsers(_searchController.text);
        _busyUserId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User updated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not update this user. Please try again.';

      setState(() {
        _busyUserId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _toggleSuspension(Map<String, dynamic> user) async {
    final isSuspended = user['is_suspended'] == true;

    final confirmed = await _confirmAction(
      title: isSuspended ? 'Activate user' : 'Suspend user',
      message: isSuspended
          ? 'Activate this account and allow it to sign in again?'
          : 'Suspend this account and block access to SecureChat?',
      confirmLabel: isSuspended ? 'Activate' : 'Suspend',
    );

    if (confirmed != true) {
      return;
    }

    await _updateUser(
      user,
      () => isSuspended
          ? ApiService.instance.activateUser(
              (user['id'] ?? '').toString(),
            )
          : ApiService.instance.suspendUser(
              (user['id'] ?? '').toString(),
            ),
    );
  }

  Future<void> _changeRole(
    Map<String, dynamic> user,
    String role,
  ) async {
    final currentRole = (user['role'] ?? '').toString().toUpperCase();

    if (currentRole == role) {
      return;
    }

    final confirmed = await _confirmAction(
      title: role == 'ADMIN' ? 'Make administrator' : 'Make Guard',
      message: role == 'ADMIN'
          ? 'Give this user administrator privileges?'
          : 'Change this user to a Guard account?',
      confirmLabel: 'Confirm',
    );

    if (confirmed != true) {
      return;
    }

    await _updateUser(
      user,
      () => ApiService.instance.changeUserRole(
        (user['id'] ?? '').toString(),
        role,
      ),
    );
  }

  Future<bool?> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: isDangerous
                    ? const Color(0xFFEF5350)
                    : const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('User Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Search by name, role, zone, email, or phone',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF1E88E5),
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF78909C),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterUsers('');
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.manage_accounts_rounded,
                  size: 18,
                  color: Color(0xFF1E88E5),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_filteredUsers.length} users',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF546E7A),
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh users',
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Color(0xFF1E88E5),
                  ),
                  onPressed: _isLoading ? null : _loadUsers,
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF1E88E5),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: Color(0xFFEF5350),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
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
        ),
      );
    }

    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF1E88E5),
              ),
              SizedBox(height: 16),
              Text(
                'No users found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try another name, role, zone, email, or phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF78909C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF1E88E5),
      onRefresh: _loadUsers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: _filteredUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredUsers[index];

          return _UserManagementCard(
            user: user,
            isBusy: _busyUserId == (user['id'] ?? '').toString(),
            onToggleSuspension: () => _toggleSuspension(user),
            onMakeAdmin: () => _changeRole(user, 'ADMIN'),
            onMakeGuard: () => _changeRole(user, 'GUARD'),
          );
        },
      ),
    );
  }
}

class _UserManagementCard extends StatelessWidget {
  const _UserManagementCard({
    required this.user,
    required this.isBusy,
    required this.onToggleSuspension,
    required this.onMakeAdmin,
    required this.onMakeGuard,
  });

  final Map<String, dynamic> user;
  final bool isBusy;
  final VoidCallback onToggleSuspension;
  final VoidCallback onMakeAdmin;
  final VoidCallback onMakeGuard;

  String get _name => (user['full_name'] ?? user['name'] ?? 'User').toString();

  String get _email => (user['email'] ?? '').toString();

  String get _phone => (user['phone'] ?? user['phone_number'] ?? '').toString();

  String get _zone => (user['zone'] ?? '').toString();

  String get _role => (user['role'] ?? 'GUARD').toString().toUpperCase();

  bool get _isSuspended => user['is_suspended'] == true;

  String get _photoUrl => (user['profile_photo_url'] ?? '').toString();

  String get _initial {
    final name = _name.trim();

    return name.isEmpty ? 'U' : name[0].toUpperCase();
  }

  Widget _buildAvatar() {
    if (_photoUrl.isEmpty) {
      return Center(
        child: Text(
          _initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E88E5),
          ),
        ),
      );
    }

    final fullUrl = _photoUrl.startsWith('http')
        ? _photoUrl
        : 'https://securechat-dp0j.onrender.com$_photoUrl';

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Text(
            _initial,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E88E5),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
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
                      _name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78909C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _phone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF78909C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _role == 'ADMIN'
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _role,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _role == 'ADMIN'
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _isSuspended
                          ? const Color(0xFFFFEBEE)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _isSuspended ? 'SUSPENDED' : 'ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _isSuspended
                            ? const Color(0xFFC62828)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 14,
                color: Color(0xFF78909C),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _zone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78909C),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isBusy)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1E88E5),
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: _isSuspended
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_rounded,
                  label: _isSuspended ? 'Activate' : 'Suspend',
                  color: _isSuspended
                      ? const Color(0xFF2E7D32)
                      : const Color(0xFFEF6C00),
                  onTap: onToggleSuspension,
                ),
                if (_role != 'ADMIN')
                  _ActionButton(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Make Admin',
                    color: const Color(0xFF1E88E5),
                    onTap: onMakeAdmin,
                  ),
                if (_role != 'GUARD')
                  _ActionButton(
                    icon: Icons.person_outline,
                    label: 'Make Guard',
                    color: const Color(0xFF546E7A),
                    onTap: onMakeGuard,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(
          color: color.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: Icon(
        icon,
        size: 18,
      ),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
