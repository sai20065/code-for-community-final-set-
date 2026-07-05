import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { citizen, official }

class UserModel {
  final String uid;
  final String name;
  final int age;
  final String phone;
  final String pincodeHome;
  final String addressHome;
  final UserRole role;
  final String? constituencyId;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.phone,
    required this.pincodeHome,
    required this.addressHome,
    required this.role,
    required this.createdAt,
    this.constituencyId,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      age: map['age'] as int? ?? 0,
      phone: map['phone'] as String? ?? '',
      pincodeHome: map['pincodeHome'] as String? ?? '',
      addressHome: map['addressHome'] as String? ?? '',
      role: (map['role'] as String? ?? 'citizen') == 'official'
          ? UserRole.official
          : UserRole.citizen,
      constituencyId: map['constituencyId'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'age': age,
      'phone': phone,
      'pincodeHome': pincodeHome,
      'addressHome': addressHome,
      'role': role.name,
      'constituencyId': constituencyId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
