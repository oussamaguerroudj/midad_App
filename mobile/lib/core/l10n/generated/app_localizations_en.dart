// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MIDAD';

  @override
  String get tagline => 'Teacher Workspace';

  @override
  String get navHome => 'Home';

  @override
  String get navClasses => 'Classes';

  @override
  String get navPlanner => 'Planner';

  @override
  String get navAnalytics => 'Analytics';

  @override
  String get navMore => 'More';

  @override
  String get quickAdd => 'Quick add';

  @override
  String pendingTitle(int phase) {
    return 'Coming in phase $phase';
  }

  @override
  String get pendingBody => 'This section is not built yet.';

  @override
  String get offlineBanner =>
      'You\'re offline. Changes will sync automatically.';

  @override
  String get syncDone => 'All changes synchronized.';

  @override
  String get errNetwork =>
      'Unable to synchronize right now. Your changes are saved on this device.';

  @override
  String get errAuth => 'Your session has expired. Please sign in again.';

  @override
  String get errValidation => 'Please check the information you entered.';

  @override
  String get errConflict =>
      'This item was changed elsewhere. Please review before saving.';

  @override
  String get errPermission => 'You don\'t have access to this item.';

  @override
  String get errFile => 'This file could not be used.';

  @override
  String get errUnknown => 'Something went wrong. Please try again.';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Create New Account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get fullName => 'Full Name';

  @override
  String get schoolName => 'School or Institution';

  @override
  String get loginAction => 'Sign In';

  @override
  String get registerAction => 'Create Account';

  @override
  String get noAccount => 'Don\'t have an account? Sign up';

  @override
  String get haveAccount => 'Already have an account? Sign in';

  @override
  String get logout => 'Sign Out';

  @override
  String greetingTeacher(String name) {
    return 'Hello, $name';
  }

  @override
  String get classesTitle => 'Classes & Courses';

  @override
  String get studentsTitle => 'Students';

  @override
  String get addClass => 'Add New Class';

  @override
  String get className => 'Class Name';

  @override
  String get classLevel => 'Grade Level';

  @override
  String get subjectName => 'Subject';

  @override
  String get addStudent => 'Add Student';

  @override
  String get firstName => 'First Name';

  @override
  String get lastName => 'Last Name';

  @override
  String get studentNumber => 'Student ID (optional)';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get noClassesYet => 'No classes registered yet';

  @override
  String get noStudentsYet => 'No students registered yet';

  @override
  String studentsCount(int count) {
    return '$count students';
  }

  @override
  String get todayClasses => 'Schedule';

  @override
  String get searchStudents => 'Search students...';

  @override
  String get notes => 'Notes';

  @override
  String get addNote => 'Add Note';

  @override
  String get noteHint => 'Write an objective note...';

  @override
  String get pinUnlock => 'Unlock with PIN';

  @override
  String get enterPin => 'Enter PIN to continue';

  @override
  String get attendance => 'Attendance';

  @override
  String get markAttendance => 'Take Attendance';

  @override
  String get markAllPresent => 'Mark all present';

  @override
  String get present => 'Present';

  @override
  String get absent => 'Absent';

  @override
  String get late => 'Late';

  @override
  String get excused => 'Excused';

  @override
  String get gradebook => 'Gradebook';

  @override
  String get addAssessment => 'Add Assessment';

  @override
  String get assessmentTitle => 'Assessment Title';

  @override
  String get maxScore => 'Max Score';

  @override
  String get coefficient => 'Coefficient';

  @override
  String get score => 'Score';

  @override
  String scoreExceedsMax(String max) {
    return 'Score cannot exceed max ($max)';
  }

  @override
  String get undo => 'Undo';

  @override
  String get syncStatusSynced => 'Synced';

  @override
  String get syncStatusPending => 'Pending sync';

  @override
  String get syncStatusConflict => 'Conflict';
}
