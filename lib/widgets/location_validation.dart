import 'dart:async';

import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';
import 'app_button.dart';

enum LocationCheckState { checking, verified, outside, unavailable }

class LocationValidationScreen extends StatefulWidget {
  const LocationValidationScreen({
    super.key,
    this.site = 'Cairo Central Site',
    this.initialState = LocationCheckState.checking,
  });

  final String site;
  final LocationCheckState initialState;

  @override
  State<LocationValidationScreen> createState() =>
      _LocationValidationScreenState();
}

class _LocationValidationScreenState extends State<LocationValidationScreen> {
  late LocationCheckState state = widget.initialState;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    if (state == LocationCheckState.checking) _finishCheck();
  }

  void _finishCheck() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => state = LocationCheckState.verified);
    });
  }

  void _retry() {
    setState(() => state = LocationCheckState.checking);
    _finishCheck();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Location Validation', 'التحقق من الموقع')),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: [
        LocationValidationPanel(state: state, site: widget.site),
        const SizedBox(height: 18),
        _LocationActions(
          state: state,
          onContinue: () => Navigator.maybePop(context),
          onRetry: _retry,
          onBack: () => Navigator.maybePop(context),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr('MOCK STATE PREVIEW', 'معاينة حالة محاكاة'),
          style: AppTypography.meta.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: LocationCheckState.values
              .map(
                (value) => ChoiceChip(
                  selected: state == value,
                  label: Text(_stateLabel(context, value)),
                  onSelected: (_) {
                    timer?.cancel();
                    setState(() => state = value);
                    if (value == LocationCheckState.checking) _finishCheck();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'Simulation only • No GPS or map access',
            'محاكاة فقط • دون الوصول إلى GPS أو الخرائط',
          ),
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    ),
  );
}

class LocationValidationView extends StatefulWidget {
  const LocationValidationView({super.key, this.holdMode = false});
  final bool holdMode;

  @override
  State<LocationValidationView> createState() => _LocationValidationViewState();
}

class _LocationValidationViewState extends State<LocationValidationView> {
  LocationCheckState state = LocationCheckState.checking;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => state = LocationCheckState.verified);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LocationValidationPanel(state: state),
      if (widget.holdMode) ...[
        const SizedBox(height: 12),
        Text(
          context.tr(
            'This mock location will be recorded with the hold action.',
            'سيتم تسجيل هذا الموقع المحاكى مع إجراء التعليق.',
          ),
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    ],
  );
}

class LocationValidationPanel extends StatelessWidget {
  const LocationValidationPanel({
    super.key,
    required this.state,
    this.site = 'Cairo Central Site',
  });
  final LocationCheckState state;
  final String site;

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      LocationCheckState.checking => AppColors.info,
      LocationCheckState.verified => AppColors.success,
      LocationCheckState.outside => AppColors.error,
      LocationCheckState.unavailable => AppColors.muted,
    };
    final icon = switch (state) {
      LocationCheckState.checking => Icons.location_searching,
      LocationCheckState.verified => Icons.verified_outlined,
      LocationCheckState.outside => Icons.wrong_location_outlined,
      LocationCheckState.unavailable => Icons.location_disabled_outlined,
    };
    final title = switch (state) {
      LocationCheckState.checking => context.tr(
        'Checking your location…',
        'جارٍ التحقق من موقعك…',
      ),
      LocationCheckState.verified => context.tr(
        'Location Verified',
        'تم التحقق من الموقع',
      ),
      LocationCheckState.outside => context.tr(
        'Outside Permitted Area',
        'خارج النطاق المسموح',
      ),
      LocationCheckState.unavailable => context.tr(
        'Location Unavailable',
        'الموقع غير متاح',
      ),
    };
    final message = switch (state) {
      LocationCheckState.checking => context.tr(
        'Comparing your mock coordinates with the site.',
        'تتم مقارنة إحداثياتك المحاكاة بالموقع.',
      ),
      LocationCheckState.verified => context.tr(
        'You are inside the permitted site area.',
        'أنت داخل نطاق الموقع المسموح.',
      ),
      LocationCheckState.outside => context.tr(
        'You must be within the permitted site area to continue.',
        'يجب أن تكون داخل نطاق الموقع المسموح للمتابعة.',
      ),
      LocationCheckState.unavailable => context.tr(
        'We could not determine your simulated location.',
        'تعذر تحديد موقعك المحاكى.',
      ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: color.withValues(alpha: .28)),
          ),
          child: Column(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: state == LocationCheckState.checking
                    ? Padding(
                        padding: const EdgeInsets.all(25),
                        child: CircularProgressIndicator(
                          color: color,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(icon, color: color, size: 45),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTypography.title.copyWith(color: color),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: AppTypography.body.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LocationInformationCard(state: state, site: site),
        if (state == LocationCheckState.unavailable) ...[
          const SizedBox(height: 13),
          _ReasonItem(
            text: context.tr(
              'Location permission unavailable',
              'إذن الموقع غير متاح',
            ),
          ),
          _ReasonItem(text: context.tr('GPS disabled', 'خدمة GPS معطلة')),
          _ReasonItem(
            text: context.tr(
              'Unable to determine location',
              'تعذر تحديد الموقع',
            ),
          ),
        ],
      ],
    );
  }
}

