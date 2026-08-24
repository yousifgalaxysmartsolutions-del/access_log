import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import '../mock/mock_data.dart';
import 'app_button.dart';
import 'background_simulation_components.dart';

class MockEvidencePhoto {
  const MockEvidencePhoto({required this.id, required this.capturedAt});
  final int id;
  final DateTime capturedAt;
}

class PhotoCaptureScreen extends StatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen> {
  bool captured = false;
  bool flash = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 58, 12, 126),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: captured
                      ? [const Color(0xFF4A6572), const Color(0xFF16242D)]
                      : [const Color(0xFF343B40), const Color(0xFF111517)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.cell_tower,
                      color: Colors.white24,
                      size: 116,
                    ),
                  ),
                  if (!captured)
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white54),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  PositionedDirectional(
                    start: 14,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        captured
                            ? context.tr('MOCK PHOTO', 'صورة محاكاة')
                            : context.tr('CAMERA PREVIEW', 'معاينة الكاميرا'),
                        style: AppTypography.meta.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            top: 7,
            start: 8,
            child: IconButton.filledTonal(
              tooltip: context.tr('Close', 'إغلاق'),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
          PositionedDirectional(
            top: 7,
            end: 8,
            child: IconButton.filledTonal(
              tooltip: context.tr('Flash', 'الفلاش'),
              onPressed: captured ? null : () => setState(() => flash = !flash),
              icon: Icon(flash ? Icons.flash_on : Icons.flash_off),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: captured
                ? Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: context.tr('Retake', 'إعادة الالتقاط'),
                          icon: Icons.refresh,
                          style: AppButtonStyle.outline,
                          expanded: true,
                          onPressed: () => setState(() => captured = false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: AppButton(
                          label: context.tr('Use Photo', 'استخدام الصورة'),
                          icon: Icons.check,
                          expanded: true,
                          onPressed: () => Navigator.pop(
                            context,
                            MockEvidencePhoto(
                              id: DateTime.now().microsecondsSinceEpoch,
                              capturedAt: DateTime(2026, 8, 11, 10, 42),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Semantics(
                      button: true,
                      label: context.tr('Capture photo', 'التقاط صورة'),
                      child: InkWell(
                        onTap: () => setState(() => captured = true),
                        customBorder: const CircleBorder(),
                        child: Container(
                          width: 78,
                          height: 78,
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class MockPhotoPicker extends StatefulWidget {
  const MockPhotoPicker({
    super.key,
    required this.title,
    this.optional = false,
    this.initialPhotoCount = 0,
  });
  final String title;
  final bool optional;
  final int initialPhotoCount;

  @override
  State<MockPhotoPicker> createState() => _MockPhotoPickerState();
}

class _MockPhotoPickerState extends State<MockPhotoPicker> {
  late final List<MockEvidencePhoto> photos = List.generate(
    widget.initialPhotoCount,
    (index) => MockEvidencePhoto(
      id: index + 1,
      capturedAt: DateTime(2026, 8, 11, 10, 30 + index),
    ),
  );

  Future<void> _capture() async {
    final photo = await Navigator.push<MockEvidencePhoto>(
      context,
      MaterialPageRoute(builder: (_) => const PhotoCaptureScreen()),
    );
    if (photo != null && mounted) setState(() => photos.add(photo));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.photo_library_outlined,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: AppTypography.title),
                Text(
                  widget.optional
                      ? context.tr(
                          'Optional photo evidence',
                          'أدلة صور اختيارية',
                        )
                      : context.tr(
                          'Add 1–3 mock evidence photos',
                          'أضف 1–3 صور أدلة محاكاة',
                        ),
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (photos.isEmpty)
        _EmptyPhotoCollection(onAdd: _capture)
      else ...[
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.12,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: photos.length,
          itemBuilder: (_, index) => _PhotoThumbnail(
            index: index,
            onPreview: () => _preview(index),
            onDelete: () => setState(() => photos.removeAt(index)),
          ),
        ),
        if (photos.length < 3) ...[
          const SizedBox(height: 12),
          AppButton(
            label: context.tr('Add Photo', 'إضافة صورة'),
            icon: Icons.add_a_photo_outlined,
            style: AppButtonStyle.outline,
            expanded: true,
            onPressed: _capture,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          context.tr('Photo metadata', 'بيانات الصور'),
          style: AppTypography.section,
        ),
        const SizedBox(height: 8),
        ...List.generate(
          photos.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: EvidencePhotoCard(
              index: index + 1,
              site: 'CAI-CORE-014',
              interventionId: 'INT-260811-0064',
            ),
          ),
        ),
      ],
    ],
  );

  void _preview(int index) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 1.15,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF607D8B), Color(0xFF263238)],
                ),
              ),
              child: const Icon(
                Icons.cell_tower,
                color: Colors.white54,
                size: 90,
              ),
            ),
          ),
          ListTile(
            title: Text(
              context.tr(
                'Evidence Photo ${index + 1}',
                'صورة دليل ${index + 1}',
              ),
            ),
            subtitle: const Text('11 Aug 2026 • 10:42 AM\n30.0566, 31.3301'),
            trailing: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmptyPhotoCollection extends StatelessWidget {
  const _EmptyPhotoCollection({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onAdd,
    borderRadius: BorderRadius.circular(AppRadius.card),
    child: Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.orange),
        color: AppColors.orange.withValues(alpha: .04),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_a_photo_outlined,
            color: AppColors.orange,
            size: 44,
          ),
          const SizedBox(height: 10),
          Text(
            context.tr('Add Photo', 'إضافة صورة'),
            style: AppTypography.section,
          ),
          const SizedBox(height: 4),
          Text(
            context.tr('Opens simulated camera only', 'يفتح كاميرا محاكاة فقط'),
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.index,
    required this.onPreview,
    required this.onDelete,
  });
  final int index;
  final VoidCallback onPreview, onDelete;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      InkWell(
        onTap: onPreview,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF78909C), Color(0xFF263238)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.cell_tower, color: Colors.white54, size: 48),
        ),
      ),
      PositionedDirectional(
        top: 6,
        end: 6,
        child: IconButton.filled(
          visualDensity: VisualDensity.compact,
          tooltip: context.tr('Delete photo', 'حذف الصورة'),
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline, size: 18),
        ),
      ),
      PositionedDirectional(
        start: 8,
        bottom: 7,
        child: Text(
          context.tr('PHOTO ${index + 1}', 'صورة ${index + 1}'),
          style: AppTypography.meta.copyWith(color: Colors.white),
        ),
      ),
    ],
  );
}

