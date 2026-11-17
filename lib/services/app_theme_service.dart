import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  AppThemeService._();

  static final AppThemeService instance = AppThemeService._();

  static const String _darkModeKey = 'dark_mode';

  final ValueNotifier<bool> darkMode = ValueNotifier<bool>(false);

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    darkMode.value = preferences.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    darkMode.value = value;

    final preferences = await SharedPreferences.getInstance();

    await preferences.setBool(
      _darkModeKey,
      value,
    );
  }
}
