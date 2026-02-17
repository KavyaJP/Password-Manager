import 'package:flutter/foundation.dart';
import '../../../core/models/password_entry.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/password_generator.dart'; // Using your existing utility

class EntryController extends ChangeNotifier {
  final StorageService _storageService;

  bool _isObscured = true;
  bool get isObscured => _isObscured;

  EntryController({StorageService? storageService})
    : _storageService = storageService ?? StorageService();

  void togglePasswordVisibility() {
    _isObscured = !_isObscured;
    notifyListeners();
  }

  String generatePassword({
    int length = 16,
    bool upper = true,
    bool lower = true,
    bool numbers = true,
    bool symbols = true,
  }) {
    return PasswordGenerator.generate(
      length: length,
      includeUpper: upper,
      includeLower: lower,
      includeNumbers: numbers,
      includeSymbols: symbols,
    );
  }

  /// Returns null if valid, or an error string if invalid
  String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Required";
    }
    return null;
  }

  Future<void> saveEntry({
    required String? id,
    required String service,
    required String username,
    required String password,
    String? note,
    String? category,
    required List<String> imagePaths,
    bool isFavorite = false,
  }) async {
    final entryId = id ?? DateTime.now().millisecondsSinceEpoch.toString();

    final newEntry = PasswordEntry(
      id: entryId,
      service: service.trim(),
      username: username.trim(),
      password: password.trim(),
      note: note?.trim(),
      category: category?.trim(),
      imagePaths: imagePaths,
      isFavorite: isFavorite,
    );

    await _storageService.saveEntry(newEntry);
  }
}
