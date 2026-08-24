import 'package:flutter/material.dart';

import '../core/theme/app_tokens.dart';
import '../models/models.dart';

class TimelineItem extends StatelessWidget {
  const TimelineItem({super.key, required this.event, this.isLast = false});

  final TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(event.icon, size: 16, color: Colors.white),
              ),
              if (!isLast)
                Expanded(child: Container(width: 1, color: AppColors.border)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(event.title, style: AppTypography.label),
                    ),
                    Text(
                      event.time,
                      style: AppTypography.meta.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  event.description,
                  style: AppTypography.body.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