class _LocationInformationCard extends StatelessWidget {
  const _LocationInformationCard({required this.state, required this.site});
  final LocationCheckState state;
  final String site;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppRadius.card),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        _DataRow(label: context.tr('Site', 'الموقع'), value: site),
        _DataRow(
          label: context.tr('Site Coordinates', 'إحداثيات الموقع'),
          value: '30.0444, 31.2357',
        ),
        _DataRow(
          label: context.tr('Engineer Coordinates', 'إحداثيات المهندس'),
          value: state == LocationCheckState.unavailable
              ? '—'
              : '30.0441, 31.2354',
        ),
        _DataRow(
          label: context.tr('Allowed Radius', 'النطاق المسموح'),
          value: context.tr('100 meters', '100 متر'),
        ),
        _DataRow(
          label: state == LocationCheckState.outside
              ? context.tr('Distance from Site', 'المسافة من الموقع')
              : context.tr('Distance', 'المسافة'),
          value: switch (state) {
            LocationCheckState.checking => context.tr(
              'Calculating…',
              'جارٍ الحساب…',
            ),
            LocationCheckState.verified => context.tr('42 meters', '42 مترًا'),
            LocationCheckState.outside => context.tr('265 meters', '265 مترًا'),
            LocationCheckState.unavailable => '—',
          },
          last: true,
        ),
      ],
    ),
  );
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value, this.last = false});
  final String label, value;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: AppColors.border)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: AppTypography.label,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    ),
  );
}

class _ReasonItem extends StatelessWidget {
  const _ReasonItem({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 7, color: AppColors.muted),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
        ),
      ],
    ),
  );
}

class _LocationActions extends StatelessWidget {
  const _LocationActions({
    required this.state,
    required this.onContinue,
    required this.onRetry,
    required this.onBack,
  });
  final LocationCheckState state;
  final VoidCallback onContinue, onRetry, onBack;

  @override
  Widget build(BuildContext context) => switch (state) {
    LocationCheckState.checking => const SizedBox.shrink(),
    LocationCheckState.verified => AppButton(
      label: context.tr('Continue', 'متابعة'),
      icon: Icons.arrow_forward,
      expanded: true,
      onPressed: onContinue,
    ),
    LocationCheckState.outside || LocationCheckState.unavailable => Row(
      children: [
        Expanded(
          child: AppButton(
            label: state == LocationCheckState.outside
                ? context.tr('Back', 'رجوع')
                : context.tr('Cancel', 'إلغاء'),
            icon: Icons.arrow_back,
            style: AppButtonStyle.outline,
            expanded: true,
            onPressed: onBack,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: AppButton(
            label: state == LocationCheckState.outside
                ? context.tr('Retry Location', 'إعادة فحص الموقع')
                : context.tr('Retry', 'إعادة المحاولة'),
            icon: Icons.refresh,
            expanded: true,
            onPressed: onRetry,
          ),
        ),
      ],
    ),
  };
}

class MiniLocationCard extends StatelessWidget {
  const MiniLocationCard({
    super.key,
    this.site = 'Cairo Central Site',
    this.distance = '42 m',
    this.status = LocationCheckState.verified,
    this.onTap,
  });
  final String site, distance;
  final LocationCheckState status;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final verified = status == LocationCheckState.verified;
    final color = verified ? AppColors.success : AppColors.error;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(AppRadius.control),
          border: Border.all(color: color.withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                verified ? Icons.location_on : Icons.wrong_location,
                color: color,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    site,
                    style: AppTypography.label,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${context.tr('Distance', 'المسافة')}: $distance',
                    style: AppTypography.meta.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                verified
                    ? context.tr('Inside', 'داخل النطاق')
                    : context.tr('Outside', 'خارج النطاق'),
                style: AppTypography.meta.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _stateLabel(BuildContext context, LocationCheckState state) =>
    switch (state) {
      LocationCheckState.checking => context.tr('Checking', 'جارٍ التحقق'),
      LocationCheckState.verified => context.tr('Verified', 'تم التحقق'),
      LocationCheckState.outside => context.tr('Outside', 'خارج النطاق'),
      LocationCheckState.unavailable => context.tr('Unavailable', 'غير متاح'),
    };
