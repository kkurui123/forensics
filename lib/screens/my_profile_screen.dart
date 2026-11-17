import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../services/api_service.dart';
import 'notification_controls_screen.dart';
import 'role_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({
    super.key,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.zone,
    required this.profilePhotoUrl,
  });

  final String fullName;
  final String email;
  final String phone;
  final String zone;
  final String profilePhotoUrl;

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  static const Color _background = Color(0xFF17212B);
  static const Color _card = Color(0xFF232F3D);
  static const Color _cardDivider = Color(0xFF2E3D4D);
  static const Color _accent = Color(0xFF5EB5F7);
  static const Color _muted = Color(0xFF8FA3B4);

  final ImagePicker _imagePicker = ImagePicker();

  late String _fullName;
  late String _email;
  late String _phone;
  late String _zone;
  late String _profilePhotoUrl;

  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();

    _fullName = widget.fullName;
    _email = widget.email;
    _phone = widget.phone;
    _zone = widget.zone;
    _profilePhotoUrl = widget.profilePhotoUrl;
  }

  String get _initial {
    final name = _fullName.trim();

    return name.isEmpty ? 'G' : name[0].toUpperCase();
  }

  void _openNotificationControls() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const NotificationControlsScreen(),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    if (_isUploadingPhoto) {
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 14),
              const Text(
                'Change profile photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: _accent,
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(
                    Icons.photo_camera_outlined,
                    color: _accent,
                  ),
                  title: const Text(
                    'Take photo',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    try {
      final selectedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );

      if (selectedFile == null) {
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
      });

      debugPrint(
        'PROFILE PHOTO SELECTED: '
        'path=${selectedFile.path}, '
        'name=${selectedFile.name}, '
        'mimeType=${selectedFile.mimeType}',
      );

      if (!mounted) {
        return;
      }

      final photoUrl = await ApiService.instance.uploadProfilePhoto(
        selectedFile.path,
      );

      debugPrint('UPLOADED PHOTO URL: $photoUrl');

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = photoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: _card,
          content: Text(
            'Profile photo updated.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('PROFILE PHOTO ERROR: $error');
      debugPrint('PROFILE PHOTO STACK: $stackTrace');

      if (!mounted) {
        return;
      }

      final message = error is ApiException
          ? error.message
          : 'Could not update your profile photo: '
              '${error.runtimeType}: $error';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _card,
          content: Text(
            message,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _card,
          title: const Text(
            'Logout',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(color: _muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _accent),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF5350),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ApiService.instance.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => const RoleScreen(),
      ),
      (route) => false,
    );
  }

  Widget _profilePhoto() {
    final photoUrl = _profilePhotoUrl;

    final fallback = Center(
      child: Text(
        _initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (photoUrl.isEmpty) {
      return fallback;
    }

    final fullUrl = photoUrl.startsWith('http')
        ? photoUrl
        : '${ApiService.baseUrl}$photoUrl';

    debugPrint('PROFILE PHOTO URL BEING DISPLAYED: $fullUrl');

    return Image.network(
      fullUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        debugPrint(
          'PROFILE PHOTO LOAD ERROR: '
          'type=${error.runtimeType}, '
          'error=$error',
        );

        return fallback;
      },
    );
  }

  Widget _avatar() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 136,
          height: 136,
          decoration: BoxDecoration(
            color: const Color(0xFF3D6E8F),
            shape: BoxShape.circle,
            border: Border.all(
              color: _background,
              width: 5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: _profilePhoto(),
        ),
        Material(
          color: const Color(0xFF3390EC),
          shape: const CircleBorder(),
          child: _isUploadingPhoto
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Change profile photo',
                  onPressed: _changeProfilePhoto,
                  icon: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _row({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _cardDivider,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: _muted,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.isEmpty ? 'Not provided' : value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color iconColor = _accent,
  }) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _cardDivider,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: Icon(
          icon,
          color: iconColor,
          size: 26,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            subtitle,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: _muted,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        children: [
          const SizedBox(height: 8),
          Center(child: _avatar()),
          const SizedBox(height: 18),
          Text(
            _fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _zone,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 28),
          _section(
            title: 'Account',
            children: [
              _row(
                icon: Icons.person_outline_rounded,
                label: 'Full name',
                value: _fullName,
              ),
              _row(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _email,
              ),
              _row(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value: _phone,
              ),
              _row(
                icon: Icons.location_on_outlined,
                label: 'Zone',
                value: _zone,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _section(
            title: 'Settings',
            children: [
              _actionRow(
                icon: Icons.notifications_outlined,
                title: 'Notification Controls',
                subtitle: 'Manage message alerts',
                onTap: _openNotificationControls,
              ),
            ],
          ),
          const SizedBox(height: 26),
          _section(
            title: 'Session',
            children: [
              _actionRow(
                icon: Icons.logout_rounded,
                title: 'Logout',
                subtitle: 'Sign out of this device',
                iconColor: const Color(0xFFEF5350),
                onTap: _isUploadingPhoto ? () {} : _logout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}