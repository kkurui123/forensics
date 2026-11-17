import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class ForensicReconstructionScreen extends StatefulWidget {
  const ForensicReconstructionScreen({super.key});

  @override
  State<ForensicReconstructionScreen> createState() =>
      _ForensicReconstructionScreenState();
}

class _ForensicReconstructionScreenState
    extends State<ForensicReconstructionScreen> {
  List<Map<String, dynamic>> _incidents = [];

  bool _isLoading = true;
  String? _errorMessage;

  String? _busyIncidentId;

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final incidents = await ApiService.instance.getAdminIncidents();

      if (!mounted) {
        return;
      }

      setState(() {
        _incidents = incidents;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not load approved incidents. Please try again.';

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _approvedIncidents {
    return _incidents
        .where(
          (incident) =>
              (incident['status'] ?? '').toString().toUpperCase() == 'APPROVED',
        )
        .toList();
  }

  Future<void> _requestRecovery(Map<String, dynamic> incident) async {
    final incidentId = (incident['id'] ?? '').toString();

    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Request recovery'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Request authorized recovery for this approved incident? '
                'Message content remains end-to-end encrypted unless the '
                'involved users provide recovery consent.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Recovery reason',
                  hintText: 'Explain why recovery authorization is required',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      reasonController.dispose();
      return;
    }

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (reason.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter at least 10 characters explaining the recovery request.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _busyIncidentId = incidentId;
    });

    try {
      await ApiService.instance.requestIncidentRecovery(
        incidentId,
        reason,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Recovery request submitted. It is awaiting recovery consent.',
          ),
        ),
      );

      await _loadIncidents();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not submit the recovery request. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyIncidentId = null;
        });
      }
    }
  }

  String _formatDate(String value) {
    final dateTime = DateTime.tryParse(value);

    if (dateTime == null) {
      return 'Unknown date';
    }

    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-'
        '${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Forensic Reconstruction'),
      ),
      body: _buildBody(),
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
                onPressed: _loadIncidents,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final incidents = _approvedIncidents;

    if (incidents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  size: 36,
                  color: Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No approved incidents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Approve an incident in Incident Requests before '
                'starting forensic reconstruction.',
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
      onRefresh: _loadIncidents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: incidents.length,
        itemBuilder: (context, index) {
          final incident = incidents[index];

          return _ForensicIncidentCard(
            incident: incident,
            isBusy: _busyIncidentId == (incident['id'] ?? '').toString(),
            onRequestRecovery: () => _requestRecovery(incident),
            formatDate: _formatDate,
          );
        },
      ),
    );
  }
}

class _ForensicIncidentCard extends StatelessWidget {
  const _ForensicIncidentCard({
    required this.incident,
    required this.isBusy,
    required this.onRequestRecovery,
    required this.formatDate,
  });

  final Map<String, dynamic> incident;
  final bool isBusy;
  final VoidCallback onRequestRecovery;
  final String Function(String value) formatDate;

  String get _reportType =>
      (incident['report_type'] ?? 'UNKNOWN').toString().toUpperCase();

  String get _reason => (incident['reason'] ?? '').toString();

  String get _createdAt => (incident['created_at'] ?? '').toString();

  String get _conversationId => (incident['conversation_id'] ?? '').toString();

  String get _reportedBy => (incident['reported_by'] ?? '').toString();

  String get _reportedGuard => (incident['reported_guard_id'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.manage_search_rounded,
                  color: Color(0xFF1E88E5),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _reportType,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF263238),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDate(_createdAt),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF78909C),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'APPROVED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Incident reason',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78909C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _reason,
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              color: Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 14),
          _ForensicDetail(
            icon: Icons.person_outline,
            title: 'Reported by',
            value: _reportedBy,
          ),
          if (_reportedGuard.isNotEmpty)
            _ForensicDetail(
              icon: Icons.person_search_outlined,
              title: 'Reported Guard',
              value: _reportedGuard,
            ),
          if (_conversationId.isNotEmpty)
            _ForensicDetail(
              icon: Icons.forum_outlined,
              title: 'Conversation',
              value: _conversationId,
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
            FilledButton.icon(
              onPressed: onRequestRecovery,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.key_rounded),
              label: const Text('Request Recovery'),
            ),
        ],
      ),
    );
  }
}

class _ForensicDetail extends StatelessWidget {
  _ForensicDetail({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: const Color(0xFF78909C),
          ),
          const SizedBox(width: 8),
          Text(
            '$title:',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF78909C),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF263238),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
