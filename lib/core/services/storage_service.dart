import 'package:hive_flutter/hive_flutter.dart';
import '../models/password_entry.dart';

class StorageService {
  static const String _boxName = 'passwords';

  /// Ensures Hive is ready (call this in main if needed, or lazily)
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PasswordEntryAdapter());
    }
    await Hive.openBox<PasswordEntry>(_boxName);
  }

  /// Get all entries as a list
  Future<List<PasswordEntry>> getAllEntries() async {
    final box = await Hive.openBox<PasswordEntry>(_boxName);
    return box.values.toList();
  }

  /// Save or Update a single entry
  Future<void> saveEntry(PasswordEntry entry) async {
    final box = await Hive.openBox<PasswordEntry>(_boxName);
    // Uses the ID as the key to ensure uniqueness/updates
    await box.put(entry.id, entry);
  }

  /// Delete a single entry by ID
  Future<void> deleteEntry(String id) async {
    final box = await Hive.openBox<PasswordEntry>(_boxName);
    await box.delete(id);
  }

  /// Bulk replace (useful for restores)
  Future<void> replaceAllEntries(List<PasswordEntry> entries) async {
    final box = await Hive.openBox<PasswordEntry>(_boxName);
    await box.clear();
    await box.putAll({for (var e in entries) e.id: e});
  }
}
