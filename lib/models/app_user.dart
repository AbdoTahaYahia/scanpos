import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role; // 'manager', 'warehouse', 'cashier', 'pending'
  final String? storeId;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    this.storeId,
    required this.createdAt,
  });

  bool get isManager => role == 'manager';
  bool get isWarehouse => role == 'warehouse';
  bool get isCashier => role == 'cashier';
  bool get isPending => role == 'pending';

  bool get canManageInventory => isManager || isWarehouse;
  bool get canViewSales => isManager;
  bool get canManageTeam => isManager;

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    String? storeId,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      storeId: storeId ?? this.storeId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'storeId': storeId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      photoUrl: map['photoUrl'] as String?,
      role: map['role'] as String,
      storeId: map['storeId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
