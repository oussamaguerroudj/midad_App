// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'مِداد';

  @override
  String get tagline => 'مساحة عمل المعلم';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navClasses => 'الحصص';

  @override
  String get navPlanner => 'المخطط';

  @override
  String get navAnalytics => 'التحليلات';

  @override
  String get navMore => 'المزيد';

  @override
  String get quickAdd => 'إضافة سريعة';

  @override
  String pendingTitle(int phase) {
    return 'متاح في المرحلة $phase';
  }

  @override
  String get pendingBody => 'هذا القسم لم يُبنَ بعد.';

  @override
  String get offlineBanner => 'أنت غير متصل. ستتم مزامنة التغييرات تلقائيًا.';

  @override
  String get syncDone => 'تمت مزامنة جميع التغييرات.';

  @override
  String get errNetwork =>
      'تعذّرت المزامنة الآن. تغييراتك محفوظة على هذا الجهاز.';

  @override
  String get errAuth => 'انتهت جلستك. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get errValidation => 'يرجى التحقق من المعلومات المدخلة.';

  @override
  String get errConflict => 'تم تعديل هذا العنصر في مكان آخر. راجعه قبل الحفظ.';

  @override
  String get errPermission => 'ليس لديك صلاحية الوصول إلى هذا العنصر.';

  @override
  String get errFile => 'تعذّر استخدام هذا الملف.';

  @override
  String get errUnknown => 'حدث خطأ ما. يرجى المحاولة مرة أخرى.';
}
