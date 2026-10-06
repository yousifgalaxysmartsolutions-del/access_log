import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../widgets/app_button.dart';
import '../../data/models/cap_form_models.dart';

/// Foreground, user-initiated capture only. No calls to CAP or background work.
class CapNativeFormCapture {
  static const maxEvidenceBytes = 16 * 1024 * 1024;

  /// Shared camera capture for form fields and action requirements.
  Future<CapFormEvidence?> capturePhoto() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (file == null) return null;
    if (await file.length() > maxEvidenceBytes) {
      throw const FormatException('Evidence exceeds 16 MB');
    }
    return CapFormEvidence(
      name: file.name,
      mimeType: file.mimeType ?? 'image/jpeg',
      bytes: await file.readAsBytes(),
    );
  }

  /// Shared foreground location retrieval for form fields and action requirements.
  Future<String> getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const FormatException('Location services disabled');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const FormatException('Location permission denied');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return '${position.latitude},${position.longitude}';
  }

  Future<CapFormAnswer?> capture(
    BuildContext context,
    CapFormQuestion q,
  ) async {
    CapFormEvidence? evidence;
    String? text;
    switch (q.type) {
      case CapQuestionType.image:
        evidence = await capturePhoto();
      case CapQuestionType.video:
        final picker = ImagePicker();
        final file = await picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(seconds: 30),
        );
        if (file == null) return null;
        if (await file.length() > maxEvidenceBytes) {
          throw const FormatException('Evidence exceeds 16 MB');
        }
        evidence = CapFormEvidence(
          name: file.name,
          mimeType: file.mimeType ?? 'video/mp4',
          bytes: await file.readAsBytes(),
        );
      case CapQuestionType.signature:
        evidence = await Navigator.of(context).push<CapFormEvidence>(
          MaterialPageRoute(builder: (_) => const CapSignatureScreen()),
        );
      case CapQuestionType.audio:
        evidence = await Navigator.of(context).push<CapFormEvidence>(
          MaterialPageRoute(builder: (_) => const _AudioScreen()),
        );
      case CapQuestionType.qr:
      case CapQuestionType.barcode:
        text = await Navigator.of(context).push<String>(
          MaterialPageRoute(builder: (_) => const _ScannerScreen()),
        );
      case CapQuestionType.location:
        text = await getCurrentLocation();
      default:
        return null;
    }
    if (evidence == null && text == null) return null;
    return CapFormAnswer(
      questionId: q.id,
      questionTypeId: q.typeId,
      text: text ?? '',
      evidence: evidence,
    );
  }
}

class CapSignatureScreen extends StatefulWidget {
  const CapSignatureScreen({super.key});
  @override
  State<CapSignatureScreen> createState() => _CapSignatureScreenState();
}

class _CapSignatureScreenState extends State<CapSignatureScreen> {
  final points = <Offset?>[];
  Size canvasSize = Size.zero;
  bool saving = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Signature', 'التوقيع'))),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(context.tr('Draw your signature below', 'ارسم توقيعك بالأسفل')),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: LayoutBuilder(
              builder: (context, constraints) {
                canvasSize = Size(constraints.maxWidth, constraints.maxHeight);
                return Semantics(
                  label: context.tr('Signature canvas', 'مساحة رسم التوقيع'),
                  child: ClipRect(
                    child: GestureDetector(
                      onPanStart: saving
                          ? null
                          : (d) => setState(() => points.add(d.localPosition)),
                      onPanUpdate: saving
                          ? null
                          : (d) => setState(() => points.add(d.localPosition)),
                      onPanEnd: saving
                          ? null
                          : (_) => setState(() => points.add(null)),
                      onPanCancel: saving
                          ? null
                          : () => setState(() => points.add(null)),
                      child: CustomPaint(
                        painter: _SignaturePainter(List.of(points)),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          TextButton(
            onPressed: saving ? null : () => setState(points.clear),
            child: Text(context.tr('Clear', 'مسح')),
          ),
          AppButton(
            label: context.tr('Use signature', 'اعتماد التوقيع'),
            loading: saving,
            onPressed: points.whereType<Offset>().length < 2
                ? null
                : () async {
                    setState(() => saving = true);
                    try {
                      final recorder = ui.PictureRecorder();
                      _SignaturePainter(
                        points,
                      ).paint(Canvas(recorder), canvasSize);
                      final picture = recorder.endRecording();
                      final image = await picture.toImage(
                        canvasSize.width.ceil(),
                        canvasSize.height.ceil(),
                      );
                      picture.dispose();
                      final bytes = await image.toByteData(
                        format: ui.ImageByteFormat.png,
                      );
                      image.dispose();
                      if (context.mounted && bytes != null) {
                        Navigator.pop(
                          context,
                          CapFormEvidence(
                            name: 'signature.png',
                            mimeType: 'image/png',
                            bytes: bytes.buffer.asUint8List(),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => saving = false);
                    }
                  },
          ),
        ],
      ),
    ),
  );
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);
  final List<Offset?> points;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    final pen = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1] != null && points[i] != null) {
        canvas.drawLine(points[i - 1]!, points[i]!, pen);
      }
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter oldDelegate) => true;
}

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();
  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  bool finished = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Scan code', 'مسح الكود'))),
    body: MobileScanner(
      errorBuilder: (context, error) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.tr(
              'Camera unavailable. Check camera permission or go back and enter the code manually.',
              'الكاميرا غير متاحة. راجع صلاحيتها أو ارجع وأدخل الكود يدويًا.',
            ),
          ),
        ),
      ),
      onDetect: (capture) {
        if (finished) return;
        final codes = capture.barcodes
            .map((b) => b.rawValue)
            .whereType<String>()
            .where((s) => s.isNotEmpty);
        if (codes.isEmpty) return;
        finished = true;
        Navigator.pop(context, codes.first);
      },
    ),
  );
}

