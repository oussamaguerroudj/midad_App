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
}
