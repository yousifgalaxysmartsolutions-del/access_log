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
}
