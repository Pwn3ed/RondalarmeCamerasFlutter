import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_role.dart';

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final bool mustChangePassword;
  final bool disabled;
  final int maxDevices;
  /// Cliente pode alternar câmera pública/privada (admin sempre pode).
  final bool canToggleCameraPublic;
  /// `admin` ou `auto` quando [canToggleCameraPublic] é false.
  final String? publicToggleBlockedReason;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.mustChangePassword = false,
    this.disabled = false,
    this.maxDevices = 2,
    this.canToggleCameraPublic = true,
    this.publicToggleBlockedReason,
    this.createdBy,
    this.createdAt,
    this.lastLoginAt,
  });

  bool get isAdmin => role.isAdmin;

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role.storageValue,
      'mustChangePassword': mustChangePassword,
      'disabled': disabled,
      'maxDevices': maxDevices,
      'canToggleCameraPublic': canToggleCameraPublic,
      if (publicToggleBlockedReason != null)
        'publicToggleBlockedReason': publicToggleBlockedReason,
      if (createdBy != null) 'createdBy': createdBy,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (lastLoginAt != null) 'lastLoginAt': Timestamp.fromDate(lastLoginAt!),
    };
  }

  static AppUser fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String? ?? '',
      role: UserRole.fromStorage(data['role'] as String?),
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      disabled: data['disabled'] as bool? ?? false,
      maxDevices: data['maxDevices'] as int? ?? 2,
      canToggleCameraPublic: data['canToggleCameraPublic'] as bool? ?? true,
      publicToggleBlockedReason:
          data['publicToggleBlockedReason'] as String?,
      createdBy: data['createdBy'] as String?,
      createdAt: _tsToDate(data['createdAt']),
      lastLoginAt: _tsToDate(data['lastLoginAt']),
    );
  }

  static DateTime? _tsToDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  AppUser copyWith({
    String? email,
    String? displayName,
    UserRole? role,
    bool? mustChangePassword,
    bool? disabled,
    int? maxDevices,
    bool? canToggleCameraPublic,
    String? publicToggleBlockedReason,
    bool clearPublicToggleBlockedReason = false,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      disabled: disabled ?? this.disabled,
      maxDevices: maxDevices ?? this.maxDevices,
      canToggleCameraPublic:
          canToggleCameraPublic ?? this.canToggleCameraPublic,
      publicToggleBlockedReason: clearPublicToggleBlockedReason
          ? null
          : (publicToggleBlockedReason ?? this.publicToggleBlockedReason),
      createdBy: createdBy,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
