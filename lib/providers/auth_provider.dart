// File: lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  // Removed eager initialization of GoogleSignIn to prevent Web crash (missing clientId)
  User? _user;
  bool _isLoading = true;

  User? get user => _user;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

// ... (init)

  Future<void> signIn(String email, String password) async {
    await _authService.signIn(email, password);
  }

  Future<void> signUp(String email, String password) async {
    await _authService.signUp(email, password);
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return; // User canceled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _authService.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }

// ... (rest of methods)

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _authService.reauthenticate(currentPassword);
    await _authService.updatePassword(newPassword);
  }

  Future<void> signInAnonymously() async {
    // ...
    await _authService.signInAnonymously();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
