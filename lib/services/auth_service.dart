import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/foundation.dart' show ValueNotifier;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: kIsWeb
        ? '887184426457-stmng7ma1lscjckmj6l2sriveqpock48.apps.googleusercontent.com'
        : null,
  );

  // Guest mode flag — shared across the app
  static final ValueNotifier<bool> isGuest = ValueNotifier<bool>(false);

  // Expose the auth state so your app knows instantly when a user logs in/out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Continue as Guest (skip sign-in entirely)
  void continueAsGuest() {
    isGuest.value = true;
  }

  // 1. Standard Interactive Login (Triggered by a button click)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential result;
      if (kIsWeb) {
        // Use Firebase Auth's native web popup method
        GoogleAuthProvider authProvider = GoogleAuthProvider();
        result = await _auth.signInWithPopup(authProvider);
      } else {
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null; // User canceled the popup

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        result = await _auth.signInWithCredential(credential);
      }

      // On successful sign-in, exit guest mode
      isGuest.value = false;
      return result;
    } catch (e) {
      print("Google Auth Error: $e");
      return null;
    }
  }

  // 2. Silent Login (Triggered automatically when the app starts)
  Future<UserCredential?> signInSilently() async {
    try {
      // Attempt to sign in without prompting the user UI
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();
      if (googleUser == null) {
        return null; // No cached login found, user must login manually
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Silent Auth Error: $e");
      return null;
    }
  }

  // 3. Sign Out (also exits guest mode)
  Future<void> signOut() async {
    try {
      isGuest.value = false;
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }
}
