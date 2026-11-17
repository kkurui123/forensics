import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'guard_profile_screen.dart';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/api_service.dart';
import '../services/chat_crypto.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> other;
  final String conversationId;

  const ChatScreen({
    super.key,
    required this.user,
    required this.other,
    required this.conversationId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const int _maximumAttachmentBytes = 1024 * 1024;

  static const Color _background = Color(0xFF17212B);
  static const Color _header = Color(0xFF22303F);
  static const Color _incoming = Color(0xFF253442);
  static const Color _outgoing = Color(0xFF2B5278);
  static const Color _accent = Color(0xFF5EB5F7);
  static const Color _muted = Color(0xFFA7BACB);

  final TextEditingController _messageController = TextEditingController();

  final ChatCrypto _crypto = ChatCrypto();

  final Map<String, Map<String, dynamic>> _messages = {};
  final Map<String, Future<String>> _decryptionCache = {};

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  String? _conversationKey;
  String? _errorMessage;

  bool _isLive = false;
  bool _isConnecting = false;
  bool _isSending = false;
  bool _isLoadingHistory = false;

  int _connectionGeneration = 0;

  String get _userId => widget.user['id'] as String;

  String get _otherUserId => widget.other['id'] as String;

  String get _conversationId => widget.conversationId;

  String get _otherName {
    final name = widget.other['full_name']?.toString().trim() ?? '';

    return name.isEmpty ? 'Guard' : name;
  }

  String get _otherDetails {
    final phone = widget.other['phone']?.toString().trim() ?? '';
    final zone = widget.other['zone']?.toString().trim() ?? '';

    final details = <String>[
      if (phone.isNotEmpty) phone,
      if (zone.isNotEmpty) zone,
    ];

    return details.isEmpty ? 'Guard conversation' : details.join(' • ');
  }

  void _openGuardProfile() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuardProfileScreen(
          guard: widget.other,
          conversationId: _conversationId,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _connectionGeneration++;
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.dispose();

    super.dispose();
  }

  void _showError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _errorMessage = error is ApiException
          ? error.message
          : 'Unable to complete this action. Please try again.';
    });
  }

  Future<void> _connect() async {
    if (!mounted || _isConnecting || _isSending) {
      return;
    }

    final generation = ++_connectionGeneration;

    setState(() {
      _isConnecting = true;
      _isLive = false;
      _errorMessage = null;
    });

    WebSocketChannel? newChannel;

    try {
      final previousSubscription = _subscription;
      final previousChannel = _channel;

      _subscription = null;
      _channel = null;

      await previousSubscription?.cancel();
      await previousChannel?.sink.close();

      final key = await _crypto.prepare(
        _userId,
        _conversationId,
        _otherUserId,
      );

      if (!mounted || generation != _connectionGeneration) {
        return;
      }

      setState(() {
        _conversationKey = key;
        _decryptionCache.clear();
      });

      final socketToken = await ApiService.instance.getSocketToken();

      if (!mounted || generation != _connectionGeneration) {
        return;
      }

      final channel = WebSocketChannel.connect(
        ApiService.instance.socketUri,
      );

      newChannel = channel;
      _channel = channel;

      await channel.ready.timeout(
        const Duration(seconds: 30),
      );

      if (!mounted || generation != _connectionGeneration) {
        await channel.sink.close();
        return;
      }

      _subscription = channel.stream.listen(
        (dynamic raw) {
          _handleSocketEvent(raw, channel, generation);
        },
        onError: (Object error) {
          if (!mounted || generation != _connectionGeneration) {
            return;
          }

          setState(() {
            _isLive = false;
            _errorMessage = 'Live connection failed. Tap reconnect.';
          });
        },
        onDone: () {
          if (!mounted || generation != _connectionGeneration) {
            return;
          }

          setState(() {
            _isLive = false;
          });
        },
      );

      channel.sink.add(
        jsonEncode({'token': socketToken}),
      );
    } catch (error) {
      try {
        await newChannel?.sink.close();
      } catch (_) {
        // Preserve the original initialization error.
      }

      if (!mounted || generation != _connectionGeneration) {
        return;
      }

      setState(() {
        _isLive = false;
        _errorMessage = error is ApiException
            ? error.message
            : 'Unable to prepare encrypted messaging. '
                'Please tap reconnect.';
      });
    } finally {
      if (mounted && generation == _connectionGeneration) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }

  Future<void> _handleSocketEvent(
    dynamic raw,
    WebSocketChannel channel,
    int generation,
  ) async {
    if (!mounted || generation != _connectionGeneration) {
      return;
    }

    try {
      if (raw is! String) {
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return;
      }

      final event = Map<String, dynamic>.from(decoded);
      final type = event['type'];

      if (type == 'ping') {
        channel.sink.add(jsonEncode({'type': 'pong'}));
        return;
      }

      if (type == 'ready') {
        setState(() {
          _isLive = true;
          _errorMessage = null;
        });

        await _loadHistory();
        return;
      }

      if (type == 'message') {
        final rawMessage = event['message'];

        if (rawMessage is! Map) {
          return;
        }

        final message = Map<String, dynamic>.from(rawMessage);

        if (message['conversation_id'] == _conversationId) {
          _addMessage(message);
        }

        return;
      }

      if (type == 'error') {
        setState(() {
          _errorMessage = event['detail']?.toString() ??
              'Unable to process a message update.';
        });
      }
    } catch (_) {
      if (!mounted || generation != _connectionGeneration) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to read a live update. '
            'Tap reconnect to synchronize.';
      });
    }
  }

  Future<void> _loadHistory() async {
    if (!mounted || _isLoadingHistory) {
      return;
    }

    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final rows = await ApiService.instance.getMessages(
        _conversationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        for (final message in rows) {
          final id = message['id'];

          if (id is String) {
            _messages[id] = message;
            _decryptionCache.remove(id);
          }
        }
      });
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }
    }
  }

  void _addMessage(Map<String, dynamic> message) {
    final id = message['id'];

    if (!mounted || id is! String) {
      return;
    }

    setState(() {
      _messages[id] = message;
      _decryptionCache.remove(id);
    });
  }

  List<Map<String, dynamic>> _sortedMessages() {
    final rows = _messages.values.toList();

    rows.sort((first, second) {
      final firstTime = DateTime.tryParse(
        first['created_at']?.toString() ?? '',
      );

      final secondTime = DateTime.tryParse(
        second['created_at']?.toString() ?? '',
      );

      if (firstTime != null && secondTime != null) {
        final comparison = secondTime.compareTo(firstTime);

        if (comparison != 0) {
          return comparison;
        }
      }

      return second['id'].toString().compareTo(first['id'].toString());
    });

    return rows;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final key = _conversationKey;

    if (_isSending || _isConnecting || text.isEmpty || key == null) {
      return;
    }

    if (utf8.encode(text).length > 16000) {
      setState(() {
        _errorMessage = 'Your message is too long.';
      });
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final payload = jsonEncode({
        'version': 1,
        'type': 'text',
        'text': text,
      });

      final ciphertext = await _crypto.encrypt(
        payload,
        key,
        _conversationId,
        _userId,
      );

      if (!mounted) {
        return;
      }

      final message = await ApiService.instance.sendEncryptedText(
        _conversationId,
        const Uuid().v4(),
        ciphertext,
      );

      if (!mounted) {
        return;
      }

      _addMessage(message);
      _messageController.clear();
    } catch (error) {
      _showSendError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _pickAttachment({
    required bool photo,
  }) async {
    final key = _conversationKey;

    if (_isSending || _isConnecting || key == null) {
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final file = await FilePicker.pickFile(
        type: photo ? FileType.image : FileType.any,
      );

      if (file == null || !mounted) {
        return;
      }

      final length = await file.length();

      if (!mounted) {
        return;
      }

      if (length == null) {
        throw const ApiException(
          'Unable to determine the file size. '
          'Please choose another file.',
        );
      }

      if (length > _maximumAttachmentBytes) {
        throw const ApiException(
          'Choose a photo or file no larger than 1 MB.',
        );
      }

      final bytes = await file.readAsBytes();

      if (!mounted) {
        return;
      }

      if (bytes.length > _maximumAttachmentBytes) {
        throw const ApiException(
          'Choose a photo or file no larger than 1 MB.',
        );
      }

      final payload = jsonEncode({
        'version': 1,
        'type': photo ? 'photo' : 'file',
        'name': file.name,
        'data': base64Encode(bytes),
      });

      final ciphertext = await _crypto.encrypt(
        payload,
        key,
        _conversationId,
        _userId,
      );

      if (!mounted) {
        return;
      }

      final message = await ApiService.instance.sendEncryptedText(
        _conversationId,
        const Uuid().v4(),
        ciphertext,
      );

      if (!mounted) {
        return;
      }

      _addMessage(message);
    } catch (error) {
      _showSendError(error);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showSendError(Object error) {
    if (!mounted) {
      return;
    }

    final detail =
        error is ApiException ? error.message : 'Unable to send this content.';

    setState(() {
      _errorMessage = '$detail If delivery is uncertain, reconnect and '
          'check history before sending again.';
    });
  }

  Future<String> _decryptMessage(
    Map<String, dynamic> message,
  ) async {
    if (message['kind'] != 'TEXT') {
      return '[Unsupported message format]';
    }

    final key = _conversationKey;

    if (key == null) {
      return '[Encryption is not ready yet]';
    }

    try {
      final ciphertext = message['ciphertext'];
      final senderId = message['sender_id'];

      if (ciphertext is! String || senderId is! String) {
        throw const FormatException(
          'Message ciphertext or sender ID is missing.',
        );
      }

      return await _crypto.decrypt(
        ciphertext,
        key,
        _conversationId,
        senderId,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'Decryption failed: '
          'type=${error.runtimeType}, '
          'message_id=${message['id']}, '
          'conversation_id=$_conversationId, '
          'sender_id=${message['sender_id']}',
        );
      }

      return '[Unable to decrypt this message]';
    }
  }

  Future<String> _decryptionFor(
    Map<String, dynamic> message,
  ) {
    final id = message['id'] as String;

    return _decryptionCache.putIfAbsent(
      id,
      () => _decryptMessage(message),
    );
  }

  Future<void> _savePhotoToGallery(
    String filename,
    Uint8List bytes,
  ) async {
    File? temporaryFile;

    try {
      final directory = await getTemporaryDirectory();

      final safeName = filename.replaceAll(
        RegExp(r'[\\/\x00-\x1F]'),
        '_',
      );

      final finalName = safeName.isEmpty
          ? 'securechat_photo_${DateTime.now().millisecondsSinceEpoch}.jpg'
          : safeName;

      temporaryFile = File('${directory.path}/$finalName');

      await temporaryFile.writeAsBytes(bytes);

      await Gal.putImage(
        temporaryFile.path,
        album: 'SecureChat',
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo saved to your gallery.'),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to save the photo. Allow photo access and try again.',
          ),
        ),
      );
    } finally {
      try {
        await temporaryFile?.delete();
      } catch (_) {
        // The temporary file is not important after saving.
      }
    }
  }

  Future<void> _saveAttachment(
    String filename,
    Uint8List bytes,
  ) async {
    try {
      final safeName = filename.replaceAll(
        RegExp(r'[\\/\x00-\x1F]'),
        '_',
      );

      await FileSaver.instance.saveFile(
        name: safeName.isEmpty ? 'attachment' : safeName,
        bytes: bytes,
        includeExtension: false,
        mimeType: MimeType.other,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'File passed to your device’s save/download handler.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Unable to save the attachment.';
      });
    }
  }

  Widget _textContent(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFF2F7FC),
        fontSize: 16,
        height: 1.4,
      ),
    );
  }

  Widget _renderContent(String plaintext) {
    Map<String, dynamic>? payload;

    try {
      final decoded = jsonDecode(plaintext);

      if (decoded is Map && decoded['version'] == 1) {
        payload = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Allow older messages containing plain text after decryption.
    }

    if (payload == null) {
      return _textContent(plaintext);
    }

    final item = payload;

    if (item['type'] == 'text' && item['text'] is String) {
      return _textContent(item['text'] as String);
    }

    final isPhoto = item['type'] == 'photo';
    final isFile = item['type'] == 'file';

    if ((!isPhoto && !isFile) ||
        item['name'] is! String ||
        item['data'] is! String) {
      return _textContent(plaintext);
    }

    final name = item['name'] as String;
    final encodedData = item['data'] as String;

    if (encodedData.length > 1400000) {
      return _textContent('[Attachment exceeds the supported size]');
    }

    late final Uint8List bytes;

    try {
      bytes = base64Decode(encodedData);
    } catch (_) {
      return _textContent('[Invalid attachment]');
    }

    if (bytes.length > _maximumAttachmentBytes) {
      return _textContent('[Attachment exceeds the supported size]');
    }

    if (isPhoto) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 260,
              height: 220,
              fit: BoxFit.contain,
              cacheWidth: 800,
              errorBuilder: (context, error, stackTrace) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Photo preview unavailable. '
                    'You can still save the photo.',
                    style: TextStyle(
                      color: Colors.white,
                      height: 1.5,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),
          TextButton.icon(
            onPressed: () => _savePhotoToGallery(name, bytes),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFB5E0FF),
            ),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Save to gallery'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF37648A),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.insert_drive_file_outlined,
            size: 30,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(bytes.length / 1024).toStringAsFixed(1)} KB',
          style: const TextStyle(
            color: Color(0xFFBCD1E3),
            fontSize: 12,
          ),
        ),
        TextButton.icon(
          onPressed: () => _saveAttachment(name, bytes),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB5E0FF),
          ),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Save file'),
        ),
      ],
    );
  }

  DateTime? _messageDate(Map<String, dynamic> message) {
    return DateTime.tryParse(
      message['created_at']?.toString() ?? '',
    )?.toLocal();
  }

  String _timeLabel(Map<String, dynamic> message) {
    final time = _messageDate(message);

    if (time == null) {
      return '';
    }

    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _dateLabel(DateTime date) {
    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));

    if (_sameDay(date, today)) {
      return 'Today';
    }

    if (_sameDay(date, yesterday)) {
      return 'Yesterday';
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Widget _dateChip(DateTime date) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF304557),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _dateLabel(date),
          style: const TextStyle(
            color: Color(0xFFD8E7F3),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final mine = message['sender_id'] == _userId;
    final time = _timeLabel(message);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: EdgeInsets.only(
          left: mine ? 38 : 0,
          right: mine ? 0 : 38,
          bottom: 7,
        ),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
        decoration: BoxDecoration(
          color: mine ? _outgoing : _incoming,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder<String>(
              future: _decryptionFor(message),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text(
                    'Decrypting…',
                    style: TextStyle(color: _muted),
                  );
                }

                return _renderContent(snapshot.data!);
              },
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color:
                      mine ? const Color(0xFFB2D3EC) : const Color(0xFF9FB1C0),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _connectionStatus() {
    final String label;
    final Color color;

    if (_isConnecting) {
      label = 'Preparing encrypted connection…';
      color = _muted;
    } else if (_isLive) {
      label = 'Live connection';
      color = _accent;
    } else if (_conversationKey != null) {
      label = 'Not live — reconnect for incoming messages';
      color = _muted;
    } else {
      label = 'Encryption setup incomplete — tap reconnect';
      color = _muted;
    }

    return Container(
      color: _header,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          Icon(
            _isLive ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerAvatar() {
    final photo = widget.other['profile_photo_url']?.toString().trim() ?? '';

    final fallback = Center(
      child: Text(
        _otherName[0].toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: Color(0xFF4385B6),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: photo.isEmpty
          ? fallback
          : Image.network(
              Uri.parse('${ApiService.baseUrl}/').resolve(photo).toString(),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => fallback,
            ),
    );
  }

  Widget _composer() {
    final canCompose =
        _conversationKey != null && !_isSending && !_isConnecting;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _header,
                borderRadius: BorderRadius.circular(27),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(14, 14, 10, 14),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: _muted,
                      size: 23,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: canCompose,
                      minLines: 1,
                      maxLines: 4,
                      cursorColor: _accent,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        hintText: _conversationKey == null
                            ? 'Preparing encryption…'
                            : 'Message',
                        hintStyle: const TextStyle(
                          color: _muted,
                          fontSize: 16,
                        ),
                        filled: true,
                        fillColor: _header,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Attach photo or file',
                    enabled: canCompose,
                    color: const Color(0xFF2B4055),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    icon: const Icon(
                      Icons.attach_file_rounded,
                      color: _muted,
                    ),
                    onSelected: (value) {
                      _pickAttachment(photo: value == 'photo');
                    },
                    itemBuilder: (context) {
                      return const [
                        PopupMenuItem<String>(
                          value: 'photo',
                          child: Row(
                            children: [
                              Icon(
                                Icons.image_outlined,
                                color: _accent,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Send photo',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'file',
                          child: Row(
                            children: [
                              Icon(
                                Icons.insert_drive_file_outlined,
                                color: _accent,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Send file',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            height: 52,
            child: IconButton.filled(
              tooltip: 'Send message',
              onPressed: canCompose ? _sendMessage : null,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF3390EC),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF36516B),
                disabledForegroundColor: const Color(0xFFB0C5D8),
                shape: const CircleBorder(),
              ),
              icon: Icon(
                _isSending ? Icons.hourglass_empty_rounded : Icons.send_rounded,
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: const Color(0xFF49313F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFFFCED9),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Dismiss error',
            onPressed: () {
              setState(() {
                _errorMessage = null;
              });
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: Color(0xFFFFCED9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyConversation() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF223446),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.forum_outlined,
              color: _accent,
              size: 46,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your conversation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _conversationKey == null
                  ? 'Both Guards need to open this conversation once '
                      'to initialize messaging. Then tap reconnect.'
                  : 'Send a message, photo, or file. '
                      'Encryption and decryption happen automatically.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _muted,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = _sortedMessages();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _header,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        titleSpacing: 0,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _openGuardProfile,
          child: Row(
            children: [
              _headerAvatar(),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _otherName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _otherDetails,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Reconnect and synchronize',
            onPressed: _isConnecting || _isSending ? null : _connect,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFCFDFED),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _connectionStatus(),
            if (_isConnecting || _isLoadingHistory)
              const LinearProgressIndicator(
                color: _accent,
                backgroundColor: _header,
                minHeight: 2,
              ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      painter: _ChatWallpaperPainter(),
                    ),
                  ),
                  Column(
                    children: [
                      if (_errorMessage != null) _errorBanner(),
                      Expanded(
                        child: messages.isEmpty
                            ? _emptyConversation()
                            : ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  10,
                                  8,
                                  10,
                                  8,
                                ),
                                itemCount: messages.length,
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final date = _messageDate(message);

                                  final olderDate = index + 1 < messages.length
                                      ? _messageDate(
                                          messages[index + 1],
                                        )
                                      : null;

                                  final showDate = date != null &&
                                      (olderDate == null ||
                                          !_sameDay(date, olderDate));

                                  return KeyedSubtree(
                                    key: ValueKey(message['id']),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        if (showDate) _dateChip(date),
                                        _messageBubble(message),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }
}

class _ChatWallpaperPainter extends CustomPainter {
  const _ChatWallpaperPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF20303E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (double y = 28; y < size.height; y += 110) {
      for (double x = 24; x < size.width; x += 100) {
        final offset = ((y ~/ 110) % 2) * 24.0;
        final left = x + offset;

        final bubble = RRect.fromRectAndRadius(
          Rect.fromLTWH(left, y, 26, 19),
          const Radius.circular(6),
        );

        canvas.drawRRect(bubble, paint);

        final tail = Path()
          ..moveTo(left + 6, y + 19)
          ..lineTo(left + 3, y + 24)
          ..lineTo(left + 12, y + 19);

        canvas.drawPath(tail, paint);
        canvas.drawCircle(Offset(left + 48, y + 48), 7, paint);

        canvas.drawLine(
          Offset(left + 12, y + 65),
          Offset(left + 20, y + 73),
          paint,
        );

        canvas.drawLine(
          Offset(left + 20, y + 65),
          Offset(left + 12, y + 73),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChatWallpaperPainter oldDelegate) {
    return false;
  }
}
