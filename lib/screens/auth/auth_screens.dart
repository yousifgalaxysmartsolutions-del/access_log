import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../core/localization/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../widgets/app_button.dart';

String _copy(BuildContext context, String en, String ar) =>
    context.strings.isArabic ? ar : en;

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.footer,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Stack(
        children: [
          PositionedDirectional(
            top: -110,
            end: -90,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange.withValues(alpha: .07),
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    if (showBack)
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    IconButton(
                      tooltip: AccessLogApp.of(context).isDark
                          ? _copy(context, 'Light mode', 'الوضع الفاتح')
                          : _copy(context, 'Dark mode', 'الوضع الليلي'),
                      onPressed: () => AccessLogApp.of(context).toggleTheme(),
                      icon: Icon(
                        AccessLogApp.of(context).isDark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => AccessLogApp.of(context).toggleLocale(),
                      icon: const Icon(Icons.language, size: 18),
                      label: Text(context.strings.t('language')),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _BrandMark(),
                          const SizedBox(height: 34),
                          Text(title, style: AppTypography.display),
                          const SizedBox(height: 9),
                          Text(
                            subtitle,
                            style: AppTypography.body.copyWith(
                              color: AppColors.muted,
                            ),
                          ),
                          const SizedBox(height: 30),
                          child,
                          if (footer != null) ...[
                            const SizedBox(height: 28),
                            footer!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .13),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            '+',
            style: TextStyle(
              color: AppColors.orange,
              fontSize: 39,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
      const SizedBox(width: 13),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Access Log+',
              style: AppTypography.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2),
            Text(
              'FIELD OPERATIONS',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.orange,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

enum LoginPreviewState { normal, invalid, inactive, unauthorized, loading }

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialPreview = LoginPreviewState.normal,
  });
  final LoginPreviewState initialPreview;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool obscure = true;
  bool remember = true;
  late LoginPreviewState preview = widget.initialPreview;

  String _stateLabel(LoginPreviewState state) => switch (state) {
    LoginPreviewState.normal => 'Default',
    LoginPreviewState.invalid => 'Invalid credentials',
    LoginPreviewState.inactive => 'Inactive user',
    LoginPreviewState.unauthorized => 'Unauthorized device',
    LoginPreviewState.loading => 'Loading',
  };

  Future<void> _login() async {
    if (preview == LoginPreviewState.loading) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }
    if (!mounted) return;
    if (preview == LoginPreviewState.normal ||
        preview == LoginPreviewState.loading) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    title: _copy(context, 'Welcome back', 'مرحباً بعودتك'),
    subtitle: _copy(
      context,
      'Sign in securely to manage your field assignments.',
      'سجّل الدخول بأمان لإدارة مهامك الميدانية.',
    ),
    footer: Column(
      children: [
        Text(
          'Access Log+  •  v1.0.0 (Prototype)',
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Text(
          '© 2026 Field Operations',
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (preview != LoginPreviewState.normal &&
            preview != LoginPreviewState.loading) ...[
          _LoginAlert(state: preview),
          const SizedBox(height: 16),
        ],
        TextField(
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: _copy(
              context,
              'Username or mobile number',
              'اسم المستخدم أو رقم الهاتف',
            ),
            hintText: 'e.g. omar.hassan',
            prefixIcon: const Icon(Icons.person_outline),
            errorText: preview == LoginPreviewState.invalid
                ? _copy(context, 'Check your username', 'تحقق من اسم المستخدم')
                : null,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          obscureText: obscure,
          onSubmitted: (_) => _login(),
          decoration: InputDecoration(
            labelText: _copy(context, 'Password', 'كلمة المرور'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: obscure ? 'Show password' : 'Hide password',
              onPressed: () => setState(() => obscure = !obscure),
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off,
              ),
            ),
            errorText: preview == LoginPreviewState.invalid
                ? _copy(context, 'Incorrect password', 'كلمة المرور غير صحيحة')
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: remember,
                  onChanged: (value) =>
                      setState(() => remember = value ?? false),
                ),
                Text(
                  _copy(context, 'Remember me', 'تذكرني'),
                  style: AppTypography.label,
                ),
              ],
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.forgotPassword),
              child: Text(
                _copy(context, 'Forgot password?', 'نسيت كلمة المرور؟'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppButton(
          label: _copy(context, 'Sign in', 'تسجيل الدخول'),
          icon: Icons.login,
          expanded: true,
          loading: preview == LoginPreviewState.loading,
          onPressed: _login,
        ),
        const SizedBox(height: 12),
        AppButton(
          label: _copy(context, 'Sign in with biometrics', 'الدخول بالبصمة'),
          icon: Icons.fingerprint,
          style: AppButtonStyle.outline,
          expanded: true,
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.home,
            (_) => false,
          ),
        ),
        const SizedBox(height: 24),
        _PreviewSelector(
          value: preview,
          labelFor: _stateLabel,
          onChanged: (value) => setState(() => preview = value),
        ),
      ],
    ),
  );
}

class _LoginAlert extends StatelessWidget {
  const _LoginAlert({required this.state});
  final LoginPreviewState state;
  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (state) {
      LoginPreviewState.invalid => (
        Icons.error_outline,
        _copy(context, 'Unable to sign in', 'تعذر تسجيل الدخول'),
        _copy(
          context,
          'The credentials you entered are incorrect.',
          'بيانات تسجيل الدخول التي أدخلتها غير صحيحة.',
        ),
      ),
      LoginPreviewState.inactive => (
        Icons.person_off_outlined,
        _copy(context, 'Account inactive', 'الحساب غير نشط'),
        _copy(
          context,
          'Contact your supervisor or IT support for access.',
          'تواصل مع مشرفك أو الدعم الفني لاستعادة الوصول.',
        ),
      ),
      _ => (
        Icons.phonelink_lock_outlined,
        _copy(context, 'Device not authorized', 'الجهاز غير مصرح به'),
        _copy(
          context,
          'This device must be registered by IT before use.',
          'يجب تسجيل هذا الجهاز بواسطة الدعم الفني قبل الاستخدام.',
        ),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppColors.error.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.error),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.label.copyWith(color: AppColors.error),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: AppTypography.meta.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSelector extends StatelessWidget {
  const _PreviewSelector({
    required this.value,
    required this.labelFor,
    required this.onChanged,
  });
  final LoginPreviewState value;
  final String Function(LoginPreviewState) labelFor;
  final ValueChanged<LoginPreviewState> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
    decoration: BoxDecoration(
      color: AppColors.orange.withValues(alpha: .06),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: AppColors.orange.withValues(alpha: .15)),
    ),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 19, color: AppColors.orange),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prototype state',
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
              Text(labelFor(value), style: AppTypography.label),
            ],
          ),
        ),
        PopupMenuButton<LoginPreviewState>(
          tooltip: 'Change prototype state',
          onSelected: onChanged,
          itemBuilder: (_) => LoginPreviewState.values
              .map(
                (state) =>
                    PopupMenuItem(value: state, child: Text(labelFor(state))),
              )
              .toList(),
          icon: const Icon(Icons.tune, color: AppColors.orange),
        ),
      ],
    ),
  );
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});
  @override
  Widget build(BuildContext context) => AuthScaffold(
    showBack: true,
    title: _copy(context, 'Forgot password?', 'نسيت كلمة المرور؟'),
    subtitle: _copy(
      context,
      'Enter your registered username or mobile number. We’ll send a verification code.',
      'أدخل اسم المستخدم أو رقم الهاتف المسجل وسنرسل رمز التحقق.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          keyboardType: TextInputType.text,
          decoration: InputDecoration(
            labelText: _copy(
              context,
              'Username or mobile number',
              'اسم المستخدم أو رقم الهاتف',
            ),
            prefixIcon: const Icon(Icons.person_search_outlined),
          ),
        ),
        const SizedBox(height: 20),
        AppButton(
          label: _copy(context, 'Continue', 'متابعة'),
          icon: Icons.arrow_forward,
          expanded: true,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.otp),
        ),
        const SizedBox(height: 18),
        _SecurityNote(
          text: _copy(
            context,
            'For your security, the destination is partially hidden.',
            'لحمايتك، يتم إخفاء جزء من بيانات الاستلام.',
          ),
        ),
      ],
    ),
  );
}

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});
  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late List<TextEditingController> controllers;
  late List<FocusNode> focuses;
  Timer? timer;
  int seconds = 45;
  @override
  void initState() {
    super.initState();
    controllers = List.generate(6, (_) => TextEditingController());
    focuses = List.generate(6, (_) => FocusNode());
    _startTimer();
  }

  void _startTimer() {
    timer?.cancel();
    setState(() => seconds = 45);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || seconds == 0) return timer.cancel();
      setState(() => seconds--);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final focus in focuses) {
      focus.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
    showBack: true,
    title: _copy(context, 'Verify it’s you', 'تحقق من هويتك'),
    subtitle: _copy(
      context,
      'Enter the 6-digit code sent to •••• ••42.',
      'أدخل الرمز المكون من 6 أرقام المرسل إلى •••• ••42.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            children: List.generate(
              6,
              (index) => Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(end: index == 5 ? 0 : 7),
                  child: TextField(
                    controller: controllers[index],
                    focusNode: focuses[index],
                    autofocus: index == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(1),
                    ],
                    style: AppTypography.title,
                    onChanged: (value) {
                      if (value.isNotEmpty && index < 5) {
                        focuses[index + 1].requestFocus();
                      }
                      if (value.isEmpty && index > 0) {
                        focuses[index - 1].requestFocus();
                      }
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(vertical: 17),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _copy(context, 'Didn’t receive it?', 'لم يصلك الرمز؟'),
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
            TextButton(
              onPressed: seconds == 0 ? _startTimer : null,
              child: Text(
                seconds == 0
                    ? _copy(context, 'Resend OTP', 'إعادة الإرسال')
                    : '00:${seconds.toString().padLeft(2, '0')}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppButton(
          label: _copy(context, 'Verify code', 'تحقق من الرمز'),
          icon: Icons.verified_user_outlined,
          expanded: true,
          onPressed: () => Navigator.pushNamed(context, AppRoutes.newPassword),
        ),
      ],
    ),
  );
}

