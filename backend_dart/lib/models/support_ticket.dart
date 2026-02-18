import 'firestore_model.dart';

/// A single reply within a support ticket conversation.
class TicketReply {
  final String sender;
  final String message;
  final DateTime date;

  TicketReply({
    required this.sender,
    required this.message,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'sender': sender,
        'message': message,
        'date': date.toIso8601String(),
      };

  factory TicketReply.fromMap(Map<String, dynamic> map) => TicketReply(
        sender: map['sender'] as String? ?? 'user',
        message: map['message'] as String? ?? '',
        date: FirestoreModel.parseDate(map['date']) ?? DateTime.now(),
      );
}

/// A support ticket submitted by a user.
class SupportTicket extends FirestoreModel {
  String user;
  String subject;
  String message;
  String status;
  List<TicketReply> replies;

  SupportTicket({
    this.user = '',
    this.subject = '',
    this.message = '',
    this.status = 'open',
    this.replies = const [],
  });

  @override
  String get collectionName => 'supportTickets';

  @override
  Map<String, dynamic> toMap() => {
        'user': user,
        'subject': subject,
        'message': message,
        'status': status,
        'replies': replies.map((r) => r.toMap()).toList(),
      };

  /// Creates a [SupportTicket] from a Firestore document map.
  factory SupportTicket.fromMap(Map<String, dynamic> map) {
    final ticket = SupportTicket(
      user: map['user'] as String? ?? '',
      subject: map['subject'] as String? ?? '',
      message: map['message'] as String? ?? '',
      status: map['status'] as String? ?? 'open',
      replies: (map['replies'] as List<dynamic>?)
              ?.map((r) =>
                  TicketReply.fromMap(Map<String, dynamic>.from(r as Map)))
              .toList() ??
          [],
    );
    ticket.populateFromMap(map);
    return ticket;
  }
}

/// Global repository for [SupportTicket] documents.
final supportTicketRepo =
    ModelRepository<SupportTicket>('supportTickets', SupportTicket.fromMap);
