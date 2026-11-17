import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';

class CreateIncidentScreen extends StatefulWidget {
  const CreateIncidentScreen({
    super.key,
    this.conversationId,
    this.reportedGuard,
  });

  final String? conversationId;
  final Map<String, dynamic>? reportedGuard;

  @override
  State<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends State<CreateIncidentScreen> {
  static const Color _background = Color(0xFF000000);
  static const Color _surface = Color(0xFF191919);
  static const Color _danger = Color(0xFFEF0033);
  static const Color _muted = Color(0xFFBDBDBD);

  final TextEditingController _reasonController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;

  String? _selectedReportType;

  bool get _hasConversation {
    return widget.conversationId != null && widget.conversationId!.isNotEmpty;
  }

  bool get _hasGuard {
    final guardId = widget.reportedGuard?['id']?.toString().trim() ?? '';

    return guardId.isNotEmpty;
  }

  String get _guardName {
    final guard = widget.reportedGuard ?? {};
    final name = guard['full_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'Guard' : name;
  }

  String get _title {
    if (_selectedReportType == 'GUARD') {
      return 'Report Guard';
    }

    if (_selectedReportType == 'CONVERSATION') {
      return 'Report Conversation';
    }

    return 'Report Incident';
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _selectReportType(String type) {
    setState(() {
      _selectedReportType = type;
    });
  }

  void _changeReportType() {
    setState(() {
      _selectedReportType = null;
      _reasonController.clear();
    });
  }

  Future<void> _submitReport() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedReportType == null) {
      return;
    }

    final isConversationReport = _selectedReportType == 'CONVERSATION';

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApiService.instance.createIncident(
        reportType: isConversationReport ? 'CONVERSATION' : 'GUARD',
        conversationId: isConversationReport ? widget.conversationId : null,
        reportedGuardId: isConversationReport
            ? null
            : widget.reportedGuard?['id']?.toString(),
        reason: _reasonController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Incident submitted for Admin review.'),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not submit the incident. Please try again.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _reportOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
  }) {
    final isSelected = _selectedReportType == value;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? () => _selectReportType(value) : null,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _danger : Colors.transparent,
                width: 1.4,
              ),
            ),
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
                    color: _danger,
                    size: 27,
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
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? _danger : _muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'What would you like to report?',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Choose whether you want to report a Guard or this conversation.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 26),
        _reportOption(
          value: 'GUARD',
          icon: Icons.person_off_outlined,
          title: 'Report Guard',
          subtitle: 'Report inappropriate behaviour by $_guardName.',
          enabled: _hasGuard,
        ),
        const SizedBox(height: 16),
        _reportOption(
          value: 'CONVERSATION',
          icon: Icons.forum_outlined,
          title: 'Report Conversation',
          subtitle: 'Report an issue in this encrypted conversation.',
          enabled: _hasConversation,
        ),
      ],
    );
  }

  Widget _buildReportForm() {
    final isConversationReport = _selectedReportType == 'CONVERSATION';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
          ),
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
                  isConversationReport
                      ? Icons.forum_outlined
                      : Icons.person_outline,
                  color: _danger,
                  size: 27,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConversationReport
                          ? 'Reporting conversation'
                          : 'Reporting Guard',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isConversationReport ? 'Conversation' : _guardName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _isSubmitting ? null : _changeReportType,
                style: TextButton.styleFrom(
                  foregroundColor: _danger,
                ),
                child: const Text('Change'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Reason for reporting',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _reasonController,
          enabled: !_isSubmitting,
          maxLines: 5,
          cursorColor: _danger,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.6,
          ),
          decoration: InputDecoration(
            labelText: 'Reason',
            hintText: 'Describe what happened',
            alignLabelWithHint: true,
            labelStyle: const TextStyle(
              color: _muted,
            ),
            floatingLabelStyle: const TextStyle(
              color: _danger,
            ),
            hintStyle: const TextStyle(
              color: _muted,
              fontSize: 16,
            ),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.all(22),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: _danger,
                width: 1.4,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFFF7B94),
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: const BorderSide(
                color: Color(0xFFFF7B94),
                width: 1.4,
              ),
            ),
            errorStyle: const TextStyle(
              color: Color(0xFFFF9AAF),
              fontSize: 12,
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().length < 10) {
              return 'Enter at least 10 characters.';
            }

            return null;
          },
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 56,
          child: FilledButton(
            onPressed: _isSubmitting ? null : _submitReport,
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF86152D),
              disabledForegroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
            ),
            child: Text(
              _isSubmitting ? 'Submitting…' : 'Submit Report',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showTypeSelection = _selectedReportType == null;

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _title,
          style: const TextStyle(
            color: _muted,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text.rich(
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
                              color: _danger,
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
                    ),
                    const SizedBox(height: 32),
                    const Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Tell us what happened.\n',
                          ),
                          TextSpan(
                            text: 'Report an incident.',
                            style: TextStyle(
                              color: _danger,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Provide the details below for Administrator review.',
                      style: TextStyle(
                        color: _muted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 32),
                    showTypeSelection
                        ? _buildTypeSelection()
                        : _buildReportForm(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
