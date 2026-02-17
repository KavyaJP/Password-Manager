import 'package:flutter/foundation.dart';
import '../../../core/models/password_entry.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/backup_service.dart';

class HomeController extends ChangeNotifier {
  // Dependencies
  final StorageService _storageService;
  final AuthService _authService;
  final BackupService _backupService;

  // State
  List<PasswordEntry> _allEntries = [];
  List<PasswordEntry> _filteredEntries = [];
  AuthUser? _currentUser;
  bool _isLoading = false;
  String _searchQuery = "";
  bool _showOnlyFavorites = false;
  bool _groupByCategory = false;

  // Getters for UI
  List<PasswordEntry> get entries => _filteredEntries;
  AuthUser? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get showOnlyFavorites => _showOnlyFavorites;
  bool get groupByCategory => _groupByCategory;

  HomeController({
    StorageService? storageService,
    AuthService? authService,
    BackupService? backupService,
  }) : _storageService = storageService ?? StorageService(),
       _authService = authService ?? AuthService(),
       _backupService = backupService ?? BackupService() {
    _init();
  }

  Future<void> _init() async {
    await refresh(); // Load data immediately on startup
    await _checkAuthStatus();
  }

  /// 🔄 Reloads data from Hive (Call this after adding/editing)
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Ensure box is open (important if path changed)
      await _storageService.init();
      _allEntries = await _storageService.getAllEntries();
      _applyFilters();
    } catch (e) {
      debugPrint("Error loading vault: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    await _storageService.deleteEntry(id);
    _allEntries.removeWhere((e) => e.id == id);
    _applyFilters();
    notifyListeners();
  }

  // --- Filtering & Searching ---

  void search(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void toggleFavorites() {
    _showOnlyFavorites = !_showOnlyFavorites;
    _applyFilters();
    notifyListeners();
  }

  void toggleGrouping() {
    _groupByCategory = !_groupByCategory;
    notifyListeners();
  }

  void _applyFilters() {
    _filteredEntries = _allEntries.where((entry) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery =
          entry.service.toLowerCase().contains(query) ||
          entry.username.toLowerCase().contains(query);
      final matchesFav = _showOnlyFavorites ? entry.isFavorite : true;
      return matchesQuery && matchesFav;
    }).toList();
  }

  // --- Google Drive & Auth ---

  Future<void> _checkAuthStatus() async {
    _currentUser = await _authService.signInSilently();
    notifyListeners();
  }

  Future<void> signIn() async {
    _currentUser = await _authService.signIn();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<String> backupToDrive() async {
    if (_currentUser == null) await signIn();
    if (_currentUser == null) return "Sign-in failed";

    try {
      _isLoading = true;
      notifyListeners();

      await _backupService.uploadToDrive(_currentUser!.authClient, _allEntries);
      return "Backup successful";
    } catch (e) {
      return "Backup failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> restoreFromDrive() async {
    if (_currentUser == null) await signIn();
    if (_currentUser == null) return "Sign-in failed";

    try {
      _isLoading = true;
      notifyListeners();

      final restored = await _backupService.restoreFromDrive(
        _currentUser!.authClient,
      );

      // Update local storage and state
      await _storageService.replaceAllEntries(restored);
      _allEntries = restored;
      _applyFilters();

      return "Restore successful";
    } catch (e) {
      return "Restore failed: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
