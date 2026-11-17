import 'package:material_ui/material_ui.dart';

import '../services/app_theme_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
        title: const Text('Settings'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: AppThemeService.instance.darkMode,
        builder: (context, darkMode, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SwitchListTile(
                  title: const Text(
                    'Dark mode',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF263238),
                    ),
                  ),
                  subtitle: const Text(
                    'Use a darker app appearance',
                    style: TextStyle(color: Color(0xFF78909C)),
                  ),
                  value: darkMode,
                  activeThumbColor: const Color(0xFF1E88E5),
                  onChanged: (value) {
                    AppThemeService.instance.setDarkMode(value);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Dark mode changes the app appearance. '
                  'It is saved on this device.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF78909C),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
