import 'package:flutter/material.dart';
import '../utils/deadline_helper.dart';

class StatusChip extends StatelessWidget {
  final DeadlineStatus status;
  final String? customLabel;
  final double fontSize;
  const StatusChip({super.key, required this.status, this.customLabel, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: DeadlineHelper.bgForStatus(status),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: DeadlineHelper.colorForStatus(status).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(DeadlineHelper.iconForStatus(status), size: 12, color: DeadlineHelper.colorForStatus(status)),
          const SizedBox(width: 4),
          Text(
            customLabel ?? DeadlineHelper.labelForStatus(status),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: DeadlineHelper.colorForStatus(status)),
          ),
        ],
      ),
    );
  }
}
