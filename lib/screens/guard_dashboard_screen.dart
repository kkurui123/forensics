import 'dart:async';
import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api_service.dart';
import 'chat_screen.dart';
import 'create_incident_screen.dart';
import 'my_profile_screen.dart';
import 'create_incident_screen.dart';

class GuardDashboardScreen extends StatefulWidget {
  const GuardDashboardScreen({
    super.key,
    required this.user,
  });

  final Map<String, dynamic> user;

  @override
  State<GuardDashboardScreen> createState() => _GuardDashboardScreenState();
}

class _GuardDashboardScreenState extends State<GuardDashboardScreen> {
  int _selectedIndex = 0;

  final TextEditingController _searchController = TextEditingController();

  Map<String, dynamic> _currentUser = {};

  List<Map<String, dynamic>> _guards = [];
  List<Map<String, dynamic>> _filteredGuards = [];

  Map<String, String> _conversationByGuardId = {};
  Map<String, int> _unreadByGuardId = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  bool _isLoading = true;
  String? _errorMessage;

  String get guardId => _currentUser['id'].toString();

  String get fullName =>
      (_currentUser['full_name'] ?? _currentUser['name'] ?? 'Guard').toString();

  String get email => (_currentUser['email'] ?? '').toString();

  String get phone =>
      (_currentUser['phone'] ?? _currentUser['phone_number'] ?? '').toString();

  String get zone => (_currentUser['zone'] ?? '').toString();

  String get profilePhotoUrl =>
      (_currentUser['profile_photo_url'] ?? '').toString();

  String get _initial {
    final name = fullName.trim();

    return name.isEmpty ? 'G' : name[0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();

    _currentUser = Map<String, dynamic>.from(widget.user);

    _loadDashboard();
    _connectForUnreadUpdates();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final guards = await ApiService.instance.getGuards();
      final conversations = await ApiService.instance.getConversations();
      final unreadCounts = await ApiService.instance.getUnreadCounts();

      final conversationByGuardId = <String, String>{};
      final unreadByGuardId = <String, int>{};

      for (final conversation in conversations) {
        final conversationId = conversation['id']?.toString() ?? '';

        final guardA = conversation['guard_a']?.toString() ?? '';
        final guardB = conversation['guard_b']?.toString() ?? '';

        final otherGuardId = guardA == guardId ? guardB : guardA;

        if (conversationId.isEmpty || otherGuardId.isEmpty) {
          continue;
        }

        conversationByGuardId[otherGuardId] = conversationId;

        final unreadCount = unreadCounts[conversationId] ?? 0;

        if (unreadCount > 0) {
          unreadByGuardId[otherGuardId] = unreadCount;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _guards = guards;
        _filteredGuards = List<Map<String, dynamic>>.from(guards);
        _conversationByGuardId = conversationByGuardId;
        _unreadByGuardId = unreadByGuardId;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not load Guards. Please try again.';
      });
    }
  }

