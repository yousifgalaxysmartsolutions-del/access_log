import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/theme/app_tokens.dart';

Future<bool?> showMockIdentityVerification(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _IdentityVerificationDialog(),
  );
}

class _IdentityVerificationDialog extends StatefulWidget {
  const _IdentityVerificationDialog();

  @override
  State<_IdentityVerificationDialog> createState() =>
      _IdentityVerificationDialogState();
}

class _IdentityVerificationDialogState
    extends State<_IdentityVerificationDialog> {
  int state = 0;

  Future<void> _verify() async {
    setState(() => state = 1);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (mounted) setState(() => state = 2);
  }

  @override
  Widget build(BuildContext context) {
    final verified = state == 2;
    return AlertDialog(
      icon: Icon(
        verified ? Icons.verified_user_rounded : Icons.face_retouching_natural,
        color: verified ? AppColors.success : AppColors.orange,
        size: 34,
      ),
      title: Text(
        verified
            ? context.tr('Identity Verified', 'تم التحقق من الهوية')
            : context.tr('Identity Check Required', 'مطلوب التحقق من الهوية'),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              verified
                  ? context.tr(
                      'Your identity was confirmed successfully. You can continue working.',
                      'تم تأكيد هويتك بنجاح. يمكنك متابعة العمل.',
                    )
                  : context.tr(
                      'For device security, confirm that the registered engineer is using this phone.',
                      'لحماية الجهاز، أكد أن المهندس المسجل هو من يستخدم الهاتف.',
                    ),
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 190,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: verified ? AppColors.success : AppColors.orange,
                  width: 2,
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    verified ? Icons.person : Icons.face_6_outlined,
                    size: 92,
                    color: verified ? AppColors.success : Colors.white54,
                  ),
                  if (state == 1)
                    const CircularProgressIndicator(color: AppColors.orange),
                  PositionedDirectional(
                    bottom: 12,
                    start: 12,
                    end: 12,
                    child: Text(
                      state == 1
                          ? context.tr('Checking face...', 'جارٍ فحص الوجه...')
                          : verified
                          ? context.tr('Match confirmed', 'تم تأكيد التطابق')
                          : context.tr(
                              'Mock front camera preview',
                              'معاينة محاكاة للكاميرا الأمامية',
                            ),
                      textAlign: TextAlign.center,
                      style: AppTypography.meta.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.tr(
                'Prototype simulation only • No photo is captured',
                'محاكاة للنموذج فقط • لا يتم التقاط أي صورة',
              ),
              textAlign: TextAlign.center,
              style: AppTypography.meta.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        if (!verified && state == 0)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Remind Me Later', 'ذكّرني لاحقًا')),
          ),
        FilledButton.icon(
          onPressed: state == 1
              ? null
              : verified
              ? () => Navigator.pop(context, true)
              : _verify,
          icon: Icon(verified ? Icons.check : Icons.face),
          label: Text(
            verified
                ? context.tr('Continue', 'متابعة')
                : context.tr('Verify Now', 'تحقق الآن'),
          ),
        ),
      ],
    );
  }
}
