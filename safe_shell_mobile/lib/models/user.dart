class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? token;
  final String? recoveryKey;
  String? userKey;
  final String? subscriptionStatus;
  final String? subscriptionExpiry;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.token,
    this.recoveryKey,
    this.userKey,
    this.subscriptionStatus,
    this.subscriptionExpiry,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      token: json['token'],
      recoveryKey: json['recoveryKey'],
      userKey: json['userKey'],
      subscriptionStatus: json['subscriptionStatus'],
      subscriptionExpiry: json['subscriptionExpiry'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'role': role,
      'token': token,
      'recoveryKey': recoveryKey,
      'userKey': userKey,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionExpiry': subscriptionExpiry,
    };
  }
}
