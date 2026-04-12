import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo completo de usuario para Orbit
/// Incluye campos de perfil, seguridad y metadata
class OrbitUser {
  final String uid;
  final String? fullName;
  final String? email;
  final bool emailVerified;
  final String? phoneNumber;
  final String? photoUrl;
  final String? documentType;
  final String? documentNumber;
  final String? country;
  final String? city;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;
  final bool mfaEnabled;
  final String? preferredMfaMethod; // 'totp', 'email', 'sms'
  final int loginAttempts;
  final DateTime? lockedUntil;

  OrbitUser({
    required this.uid,
    this.fullName,
    this.email,
    this.emailVerified = false,
    this.phoneNumber,
    this.photoUrl,
    this.documentType,
    this.documentNumber,
    this.country,
    this.city,
    this.bio,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
    this.mfaEnabled = false,
    this.preferredMfaMethod,
    this.loginAttempts = 0,
    this.lockedUntil,
  });

  /// Convierte el modelo a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      'emailVerified': emailVerified,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'country': country,
      'city': city,
      'bio': bio,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastLoginAt': lastLoginAt,
      'mfaEnabled': mfaEnabled,
      'preferredMfaMethod': preferredMfaMethod,
      'loginAttempts': loginAttempts,
      'lockedUntil': lockedUntil,
    };
  }

  /// Crea OrbitUser desde Firestore
  factory OrbitUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) throw Exception('Documento vacío');

    return OrbitUser(
      uid: doc.id,
      fullName: data['fullName'] as String?,
      email: data['email'] as String?,
      emailVerified: data['emailVerified'] as bool? ?? false,
      phoneNumber: data['phoneNumber'] as String?,
      photoUrl: data['photoUrl'] as String?,
      documentType: data['documentType'] as String?,
      documentNumber: data['documentNumber'] as String?,
      country: data['country'] as String?,
      city: data['city'] as String?,
      bio: data['bio'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      lastLoginAt: (data['lastLoginAt'] as Timestamp?)?.toDate(),
      mfaEnabled: data['mfaEnabled'] as bool? ?? false,
      preferredMfaMethod: data['preferredMfaMethod'] as String?,
      loginAttempts: data['loginAttempts'] as int? ?? 0,
      lockedUntil: (data['lockedUntil'] as Timestamp?)?.toDate(),
    );
  }

  /// Crea copia con campos modificados
  OrbitUser copyWith({
    String? uid,
    String? fullName,
    String? email,
    bool? emailVerified,
    String? phoneNumber,
    String? photoUrl,
    String? documentType,
    String? documentNumber,
    String? country,
    String? city,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
    bool? mfaEnabled,
    String? preferredMfaMethod,
    int? loginAttempts,
    DateTime? lockedUntil,
  }) {
    return OrbitUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      country: country ?? this.country,
      city: city ?? this.city,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      preferredMfaMethod: preferredMfaMethod ?? this.preferredMfaMethod,
      loginAttempts: loginAttempts ?? this.loginAttempts,
      lockedUntil: lockedUntil ?? this.lockedUntil,
    );
  }

  /// Verifica si la cuenta está bloqueada
  bool get isAccountLocked {
    if (lockedUntil == null) return false;
    return DateTime.now().isBefore(lockedUntil!);
  }

  /// Calcula si requiere MFA
  bool get requiresMfa => mfaEnabled;

  @override
  String toString() {
    return 'OrbitUser(uid: $uid, fullName: $fullName, email: $email, mfaEnabled: $mfaEnabled)';
  }
}
