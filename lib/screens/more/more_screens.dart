import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/network/result.dart';
import '../../core/routes/app_routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/authentication/data/models/auth_models.dart';
import '../../features/authentication/domain/usecases/get_user_profile_use_case.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/session_timeout_ui.dart';
import '../incidents/incident_action_flows.dart';
import '../incidents/incident_details_screen.dart';
import '../incidents/new_request_flows.dart';
import '../map/tower_map_screen.dart';
import '../reporting/reporting_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});
  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  late List<AppNotification> notifications = List<AppNotification>.of(
    MockData.notifications,
  );

  Future<void> _open(int index) async {
    final item = notifications[index];
    setState(() => notifications[index] = item.copyWith(isRead: true));
    final incident = MockData.capIncidents.first;
    final page = switch (item.type) {
      AppNotificationType.newAssignment => IncidentDetailsScreen(
        incident: incident,
      ),
      AppNotificationType.renewalReminder => NewRequestWizard(
        incident: incident,
        type: RelatedRequestType.renewal,
      ),
      AppNotificationType.departureReminder => NewRequestWizard(
        incident: incident,
        type: RelatedRequestType.departure,
      ),
      AppNotificationType.photoReminder => FieldTaskWizard(
        incident: incident,
        type: TaskFlowType.complete,
        initialStep: 0,
      ),
      AppNotificationType.gpsWarning => FieldTaskWizard(
        incident: incident,
        type: TaskFlowType.start,
      ),
      AppNotificationType.socMessage => MessageDetailsScreen(
        notification: item,
        announcement: false,
      ),
      AppNotificationType.systemAnnouncement => MessageDetailsScreen(
        notification: item,
        announcement: true,
      ),
    };
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final unread = notifications.where((item) => !item.isRead).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Notifications', 'الإشعارات')),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              notifications = notifications
                  .map((item) => item.copyWith(isRead: true))
                  .toList();
            }),
            child: Text(context.tr('Mark all read', 'قراءة الكل')),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.orange,
        onRefresh: () async =>
            Future<void>.delayed(const Duration(milliseconds: 650)),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Notification Center', 'مركز الإشعارات'),
                    style: AppTypography.display,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    context.strings.isArabic
                        ? '$unread غير مقروء'
                        : '$unread unread',
                    style: AppTypography.meta.copyWith(
                      color: AppColors.orangeDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...List.generate(
              notifications.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _NotificationCard(
                  notification: notifications[index],
                  onTap: () => _open(index),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _notificationVisual(notification.type);
    return Card(
      color: notification.isRead
          ? Theme.of(context).cardColor
          : AppColors.orange.withValues(alpha: .045),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _notificationTitle(context, notification),
                            style: AppTypography.label.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w800,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.orange,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _notificationDescription(context, notification),
                      style: AppTypography.body.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: AppColors.muted),
                        const SizedBox(width: 5),
                        Text(
                          _notificationTime(context, notification.time),
                          style: AppTypography.meta.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_forward,
                          size: 17,
                          color: AppColors.muted,
                        ),
                      ],
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
}

class MessageDetailsScreen extends StatelessWidget {
  const MessageDetailsScreen({
    super.key,
    required this.notification,
    required this.announcement,
  });
  final AppNotification notification;
  final bool announcement;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        announcement
            ? context.tr('Announcement Details', 'تفاصيل الإعلان')
            : context.tr('SOC Message', 'رسالة SOC'),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          width: 74,
          height: 74,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: .1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            announcement ? Icons.campaign_outlined : Icons.security_outlined,
            color: AppColors.orange,
            size: 36,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          _notificationTitle(context, notification),
          style: AppTypography.display,
        ),
        const SizedBox(height: 8),
        Text(
          _notificationTime(context, notification.time),
          style: AppTypography.meta.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Text(
              _notificationDescription(context, notification),
              style: AppTypography.body,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          announcement
              ? context.tr(
                  'This is a mock system announcement. No action is required.',
                  'هذا إعلان نظام محاكى ولا يتطلب أي إجراء.',
                )
              : context.tr(
                  'Sent securely by the Security Operations Center.',
                  'تم الإرسال بأمان من مركز عمليات الأمن.',
                ),
          style: AppTypography.meta.copyWith(color: AppColors.muted),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final Future<Result<UserProfile>> _profileFuture;

  @override
  void initState() {
    super.initState();
    final userId = services<SessionManager>().userId;
    _profileFuture = services<GetUserProfileUseCase>().call(userId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('Profile', 'الملف الشخصي'))),
    body: FutureBuilder<Result<UserProfile>>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data is FailureResult) {
          return Center(
            child: Text(
              context.tr('Failed to load profile', 'فشل تحميل الملف الشخصي'),
            ),
          );
        }

        final profile = (snapshot.data as Success<UserProfile>).data;
        final bool hasImage = profile.userImageUrl.isNotEmpty;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 43,
                    backgroundColor: AppColors.orange,
                    backgroundImage: hasImage
                        ? NetworkImage(profile.userImageUrl)
                        : null,
                    child: !hasImage
                        ? Text(
                            profile.userName.isNotEmpty
                                ? profile.userName.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    profile.fullName ?? profile.userName,
                    style: AppTypography.title.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.strings.isArabic
                        ? profile.userTypeAr
                        : profile.userTypeEn,
                    style: AppTypography.body.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      context.tr('ACTIVE EMPLOYEE', 'موظف نشط'),
                      style: AppTypography.meta.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _ProfileInfo(
                      icon: Icons.business_outlined,
                      label: context.tr('Company', 'الشركة'),
                      value: MockData.companyName,
                    ),
                    _ProfileInfo(
                      icon: Icons.public,
                      label: context.tr('Region', 'الإقليم'),
                      value: profile.userRegion,
                    ),
                    _ProfileInfo(
                      icon: Icons.groups_outlined,
                      label: context.tr('Team', 'الفريق'),
                      value: profile
                          .userTypeEn, // Using type as a fallback for team
                    ),
                    _ProfileInfo(
                      icon: Icons.phone_outlined,
                      label: context.tr('Mobile Number', 'رقم الهاتف'),
                      value: profile.phoneNumber,
                    ),
                    _ProfileInfo(
                      icon: Icons.email_outlined,
                      label: context.tr('Email', 'البريد الإلكتروني'),
                      value: profile.email ?? 'N/A',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.lock_reset,
                    title: context.tr('Change Password', 'تغيير كلمة المرور'),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.newPassword),
                  ),
                  const Divider(height: 1, indent: 62),
                  _MenuTile(
                    icon: Icons.language,
                    title: context.tr('Change Language', 'تغيير اللغة'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ChangeLanguageScreen(),
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 62),
                  _MenuTile(
                    icon: Icons.phonelink_lock_outlined,
                    title: context.tr('Registered Device', 'الجهاز المسجل'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisteredDeviceScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: _MenuTile(
                icon: Icons.logout,
                title: context.tr('Logout', 'تسجيل الخروج'),
                destructive: true,
                onTap: () => _logout(context),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class ChangeLanguageScreen extends StatelessWidget {
  const ChangeLanguageScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final arabic = context.strings.isArabic;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Change Language', 'تغيير اللغة'))),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            context.tr('Application language', 'لغة التطبيق'),
            style: AppTypography.display,
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(
              'Switching language updates text direction immediately.',
              'يؤدي تغيير اللغة إلى تحديث اتجاه النص فورًا.',
            ),
            style: AppTypography.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 22),
          _LanguageCard(
            title: 'العربية',
            subtitle: 'واجهة من اليمين إلى اليسار',
            code: 'AR',
            selected: arabic,
            onTap: () => AccessLogApp.of(context).setLocale(const Locale('ar')),
          ),
          const SizedBox(height: 11),
          _LanguageCard(
            title: 'English',
            subtitle: 'Left-to-right interface',
            code: 'EN',
            selected: !arabic,
            onTap: () => AccessLogApp.of(context).setLocale(const Locale('en')),
          ),
        ],
      ),
    );
  }
}

class RegisteredDeviceScreen extends StatelessWidget {
  const RegisteredDeviceScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Registered Device', 'الجهاز المسجل')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Center(
          child: Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: .1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.phone_iphone,
              color: AppColors.orange,
              size: 47,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr('Authorized field device', 'جهاز ميداني مصرح به'),
          textAlign: TextAlign.center,
          style: AppTypography.title,
        ),
        const SizedBox(height: 6),
        Text(
          context.tr('Mock registration information', 'بيانات تسجيل محاكاة'),
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 22),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _ProfileInfo(
                  icon: Icons.smartphone,
                  label: context.tr('Device Name', 'اسم الجهاز'),
                  value: 'Omar’s iPhone 15',
                ),
                _ProfileInfo(
                  icon: Icons.layers_outlined,
                  label: context.tr('Platform', 'النظام'),
                  value: 'iOS 19.0',
                ),
                _ProfileInfo(
                  icon: Icons.event_outlined,
                  label: context.tr('Registered Date', 'تاريخ التسجيل'),
                  value: context.tr('03 August 2026', '03 أغسطس 2026'),
                ),
                _ProfileInfo(
                  icon: Icons.verified_outlined,
                  label: context.tr('Status', 'الحالة'),
                  value: context.tr('Authorized', 'مصرح به'),
                  valueColor: AppColors.success,
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.tr('About', 'حول التطبيق'))),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text(
                  '+',
                  style: TextStyle(
                    color: AppColors.orange,
                    fontSize: 50,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Access Log+', style: AppTypography.display),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Field Operations Prototype',
                'نموذج العمليات الميدانية',
              ),
              style: AppTypography.body.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Text(
              context.tr(
                'Version 1.0.0 (Prototype)',
                'الإصدار 1.0.0 (نموذج أولي)',
              ),
              style: AppTypography.label,
            ),
            const SizedBox(height: 24),
            Text(
              context.tr(
                'A premium mobile workspace designed for Orange field engineers. All data and operational actions in this build are simulated.',
                'مساحة عمل متميزة للمهندسين الميدانيين في أورنج. جميع البيانات والإجراءات التشغيلية في هذه النسخة محاكاة.',
              ),
              textAlign: TextAlign.center,
              style: AppTypography.body,
            ),
          ],
        ),
      ),
    ),
  );
}

