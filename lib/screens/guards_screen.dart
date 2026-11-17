import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import 'chat_screen.dart';

class GuardsScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const GuardsScreen({
    super.key,
    required this.user,
  });

  @override
  State<GuardsScreen> createState() => _GuardsScreenState();
}

class _GuardsScreenState extends State<GuardsScreen> {
  final _searchController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _guards;

  Timer? _debounce;
  String? _openingGuardId;

  @override
  void initState() {
    super.initState();
    _guards = ApiService.instance.getGuards();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();

    _debounce = Timer(
      const Duration(milliseconds: 350),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _guards = ApiService.instance.getGuards(
            search: value,
          );
        });
      },
    );
  }

  void _refresh() {
    _debounce?.cancel();

    setState(() {
      _guards = ApiService.instance.getGuards(
        search: _searchController.text,
      );
    });
  }

  String _displayName(Map<String, dynamic> guard) {
    final name = guard['full_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'Guard' : name;
  }

  Future<void> _openChat(Map<String, dynamic> guard) async {
    if (_openingGuardId != null) {
      return;
    }

    setState(() {
      _openingGuardId = guard['id'] as String;
    });

    try {
      final conversation = await ApiService.instance.openConversation(
        guard['id'] as String,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            user: widget.user,
            other: guard,
            conversationId: conversation['id'] as String,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is ApiException
                ? error.message
                : 'Unable to open this conversation.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingGuardId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                decoration: InputDecoration(
                  hintText: 'Search name, zone, email or phone',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchController.clear();
                      _refresh();
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _guards,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final guards = snapshot.data ?? [];

                  if (guards.isEmpty) {
                    return const Center(
                      child: Text('No matching Guards found.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      24,
                    ),
                    itemCount: guards.length,
                    separatorBuilder: (context, index) {
                      return const SizedBox(height: 10);
                    },
                    itemBuilder: (context, index) {
                      final guard = guards[index];

                      final name = _displayName(guard);
                      final zone =
                          guard['zone']?.toString() ?? 'Zone not assigned';
                      final phone = guard['phone']?.toString() ?? '';
                      final email = guard['email']?.toString() ?? '';

                      return Card(
                        color: Colors.white,
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFDDF2FF),
                            child: Text(
                              name.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFF218FD0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          title: Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF153B56),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              '$zone\n$phone\n$email',
                            ),
                          ),
                          trailing: _openingGuardId == guard['id']
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: Color(0xFF218FD0),
                                ),
                          onTap: _openingGuardId == null
                              ? () => _openChat(guard)
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
