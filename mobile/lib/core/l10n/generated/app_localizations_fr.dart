// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'MIDAD';

  @override
  String get tagline => 'Espace de travail de l\'enseignant';

  @override
  String get navHome => 'Accueil';

  @override
  String get navClasses => 'Classes';

  @override
  String get navPlanner => 'Planning';

  @override
  String get navAnalytics => 'Analyses';

  @override
  String get navMore => 'Plus';

  @override
  String get quickAdd => 'Ajout rapide';

  @override
  String pendingTitle(int phase) {
    return 'Disponible en phase $phase';
  }

  @override
  String get pendingBody => 'Cette section n\'est pas encore développée.';

  @override
  String get offlineBanner =>
      'Vous êtes hors ligne. Les modifications seront synchronisées automatiquement.';

  @override
  String get syncDone => 'Toutes les modifications sont synchronisées.';

  @override
  String get errNetwork =>
      'Synchronisation impossible pour le moment. Vos modifications sont enregistrées sur cet appareil.';

  @override
  String get errAuth => 'Votre session a expiré. Veuillez vous reconnecter.';

  @override
  String get errValidation => 'Veuillez vérifier les informations saisies.';

  @override
  String get errConflict =>
      'Cet élément a été modifié ailleurs. Vérifiez avant d\'enregistrer.';

  @override
  String get errPermission => 'Vous n\'avez pas accès à cet élément.';

  @override
  String get errFile => 'Ce fichier n\'a pas pu être utilisé.';

  @override
  String get errUnknown => 'Une erreur est survenue. Veuillez réessayer.';
}