enum MockUploadStatus { ready, uploading, uploaded, failed }

class _MockAttachment {
  const _MockAttachment(this.name, this.size, this.type, this.status);
  final String name, size, type;
  final MockUploadStatus status;

  _MockAttachment withStatus(MockUploadStatus value) =>
      _MockAttachment(name, size, type, value);
}

class AttachmentPickerView extends StatefulWidget {
  const AttachmentPickerView({super.key});

  @override
  State<AttachmentPickerView> createState() => _AttachmentPickerViewState();
}

class _AttachmentPickerViewState extends State<AttachmentPickerView> {
  List<_MockAttachment> files = const [
    _MockAttachment(
      'site_report.pdf',
      '2.4 MB',
      'PDF',
      MockUploadStatus.uploaded,
    ),
    _MockAttachment(
      'cabinet_photo.jpg',
      '1.8 MB',
      'IMAGE',
      MockUploadStatus.uploading,
    ),
    _MockAttachment(
      'test_readings.docx',
      '640 KB',
      'DOC',
      MockUploadStatus.failed,
    ),
  ];

  void _setStatus(int index, MockUploadStatus status) => setState(() {
    files = [...files]..[index] = files[index].withStatus(status);
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.attach_file, color: AppColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Attachments', 'المرفقات'),
                  style: AppTypography.title,
                ),
                Text(
                  context.tr(
                    'PDF, image and document • Mock only',
                    'PDF وصورة ومستند • محاكاة فقط',
                  ),
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      ...List.generate(
        files.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _AttachmentFileCard(
            file: files[index],
            onTap: () => _setStatus(
              index,
              files[index].status == MockUploadStatus.failed
                  ? MockUploadStatus.ready
                  : MockUploadStatus.uploaded,
            ),
          ),
        ),
      ),
      AppButton(
        label: context.tr('Add Mock Attachment', 'إضافة مرفق محاكى'),
        icon: Icons.add,
        style: AppButtonStyle.outline,
        expanded: true,
        onPressed: () => setState(
          () => files = [
            ...files,
            const _MockAttachment(
              'maintenance_note.docx',
              '320 KB',
              'DOC',
              MockUploadStatus.ready,
            ),
          ],
        ),
      ),
    ],
  );
}

