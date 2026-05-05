import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String role; // 'manager', 'pending', or legacy single role
  final List<String> roles; // ['cashier', 'warehouse'] — multi-role support
  final String? storeId;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.role,
    List<String>? roles,
    this.storeId,
    required this.createdAt,
  }) : roles = roles ?? [];

  bool get isManager => role == 'manager';
  bool get isWarehouse => role == 'manager' || roles.contains('warehouse');
  bool get isCashier => role == 'manager' || roles.contains('cashier');
  bool get isPending => role == 'pending';

  bool get canManageInventory => isManager || isWarehouse;
  bool get canViewSales => isManager;
  bool get canManageTeam => isManager;

  /// Human-readable display of assigned roles
  String get rolesDisplay {
    if (isManager) return 'MANAGER';
    if (isPending) return 'PENDING';
    if (roles.isEmpty) return 'NO ROLE';
    return roles.map((r) => r.toUpperCase()).join(' + ');
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    List<String>? roles,
    String? storeId,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      roles: roles ?? this.roles,
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
      'roles': roles,
      'storeId': storeId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    final role = map['role'] as String;
    // Backward compat: if 'roles' list doesn't exist, derive from old 'role' field
    List<String> roles;
    if (map['roles'] != null) {
      roles = List<String>.from(map['roles'] as List<dynamic>);
    } else if (role == 'cashier') {
      roles = ['cashier'];
    } else if (role == 'warehouse') {
      roles = ['warehouse'];
    } else {
      roles = [];
    }

    return AppUser(
      uid: map['uid'] as String,
      email: map['email'] as String,
      displayName: map['displayName'] as String,
      photoUrl: map['photoUrl'] as String?,
      role: role,
      roles: roles,
      storeId: map['storeId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