class _AudioScreen extends StatefulWidget {
  const _AudioScreen();
  @override
  State<_AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<_AudioScreen>
    with WidgetsBindingObserver {
  final recorder = AudioRecorder();
  Directory? directory;
  String? path, error;
  bool recording = false, busy = false;
  Timer? limit;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && recording) unawaited(stop());
  }

  Future<void> stop() async {
    if (busy || !recording) return;
    setState(() => busy = true);
    limit?.cancel();
    try {
      path = await recorder.stop();
    } catch (_) {
      if (mounted) {
        error = context.tr('Unable to stop recording', 'تعذّر إيقاف التسجيل');
      }
    } finally {
      if (mounted) {
        setState(() {
          recording = false;
          busy = false;
        });
      }
    }
  }

  Future<void> cleanup() async {
    try {
      await recorder.dispose();
    } finally {
      final dir = directory;
      // Only this screen's newly-created temporary capture directory.
      if (dir != null && await dir.exists()) await dir.delete(recursive: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    limit?.cancel();
    unawaited(cleanup().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: Text(context.tr('Audio evidence', 'إثبات صوتي'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(recording ? Icons.mic : Icons.mic_none, size: 64),
            Text(
              recording
                  ? context.tr(
                      'Recording • maximum 60 seconds',
                      'جارٍ التسجيل • بحد أقصى ٦٠ ثانية',
                    )
                  : context.tr(
                      'Tap to record an audio answer',
                      'اضغط لتسجيل إجابة صوتية',
                    ),
            ),
            if (path != null) Text(context.tr('Audio recorded', 'تم التسجيل')),
            if (error != null)
              Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 20),
            AppButton(
              label: recording
                  ? context.tr('Stop', 'إيقاف')
                  : context.tr('Record', 'تسجيل'),
              loading: busy,
              onPressed: recording
                  ? stop
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        if (!await recorder.hasPermission()) {
                          if (context.mounted) {
                            error = context.tr(
                              'Microphone permission is required',
                              'يلزم السماح بالميكروفون',
                            );
                          }
                          return;
                        }
                        if (!mounted ||
                            WidgetsBinding.instance.lifecycleState !=
                                AppLifecycleState.resumed) {
                          return;
                        }
                        directory ??= await (await getTemporaryDirectory())
                            .createTemp('cap-form-audio-');
                        await recorder.start(
                          const RecordConfig(),
                          path: '${directory!.path}/answer.m4a',
                        );
                        if (!mounted ||
                            WidgetsBinding.instance.lifecycleState !=
                                AppLifecycleState.resumed) {
                          await recorder.stop();
                          return;
                        }
                        recording = true;
                        path = null;
                        limit = Timer(const Duration(seconds: 60), stop);
                      } catch (_) {
                        if (context.mounted) {
                          error = context.tr(
                            'Unable to record. Check microphone permission.',
                            'تعذّر التسجيل. راجع صلاحية الميكروفون.',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
            const SizedBox(height: 12),
            AppButton(
              label: context.tr('Use recording', 'اعتماد التسجيل'),
              onPressed: busy || recording || path == null
                  ? null
                  : () async {
                      setState(() => busy = true);
                      try {
                        final file = File(path!);
                        if (await file.length() >
                            CapNativeFormCapture.maxEvidenceBytes) {
                          throw const FormatException('Audio too large');
                        }
                        final evidence = CapFormEvidence(
                          name: 'answer.m4a',
                          mimeType: 'audio/mp4',
                          bytes: await file.readAsBytes(),
                        );
                        if (context.mounted) Navigator.pop(context, evidence);
                      } catch (_) {
                        if (context.mounted) {
                          error = context.tr(
                            'Unable to read recording',
                            'تعذّر قراءة التسجيل',
                          );
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
            ),
          ],
        ),
      ),
    ),
  );
}
