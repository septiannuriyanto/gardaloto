import 'package:gardaloto/domain/entities/user_entity.dart';
import 'package:supabase/supabase.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    super.nrp,
    super.nama,
    super.activeDate,
    super.position,
    super.sidCode,
    super.positionDescription,
    super.photoUrl,
    super.bgPhotoUrl,
    super.active,
    super.registered,
    super.section,
    super.updatedAt,
  });

  factory UserModel.fromSupabase(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      nrp: user.userMetadata?['nrp'],
      nama: user.userMetadata?['full_name'],
    );
  }

  factory UserModel.fromManpower(Map<String, dynamic> map, String authId) {
    return UserModel(
      id: authId,
      email: map['email'] as String? ?? '',
      nrp: map['nrp'] as String?,
      nama: map['nama'] as String?,
      activeDate: map['active_date'] != null
          ? DateTime.tryParse(map['active_date'])
          : null,
      position: map['position'] as int?,
      sidCode: map['sid_code'] as String?,
      positionDescription: map['incumbent']?['incumbent'] as String?,
      photoUrl: map['photo_url'] as String?,
      bgPhotoUrl: map['bg_photo_url'] as String?,
      active: map['active'] as bool? ?? true,
      registered: map['registered'] as bool? ?? true, // Default true if column missing during migration
      section: map['section'] as String?,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at']) : null,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      nrp: json['nrp'],
      nama: json['nama'],
      activeDate: json['activeDate'] != null
          ? DateTime.parse(json['activeDate'])
          : null,
      position: json['position'],
      sidCode: json['sidCode'],
      positionDescription: json['positionDescription'],
      photoUrl: json['photoUrl'],
      bgPhotoUrl: json['bgPhotoUrl'],
      active: json['active'],
      registered: json['registered'],
      section: json['section'],
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'nrp': nrp,
      'nama': nama,
      'activeDate': activeDate?.toIso8601String(),
      'position': position,
      'sidCode': sidCode,
      'positionDescription': positionDescription,
      'photoUrl': photoUrl,
      'bgPhotoUrl': bgPhotoUrl,
      'active': active,
      'registered': registered,
      'section': section,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? nrp,
    String? nama,
    DateTime? activeDate,
    int? position,
    String? sidCode,
    String? positionDescription,
    String? photoUrl,
    String? bgPhotoUrl,
    bool? active,
    bool? registered,
    String? section,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      nrp: nrp ?? this.nrp,
      nama: nama ?? this.nama,
      activeDate: activeDate ?? this.activeDate,
      position: position ?? this.position,
      sidCode: sidCode ?? this.sidCode,
      positionDescription: positionDescription ?? this.positionDescription,
      photoUrl: photoUrl ?? this.photoUrl,
      bgPhotoUrl: bgPhotoUrl ?? this.bgPhotoUrl,
      active: active ?? this.active,
      registered: registered ?? this.registered,
      section: section ?? this.section,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
