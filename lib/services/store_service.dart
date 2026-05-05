import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store.dart';
import '../models/app_user.dart';

class StoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Generate a random 6-character alphanumeric invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Create a new store for a manager
  Future<Store> createStore(String managerId, String storeName) async {
    final storeRef = _firestore.collection('stores').doc();
    final inviteCode = _generateInviteCode();

    final store = Store(
      id: storeRef.id,
      name: storeName,
      managerId: managerId,
      inviteCode: inviteCode,
      createdAt: DateTime.now(),
    );

    await storeRef.set(store.toMap());
    return store;
  }

  /// Find a store by invite code
  Future<Store?> findStoreByInviteCode(String code) async {
    final query = await _firestore
        .collection('stores')
        .where('inviteCode', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return Store.fromMap(query.docs.first.data());
  }

  /// Get store by ID
  Future<Store?> getStore(String storeId) async {
    final doc = await _firestore.collection('stores').doc(storeId).get();
    if (!doc.exists) return null;
    return Store.fromMap(doc.data()!);
  }

  /// Stream store data
  Stream<Store?> storeStream(String storeId) {
    return _firestore
        .collection('stores')
        .doc(storeId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return Store.fromMap(doc.data()!);
    });
  }

  /// Regenerate invite code for a store
  Future<String> regenerateInviteCode(String storeId) async {
    final newCode = _generateInviteCode();
    await _firestore.collection('stores').doc(storeId).update({
      'inviteCode': newCode,
    });
    return newCode;
  }

  /// Get all employees of a store
  Stream<List<AppUser>> getStoreEmployees(String storeId) {
    return _firestore
        .collection('users')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap(doc.data()))
          .toList();
    });
  }

  /// Update an employee's roles (multi-role support)
  Future<void> updateEmployeeRoles(String userId, List<String> roles) async {
    await _firestore.collection('users').doc(userId).update({
      'role': 'employee',
      'roles': roles,
    });
  }

  /// Toggle a single role on/off for an employee
  Future<void> toggleEmployeeRole(String userId, String role, bool enabled) async {
    if (enabled) {
      await _firestore.collection('users').doc(userId).update({
        'role': 'employee',
        'roles': FieldValue.arrayUnion([role]),
      });
    } else {
      await _firestore.collection('users').doc(userId).update({
        'roles': FieldValue.arrayRemove([role]),
      });
    }
  }

  /// Remove an employee from the store
  Future<void> removeEmployee(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'storeId': null,
      'role': 'pending',
      'roles': [],
    });
  }
}
