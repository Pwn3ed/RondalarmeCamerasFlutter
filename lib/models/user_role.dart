enum UserRole {
  admin,
  user;

  String get storageValue => name;

  static UserRole fromStorage(String? value) {
    if (value == 'admin') return UserRole.admin;
    return UserRole.user;
  }

  bool get isAdmin => this == UserRole.admin;
}
