import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:supabase/supabase.dart';

class UserModel extends UserEntity {
  UserModel({
    required super.id,
    required super.email,
    super.nrp,
    super.nama,
    super.activeDate,
    super.position,
    super.sidCode,
  });

  factory UserModel.fromSupabase(User user) {
    return UserModel(id: user.id, email: user.email ?? '');
  }

  factory UserModel.fromManpower(Map<String, dynamic> json, String authId) {
    return UserModel(
      id: authId,
      email: json['email'] ?? '',
      nrp: json['nrp'],
      nama: json['nama'],
      activeDate: json['active_date'] != null ? DateTime.parse(json['active_date']) : null,
      position: json['position'],
      sidCode: json['sid_code'],
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? nrp,
    String? nama,
    DateTime? activeDate,
    int? position,
    String? sidCode,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      nrp: nrp ?? this.nrp,
      nama: nama ?? this.nama,
      activeDate: activeDate ?? this.activeDate,
      position: position ?? this.position,
      sidCode: sidCode ?? this.sidCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nrp': nrp,
      'nama': nama,
      'active_date': activeDate?.toIso8601String(),
      'position': position,
      'sid_code': sidCode,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      nrp: json['nrp'],
      nama: json['nama'],
      activeDate: json['active_date'] != null ? DateTime.parse(json['active_date']) : null,
      position: json['position'],
      sidCode: json['sid_code'],
    );
  }
}
