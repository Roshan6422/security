import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../middleware/admin_middleware.dart';
import '../config/firebase.dart';
import '../models/user.dart';
import '../models/payment.dart';
import '../models/support_ticket.dart';
import '../models/vault_item.dart';

/// In-memory bank settings store (persisted to Firestore when available).
Map<String, dynamic> _bankSettings = {
  'bankName': '',
  'accountHolder': '',
  'accountNumber': '',
  'branch': '',
  'swiftCode': '',
};

/// Builds the `/api/admin` router.
///
/// All routes require authentication **and** admin role, applied externally
/// when mounting via [adminPipeline].
Router adminRouter() {
  final router = Router();

  // GET /stats
  router.get('/stats', (Request request) async {
    try {
      final users = await userRepo.find();
      final payments = await paymentRepo.find();
      final tickets = await supportTicketRepo.find();

      final totalUsers = users.length;
      final totalRevenue = payments.fold<double>(0, (acc, p) => acc + (p.amount as num).toDouble());
      final activeTickets = tickets.where((t) => t.status == 'open').length;

      // Combine for recent activity
      final recentUsers = users.length > 5 
          ? users.sublist(users.length - 5) 
          : users;
      final recentPayments = payments.length > 5 
          ? payments.sublist(payments.length - 5) 
          : payments;

      final activity = [
        ...recentUsers.map((u) => {
          'type': 'user',
          'title': 'New user: ${u.name}',
          'date': u.createdAt?.toIso8601String()
        }),
        ...recentPayments.map((p) => {
          'type': 'payment',
          'title': 'New payment: \$${p.amount}',
          'date': p.date.toIso8601String()
        }),
      ]..sort((a, b) => b['date'].toString().compareTo(a['date'].toString()));

      return Response.ok(
          jsonEncode({
            'totalUsers': totalUsers,
            'totalRevenue': totalRevenue,
            'activeTickets': activeTickets,
            'recentActivity': activity.take(10).toList(),
            'payments': payments.map((p) => p.toJson()).toList(), // Still return payments for chart calculation for now
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      print('Stats error: \$e');
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /users
  router.get('/users', (Request request) async {
    try {
      final users = await userRepo.find();
      return Response.ok(
          jsonEncode(users.map((u) {
            final json = u.toJson();
            json.remove('password');
            return json;
          }).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /payments
  router.get('/payments', (Request request) async {
    try {
      final payments = await paymentRepo.find();
      final users = await userRepo.find();
      final userMap = {for (var u in users) u.id: u};

      return Response.ok(
          jsonEncode(payments.map((p) {
            final json = p.toJson();
            final u = userMap[p.user];
            if (u != null) {
              json['user'] = {
                '_id': u.id,
                'name': u.name,
                'email': u.email,
              };
            }
            return json;
          }).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET /tickets
  router.get('/tickets', (Request request) async {
    try {
      final tickets = await supportTicketRepo.find();
      // Fetch users efficiently - only once
      final users = await userRepo.find();
      final userMap = {for (var u in users) u.id: u};

      return Response.ok(
          jsonEncode(tickets.map((t) {
            final json = t.toJson();
            final u = userMap[t.user];
            if (u != null) {
              json['user'] = {
                '_id': u.id,
                'name': u.name,
                'email': u.email,
              };
            }
            return json;
          }).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /tickets/<id>/reply
  router.post('/tickets/<id>/reply',
      (Request request, String id) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final ticket = await supportTicketRepo.findById(id);
      if (ticket == null) {
        return Response(404,
            body: jsonEncode({'message': 'Ticket not found'}),
            headers: {'content-type': 'application/json'});
      }

      ticket.replies = [
        ...ticket.replies,
        TicketReply(
          sender: 'admin',
          message: body['message'] as String? ?? '',
          date: DateTime.now(),
        ),
      ];
      await ticket.save();

      return Response.ok(jsonEncode(ticket.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PATCH /tickets/<id>/status
  router.patch('/tickets/<id>/status',
      (Request request, String id) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final ticket = await supportTicketRepo.findById(id);
      if (ticket == null) {
        return Response(404,
            body: jsonEncode({'message': 'Ticket not found'}),
            headers: {'content-type': 'application/json'});
      }

      ticket.status = body['status'] as String? ?? ticket.status;
      await ticket.save();

      return Response.ok(jsonEncode(ticket.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // DELETE /users/<id>
  router.delete('/users/<id>',
      (Request request, String id) async {
    try {
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      // Cascade delete
      await vaultItemRepo.deleteMany({'user': id});
      await paymentRepo.deleteMany({'user': id});
      await supportTicketRepo.deleteMany({'user': id});
      await user.deleteOne();

      return Response.ok(
          jsonEncode({'message': 'User deleted successfully'}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PATCH /users/<id>/status
  router.patch('/users/<id>/status',
      (Request request, String id) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      if (body['isSuspended'] != null) {
        user.isSuspended = body['isSuspended'] as bool;
      }
      await user.save();

      return Response.ok(
          jsonEncode({'message': 'User status updated', 'user': user.toJson()}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PATCH /users/<id>/subscription
  router.patch('/users/<id>/subscription',
      (Request request, String id) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.subscriptionStatus =
          body['subscriptionStatus'] as String? ?? user.subscriptionStatus;
      await user.save();

      return Response.ok(
          jsonEncode({
            'message': 'Subscription updated',
            'user': user.toJson(),
          }),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PATCH /users/<id>/role
  router.patch('/users/<id>/role',
      (Request request, String id) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.role = body['role'] as String? ?? user.role;
      await user.save();

      return Response.ok(
          jsonEncode({'message': 'Role updated', 'user': user.toJson()}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PUT /users/<id>/block
  router.put('/users/<id>/block',
      (Request request, String id) async {
    try {
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.isSuspended = true;
      await user.save();

      return Response.ok(
          jsonEncode({'message': 'User blocked', 'user': user.toJson()}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // PUT /users/<id>/activate
  router.put('/users/<id>/activate',
      (Request request, String id) async {
    try {
      final user = await userRepo.findById(id);
      if (user == null) {
        return Response(404,
            body: jsonEncode({'message': 'User not found'}),
            headers: {'content-type': 'application/json'});
      }

      user.isSuspended = false;
      await user.save();

      return Response.ok(
          jsonEncode({'message': 'User activated', 'user': user.toJson()}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // POST /notify
  router.post('/notify', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;
      final title = body['title'] as String? ?? '';
      final message = body['body'] as String? ?? body['message'] as String? ?? '';
      final userId = body['userId'] as String?;

      print('[ADMIN] Sending notification: title=$title, message=$message, userId=$userId');

      return Response.ok(
          jsonEncode({'message': 'Notification sent', 'title': title}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // ── Bank Account Settings (in-memory fallback) ───────────────────
  // A simple key-value store for admin settings.
  // In production with Firebase, this persists to a 'settings' document.

  router.get('/bank-settings', (Request request) async {
    try {
      // Try to load from Firestore first
      final db = FirebaseConfig.db;
      if (db != null) {
        final doc = await db.collection('settings').doc('bank_account').get();
        if (doc.exists) {
          return Response.ok(jsonEncode(doc.data),
              headers: {'content-type': 'application/json'});
        }
      }

      // Fallback: return from in-memory store
      return Response.ok(jsonEncode(_bankSettings),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response.ok(jsonEncode(_bankSettings),
          headers: {'content-type': 'application/json'});
    }
  });

  router.post('/bank-settings', (Request request) async {
    try {
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final settings = {
        'bankName': body['bankName'] ?? '',
        'accountHolder': body['accountHolder'] ?? '',
        'accountNumber': body['accountNumber'] ?? '',
        'branch': body['branch'] ?? '',
        'swiftCode': body['swiftCode'] ?? '',
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Save to Firestore if available
      final db = FirebaseConfig.db;
      if (db != null) {
        await db.collection('settings').doc('bank_account').set(settings);
      }

      // Always update in-memory
      _bankSettings = settings;

      return Response.ok(
          jsonEncode({'message': 'Bank settings saved successfully', ...settings}),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Failed to save bank settings: $e'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

/// Creates a [Handler] for admin routes with auth + admin middleware applied.
Handler adminHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addMiddleware(adminMiddleware())
      .addHandler(adminRouter().call);
}
