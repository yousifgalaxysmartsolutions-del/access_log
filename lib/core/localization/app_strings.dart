import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings(this.locale);
  final Locale locale;
  bool get isArabic => locale.languageCode == 'ar';
  String t(String key) => _values[isArabic ? 'ar' : 'en']?[key] ?? key;
  static const _values = {
    'en': {
      'home': 'Home',
      'incidents': 'Incidents',
      'activity': 'Activity',
      'profile': 'Profile',
      'showcase': 'Design system',
      'welcome': 'Good morning, Omar',
      'subtitle': 'Your field operations at a glance',
      'today': 'Today’s assignment',
      'components': 'Components',
      'viewAll': 'View all',
      'language': 'العربية',
      'ready': 'Ready for the field',
      'placeholder': 'This workspace is ready for the next phase.',
      'notifications': 'Notifications',
    },
    'ar': {
      'home': 'الرئيسية',
      'incidents': 'البلاغات',
      'activity': 'النشاط',
      'profile': 'الملف الشخصي',
      'showcase': 'نظام التصميم',
      'welcome': 'صباح الخير، عمر',
      'subtitle': 'نظرة سريعة على عملياتك الميدانية',
      'today': 'مهمة اليوم',
      'components': 'المكونات',
      'viewAll': 'عرض الكل',
      'language': 'English',
      'ready': 'جاهز للعمل الميداني',
      'placeholder': 'مساحة العمل جاهزة للمرحلة التالية.',
      'notifications': 'الإشعارات',
    },
  };
}

extension StringsX on BuildContext {
  AppStrings get strings => AppStrings(Localizations.localeOf(this));
  String tr(String english, String arabic) =>
      strings.isArabic ? arabic : english;

  /// Presentation labels only; request IDs and API payloads stay unchanged.
  String requestTypeLabel(int? id, {String? name, String? code}) {
    final value = (code ?? name ?? '').trim().toLowerCase();
    if (id == 1 || value.contains('intervention')) {
      return tr('Entry Request', 'طلب دخول');
    }
    if (id == 2 || value.contains('renewal')) {
      return tr('Renewal Request', 'طلب تجديد');
    }
    if (id == 3 || value.contains('departure')) {
      return tr('Departure Request', 'طلب خروج');
    }
    return name?.trim().isNotEmpty == true
        ? name!.trim()
        : tr('Request type unavailable', 'نوع الطلب غير متاح');
  }
}