class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
    children: [
      Text(context.tr('More', 'المزيد'), style: AppTypography.display),
      const SizedBox(height: 6),
      Text(
        context.tr(
          'Account, notifications, and application settings',
          'الحساب والإشعارات وإعدادات التطبيق',
        ),
        style: AppTypography.body.copyWith(color: AppColors.muted),
      ),
      const SizedBox(height: 22),
      Card(
        child: Column(
          children: [
            _MenuTile(
              icon: Icons.person_outline,
              title: context.tr('Profile', 'الملف الشخصي'),
              subtitle: MockData.engineer.name,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.notifications_none,
              title: context.tr('Notifications', 'الإشعارات'),
              subtitle: context.tr(
                'Assignments, reminders, and messages',
                'المهام والتذكيرات والرسائل',
              ),
              badge: '4',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationCenterScreen(),
                ),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.language,
              title: context.tr('Language', 'اللغة'),
              subtitle: context.strings.isArabic ? 'العربية' : 'English',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChangeLanguageScreen()),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.phonelink_lock_outlined,
              title: context.tr('Registered Device', 'الجهاز المسجل'),
              subtitle: context.tr('Authorized', 'مصرح به'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RegisteredDeviceScreen(),
                ),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.map_outlined,
              title: context.tr('Tower Map', 'خريطة الأبراج'),
              subtitle: context.tr(
                'Browse towers, incidents, and requests',
                'تصفح الأبراج والبلاغات والطلبات',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TowerMapScreen()),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.bar_chart_outlined,
              title: context.tr('Reporting', 'التقارير'),
              subtitle: context.tr(
                'Incident and engineer reports',
                'تقارير البلاغات والمهندسين',
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(context.tr('Reporting', 'التقارير')),
                    ),
                    body: const SafeArea(child: ReportingScreen()),
                  ),
                ),
              ),
            ),
            const Divider(height: 1, indent: 62),
            _MenuTile(
              icon: Icons.info_outline,
              title: context.tr('About', 'حول التطبيق'),
              subtitle: 'Access Log+ v1.0.0',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Card(
        child: _MenuTile(
          icon: Icons.logout,
          title: context.tr('Logout', 'تسجيل الخروج'),
          subtitle: context.tr(
            'Return to secure login',
            'العودة إلى تسجيل الدخول الآمن',
          ),
          destructive: true,
          onTap: () => _logout(context),
        ),
      ),
    ],
  );
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });
  final IconData icon;
  final String label, value;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.orange),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.meta.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTypography.label.copyWith(color: valueColor),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.badge,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle, badge;
  final bool destructive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    minTileHeight: 68,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: (destructive ? AppColors.error : AppColors.orange).withValues(
          alpha: .08,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        color: destructive ? AppColors.error : AppColors.orange,
      ),
    ),
    title: Text(
      title,
      style: AppTypography.label.copyWith(
        color: destructive ? AppColors.error : null,
      ),
    ),
    subtitle: subtitle == null
        ? null
        : Text(
            subtitle!,
            style: AppTypography.meta.copyWith(color: AppColors.muted),
          ),
    trailing: badge == null
        ? Icon(
            Directionality.of(context) == TextDirection.rtl
                ? Icons.chevron_left
                : Icons.chevron_right,
            color: AppColors.muted,
          )
        : Badge(
            label: Text(badge!),
            backgroundColor: AppColors.orange,
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? Icons.chevron_left
                  : Icons.chevron_right,
              color: AppColors.muted,
            ),
          ),
  );
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.selected,
    required this.onTap,
  });
  final String title, subtitle, code;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      minTileHeight: 78,
      leading: CircleAvatar(
        backgroundColor: selected ? AppColors.orange : const Color(0xFFF0F0ED),
        child: Text(
          code,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(title, style: AppTypography.section),
      subtitle: Text(
        subtitle,
        style: AppTypography.meta.copyWith(color: AppColors.muted),
      ),
      trailing: Icon(
        selected ? Icons.check_circle : Icons.circle_outlined,
        color: selected ? AppColors.orange : AppColors.muted,
      ),
    ),
  );
}

