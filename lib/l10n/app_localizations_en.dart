// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Voice of the constituency';

  @override
  String get tabCitizen => 'Citizen';

  @override
  String get tabMpOffice => 'MP office';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get constituencyId => 'Constituency ID';

  @override
  String get password => 'Password';

  @override
  String get couldNotSignInOfficial =>
      'Could not sign in. Check your constituency ID and password.';

  @override
  String get citizenIntro =>
      'Share a development suggestion or report a civic problem — in your own language, by voice, text or photo.';

  @override
  String get welcomeAnonymityNote =>
      'You stay anonymous to other citizens. Your Aadhaar number is never stored. Your MP\'s office sees aggregated demand, not your identity.';

  @override
  String get newHereSignUp => 'New here? Sign Up';

  @override
  String get alreadyHaveAccountSignIn => 'I already have an account — Sign In';

  @override
  String get aadhaarPrivacyNote =>
      'Upload a photo of your Aadhaar so we can read your name and address. We keep only your name, address and pincode — the photo and your Aadhaar number are never saved. This is not ID verification; you can also just type your details below.';

  @override
  String get aadhaarUploadNote =>
      'Upload photos of your Aadhaar (front and back) so we can read your name and address — the back side often has your full address, so capturing it too gives more accurate results. We keep only your name, address, pincode and ward number — the photos and your Aadhaar number are never saved. This is not ID verification, and both photos are optional — you can always just type your details below.';

  @override
  String get slotFront => 'Front';

  @override
  String get slotBack => 'Back';

  @override
  String get alreadyHaveAccountSignInShort =>
      'Already have an account? Sign In';

  @override
  String get aadhaarBackNote =>
      'Tip: capture the BACK of your Aadhaar too — it often has your full address the front leaves out. Both sides are optional.';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

  @override
  String get extractDetails => 'Extract details';

  @override
  String get couldNotReadClearly =>
      'Couldn\'t read that clearly — check the details below or enter them manually.';

  @override
  String get couldNotProcessImage =>
      'Couldn\'t process that image right now — enter your details manually below.';

  @override
  String get hideManualEntry => 'Hide manual entry';

  @override
  String get skipEnterManually => 'Skip — I\'ll enter manually';

  @override
  String get fullName => 'Full name';

  @override
  String get pincode => 'Pincode';

  @override
  String get wardNumberOptional => 'Ward number (optional)';

  @override
  String get useMyLocation => 'Use my location';

  @override
  String get updateMyLocation => 'Update my location';

  @override
  String get tapMapToAdjust => 'Tap the map to adjust your exact location.';

  @override
  String get continueLabel => 'Continue';

  @override
  String get verifyWithPhone => 'Verify with your phone number';

  @override
  String get mobileNumberHint => '10-digit mobile number';

  @override
  String get sendCode => 'Send code';

  @override
  String get sixDigitCode => '6-digit code';

  @override
  String get verifyAndContinue => 'Verify & continue';

  @override
  String get verifyAndSignIn => 'Verify & sign in';

  @override
  String get enterValidMobile => 'Enter a valid 10-digit mobile number.';

  @override
  String get codeDidntMatch =>
      'That code didn\'t match — check it and try again.';

  @override
  String get couldNotContinue =>
      'Could not continue — check your connection and try again.';

  @override
  String get skipStayAnonymous => 'Skip — stay anonymous';

  @override
  String get aggregatedDemandNote =>
      'Whichever way you sign in, your MP\'s office only ever sees aggregated demand, never your identity.';

  @override
  String get welcomeBack =>
      'Welcome back — sign in with the phone number you signed up with.';

  @override
  String get noAccountFound =>
      'No account found for this number — please Sign Up first.';

  @override
  String get dontHaveAccountSignUp => 'Don\'t have an account? Sign Up';

  @override
  String get yourName => 'Your name';

  @override
  String get age => 'Age';

  @override
  String get next => 'Next';

  @override
  String get youAreSetUp => 'You\'re set up';

  @override
  String get setUpBody =>
      'You can now submit development suggestions and report problems in your area.';

  @override
  String get enterApp => 'Enter app';

  @override
  String get reportByVoice => 'Report by Voice';

  @override
  String get suggestByVoice => 'Suggest by Voice';

  @override
  String get reRecord => 'Re-record';

  @override
  String get convertingVoiceToText => 'Converting your voice to text…';

  @override
  String get yourWordsEditIfNeeded => 'Your words (edit if needed)';

  @override
  String get spokenReportAppearsHere => 'Your spoken report appears here…';

  @override
  String get couldNotConvertVoice =>
      'Couldn\'t convert your voice to text — you can type it below or re-record.';

  @override
  String get tryConvertingAgain => 'Try converting again';

  @override
  String get pickCategoryOptional => 'Pick a category (optional)';

  @override
  String get submitReport => 'Submit Report';

  @override
  String get submitSuggestion => 'Submit Suggestion';
}
