import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const LockScreen({required this.onAuthenticated, super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _checkIfLockEnabled();
    _authenticate();
  }

  Future<void> _checkIfLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    // Default to true if not set, or false? Logic from original file:
    final isLockEnabled = prefs.getBool('lock_enabled') ?? false;

    if (isLockEnabled) {
      _authenticate();
    } else {
      widget.onAuthenticated();
    }
  }

  Future<void> _authenticate() async {
    try {
      bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Authenticate to unlock your password vault',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      if (didAuthenticate) {
        widget.onAuthenticated();
      }
    } catch (e) {
      // Retry or handle error
      // _authenticate(); // careful with infinite loops here
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Locked', style: TextStyle(fontSize: 24)),
            SizedBox(height: 8),
            Text('Tap to unlock', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
