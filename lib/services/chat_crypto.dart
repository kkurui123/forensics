import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_service.dart';

class ChatCrypto {
  final AesGcm _cipher = AesGcm.with256bits();
  final X25519 _keyAgreement = X25519();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  // Prevent concurrent initialization for the same account
  // within this application process.
  static final Map<String, Future<SimpleKeyPair>> _identities = {};

  String _identityStorageKey(String userId) {
    return 'securechat_identity_v1_$userId';
  }

  Future<SimpleKeyPair> _identity(String userId) {
    return _identities.putIfAbsent(
      userId,
      () => _loadOrCreateIdentity(userId),
    );
  }

  Future<SimpleKeyPair> _loadOrCreateIdentity(
    String userId,
  ) async {
    final stored = await _storage.read(
      key: _identityStorageKey(userId),
    );

    if (stored != null) {
      final privateBytes = base64Decode(stored);

      if (privateBytes.length != 32) {
        throw const ApiException(
          'The saved encryption identity is invalid. '
          'Do not clear storage; contact the administrator.',
        );
      }

      return _keyAgreement.newKeyPairFromSeed(
        privateBytes,
      );
    }

    // Do not silently create a replacement identity if the
    // account already has a public key on the server.
    final existingPublicKey =
        await ApiService.instance.getGuardEncryptionPublicKey(
      userId,
    );

    if (existingPublicKey != null) {
      throw const ApiException(
        'This account has an encryption identity on another '
        'device, or its local key has been lost. '
        'Use the original device.',
      );
    }

    final pair = await _keyAgreement.newKeyPair();
    final privateBytes = await pair.extractPrivateKeyBytes();

    await _storage.write(
      key: _identityStorageKey(userId),
      value: base64Encode(privateBytes),
    );

    return pair;
  }

  /// Creates this account's identity if needed and registers
  /// only its public key with the backend.
  Future<SimpleKeyPair> _publishIdentity(
    String userId,
  ) async {
    final pair = await _identity(userId);
    final publicKey = await pair.extractPublicKey();

    await ApiService.instance.registerEncryptionPublicKey(
      base64Encode(publicKey.bytes),
    );

    return pair;
  }

  /// Automatically derives the same conversation key on both
  /// participants' original devices.
  Future<String> prepare(
    String userId,
    String conversationId,
    String otherGuardId,
  ) async {
    final pair = await _publishIdentity(userId);

    final encodedPeerKey =
        await ApiService.instance.getGuardEncryptionPublicKey(
      otherGuardId,
    );

    if (encodedPeerKey == null) {
      throw const ApiException(
        'The other Guard has not initialized messaging yet. '
        'Ask them to open Messages, then tap reconnect.',
      );
    }

    final peerBytes = base64Decode(encodedPeerKey);

    if (peerBytes.length != 32) {
      throw const ApiException(
        'The other Guard has an invalid public key.',
      );
    }

    final sharedSecret = await _keyAgreement.sharedSecretKey(
      keyPair: pair,
      remotePublicKey: SimplePublicKey(
        peerBytes,
        type: KeyPairType.x25519,
      ),
    );

    final sharedBytes = await sharedSecret.extractBytes();

    if (sharedBytes.every((byte) => byte == 0)) {
      throw const ApiException(
        'Unable to establish a valid encryption session.',
      );
    }

    final participants = [userId, otherGuardId]..sort();

    final derivation = Hkdf(
      hmac: Hmac.sha256(),
      outputLength: 32,
    );

    final conversationKey = await derivation.deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(
        'securechat-auto-key-v1',
      ),
      info: utf8.encode(
        jsonEncode({
          'conversation_id': conversationId,
          'participants': participants,
        }),
      ),
    );

    return base64Encode(
      await conversationKey.extractBytes(),
    );
  }

  List<int> _context(
    String conversationId,
    String senderId,
  ) {
    return utf8.encode(
      'securechat-v1|$conversationId|$senderId|TEXT',
    );
  }

  SecretKey _decodeKey(String encodedKey) {
    final bytes = base64Decode(encodedKey);

    if (bytes.length != 32) {
      throw const FormatException(
        'Invalid conversation key.',
      );
    }

    return SecretKey(bytes);
  }

  Future<String> encrypt(
    String plaintext,
    String encodedKey,
    String conversationId,
    String senderId,
  ) async {
    final box = await _cipher.encrypt(
      utf8.encode(plaintext),
      secretKey: _decodeKey(encodedKey),
      nonce: _cipher.newNonce(),
      aad: _context(
        conversationId,
        senderId,
      ),
    );

    return base64Encode(
      box.concatenation(),
    );
  }

  Future<String> decrypt(
    String encodedCiphertext,
    String encodedKey,
    String conversationId,
    String senderId,
  ) async {
    final envelope = base64Decode(encodedCiphertext);

    final minimumLength = _cipher.nonceLength + _cipher.macAlgorithm.macLength;

    if (envelope.length < minimumLength) {
      throw const FormatException(
        'Incomplete encrypted message.',
      );
    }

    final box = SecretBox.fromConcatenation(
      envelope,
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );

    final bytes = await _cipher.decrypt(
      box,
      secretKey: _decodeKey(encodedKey),
      aad: _context(
        conversationId,
        senderId,
      ),
    );

    return utf8.decode(bytes);
  }
}
