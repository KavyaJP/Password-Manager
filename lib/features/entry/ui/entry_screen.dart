import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../logic/entry_controller.dart';
import '../../../../core/models/password_entry.dart';

class EntryScreen extends StatefulWidget {
  final PasswordEntry? existingEntry;

  const EntryScreen({super.key, this.existingEntry});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  late final EntryController _controller;
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  late TextEditingController _serviceCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _noteCtrl;
  late TextEditingController _categoryCtrl;
  List<String> _imagePaths = [];
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _controller = EntryController();

    // Populate fields if editing
    final e = widget.existingEntry;
    _serviceCtrl = TextEditingController(text: e?.service);
    _usernameCtrl = TextEditingController(text: e?.username);
    _passwordCtrl = TextEditingController(text: e?.password);
    _noteCtrl = TextEditingController(text: e?.note);
    _categoryCtrl = TextEditingController(text: e?.category);
    _imagePaths = List.from(e?.imagePaths ?? []);
    _isFavorite = e?.isFavorite ?? false;

    // Listen for rebuilds (e.g. visibility toggle)
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _noteCtrl.dispose();
    _categoryCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage();
    if (pickedList.isNotEmpty) {
      setState(() {
        _imagePaths.addAll(pickedList.map((e) => e.path));
      });
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      await _controller.saveEntry(
        id: widget.existingEntry?.id, // Null means new entry
        service: _serviceCtrl.text,
        username: _usernameCtrl.text,
        password: _passwordCtrl.text,
        note: _noteCtrl.text,
        category: _categoryCtrl.text,
        imagePaths: _imagePaths,
        isFavorite: _isFavorite,
      );
      if (mounted) Navigator.pop(context);
    }
  }

  void _showGenerator() {
    // Simple generator dialog using Controller logic
    showDialog(
      context: context,
      builder: (context) {
        String generated = _controller.generatePassword();
        return AlertDialog(
          title: const Text("Generated Password"),
          content: SelectableText(
            generated,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                _passwordCtrl.text = generated;
                Navigator.pop(context);
              },
              child: const Text("Use"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry == null ? "Add Entry" : "Edit Entry"),
        actions: [
          IconButton(
            icon: Icon(_isFavorite ? Icons.star : Icons.star_border),
            color: _isFavorite ? Colors.amber : null,
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _serviceCtrl,
              decoration: const InputDecoration(
                labelText: "Service (e.g. Google)",
                border: OutlineInputBorder(),
              ),
              validator: _controller.validateRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameCtrl,
              decoration: const InputDecoration(
                labelText: "Username / Email",
                border: OutlineInputBorder(),
              ),
              validator: _controller.validateRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _controller.isObscured,
              decoration: InputDecoration(
                labelText: "Password",
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.isObscured
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: _controller.togglePasswordVisibility,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: "Generate Password",
                      onPressed: _showGenerator,
                    ),
                  ],
                ),
              ),
              validator: _controller.validateRequired,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Notes",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _categoryCtrl,
              decoration: const InputDecoration(
                labelText: "Category (Optional)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _buildImageSection(),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _save,
              child: const Text("Save Entry", style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Attachments",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text("Add Image"),
            ),
          ],
        ),
        if (_imagePaths.isNotEmpty)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 100,
                      height: 100,
                      child: Image.file(
                        File(_imagePaths[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _imagePaths.removeAt(index)),
                        child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
      ],
    );
  }
}
