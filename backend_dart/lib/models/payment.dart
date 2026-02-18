import 'firestore_model.dart';

/// A payment record, typically from a PayHere transaction.
class Payment extends FirestoreModel {
  String user;
  double amount;
  String currency;
  String status;
  DateTime? date;
  String? transactionId;
  String? paymentMethod;
  String? plan;
  String? orderId;

  Payment({
    this.user = '',
    this.amount = 0,
    this.currency = 'LKR',
    this.status = 'pending',
    this.date,
    this.transactionId,
    this.paymentMethod,
    this.plan,
    this.orderId,
  });

  @override
  String get collectionName => 'payments';

  @override
  Map<String, dynamic> toMap() => {
        'user': user,
        'amount': amount,
        'currency': currency,
        'status': status,
        'date': date?.toIso8601String(),
        'transactionId': transactionId,
        'paymentMethod': paymentMethod,
        'plan': plan,
        'orderId': orderId,
      };

  /// Creates a [Payment] from a Firestore document map.
  factory Payment.fromMap(Map<String, dynamic> map) {
    final payment = Payment(
      user: map['user'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      currency: map['currency'] as String? ?? 'LKR',
      status: map['status'] as String? ?? 'pending',
      date: FirestoreModel.parseDate(map['date']),
      transactionId: map['transactionId'] as String?,
      paymentMethod: map['paymentMethod'] as String?,
      plan: map['plan'] as String?,
      orderId: map['orderId'] as String?,
    );
    payment.populateFromMap(map);
    return payment;
  }
}

/// Global repository for [Payment] documents.
final paymentRepo = ModelRepository<Payment>('payments', Payment.fromMap);
