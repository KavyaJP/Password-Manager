import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/password_entry.dart';

class BackupService {
  /// Uploads the entire vault + images to Google Drive
  Future<void> uploadToDrive(
    http.Client authClient,
    List<PasswordEntry> entries,
  ) async {
    try {
      final driveApi = drive.DriveApi(authClient);

      // 1. Clean up old backups to prevent clutter
      // (Optimized to check list first to avoid 404s)
      final fileList = await driveApi.files.list(spaces: 'appDataFolder');
      if (fileList.files != null) {
        for (final file in fileList.files!) {
          if (file.name == 'vault_backup.json' ||
              (file.name?.startsWith('vault_image_') ?? false)) {
            await driveApi.files.delete(file.id!);
          }
        }
      }

      // 2. Create and Upload JSON
      final fileToUpload = await _createLocalBackupFile(entries);
      final media = drive.Media(
        fileToUpload.openRead(),
        fileToUpload.lengthSync(),
      );

      final driveFile = drive.File()
        ..name = 'vault_backup.json'
        ..parents = ['appDataFolder'];

      await driveApi.files.create(driveFile, uploadMedia: media);

      // 3. Upload Images
      for (final entry in entries) {
        for (int i = 0; i < entry.imagePaths.length; i++) {
          final imageFile = File(entry.imagePaths[i]);
          if (!imageFile.existsSync()) continue;

          final imgMedia = drive.Media(
            imageFile.openRead(),
            imageFile.lengthSync(),
          );
          final imgDriveFile = drive.File()
            ..name = 'vault_image_${entry.id}_$i.png'
            ..parents = ['appDataFolder'];

          await driveApi.files.create(imgDriveFile, uploadMedia: imgMedia);
        }
      }
      debugPrint("✅ Backup complete");
    } catch (e) {
      debugPrint("❌ Backup failed: $e");
      rethrow;
    }
  }

  /// Restores vault + images from Google Drive
  Future<List<PasswordEntry>> restoreFromDrive(http.Client authClient) async {
    try {
      final driveApi = drive.DriveApi(authClient);

      // 1. List files
      final fileList = await driveApi.files.list(spaces: 'appDataFolder');
      final allFiles = fileList.files ?? [];

      // 2. Find JSON
      final backupFile = allFiles.firstWhere(
        (f) => f.name == 'vault_backup.json',
        orElse: () => throw Exception("No backup found"),
      );

      // 3. Download JSON
      final media =
          await driveApi.files.get(
                backupFile.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final content = await utf8.decoder.bind(media.stream).join();
      final jsonData = jsonDecode(content) as List<dynamic>;
      final restoredEntries = jsonData
          .map((e) => PasswordEntry.fromJson(e))
          .toList();

      // 4. Download Images
      final tempDir = await getTemporaryDirectory();

      for (final entry in restoredEntries) {
        final newPaths = <String>[];
        int index = 0;

        // Look for images sequentially: vault_image_ID_0, vault_image_ID_1...
        while (true) {
          final expectedName = 'vault_image_${entry.id}_$index.png';
          final matchingFiles = allFiles
              .where((f) => f.name == expectedName)
              .toList();

          if (matchingFiles.isEmpty) break;

          final fileId = matchingFiles.first.id!;
          final imageMedia =
              await driveApi.files.get(
                    fileId,
                    downloadOptions: drive.DownloadOptions.fullMedia,
                  )
                  as drive.Media;

          final localFile = File('${tempDir.path}/$expectedName');
          final sink = localFile.openWrite();
          await imageMedia.stream.pipe(sink);
          await sink.close();

          newPaths.add(localFile.path);
          index++;
        }
        // Update entry with new local paths
        entry.imagePaths.clear();
        entry.imagePaths.addAll(newPaths);
      }

      return restoredEntries;
    } catch (e) {
      debugPrint("❌ Restore failed: $e");
      rethrow;
    }
  }

  Future<File> _createLocalBackupFile(List<PasswordEntry> entries) async {
    final jsonData = entries.map((e) => e.toJson()).toList();
    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/vault_backup.json');
    return file.writeAsString(jsonEncode(jsonData));
  }
}
