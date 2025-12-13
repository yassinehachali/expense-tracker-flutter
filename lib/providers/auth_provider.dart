// File: lib/providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../data/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
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

  Future<void> signIn(String email, String password) async {
    await _authService.signIn(email, password);
  }

  Future<void> signUp(String email, String password) async {
    await _authService.signUp(email, password);
  }

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
