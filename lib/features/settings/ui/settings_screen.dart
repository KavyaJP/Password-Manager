import 'package:flutter/material.dart';
import '../logic/settings_controller.dart';

class SettingsScreen extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkTheme;

  const SettingsScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsController _controller;

  final List<int> _autoLockOptions = [0, 15, 30, 60, 120, 300];
  final List<int> _clipboardOptions = [0, 5, 10, 20, 30, 60];

  @override
  void initState() {
    super.initState();
    _controller = SettingsController();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatSeconds(int seconds) {
    if (seconds == 0) return "Never";
    if (seconds < 60) return "$seconds sec";
    return "${(seconds / 60).round()} min";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("⚙️ Settings")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text("🌗 Dark Mode"),
            value: widget.isDarkTheme,
            onChanged: widget.onThemeChanged,
          ),
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            "🔒 Auto-lock timeout",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: _controller.autoLockTimeout,
            isExpanded: true,
            items: _autoLockOptions.map((seconds) {
              return DropdownMenuItem(
                value: seconds,
                child: Text(_formatSeconds(seconds)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) _controller.updateAutoLockTimeout(value);
            },
          ),
          const SizedBox(height: 24),
          const Text(
            "📋 Clipboard auto-clear",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: _controller.clipboardClearTime,
            isExpanded: true,
            items: _clipboardOptions.map((seconds) {
              return DropdownMenuItem(
                value: seconds,
                child: Text(_formatSeconds(seconds)),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) _controller.updateClipboardTimeout(value);
            },
          ),
        ],
      ),
    );
  }
}
