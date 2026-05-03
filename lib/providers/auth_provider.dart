import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/app_user.dart';
import '../models/store.dart';
import '../services/auth_service.dart';
import '../services/store_service.dart';

enum AuthState {
  loading,
  unauthenticated,
  needsRoleSelection,
  pendingApproval,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final StoreService _storeService = StoreService();

  AuthState _state = AuthState.loading;
  AppUser? _appUser;
  Store? _store;
  String? _error;
  StreamSubscription? _userSubscription;

  AuthState get state => _state;
  AppUser? get appUser => _appUser;
  Store? get store => _store;
  String? get error => _error;
  bool get isLoading => _state == AuthState.loading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((User? firebaseUser) async {
      if (firebaseUser == null) {
        _state = AuthState.unauthenticated;
        _appUser = null;
        _store = null;
        _userSubscription?.cancel();
        notifyListeners();
        return;
      }

      // Check if user exists in Firestore
      final existingUser = await _authService.getAppUser(firebaseUser.uid);

      if (existingUser == null) {
        // New user — needs role selection
        _state = AuthState.needsRoleSelection;
        notifyListeners();
        return;
      }

      // Listen to user changes
      _listenToUser(firebaseUser.uid);
    });
  }

  void _listenToUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _authService.appUserStream(uid).listen((user) async {
      _appUser = user;

      if (user == null) {
        _state = AuthState.needsRoleSelection;
        notifyListeners();
        return;
      }

      if (user.isPending) {
        _state = AuthState.pendingApproval;
        notifyListeners();
        return;
      }

      // Load store data
      if (user.storeId != null) {
        _store = await _storeService.getStore(user.storeId!);
      }

      _state = AuthState.authenticated;
      notifyListeners();
    });
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      _error = null;
      _state = AuthState.loading;
      notifyListeners();

      await _authService.signInWithGoogle();
      // Auth state listener handles the rest
    } catch (e) {
      _error = 'Failed to sign in. Please try again.';
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  /// Register as Manager — create a new store
  Future<void> registerAsManager(String storeName) async {
    try {
      _error = null;
      _state = AuthState.loading;
      notifyListeners();

      final firebaseUser = _authService.currentFirebaseUser!;

      // Create store
      final store = await _storeService.createStore(
        firebaseUser.uid,
        storeName,
      );

      // Create user profile
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Manager',
        photoUrl: firebaseUser.photoURL,
        role: 'manager',
        storeId: store.id,
        createdAt: DateTime.now(),
      );

      await _authService.saveAppUser(appUser);
      _listenToUser(firebaseUser.uid);
    } catch (e) {
      _error = 'Failed to create store. Please try again.';
      _state = AuthState.needsRoleSelection;
      notifyListeners();
    }
  }

  /// Register as Employee — join store with invite code
  Future<bool> joinStoreWithCode(String inviteCode) async {
    try {
      _error = null;

      final store = await _storeService.findStoreByInviteCode(inviteCode);
      if (store == null) {
        _error = 'Invalid invite code. Please check and try again.';
        notifyListeners();
        return false;
      }

      final firebaseUser = _authService.currentFirebaseUser!;

      // Create user profile with pending role
      final appUser = AppUser(
        uid: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        displayName: firebaseUser.displayName ?? 'Employee',
        photoUrl: firebaseUser.photoURL,
        role: 'pending',
        storeId: store.id,
        createdAt: DateTime.now(),
      );

      await _authService.saveAppUser(appUser);
      _listenToUser(firebaseUser.uid);
      return true;
    } catch (e) {
      _error = 'Failed to join store. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _userSubscription?.cancel();
    await _authService.signOut();
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }
}
