import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../widgets/glass_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class SupportDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const SupportDetailScreen({super.key, required this.ticket});

  @override
  State<SupportDetailScreen> createState() => _SupportDetailScreenState();
}

class _SupportDetailScreenState extends State<SupportDetailScreen> {
  final _messageController = TextEditingController();
  bool _isSending = false;
  late Stream<DocumentSnapshot> _ticketStream;

  @override
  void initState() {
    super.initState();
    _ticketStream = FirebaseFirestore.instance
        .collection('support_tickets')
        .doc(widget.ticket['id'])
        .snapshots();
  }

  Future<void> _sendReply() async {
    if (_messageController.text.trim().isEmpty) return;

    setState(() => _isSending = true);
    try {
      final reply = {
        'message': _messageController.text.trim(),
        'sender': 'user',
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FirebaseFirestore.instance
          .collection('support_tickets')
          .doc(widget.ticket['id'])
          .update({
        'replies': FieldValue.arrayUnion([reply]),
        'status': 'open', // Re-open if closed? Or keep open
      });

      _messageController.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.ticket['subject'] ?? 'Ticket Details', style: AppTextStyles.heading.copyWith(fontSize: 18)),
        leading: const BackButton(),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _ticketStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final replies = (data['replies'] as List?) ?? [];
          final originalMessage = data['message'] ?? '';
          final createdAt = data['createdAt'] ?? '';

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildMessageBubble(
                      message: originalMessage,
                      time: createdAt,
                      isUser: true,
                      isFirst: true,
                    ),
                    ...replies.map((r) => _buildMessageBubble(
                      message: r['message'],
                      time: r['createdAt'],
                      isUser: r['sender'] == 'user',
                    )),
                  ],
                ),
              ),
              _buildInputArea(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMessageBubble({
    required String message,
    required String time,
    required bool isUser,
    bool isFirst = false,
  }) {
    final date = DateTime.tryParse(time) ?? DateTime.now();
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
          border: Border.all(color: isUser ? AppColors.primary.withOpacity(0.2) : Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirst)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('ORIGINAL QUERY', style: TextStyle(color: AppColors.primary.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            Text(message, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm  •  MMM d').format(date),
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a reply...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendReply,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
