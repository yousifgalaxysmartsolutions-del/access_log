import 'package:flutter/material.dart';
import '../core/theme/app_tokens.dart';
import '../models/models.dart';

class AttachmentCard extends StatelessWidget {
  const AttachmentCard({super.key, required this.attachment});
  final AppAttachment attachment;
  @override
  Widget build(BuildContext context) {
    final color = switch (attachment.state) {
      AttachmentState.uploaded => AppColors.success,
      AttachmentState.uploading => AppColors.info,
      AttachmentState.failed => AppColors.error,
    };
    final icon = attachment.type == 'Image'
        ? Icons.image_outlined
        : attachment.type == 'PDF'
        ? Icons.picture_as_pdf_outlined
        : Icons.description_outlined;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label,
                ),
                Text(
                  '${attachment.type} • ${attachment.size}',
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (attachment.state == AttachmentState.uploading)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              attachment.state == AttachmentState.uploaded
                  ? Icons.check_circle
                  : Icons.error,
              color: color,
              size: 21,
            ),
        ],
      ),
    );
  }
}
