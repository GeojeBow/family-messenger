import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/models.dart';
import '../theme.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool tail;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.tail,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(message.createdAt);
    final metaColor = mine ? AppColors.outMeta : AppColors.inMeta;
    const r = Radius.circular(16);
    const small = Radius.circular(4);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: !mine && tail ? small : r,
      bottomRight: mine && tail ? small : r,
    );
    final meta = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(time, style: TextStyle(fontSize: 11.5, color: metaColor)),
        if (mine) ...[
          const SizedBox(width: 3),
          Icon(message.readAt != null ? Icons.done_all : Icons.done,
              size: 15, color: metaColor),
        ],
      ],
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
        child: Container(
          margin: EdgeInsets.only(
              left: mine ? 60 : 8,
              right: mine ? 8 : 60,
              top: 1.5,
              bottom: tail ? 5 : 1.5),
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 5),
          decoration: BoxDecoration(
            color: mine ? AppColors.outBubble : AppColors.inBubble,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 1,
                  offset: Offset(0, 1)),
            ],
          ),
          // Lay the time out on the last line when it fits, like the classic look.
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 8,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.3,
                  color: message.failed ? Colors.black45 : Colors.black87,
                  fontStyle:
                      message.failed ? FontStyle.italic : FontStyle.normal,
                ),
              ),
              Padding(padding: const EdgeInsets.only(top: 4), child: meta),
            ],
          ),
        ),
      ),
    );
  }
}
