import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../../core/localization/app_strings.dart';
import '../../../../widgets/app_button.dart';
import '../../data/models/cap_form_models.dart';

/// Image transformations run away from the main isolate; Crop owns its crop UI.
Uint8List rotatePhotoBytes(Uint8List bytes) {
  final image = img.decodeImage(bytes);
  if (image == null) throw const FormatException('Unable to read image');
  return img.encodeJpg(img.copyRotate(image, angle: 90), quality: 90);
}

class CapPhotoEditor extends StatefulWidget {
  const CapPhotoEditor({super.key, required this.photo});
  final CapFormEvidence photo;
  @override
  State<CapPhotoEditor> createState() => _CapPhotoEditorState();
}

class _CapPhotoEditorState extends State<CapPhotoEditor> {
  final crop = CropController();
  late Uint8List bytes = widget.photo.bytes;
  bool working = false, ready = false;
  int revision = 0;
  String? error;

  Future<void> rotate() async {
    setState(() {
      working = true;
      error = null;
    });
    try {
      final rotated = await compute(rotatePhotoBytes, bytes);
      if (!mounted) return;
      setState(() {
        bytes = rotated;
        revision++;
        ready = false;
      });
    } on Exception {
      if (mounted) {
        setState(
          () => error = context.tr(
            'Unable to rotate photo',
            'تعذّر تدوير الصورة',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !working,
    child: Scaffold(
      appBar: AppBar(title: Text(context.tr('Edit photo', 'تعديل الصورة'))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.tr(
                  'Drag the corners to crop. Rotate if needed.',
                  'اسحب الزوايا لقص الصورة، ويمكنك تدويرها عند الحاجة.',
                ),
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: working,
                child: Crop(
                  key: ValueKey(revision),
                  image: bytes,
                  controller: crop,
                  initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                    size: 1,
                  ),
                  progressIndicator: const Center(
                    child: CircularProgressIndicator(),
                  ),
                  onStatusChanged: (status) {
                    if (mounted) {
                      setState(() => ready = status == CropStatus.ready);
                    }
                  },
                  onCropped: (result) {
                    if (!mounted) return;
                    switch (result) {
                      case CropSuccess(:final croppedImage):
                        // The library returns the cropped image in its encoded format.
                        final png =
                            croppedImage.length >= 4 &&
                            croppedImage[0] == 0x89 &&
                            croppedImage[1] == 0x50;
                        Navigator.pop(
                          context,
                          CapFormEvidence(
                            name: png ? 'edited-photo.png' : 'edited-photo.jpg',
                            mimeType: png ? 'image/png' : 'image/jpeg',
                            bytes: croppedImage,
                          ),
                        );
                      case CropFailure():
                        setState(() {
                          working = false;
                          error = context.tr(
                            'Unable to crop photo',
                            'تعذّر قص الصورة',
                          );
                        });
                    }
                  },
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: working || !ready ? null : rotate,
                    icon: const Icon(Icons.rotate_right),
                    label: Text(context.tr('Rotate', 'تدوير')),
                  ),
                  AppButton(
                    label: context.tr('Use photo', 'استخدام الصورة'),
                    loading: working,
                    onPressed: !ready || working
                        ? null
                        : () {
                            setState(() => working = true);
                            crop.crop();
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
