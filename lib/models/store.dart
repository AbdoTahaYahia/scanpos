import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String name;
  final String managerId;
  final String inviteCode;
  final DateTime createdAt;

  Store({
    required this.id,
    required this.name,
    required this.managerId,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'managerId': managerId,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Store.fromMap(Map<String, dynamic> map) {
    return Store(
      id: map['id'] as String,
      name: map['name'] as String,
      managerId: map['managerId'] as String,
      inviteCode: map['inviteCode'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