  Future<void> _refreshCurrentUser() async {
    try {
      final user = await ApiService.instance.getCurrentUser();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentUser = user;
      });
    } catch (_) {
      // Keep the existing user data if the refresh fails.
    }
  }

  Future<void> _connectForUnreadUpdates() async {
    try {
      final socketToken = await ApiService.instance.getSocketToken();

      final channel = WebSocketChannel.connect(
        ApiService.instance.socketUri,
      );

      _channel = channel;

      await channel.ready.timeout(
        const Duration(seconds: 30),
      );

      if (!mounted) {
        await channel.sink.close();
        return;
      }

      _subscription = channel.stream.listen(
        (dynamic raw) {
          _handleSocketEvent(raw);
        },
        onDone: () {
          // The dashboard can be refreshed manually if disconnected.
        },
        onError: (_) {
          // The dashboard can be refreshed manually if disconnected.
        },
      );

      channel.sink.add(
        jsonEncode({
          'token': socketToken,
        }),
      );
    } catch (_) {
      // Unread badges will still refresh when the dashboard reloads.
    }
  }

  void _handleSocketEvent(dynamic raw) {
    if (!mounted || raw is! String) {
      return;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return;
      }

      final event = Map<String, dynamic>.from(decoded);
      final type = event['type'];

      if (type == 'ping') {
        _channel?.sink.add(
          jsonEncode({
            'type': 'pong',
          }),
        );

        return;
      }

      if (type == 'message') {
        final message = event['message'];

        if (message is! Map) {
          return;
        }

        final senderId = message['sender_id']?.toString() ?? '';
        final conversationId = message['conversation_id']?.toString() ?? '';

        if (senderId.isEmpty || senderId == guardId || conversationId.isEmpty) {
          return;
        }

        setState(() {
          _conversationByGuardId[senderId] = conversationId;

          final currentCount = _unreadByGuardId[senderId] ?? 0;

          _unreadByGuardId[senderId] = currentCount + 1;
        });

        return;
      }

      if (type == 'messages-read') {
        final readerId = event['reader_id']?.toString() ?? '';
        final conversationId = event['conversation_id']?.toString() ?? '';

        if (readerId != guardId || conversationId.isEmpty) {
          return;
        }

        final guardWithConversation = _conversationByGuardId.entries
            .firstWhere(
              (entry) => entry.value == conversationId,
              orElse: () => const MapEntry('', ''),
            )
            .key;

        if (guardWithConversation.isEmpty) {
          return;
        }

        setState(() {
          _unreadByGuardId.remove(guardWithConversation);
        });
      }
    } catch (_) {
      // Ignore malformed socket events.
    }
  }

  void _filterGuards(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _filteredGuards = List<Map<String, dynamic>>.from(_guards);
      } else {
        _filteredGuards = _guards.where((guard) {
          final name = (guard['full_name'] ?? '').toString().toLowerCase();
          final guardEmail = (guard['email'] ?? '').toString().toLowerCase();
          final guardPhone = (guard['phone'] ?? '').toString().toLowerCase();
          final guardZone = (guard['zone'] ?? '').toString().toLowerCase();

          return name.contains(query) ||
              guardEmail.contains(query) ||
              guardPhone.contains(query) ||
              guardZone.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _openChat(Map<String, dynamic> otherGuard) async {
    final otherGuardId = otherGuard['id'].toString();

    try {
      final conversation = await ApiService.instance.openConversation(
        otherGuardId,
      );

      if (!mounted) {
        return;
      }

      final conversationId = conversation['id'].toString();

      await ApiService.instance.markConversationRead(
        conversationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _conversationByGuardId[otherGuardId] = conversationId;
        _unreadByGuardId.remove(otherGuardId);
      });

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            user: _currentUser,
            other: otherGuard,
            conversationId: conversationId,
          ),
        ),
      );

      await _refreshCurrentUser();
      await _loadDashboard();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not open the conversation. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  Future<void> _openMyProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MyProfileScreen(
          fullName: fullName,
          email: email,
          phone: phone,
          zone: zone,
          profilePhotoUrl: profilePhotoUrl,
        ),
      ),
    );

    await _refreshCurrentUser();

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _openCreateIncident() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const CreateIncidentScreen(),
      ),
    );
  }

  Widget _buildProfileAvatar() {
    if (profilePhotoUrl.isEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: const Color(0xFF3C759D),
        child: Text(
          _initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    final fullUrl = profilePhotoUrl.startsWith('http')
        ? profilePhotoUrl
        : '${ApiService.baseUrl}$profilePhotoUrl';

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFF3C759D),
      backgroundImage: NetworkImage(fullUrl),
      onBackgroundImageError: (error, stackTrace) {
        // Fall back to the initials avatar if the image cannot load.
      },
    );
  }

  Widget _buildGuardAvatar(
    Map<String, dynamic> guard,
    String name,
    String initial,
  ) {
    final photoUrl = (guard['profile_photo_url'] ?? '').toString();

    if (photoUrl.isEmpty) {
      return CircleAvatar(
        radius: 26,
        backgroundColor: const Color(0xFF315D7B),
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFFD9EFFF),
          ),
        ),
      );
    }

    final fullUrl = photoUrl.startsWith('http')
        ? photoUrl
        : '${ApiService.baseUrl}$photoUrl';

    return CircleAvatar(
      radius: 26,
      backgroundColor: const Color(0xFF315D7B),
      backgroundImage: NetworkImage(fullUrl),
      onBackgroundImageError: (error, stackTrace) {
        // The initials fallback remains visible if the image cannot load.
      },
    );
  }

  Widget? _buildUnreadBadge(String otherGuardId) {
    final unreadCount = _unreadByGuardId[otherGuardId] ?? 0;

    if (unreadCount <= 0) {
      return null;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF3390EC),
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Text(
        unreadCount > 99 ? '99+' : unreadCount.toString(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF17212B),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 96,
        title: GestureDetector(
          onTap: _openMyProfile,
          child: Row(
            children: [
              _buildProfileAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB4CADD),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      zone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB4CADD),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF24384B),
                Color(0xFF203247),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF80C7FF),
            ),
            onPressed: _isLoading ? null : _loadDashboard,
          ),
          IconButton(
            tooltip: 'My Profile',
            icon: const Icon(
              Icons.person_outline,
              color: Colors.white,
            ),
            onPressed: _openMyProfile,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildMessagesTab(),
          _buildCreateIncidentTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF22303F),
          border: Border(
            top: BorderSide(
              color: Color(0xFF324658),
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: const Color(0xFF64B5F6),
          unselectedItemColor: const Color(0xFF9FB2C4),
          selectedFontSize: 12,
          unselectedFontSize: 12,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
          ),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              activeIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Messages',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem_outlined),
              activeIcon: Icon(Icons.report_problem_rounded),
              label: 'Create Incident',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
          child: TextField(
            controller: _searchController,
            onChanged: _filterGuards,
            cursorColor: const Color(0xFF1673B8),
            style: const TextStyle(
              color: Color(0xFF16354F),
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: 'Search Guards by name, zone, email, or phone',
              hintStyle: const TextStyle(
                color: Color(0xFF496C89),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF24638F),
              ),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF496C89),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _filterGuards('');
                      },
                    ),
              filled: true,
              fillColor: const Color(0xFFC9E6FF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF64B5F6),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              const Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: Color(0xFF80C7FF),
              ),
              const SizedBox(width: 8),
              Text(
                '${_filteredGuards.length} Guards available',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD3E0EC),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Refresh Guards',
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 20,
                  color: Color(0xFF80C7FF),
                ),
                onPressed: _isLoading ? null : _loadDashboard,
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildGuardList(),
        ),
      ],
    );
  }

  Widget _buildGuardList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF64B5F6),
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
                  color: Color(0xFF29445D),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 36,
                  color: Color(0xFF80C7FF),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Color(0xFFE4EDF5),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _loadDashboard,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3390EC),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_filteredGuards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFF243447),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.search_off_rounded,
                  size: 36,
                  color: Color(0xFF80C7FF),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No Guards found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try another name, zone, email, or phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFAFC2D3),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF64B5F6),
      backgroundColor: const Color(0xFF243447),
      onRefresh: _loadDashboard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        itemCount: _filteredGuards.length,
        itemBuilder: (context, index) {
          final guard = _filteredGuards[index];

          final otherGuardId = guard['id']?.toString() ?? '';
          final name = (guard['full_name'] ?? 'Guard').toString();
          final guardPhone = (guard['phone'] ?? '').toString();
          final guardZone = (guard['zone'] ?? '').toString();

          final initial = name.isEmpty ? 'G' : name[0].toUpperCase();

          final unreadBadge = _buildUnreadBadge(otherGuardId);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF243447),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF334B61),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openChat(guard),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildGuardAvatar(
                        guard,
                        name,
                        initial,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadBadge == null
                                    ? FontWeight.w700
                                    : FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 14,
                                  color: Color(0xFFAFC2D3),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    guardZone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFAFC2D3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  size: 14,
                                  color: Color(0xFFAFC2D3),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    guardPhone,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFAFC2D3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (unreadBadge != null) ...[
                        const SizedBox(width: 8),
                        unreadBadge,
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(11),
                        decoration: const BoxDecoration(
                          color: Color(0xFF315573),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 20,
                          color: Color(0xFFA9DBFF),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateIncidentTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Container(
              width: 112,
              height: 112,
              decoration: BoxDecoration(
                color: const Color(0xFF243447),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3A5771),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.report_problem_rounded,
                size: 52,
                color: Color(0xFF64B5F6),
              ),
            ),
            const SizedBox(height: 26),
            const Text(
              'Create Incident',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Report a conversation or another Guard for Admin review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Color(0xFFAFC2D3),
              ),
            ),
            const SizedBox(height: 30),
            _IncidentOption(
              icon: Icons.forum_outlined,
              title: 'Report Conversation',
              subtitle: 'Report an issue in a conversation',
              onTap: _openCreateIncident,
            ),
            _IncidentOption(
              icon: Icons.person_outline,
              title: 'Report Guard',
              subtitle: 'Report another Guard',
              onTap: _openCreateIncident,
            ),
          ],
        ),
      ),
    );
  }
}

class _IncidentOption extends StatelessWidget {
  const _IncidentOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF243447),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF334B61),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFF315573),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFA9DBFF),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFFAFC2D3),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFC3D7E8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