Future<void> _logout(BuildContext context) async {
  final confirmed = await showActiveInterventionLogoutWarning(context);
  if (confirmed && context.mounted) navigateToSecureLogin(context);
}

(IconData, Color) _notificationVisual(
  AppNotificationType type,
) => switch (type) {
  AppNotificationType.newAssignment => (Icons.assignment_add, AppColors.orange),
  AppNotificationType.renewalReminder => (Icons.autorenew, AppColors.info),
  AppNotificationType.departureReminder => (Icons.logout, AppColors.success),
  AppNotificationType.gpsWarning => (Icons.gps_off, AppColors.error),
  AppNotificationType.photoReminder => (
    Icons.add_a_photo_outlined,
    AppColors.warning,
  ),
  AppNotificationType.socMessage => (Icons.security_outlined, AppColors.purple),
  AppNotificationType.systemAnnouncement => (
    Icons.campaign_outlined,
    AppColors.info,
  ),
};

String _notificationTitle(BuildContext context, AppNotification item) =>
    switch (item.type) {
      AppNotificationType.newAssignment => context.tr(
        item.title,
        'مهمة حرجة جديدة',
      ),
      AppNotificationType.renewalReminder => context.tr(
        item.title,
        'موعد تجديد التدخل',
      ),
      AppNotificationType.departureReminder => context.tr(
        item.title,
        'طلب المغادرة مطلوب',
      ),
      AppNotificationType.gpsWarning => context.tr(
        item.title,
        'تحذير التحقق من الموقع',
      ),
      AppNotificationType.photoReminder => context.tr(
        item.title,
        'صورة الإكمال مفقودة',
      ),
      AppNotificationType.socMessage => context.tr(item.title, 'رسالة من SOC'),
      AppNotificationType.systemAnnouncement => context.tr(
        item.title,
        'إشعار صيانة مخططة',
      ),
    };