class _AttachmentFileCard extends StatelessWidget {
  const _AttachmentFileCard({required this.file, required this.onTap});
  final _MockAttachment file;
  final VoidCallback onTap;

  Color get color => switch (file.status) {
    MockUploadStatus.uploaded => AppColors.success,
    MockUploadStatus.failed => AppColors.error,
    MockUploadStatus.uploading => AppColors.info,
    MockUploadStatus.ready => AppColors.orange,
  };

  @override
  Widget build(BuildContext context) {
    final label = switch (file.status) {
      MockUploadStatus.ready => context.tr('Ready', 'جاهز'),
      MockUploadStatus.uploading => context.tr('Uploading', 'جارٍ الرفع'),
      MockUploadStatus.uploaded => context.tr('Uploaded', 'تم الرفع'),
      MockUploadStatus.failed => context.tr(
        'Failed • Tap to retry',
        'فشل • اضغط للمحاولة',
      ),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: AppColors.border),
          color: Theme.of(context).cardColor,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                file.type == 'PDF'
                    ? Icons.picture_as_pdf_outlined
                    : file.type == 'IMAGE'
                    ? Icons.image_outlined
                    : Icons.description_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: AppTypography.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${file.type} • ${file.size}',
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                  if (file.status == MockUploadStatus.uploading) ...[
                    const SizedBox(height: 7),
                    LinearProgressIndicator(
                      value: .62,
                      minHeight: 4,
                      color: color,
                      backgroundColor: color.withValues(alpha: .12),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTypography.meta.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SignaturePadView extends StatefulWidget {
  const SignaturePadView({super.key});

  @override
  State<SignaturePadView> createState() => _SignaturePadViewState();
}

class _SignaturePadViewState extends State<SignaturePadView> {
  bool drawn = false;
  bool confirmed = false;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.draw_outlined, color: AppColors.orange),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('Engineer Signature', 'توقيع المهندس'),
                  style: AppTypography.title,
                ),
                Text(
                  context.tr('Simulated signature canvas', 'لوحة توقيع محاكاة'),
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      InkWell(
        onTap: confirmed ? null : () => setState(() => drawn = true),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          height: 240,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: confirmed
                  ? AppColors.success
                  : drawn
                  ? AppColors.orange
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 20,
                right: 20,
                bottom: 44,
                child: Container(height: 1, color: AppColors.border),
              ),
              Center(
                child: drawn
                    ? Text(
                        MockData.engineer.name,
                        style: TextStyle(
                          fontSize: 34,
                          fontStyle: FontStyle.italic,
                          color: Color(0xFF22304A),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.gesture,
                            color: AppColors.muted,
                            size: 46,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr(
                              'Tap canvas to draw mock signature',
                              'اضغط على اللوحة لرسم توقيع محاكى',
                            ),
                            style: AppTypography.meta.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
              ),
              if (confirmed)
                const PositionedDirectional(
                  top: 12,
                  end: 12,
                  child: Icon(Icons.verified, color: AppColors.success),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: AppButton(
              label: context.tr('Clear', 'مسح'),
              icon: Icons.refresh,
              style: AppButtonStyle.outline,
              expanded: true,
              onPressed: drawn
                  ? () => setState(() {
                      drawn = false;
                      confirmed = false;
                    })
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: AppButton(
              label: context.tr('Confirm Signature', 'تأكيد التوقيع'),
              icon: Icons.check,
              expanded: true,
              onPressed: drawn ? () => setState(() => confirmed = true) : null,
            ),
          ),
        ],
      ),
      if (confirmed) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: AppColors.success.withValues(alpha: .3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('Signature Captured', 'تم التقاط التوقيع'),
                      style: AppTypography.label,
                    ),
                    Text(
                      '11 Aug 2026 • 10:44 AM',
                      style: AppTypography.meta.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ],
  );
}
