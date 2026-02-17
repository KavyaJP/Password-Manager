import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  int _autoLockTimeout = 60;
  int _clipboardClearTime = 10;

  int get autoLockTimeout => _autoLockTimeout;
  int get clipboardClearTime => _clipboardClearTime;

  SettingsController() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLockTimeout = prefs.getInt('autoLockTimeout') ?? 60;
    _clipboardClearTime = prefs.getInt('clipboardClearTime') ?? 10;
    notifyListeners();
  }

  Future<void> updateAutoLockTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('autoLockTimeout', seconds);
    _autoLockTimeout = seconds;
    notifyListeners();
  }

  Future<void> updateClipboardTimeout(int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('clipboardClearTime', seconds);
    _clipboardClearTime = seconds;
    notifyListeners();
  }
}
