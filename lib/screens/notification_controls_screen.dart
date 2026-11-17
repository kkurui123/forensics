import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationControlsScreen extends StatefulWidget {
  const NotificationControlsScreen({super.key});

  @override
  State<NotificationControlsScreen> createState() =>
      _NotificationControlsScreenState();
}

class _NotificationControlsScreenState
    extends State<NotificationControlsScreen> {
  bool _isLoading = true;

  bool _messageNotifications = true;
  bool _notificationSound = true;
  bool _hideMessagePreviews = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final preferences = await SharedPreferences.getInstance();

    setState(() {
      _messageNotifications =
          preferences.getBool('message_notifications') ?? true;
      _notificationSound = preferences.getBool('notification_sound') ?? true;
      _hideMessagePreviews =
          preferences.getBool('hide_message_previews') ?? false;

      _isLoading = false;
    });
  }

  Future<void> _savePreference(
    String key,
    bool value,
  ) async {
    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(
      key,
      value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Notification Controls'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1E88E5),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _NotificationCard(
                  title: 'Message notifications',
                  subtitle: 'Show alerts when new messages arrive',
                  value: _messageNotifications,
                  onChanged: (value) {
                    setState(() {
                      _messageNotifications = value;
                    });

                    _savePreference(
                      'message_notifications',
                      value,
                    );
                  },
                ),
                _NotificationCard(
                  title: 'Notification sound',
                  subtitle: 'Play a sound for supported alerts',
                  value: _notificationSound,
                  onChanged: (value) {
                    setState(() {
                      _notificationSound = value;
                    });

                    _savePreference(
                      'notification_sound',
                      value,
                    );
                  },
                ),
                _NotificationCard(
                  title: 'Hide message previews',
                  subtitle: 'Do not show message content in alerts',
                  value: _hideMessagePreviews,
                  onChanged: (value) {
                    setState(() {
                      _hideMessagePreviews = value;
                    });

                    _savePreference(
                      'hide_message_previews',
                      value,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'These preferences are saved on this device. '
                    'Background notifications are not enabled yet.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF78909C),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SwitchListTile(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF263238),
            ),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF78909C),
            ),
          ),
          value: value,
          activeThumbColor: const Color(0xFF1E88E5),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
