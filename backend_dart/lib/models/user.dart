import 'firestore_model.dart';

/// A registered user of the SafeShell application.
class User extends FirestoreModel {
  String email;
  String? password;
  String name;
  String role;
  String subscriptionStatus;
  DateTime? subscriptionExpiry;
  String? calculatorPassword;
  bool isSuspended;
  String? deviceToken;
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
    this.calculatorPassword,
    this.isSuspended = false,
    this.deviceToken,
    this.resetOtp,
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
        'calculatorPassword': calculatorPassword,
        'isSuspended': isSuspended,
        'deviceToken': deviceToken,
        'resetOtp': resetOtp,
        'resetOtp': resetOtp,
        'resetOtpExpire': resetOtpExpire?.toIso8601String(),
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
      calculatorPassword: map['calculatorPassword'] as String?,
      isSuspended: map['isSuspended'] as bool? ?? false,
      deviceToken: map['deviceToken'] as String?,
      deviceToken: map['deviceToken'] as String?,
      resetOtp: map['resetOtp'] as String?,
      resetOtpExpire: FirestoreModel.parseDate(map['resetOtpExpire']),
      userKey: map['userKey'] as String?,
    );
    user.populateFromMap(map);
    return user;
  }
}

/// Global repository for [User] documents.
final userRepo = ModelRepository<User>('users', User.fromMap);
