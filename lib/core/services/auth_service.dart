import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// A platform-agnostic user wrapper.
class AuthUser {
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final http.Client authClient;

  AuthUser({
    this.displayName,
    required this.email,
    this.photoUrl,
    required this.authClient,
  });
}

class AuthService {
  // ---------------------------------------------------------------------------
  // ⚠️ CONFIGURATION: PASTE YOUR NEW DESKTOP CREDENTIALS HERE
  // ---------------------------------------------------------------------------
  static final _desktopClientId = ClientId(
    dotenv.env['GOOGLE_CLIENT_ID']!,
    dotenv.env['GOOGLE_CLIENT_SECRET']!,
  );

  static const _scopes = [drive.DriveApi.driveAppdataScope, 'email'];

  // Mobile Implementation
  final _googleSignIn = GoogleSignIn(scopes: _scopes);

  // Desktop Implementation (State)
  AutoRefreshingAuthClient? _desktopClient;

  /// Main Sign-In Method
  Future<AuthUser?> signIn() async {
    if (kIsWeb) return null;

    if (Platform.isAndroid || Platform.isIOS) {
      return _signInMobile();
    } else {
      return _signInDesktop();
    }
  }

  /// Main Silent Sign-In Method
  Future<AuthUser?> signInSilently() async {
    if (kIsWeb) return null;

    if (Platform.isAndroid || Platform.isIOS) {
      return _signInSilentlyMobile();
    } else {
      // For MVP, we return null to force login on desktop restart
      return null;
    }
  }

  /// Main Sign-Out Method
  Future<void> signOut() async {
    if (Platform.isAndroid || Platform.isIOS) {
      await _googleSignIn.signOut();
    } else {
      _desktopClient?.close();
      _desktopClient = null;
    }
  }

  // ---------------------------------------------------------------------------
  // 📱 MOBILE LOGIC (GoogleSignIn)
  // ---------------------------------------------------------------------------
  Future<AuthUser?> _signInMobile() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      return await _toMobileAuthUser(account);
    } catch (e) {
      debugPrint("Mobile Sign-In Error: $e");
      return null;
    }
  }

  Future<AuthUser?> _signInSilentlyMobile() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      return await _toMobileAuthUser(account);
    } catch (e) {
      return null;
    }
  }

  Future<AuthUser> _toMobileAuthUser(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    return AuthUser(
      displayName: account.displayName,
      email: account.email,
      photoUrl: account.photoUrl,
      authClient: _GoogleAuthClient(authHeaders),
    );
  }

  // ---------------------------------------------------------------------------
  // 🖥️ DESKTOP LOGIC (GoogleApisAuth + UrlLauncher)
  // ---------------------------------------------------------------------------
  Future<AuthUser?> _signInDesktop() async {
    try {
      // This will open the browser at localhost
      _desktopClient = await clientViaUserConsent(_desktopClientId, _scopes, (
        url,
      ) {
        _launchUrl(url);
      });

      return AuthUser(
        displayName: "Desktop User",
        email: "Google Drive Connected",
        photoUrl: null,
        authClient: _desktopClient!,
      );
    } catch (e) {
      debugPrint("Desktop Sign-In Error: $e");
      return null;
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      debugPrint("Could not launch $url");
    }
  }
}

/// Helper for Mobile Headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
