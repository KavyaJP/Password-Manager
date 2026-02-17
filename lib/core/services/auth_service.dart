import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;

/// A platform-agnostic user wrapper.
/// The rest of your app will use this, not GoogleSignInAccount directly.
class AuthUser {
  final String? displayName;
  final String? email;
  final String? photoUrl;
  final http.Client authClient; // The key to making Drive API calls

  AuthUser({
    this.displayName,
    required this.email,
    this.photoUrl,
    required this.authClient,
  });
}

class AuthService {
  // Mobile implementation (Wraps your existing GoogleSignIn logic)
  final _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveAppdataScope],
  );

  Future<AuthUser?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) return null;
      return await _toAuthUser(account);
    } catch (e) {
      print("Sign-In Error: $e");
      return null;
    }
  }

  Future<AuthUser?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;
      return await _toAuthUser(account);
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  /// Helper to convert GoogleSignInAccount to our generic AuthUser
  Future<AuthUser> _toAuthUser(GoogleSignInAccount account) async {
    final authHeaders = await account.authHeaders;
    return AuthUser(
      displayName: account.displayName,
      email: account.email,
      photoUrl: account.photoUrl,
      authClient: _GoogleAuthClient(authHeaders),
    );
  }
}

/// Helper Client to inject headers into requests
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
