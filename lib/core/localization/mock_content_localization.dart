import 'package:flutter/widgets.dart';

import 'app_strings.dart';

extension MockContentLocalization on BuildContext {
  String mockText(String value) {
    if (!strings.isArabic) return value;
    return _arabic[value] ?? value;
  }
}

const _arabic = <String, String>{
  'Power Alarm': 'إنذار طاقة',
  'Power Maintenance': 'صيانة نظام الطاقة',
  'Fiber Degradation': 'تدهور خط الألياف',
  'Site Access': 'دخول الموقع',
  'Transmission': 'نقل واتصالات',
  'Preventive Maintenance': 'صيانة وقائية',
  'Environmental Alarm': 'إنذار بيئي',
  'Generator Failure': 'عطل بالمولد',
  'Cooling System': 'نظام التبريد',
  'Cairo Core Site 14': 'موقع القاهرة الرئيسي 14',
  'Cairo Central Site': 'موقع القاهرة المركزي',
  'Cairo Airport Radio Site': 'موقع اتصالات مطار القاهرة',
  'Maadi Exchange': 'سنترال المعادي',
  'Giza Radio Site 08': 'موقع الجيزة للاتصالات 08',
  'New Cairo Hub 03': 'مركز القاهرة الجديدة 03',
  'October MSC': 'مركز أكتوبر MSC',
  'Heliopolis RAN 21': 'موقع مصر الجديدة RAN 21',
  'Alexandria Exchange 01': 'سنترال الإسكندرية 01',
  'Mansoura Core 02': 'موقع المنصورة الرئيسي 02',
  'Greater Cairo': 'القاهرة الكبرى',
  'Nasr City': 'مدينة نصر',
  'Maadi': 'المعادي',
  'Dokki': 'الدقي',
  'New Cairo': 'القاهرة الجديدة',
  'Giza': 'الجيزة',
  'Heliopolis': 'مصر الجديدة',
  'Alexandria': 'الإسكندرية',
  'Smouha': 'سموحة',
  'Delta': 'الدلتا',
  'Mansoura': 'المنصورة',
  'Rectifier module output below threshold':
      'خرج وحدة التقويم أقل من الحد المسموح',
  'Approve field assignment for rectifier inspection':
      'اعتماد إسناد المهمة الميدانية لفحص وحدة التقويم',
  'High attenuation on aggregation link': 'ارتفاع الفقد في وصلة التجميع',
  'Access coordination required for cabinet inspection':
      'يلزم تنسيق الدخول لفحص الكابينة',
  'Microwave link intermittent packet loss':
      'فقد متقطع للحزم في وصلة الميكروويف',
  'Quarterly battery bank health inspection':
      'فحص ربع سنوي لحالة بنك البطاريات',
  'Shelter temperature sensor inconsistency':
      'عدم اتساق قراءات مستشعر حرارة الكابينة',
  'Backup generator failed automatic startup test':
      'فشل المولد الاحتياطي في اختبار التشغيل التلقائي',
  'HVAC unit two requires corrective maintenance':
      'وحدة التكييف الثانية تحتاج إلى صيانة تصحيحية',
  'Network monitoring generated this CAP incident for field assessment and corrective action.':
      'أنشأ نظام مراقبة الشبكة هذا البلاغ للتقييم الميداني واتخاذ الإجراء التصحيحي.',
  'Mobile Network Infrastructure': 'البنية التحتية لشبكة المحمول',
  'Operational Alarm': 'إنذار تشغيلي',
  'NOC Queue': 'قائمة انتظار NOC',
  'Dispatch Team': 'فريق التوجيه',
};
