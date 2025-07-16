import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pointycastle/export.dart' as pc;

import '../models/password_entry.dart';

class VaultImporter {
  static Future<bool> importVault(BuildContext context, String path, String passphrase) async {
    try {
      final file = File(path);
      final bytes = await file.readAsBytes();

      // Split salt, IV, and encrypted data
      final salt = bytes.sublist(0, 8);
      final iv = encrypt.IV(bytes.sublist(8, 24));
      final encryptedData = bytes.sublist(24);

      final key = _deriveKey(passphrase, salt);
      final aes = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));

      final decrypted = aes.decrypt(encrypt.Encrypted(encryptedData), iv: iv);
      final List<dynamic> jsonList = jsonDecode(decrypted);

      final List<PasswordEntry> importedEntries = jsonList
          .map((json) => PasswordEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      final box = await Hive.openBox<PasswordEntry>('passwords');
      final existingEntries = box.values.toList();
      final existingIds = existingEntries.map((e) => e.id).toSet();

      // Keep only entries that are not duplicates
      final newEntries = importedEntries.where((e) => !existingIds.contains(e.id)).toList();

      await box.addAll(newEntries);

      return true;
    } catch (e) {
      print('❌ Error importing vault: $e');
      return false;
    }
  }

  static encrypt.Key _deriveKey(String passphrase, Uint8List salt) {
    final pbkdf2 = pc.PBKDF2KeyDerivator(pc.HMac(pc.SHA256Digest(), 64));
    pbkdf2.init(pc.Pbkdf2Parameters(salt, 10000, 32));
    final Uint8List keyBytes = pbkdf2.process(Uint8List.fromList(utf8.encode(passphrase)));
    return encrypt.Key(keyBytes);
  }
}