import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../config/env.dart';
import '../config/firebase.dart';
import '../middleware/auth_middleware.dart';
import '../models/payment.dart';
import '../models/user.dart';

/// Builds the `/api/payment` router.
Router paymentRouter() {
  final router = Router();
  
  // Pipeline that requires authentication
  final protected = const Pipeline().addMiddleware(authMiddleware());

  // POST /generate-hash (protected)
  router.post('/generate-hash', protected.addHandler((Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final orderId = body['order_id'] as String?;
      final amount = body['amount']?.toString() ?? '0';
      final currency = body['currency'] as String? ?? 'LKR';

      if (orderId == null) {
        return Response(400,
            body: jsonEncode({'message': 'order_id is required'}),
            headers: {'content-type': 'application/json'});
      }

      final merchantId = Env.payhereMerchantId;
      final merchantSecret = Env.payhereMerchantSecret;
      final formattedAmount = double.parse(amount).toStringAsFixed(2);

      final secretHash = md5
          .convert(utf8.encode(merchantSecret))
          .toString()
          .toUpperCase();

      final hashString =
          '$merchantId$orderId$formattedAmount$currency$secretHash';

      final hash = md5
          .convert(utf8.encode(hashString))
          .toString()
          .toUpperCase();

      return Response.ok(
          jsonEncode({
            'merchant_id': merchantId,
            'hash': hash,
            'order_id': orderId,
            'amount': formattedAmount,
            'currency': currency,
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // GET /history (protected)
  router.get('/history', protected.addHandler((Request request) async {
    try {
      final user = getAuthUser(request);
      final payments = await paymentRepo.find({'user': user.id!});
      return Response.ok(
          jsonEncode(payments.map((p) => p.toJson()).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // GET /all (admin protected)
  // We'll just check admin role manually after auth
  router.get('/all', protected.addHandler((Request request) async {
    try {
      final user = getAuthUser(request);
      if (user.role != 'admin') {
         return Response(403,
            body: jsonEncode({'message': 'Not authorized as admin'}),
            headers: {'content-type': 'application/json'});
      }
      
      final payments = await paymentRepo.find();
      return Response.ok(
          jsonEncode(payments.map((p) => p.toJson()).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  }));

  // POST /notify — PayHere webhook (PUBLIC)
  router.post('/notify', (Request request) async {
    try {
      final rawBody = await request.readAsString();
      final params = Uri.splitQueryString(rawBody);

      final merchantId = params['merchant_id'] ?? '';
      final orderId = params['order_id'] ?? '';
      final payhereAmount = params['payhere_amount'] ?? '0';
      final payhereCurrency = params['payhere_currency'] ?? 'LKR';
      final statusCode = params['status_code'] ?? '';
      final md5sig = params['md5sig'] ?? '';
      final paymentId = params['payment_id'] ?? '';
      final method = params['method'] ?? '';
      final customField1 = params['custom_1'] ?? ''; // userId

      print('[PAYHERE] Notification received: orderId=$orderId, status=$statusCode');

      final merchantSecret = Env.payhereMerchantSecret;
      final localMd5Secret = md5
          .convert(utf8.encode(merchantSecret))
          .toString()
          .toUpperCase();
      final localSig = md5
          .convert(utf8.encode(
              '$merchantId$orderId$payhereAmount$payhereCurrency$statusCode$localMd5Secret'))
          .toString()
          .toUpperCase();

      if (localSig != md5sig.toUpperCase()) {
        print('[PAYHERE] ⚠️ Signature mismatch');
        return Response(400,
            body: jsonEncode({'message': 'Invalid signature'}),
            headers: {'content-type': 'application/json'});
      }

      final status = statusCode == '2' ? 'completed' : 'failed';

      await paymentRepo.create({
        'user': customField1,
        'amount': double.tryParse(payhereAmount) ?? 0,
        'currency': payhereCurrency,
        'status': status,
        'date': DateTime.now().toIso8601String(),
        'transactionId': paymentId,
        'paymentMethod': method,
        'plan': 'pro',
        'orderId': orderId,
      });

      if (status == 'completed' && customField1.isNotEmpty) {
        final user = await userRepo.findById(customField1);
        if (user != null) {
          user.subscriptionStatus = 'pro';
          user.subscriptionExpiry =
              DateTime.now().add(const Duration(days: 30));
          await user.save();
          print('[PAYHERE] ✅ User ${user.email} upgraded to pro');
        }
      }

      return Response.ok(jsonEncode({'message': 'OK'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('PayHere notify error: $e');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /bank-details (PUBLIC for mobile app)
  router.get('/bank-details', (Request request) async {
    try {
      final db = FirebaseConfig.db;
      if (db != null) {
        final doc = await db.collection('settings').doc('bank_account').get();
        if (doc.exists) {
          return Response.ok(jsonEncode(doc.data),
              headers: {'content-type': 'application/json'});
        }
      }
      return Response.ok(jsonEncode({
        'bankName': 'Not Set',
        'accountHolder': '',
        'accountNumber': '',
        'branch': '',
        'swiftCode': '',
      }), headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500, body: jsonEncode({'error': e.toString()}), headers: {'content-type': 'application/json'});
    }
  });

  // GET /success — PayHere redirect landing page
  router.get('/success', (Request request) {
    return Response.ok('''
      <!DOCTYPE html>
      <html>
        <head>
          <title>Payment Successful</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { background: #0f172a; color: white; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
            .card { background: #1e293b; padding: 2rem; border-radius: 1.5rem; border: 1px solid #334155; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
            .icon { font-size: 3rem; margin-bottom: 1rem; }
            h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
            p { color: #94a3b8; font-size: 0.9rem; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">✅</div>
            <h1>Payment Successful!</h1>
            <p>Your vault has been upgraded. You can now close this window.</p>
          </div>
        </body>
      </html>
    ''', headers: {'content-type': 'text/html'});
  });

  // GET /cancel — PayHere redirect landing page
  router.get('/cancel', (Request request) {
    return Response.ok('''
      <!DOCTYPE html>
      <html>
        <head>
          <title>Payment Cancelled</title>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            body { background: #0f172a; color: white; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; text-align: center; }
            .card { background: #1e293b; padding: 2rem; border-radius: 1.5rem; border: 1px solid #334155; box-shadow: 0 25px 50px -12px rgba(0,0,0,0.5); }
            .icon { font-size: 3rem; margin-bottom: 1rem; }
            h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
            p { color: #94a3b8; font-size: 0.9rem; }
          </style>
        </head>
        <body>
          <div class="card">
            <div class="icon">❌</div>
            <h1>Payment Cancelled</h1>
            <p>The transaction was not completed. You can try again from the app.</p>
          </div>
        </body>
      </html>
    ''', headers: {'content-type': 'text/html'});
  });

  return router;
}

/// Creates a [Handler] for payment routes.
Handler paymentHandler() {
  return const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(paymentRouter().call);
}
