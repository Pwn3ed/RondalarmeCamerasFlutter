import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../utils/password_generator.dart';

class AdminUserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<({String tempPassword, String uid})> createClient({
    required String email,
    required String displayName,
    int maxDevices = 2,
  }) async {
    final tempPassword = generateTempPassword();
    final adminUid = _auth.currentUser?.uid;
    if (adminUid == null) {
      throw Exception('Admin não autenticado');
    }

    final secondary = await Firebase.initializeApp(
      name: 'AdminUserCreator-${DateTime.now().millisecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secAuth = FirebaseAuth.instanceFor(app: secondary);
      final cred = await secAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: tempPassword,
      );

      final uid = cred.user!.uid;
      await _firestore.collection('users').doc(uid).set({
        'email': email.trim(),
        'displayName': displayName.trim(),
        'role': 'user',
        'mustChangePassword': true,
        'disabled': false,
        'maxDevices': maxDevices,
        'createdBy': adminUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await secAuth.signOut();
      return (tempPassword: tempPassword, uid: uid);
    } finally {
      await secondary.delete();
    }
  }
}
