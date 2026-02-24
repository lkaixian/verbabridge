import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Expose the auth state so your app knows instantly when a user logs in/out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // 1. Standard Interactive Login (Triggered by a button click)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User canceled the popup

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Google Auth Error: $e");
      return null;
    }
  }

  // 2. 🌟 NEW: Silent Login (Triggered automatically when the app starts)
  Future<UserCredential?> signInSilently() async {
    try {
      // Attempt to sign in without prompting the user UI
      final GoogleSignInAccount? googleUser = await _googleSignIn
          .signInSilently();
      if (googleUser == null)
        return null; // No cached login found, user must login manually

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

  // 3. Sign Out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print("Sign Out Error: $e");
    }
  }
}
