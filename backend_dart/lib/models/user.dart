import 'firestore_model.dart';

/// A registered user of the SafeShell application.
class User extends FirestoreModel {
  String email;
  String? password;
  String name;
  String role;
  String subscriptionStatus;
  DateTime? subscriptionExpiry;
  String? recoveryKey;
  String? calculatorPassword;
  bool isSuspended;
  String? deviceToken;
  String? resetOtp;
  DateTime? resetOtpExpire;
  String? userKey;

  User({
    this.email = '',
    this.password,
    this.name = '',
    this.role = 'user',
    this.subscriptionStatus = 'free',
    this.subscriptionExpiry,
    this.recoveryKey,
    this.calculatorPassword,
    this.isSuspended = false,
    this.deviceToken,
    this.resetOtp,
    this.resetOtpExpire,
    this.userKey,
  });

  @override
  String get collectionName => 'users';

  @override
  Map<String, dynamic> toMap() => {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
        'subscriptionStatus': subscriptionStatus,
        'subscriptionExpiry': subscriptionExpiry?.toIso8601String(),
        'recoveryKey': recoveryKey,
        'calculatorPassword': calculatorPassword,
        'isSuspended': isSuspended,
        'deviceToken': deviceToken,
        'userKey': userKey,
      };

  /// Creates a [User] from a Firestore document map.
  factory User.fromMap(Map<String, dynamic> map) {
    final user = User(
      email: map['email'] as String? ?? '',
      password: map['password'] as String?,
      name: map['name'] as String? ?? '',
      role: map['role'] as String? ?? 'user',
      subscriptionStatus: map['subscriptionStatus'] as String? ?? 'free',
      subscriptionExpiry: FirestoreModel.parseDate(map['subscriptionExpiry']),
      recoveryKey: map['recoveryKey'] as String?,
      calculatorPassword: map['calculatorPassword'] as String?,
      isSuspended: map['isSuspended'] as bool? ?? false,
      deviceToken: map['deviceToken'] as String?,
      userKey: map['userKey'] as String?,
    );
    user.populateFromMap(map);
    return user;
  }
}

/// Global repository for [User] documents.
final userRepo = ModelRepository<User>('users', User.fromMap);