class CreateNewPasswordScreen extends StatefulWidget {
  const CreateNewPasswordScreen({super.key});
  @override
  State<CreateNewPasswordScreen> createState() =>
      _CreateNewPasswordScreenState();
}

class _CreateNewPasswordScreenState extends State<CreateNewPasswordScreen> {
  bool hideNew = true, hideConfirm = true;
  @override
  Widget build(BuildContext context) => AuthScaffold(
    showBack: true,
    title: _copy(context, 'Create new password', 'إنشاء كلمة مرور جديدة'),
    subtitle: _copy(
      context,
      'Choose a strong password you haven’t used before.',
      'اختر كلمة مرور قوية لم تستخدمها من قبل.',
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PasswordField(
          label: _copy(context, 'New password', 'كلمة المرور الجديدة'),
          obscure: hideNew,
          onToggle: () => setState(() => hideNew = !hideNew),
        ),
        const SizedBox(height: 14),
        _PasswordField(
          label: _copy(context, 'Confirm password', 'تأكيد كلمة المرور'),
          obscure: hideConfirm,
          onToggle: () => setState(() => hideConfirm = !hideConfirm),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.control),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _copy(context, 'Password requirements', 'متطلبات كلمة المرور'),
                style: AppTypography.label,
              ),
              const SizedBox(height: 10),
              const _Requirement('At least 8 characters'),
              const _Requirement('One uppercase and lowercase letter'),
              const _Requirement('One number and special character'),
            ],
          ),
        ),
        const SizedBox(height: 22),
        AppButton(
          label: _copy(context, 'Save new password', 'حفظ كلمة المرور'),
          icon: Icons.lock_reset,
          expanded: true,
          onPressed: () => Navigator.pushReplacementNamed(
            context,
            AppRoutes.passwordChanged,
          ),
        ),
      ],
    ),
  );
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.obscure,
    required this.onToggle,
  });
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  @override
  Widget build(BuildContext context) => TextField(
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: const Icon(Icons.lock_outline),
      suffixIcon: IconButton(
        onPressed: onToggle,
        icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off),
      ),
    ),
  );
}

class _Requirement extends StatelessWidget {
  const _Requirement(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 18,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
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

class PasswordChangedScreen extends StatelessWidget {
  const PasswordChangedScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 50,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 26),
                Text(
                  _copy(context, 'Password changed', 'تم تغيير كلمة المرور'),
                  style: AppTypography.display,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _copy(
                    context,
                    'Your password has been updated successfully. You can now sign in with your new password.',
                    'تم تحديث كلمة المرور بنجاح. يمكنك الآن تسجيل الدخول باستخدام كلمة المرور الجديدة.',
                  ),
                  style: AppTypography.body.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                AppButton(
                  label: _copy(
                    context,
                    'Back to sign in',
                    'العودة لتسجيل الدخول',
                  ),
                  icon: Icons.login,
                  expanded: true,
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.login,
                    (_) => false,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Icon(Icons.shield_outlined, size: 20, color: AppColors.info),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          text,
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
      ),
    ],
  );
}
