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

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'إنشاء حساب جديد';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get schoolName => 'المدرسة أو المؤسسة';

  @override
  String get loginAction => 'تسجيل الدخول';

  @override
  String get registerAction => 'إنشاء الحساب';

  @override
  String get noAccount => 'ليس لديك حساب؟ أنشئ حساباً الآن';

  @override
  String get haveAccount => 'لديك حساب بالفعل؟ سجّل دخولك';

  @override
  String get logout => 'تسجيل الخروج';

  @override
  String greetingTeacher(String name) {
    return 'مرحباً، $name';
  }

  @override
  String get classesTitle => 'الأقسام والحصص';

  @override
  String get studentsTitle => 'الطلاب';

  @override
  String get addClass => 'إضافة قسم جديد';

  @override
  String get className => 'اسم القسم';

  @override
  String get classLevel => 'المستوى الدراسي';

  @override
  String get subjectName => 'المادة';

  @override
  String get addStudent => 'إضافة طالب';

  @override
  String get firstName => 'الاسم';

  @override
  String get lastName => 'اللقب';

  @override
  String get studentNumber => 'رقم التعريف (اختياري)';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get noClassesYet => 'لا توجد أقسام مسجلة بعد';

  @override
  String get noStudentsYet => 'لا يوجد طلاب مسجلون بعد';

  @override
  String studentsCount(int count) {
    return '$count طالب';
  }

  @override
  String get todayClasses => 'جدول الحصص';

  @override
  String get searchStudents => 'بحث عن طالب...';

  @override
  String get notes => 'الملاحظات';

  @override
  String get addNote => 'إضافة ملاحظة';

  @override
  String get noteHint => 'اكتب ملاحظة موضوعية...';

  @override
  String get pinUnlock => 'إلغاء القفل برمز PIN';

  @override
  String get enterPin => 'أدخل رمز PIN للمتابعة';

  @override
  String get attendance => 'الحضور والغياب';

  @override
  String get markAttendance => 'تسجيل الحضور';

  @override
  String get markAllPresent => 'تحديد الكل حاضر';

  @override
  String get present => 'حاضر';

  @override
  String get absent => 'غائب';

  @override
  String get late => 'متأخر';

  @override
  String get excused => 'معذور';

  @override
  String get gradebook => 'دفتر العلامات';

  @override
  String get addAssessment => 'إضافة فرض أو تقييم';

  @override
  String get assessmentTitle => 'عنوان التقييم';

  @override
  String get maxScore => 'العلامة الكاملة';

  @override
  String get coefficient => 'المعامل';

  @override
  String get score => 'العلامة';

  @override
  String scoreExceedsMax(String max) {
    return 'العلامة لا يمكن أن تتجاوز الحد الأقصى ($max)';
  }

  @override
  String get undo => 'تراجع';

  @override
  String get syncStatusSynced => 'متزامن';

  @override
  String get syncStatusPending => 'في انتظار المزامنة';

  @override
  String get syncStatusConflict => 'تعارض في البيانات';

  @override
  String get plannerTitle => 'المخطط ودفتر النصوص';

  @override
  String get lessons => 'الدروس';

  @override
  String get newLesson => 'درس جديد';

  @override
  String get editLesson => 'تعديل الدرس';

  @override
  String get lessonTopic => 'موضوع الدرس';

  @override
  String get objectives => 'الأهداف التعليمية';

  @override
  String get contentAndActivities => 'المحتوى والأنشطة';

  @override
  String get homework => 'الواجب المنزلي';

  @override
  String get journalCovered => 'ما تم إنجازه فعلياً (دفتر النصوص)';

  @override
  String get planned => 'مخطط';

  @override
  String get inProgress => 'قيد الإنجاز';

  @override
  String get completed => 'مكتمل';

  @override
  String get recordJournal => 'تسجيل في دفتر النصوص';

  @override
  String get assignments => 'الواجبات المنزلية';

  @override
  String get newAssignment => 'واجب جديد';

  @override
  String get dueOn => 'تاريخ التسليم';

  @override
  String get assigned => 'مكلف';

  @override
  String get missing => 'غير منجز';

  @override
  String get tasks => 'المهام اليومية';

  @override
  String get newTask => 'مهمة جديدة';

  @override
  String get quickAction => 'إجراء سريع';

  @override
  String get documentsTitle => 'المستندات والملفات';

  @override
  String get newFolder => 'مجلد جديد';

  @override
  String get newDocument => 'إضافة مستند';

  @override
  String get allFiles => 'جميع الملفات';

  @override
  String get seatingPlan => 'مخطط الجلوس';

  @override
  String get newSeatingPlan => 'مخطط جديد';

  @override
  String get studentGroups => 'المجموعات الطلابية';

  @override
  String get newGroup => 'إنشاء فوج أو مجموعة';

  @override
  String get activityLogs => 'سجل المشاركة والنشاط';

  @override
  String get logActivity => 'تسجيل مشاركة صفية';

  @override
  String get followUpAlerts => 'تنبيهات المتابعة التلقائية';

  @override
  String get academicYear => 'السنة الدراسية';

  @override
  String get globalSearch => 'البحث الشامل';

  @override
  String get activityHistory => 'سجل النشاطات والتعديلات';
}
