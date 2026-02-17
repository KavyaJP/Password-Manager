import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import '../logic/home_controller.dart';
import '../../../../core/models/password_entry.dart';
import '../../../../features/entry/ui/entry_screen.dart';
import '../../../../features/settings/ui/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final bool isDarkTheme;
  final VoidCallback onManualLock;

  const HomeScreen({
    super.key,
    required this.onThemeChanged,
    required this.isDarkTheme,
    required this.onManualLock,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = HomeController();
    // Rebuild UI when controller notifies changes
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🔐 Your Vault"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _controller.search,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _controller.showOnlyFavorites ? Icons.star : Icons.star_border,
              color: _controller.showOnlyFavorites ? Colors.amber : null,
            ),
            tooltip: "Filter Favorites",
            onPressed: _controller.toggleFavorites,
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EntryScreen()),
          ).then((_) {
            // 🔄 Force refresh when coming back from Add Screen
            _controller.refresh();
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    final user = _controller.currentUser;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? "Not Signed In"),
            accountEmail: Text(user?.email ?? "Sign in to backup"),
            currentAccountPicture: user?.photoUrl != null
                ? CircleAvatar(backgroundImage: NetworkImage(user!.photoUrl!))
                : const CircleAvatar(child: Icon(Icons.person)),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          ListTile(
            leading: const Icon(Icons.cloud_upload),
            title: const Text('Backup to Drive'),
            onTap: () async {
              Navigator.pop(context);
              final msg = await _controller.backupToDrive();
              _showSnackBar(msg);
            },
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download),
            title: const Text('Restore from Drive'),
            onTap: () async {
              Navigator.pop(context);
              final msg = await _controller.restoreFromDrive();
              _showSnackBar(msg);
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    onThemeChanged: widget.onThemeChanged,
                    isDarkTheme: widget.isDarkTheme,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Lock Vault'),
            onTap: () {
              Navigator.pop(context);
              widget.onManualLock();
            },
          ),
          if (user != null) ...[
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
              onTap: () {
                _controller.signOut();
                Navigator.pop(context);
              },
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_controller.entries.isEmpty) {
      return const Center(child: Text("No entries found"));
    }
    return ListView.builder(
      itemCount: _controller.entries.length,
      itemBuilder: (context, index) {
        final entry = _controller.entries[index];
        return _PasswordListTile(
          entry: entry,
          onDelete: () => _confirmDelete(entry),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => EntryScreen(existingEntry: entry),
              ),
            ).then((_) {
              // 🔄 Force refresh when coming back from Edit Screen
              _controller.refresh();
            });
          },
        );
      },
    );
  }

  void _confirmDelete(PasswordEntry entry) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Entry?"),
        content: Text("Are you sure you want to delete '${entry.service}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              _controller.deleteEntry(entry.id);
              Navigator.pop(context);
              _showSnackBar("Deleted ${entry.service}");
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Extracted widget to handle "Obscure" state locally per item
class _PasswordListTile extends StatefulWidget {
  final PasswordEntry entry;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _PasswordListTile({
    required this.entry,
    required this.onDelete,
    required this.onTap,
  });

  @override
  State<_PasswordListTile> createState() => _PasswordListTileState();
}

class _PasswordListTileState extends State<_PasswordListTile> {
  bool _isVisible = false;

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("$label copied!")));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        onTap: widget.onTap,
        title: Text(widget.entry.service, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _copyToClipboard(widget.entry.username, "Username"),
              child: Text(widget.entry.username, style: const TextStyle(color: Colors.blueGrey)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _isVisible ? widget.entry.password : "•" * 8,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
                if (_isVisible)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    onPressed: () => _copyToClipboard(widget.entry.password, "Password"),
                  ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(_isVisible ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _isVisible = !_isVisible),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.grey),
              onPressed: widget.onDelete,
            ),
          ],
        ),
      ),
    );
  }
}