String _notificationDescription(
  BuildContext context,
  AppNotification item,
) => switch (item.type) {
  AppNotificationType.newAssignment => context.tr(
    item.description,
    'تم إسناد البلاغ ${MockData.capIncidents.first.number} في ${MockData.capIncidents.first.siteName} إليك.',
  ),
  AppNotificationType.renewalReminder => context.tr(
    item.description,
    'تنتهي النافذة المعتمدة لـ ${MockData.activeInterventionNumber} خلال 20 دقيقة.',
  ),
  AppNotificationType.departureReminder => context.tr(
    item.description,
    'أرسل تصريح المغادرة قبل مغادرة ${MockData.capIncidents.first.siteName}.',
  ),
  AppNotificationType.gpsWarning => context.tr(
    item.description,
    'آخر تحقق محاكى للموقع خارج النطاق المسموح للمحطة.',
  ),
  AppNotificationType.photoReminder => context.tr(
    item.description,
    'أضف صورة الكابينة المطلوبة قبل إكمال المهمة النشطة.',
  ),
  AppNotificationType.socMessage => context.tr(
    item.description,
    'حافظ على قيود دخول الموقع أثناء التدخل المخطط.',
  ),
  AppNotificationType.systemAnnouncement => context.tr(
    item.description,
    'ستتم صيانة خدمات CAP للهاتف الليلة الساعة 11:00 مساءً.',
  ),
};

String _notificationTime(BuildContext context, String time) =>
    context.strings.isArabic
    ? switch (time) {
        '2 min ago' => 'منذ دقيقتين',
        '12 min ago' => 'منذ 12 دقيقة',
        '28 min ago' => 'منذ 28 دقيقة',
        '45 min ago' => 'منذ 45 دقيقة',
        '1 hr ago' => 'منذ ساعة',
        '2 hrs ago' => 'منذ ساعتين',
        'Yesterday' => 'أمس',
        _ => time,
      }
    : time;
