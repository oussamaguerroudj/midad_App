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
  String get navPlanner => 'Cahier';

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
  String get pendingBody => 'Cette section n\'est pas encore construite.';

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
      'Cet élément a été modifié ailleurs. Veuillez vérifier avant d\'enregistrer.';

  @override
  String get errPermission => 'Vous n\'avez pas accès à cet élément.';

  @override
  String get errFile => 'Ce fichier n\'a pas pu être utilisé.';

  @override
  String get errUnknown => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get signIn => 'Connexion';

  @override
  String get signUp => 'Créer un compte';

  @override
  String get email => 'Adresse e-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get fullName => 'Nom complet';

  @override
  String get schoolName => 'Établissement scolaire';

  @override
  String get loginAction => 'Se connecter';

  @override
  String get registerAction => 'Créer le compte';

  @override
  String get noAccount => 'Pas de compte ? Inscrivez-vous';

  @override
  String get haveAccount => 'Déjà un compte ? Connectez-vous';

  @override
  String get logout => 'Se déconnecter';

  @override
  String greetingTeacher(String name) {
    return 'Bonjour, $name';
  }

  @override
  String get classesTitle => 'Classes et Cours';

  @override
  String get studentsTitle => 'Élèves';

  @override
  String get addClass => 'Ajouter une classe';

  @override
  String get className => 'Nom de la classe';

  @override
  String get classLevel => 'Niveau scolaire';

  @override
  String get subjectName => 'Matière';

  @override
  String get addStudent => 'Ajouter un élève';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get studentNumber => 'Identifiant (optionnel)';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get noClassesYet => 'Aucune classe enregistrée pour le moment';

  @override
  String get noStudentsYet => 'Aucun élève enregistré pour le moment';

  @override
  String studentsCount(int count) {
    return '$count élèves';
  }

  @override
  String get todayClasses => 'Emploi du temps';

  @override
  String get searchStudents => 'Rechercher un élève...';

  @override
  String get notes => 'Observations';

  @override
  String get addNote => 'Ajouter une note';

  @override
  String get noteHint => 'Écrire une observation factuelle...';

  @override
  String get pinUnlock => 'Déverrouillage par code PIN';

  @override
  String get enterPin => 'Entrez votre code PIN pour continuer';
}
