import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<AppUser?> getByUid(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromDoc(doc);
  }

  Stream<AppUser?> watchByUid(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromDoc(doc);
    });
  }

  Stream<List<AppUser>> watchAll() {
    return _users
        .orderBy('displayName')
        .snapshots()
        .map((snap) => snap.docs.map(AppUser.fromDoc).toList());
  }

  Future<List<AppUser>> listForOwnerDropdown() async {
    final snap = await _users.orderBy('displayName').get();
    return snap.docs
        .map(AppUser.fromDoc)
        .where((u) => !u.isAdmin && !u.disabled)
        .toList();
  }

  Future<void> setMustChangePassword(String uid, bool value) async {
    await _users.doc(uid).update({'mustChangePassword': value});
  }

  Future<void> setDisabled(String uid, bool value) async {
    await _users.doc(uid).update({'disabled': value});
  }

  Future<void> setMaxDevices(String uid, int maxDevices) async {
    await _users.doc(uid).update({'maxDevices': maxDevices});
  }

  Future<void> updateLastLogin(String uid) async {
    await _users.doc(uid).update({'lastLoginAt': FieldValue.serverTimestamp()});
  }

  Future<void> clearMustChangePassword(String uid) async {
    await _users.doc(uid).update({'mustChangePassword': false});
  }
}
