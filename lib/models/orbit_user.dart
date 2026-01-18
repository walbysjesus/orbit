class OrbitUser {
  final String uid;
  final String? fullName;
  final String? email;

  OrbitUser({
    required this.uid,
    this.fullName,
    this.email,
  });

  OrbitUser copyWith({
    String? uid,
    String? fullName,
    String? email,
  }) {
    return OrbitUser(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
    );
  }
}
