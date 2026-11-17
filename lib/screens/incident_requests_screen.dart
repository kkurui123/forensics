import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class IncidentRequestsScreen extends StatefulWidget {
  const IncidentRequestsScreen({super.key});

  @override
  State<IncidentRequestsScreen> createState() => _IncidentRequestsScreenState();
}

class _IncidentRequestsScreenState extends State<IncidentRequestsScreen> {
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
          : 'Could not load incident reports. Please try again.';

      setState(() {
        _errorMessage = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _reviewIncident(
    Map<String, dynamic> incident,
    String status,
  ) async {
    final incidentId = (incident['id'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            status == 'APPROVED' ? 'Approve incident' : 'Reject incident',
          ),
          content: Text(
            status == 'APPROVED'
                ? 'Approve this incident report?'
                : 'Reject this incident report?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: status == 'APPROVED'
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFEF5350),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                status == 'APPROVED' ? 'Approve' : 'Reject',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _busyIncidentId = incidentId;
    });

    try {
      final updated = await ApiService.instance.reviewIncident(
        incidentId,
        status,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        final index = _incidents.indexWhere(
          (item) => (item['id'] ?? '').toString() == incidentId,
        );

        if (index != -1) {
          _incidents[index] = updated;
        }

        _busyIncidentId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'APPROVED' ? 'Incident approved.' : 'Incident rejected.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not update this incident. Please try again.';

      setState(() {
        _busyIncidentId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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
        title: const Text('Incident Requests'),
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

    if (_incidents.isEmpty) {
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
                  Icons.inbox_rounded,
                  size: 36,
                  color: Color(0xFFEF5350),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No incident reports',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF263238),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Incident reports submitted by Guards will appear here.',
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
        itemCount: _incidents.length,
        itemBuilder: (context, index) {
          final incident = _incidents[index];

          return _IncidentCard(
            incident: incident,
            isBusy: _busyIncidentId == (incident['id'] ?? '').toString(),
            onApprove: () => _reviewIncident(incident, 'APPROVED'),
            onReject: () => _reviewIncident(incident, 'REJECTED'),
            formatDate: _formatDate,
          );
        },
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.incident,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
    required this.formatDate,
  });

  final Map<String, dynamic> incident;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final String Function(String value) formatDate;

  String get _id => (incident['id'] ?? '').toString();

  String get _reportType =>
      (incident['report_type'] ?? 'UNKNOWN').toString().toUpperCase();

  String get _reason => (incident['reason'] ?? '').toString();

  String get _status =>
      (incident['status'] ?? 'PENDING').toString().toUpperCase();

  String get _createdAt => (incident['created_at'] ?? '').toString();

  String get _reportedBy =>
      (incident['reported_by_name'] ?? incident['reported_by'] ?? 'Guard')
          .toString();

  String get _reportedGuard =>
      (incident['reported_guard_name'] ?? incident['reported_guard_id'] ?? '')
          .toString();

  Color get _statusColor {
    switch (_status) {
      case 'APPROVED':
        return const Color(0xFF2E7D32);
      case 'REJECTED':
        return const Color(0xFFC62828);
      default:
        return const Color(0xFFEF6C00);
    }
  }

  Color get _statusBackground {
    switch (_status) {
      case 'APPROVED':
        return const Color(0xFFE8F5E9);
      case 'REJECTED':
        return const Color(0xFFFFEBEE);
      default:
        return const Color(0xFFFFF3E0);
    }
  }

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
                  color: Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  color: Color(0xFFEF5350),
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
                  color: _statusBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Reason',
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
          _IncidentDetail(
            icon: Icons.person_outline,
            title: 'Reported by',
            value: _reportedBy,
          ),
          if (_reportedGuard.isNotEmpty)
            _IncidentDetail(
              icon: Icons.person_search_outlined,
              title: 'Reported Guard',
              value: _reportedGuard,
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
          else if (_status == 'PENDING')
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF5350),
                      side: const BorderSide(
                        color: Color(0xFFEF5350),
                      ),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _IncidentDetail extends StatelessWidget {
  const _IncidentDetail({
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
