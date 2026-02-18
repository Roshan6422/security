import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../middleware/auth_middleware.dart';
import '../models/support_ticket.dart';

/// Builds the `/api/support` router.
Router supportRouter() {
  final router = Router();

  // POST / — create ticket
  router.post('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final body =
          jsonDecode(await request.readAsString()) as Map<String, dynamic>;

      final ticket = await supportTicketRepo.create({
        'user': user.id!,
        'subject': body['subject'] ?? '',
        'message': body['message'] ?? '',
        'status': 'open',
        'replies': <Map<String, dynamic>>[],
      });

      return Response(201,
          body: jsonEncode(ticket.toJson()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  // GET / — get user's tickets
  router.get('/', (Request request) async {
    try {
      final user = getAuthUser(request);
      final tickets =
          await supportTicketRepo.find({'user': user.id!});
      return Response.ok(
          jsonEncode(tickets.map((t) => t.toJson()).toList()),
          headers: {'content-type': 'application/json'});
    } catch (e) {
      return Response(500,
          body: jsonEncode({'message': 'Server error'}),
          headers: {'content-type': 'application/json'});
    }
  });

  return router;
}

/// Creates a [Handler] for support routes.
Handler supportHandler() {
  return const Pipeline()
      .addMiddleware(authMiddleware())
      .addHandler(supportRouter().call);
}
