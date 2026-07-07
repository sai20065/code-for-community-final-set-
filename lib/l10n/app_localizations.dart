import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_bn.dart';
import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_kn.dart';
import 'app_localizations_ml.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_ta.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('bn'),
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
    Locale('kn'),
    Locale('ml'),
    Locale('mr'),
    Locale('pa'),
    Locale('ta'),
    Locale('te')
  ];

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Voice of the constituency'**
  String get appTagline;

  /// No description provided for @tabCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get tabCitizen;

  /// No description provided for @tabMpOffice.
  ///
  /// In en, this message translates to:
  /// **'MP office'**
  String get tabMpOffice;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @constituencyId.
  ///
  /// In en, this message translates to:
  /// **'Constituency ID'**
  String get constituencyId;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @couldNotSignInOfficial.
  ///
  /// In en, this message translates to:
  /// **'Could not sign in. Check your constituency ID and password.'**
  String get couldNotSignInOfficial;

  /// No description provided for @citizenIntro.
  ///
  /// In en, this message translates to:
  /// **'Share a development suggestion or report a civic problem — in your own language, by voice, text or photo.'**
  String get citizenIntro;

  /// No description provided for @welcomeAnonymityNote.
  ///
  /// In en, this message translates to:
  /// **'You stay anonymous to other citizens. Your Aadhaar number is never stored. Your MP\'s office sees aggregated demand, not your identity.'**
  String get welcomeAnonymityNote;

  /// No description provided for @newHereSignUp.
  ///
  /// In en, this message translates to:
  /// **'New here? Sign Up'**
  String get newHereSignUp;

  /// No description provided for @alreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'I already have an account — Sign In'**
  String get alreadyHaveAccountSignIn;

  /// No description provided for @aadhaarPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Upload a photo of your Aadhaar so we can read your name and address. We keep only your name, address and pincode — the photo and your Aadhaar number are never saved. This is not ID verification; you can also just type your details below.'**
  String get aadhaarPrivacyNote;

  /// No description provided for @aadhaarUploadNote.
  ///
  /// In en, this message translates to:
  /// **'Upload photos of your Aadhaar (front and back) so we can read your name and address — the back side often has your full address, so capturing it too gives more accurate results. We keep only your name, address, pincode and ward number — the photos and your Aadhaar number are never saved. This is not ID verification, and both photos are optional — you can always just type your details below.'**
  String get aadhaarUploadNote;

  /// No description provided for @slotFront.
  ///
  /// In en, this message translates to:
  /// **'Front'**
  String get slotFront;

  /// No description provided for @slotBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get slotBack;

  /// No description provided for @alreadyHaveAccountSignInShort.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign In'**
  String get alreadyHaveAccountSignInShort;

  /// No description provided for @aadhaarBackNote.
  ///
  /// In en, this message translates to:
  /// **'Tip: capture the BACK of your Aadhaar too — it often has your full address the front leaves out. Both sides are optional.'**
  String get aadhaarBackNote;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @extractDetails.
  ///
  /// In en, this message translates to:
  /// **'Extract details'**
  String get extractDetails;

  /// No description provided for @couldNotReadClearly.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t read that clearly — check the details below or enter them manually.'**
  String get couldNotReadClearly;

  /// No description provided for @couldNotProcessImage.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process that image right now — enter your details manually below.'**
  String get couldNotProcessImage;

  /// No description provided for @hideManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Hide manual entry'**
  String get hideManualEntry;

  /// No description provided for @skipEnterManually.
  ///
  /// In en, this message translates to:
  /// **'Skip — I\'ll enter manually'**
  String get skipEnterManually;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @pincode.
  ///
  /// In en, this message translates to:
  /// **'Pincode'**
  String get pincode;

  /// No description provided for @wardNumberOptional.
  ///
  /// In en, this message translates to:
  /// **'Ward number (optional)'**
  String get wardNumberOptional;

  /// No description provided for @useMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Use my location'**
  String get useMyLocation;

  /// No description provided for @updateMyLocation.
  ///
  /// In en, this message translates to:
  /// **'Update my location'**
  String get updateMyLocation;

  /// No description provided for @tapMapToAdjust.
  ///
  /// In en, this message translates to:
  /// **'Tap the map to adjust your exact location.'**
  String get tapMapToAdjust;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @verifyWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify with your phone number'**
  String get verifyWithPhone;

  /// No description provided for @mobileNumberHint.
  ///
  /// In en, this message translates to:
  /// **'10-digit mobile number'**
  String get mobileNumberHint;

  /// No description provided for @sendCode.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// No description provided for @sixDigitCode.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get sixDigitCode;

  /// No description provided for @verifyAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & continue'**
  String get verifyAndContinue;

  /// No description provided for @verifyAndSignIn.
  ///
  /// In en, this message translates to:
  /// **'Verify & sign in'**
  String get verifyAndSignIn;

  /// No description provided for @enterValidMobile.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit mobile number.'**
  String get enterValidMobile;

  /// No description provided for @codeDidntMatch.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t match — check it and try again.'**
  String get codeDidntMatch;

  /// No description provided for @couldNotContinue.
  ///
  /// In en, this message translates to:
  /// **'Could not continue — check your connection and try again.'**
  String get couldNotContinue;

  /// No description provided for @skipStayAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Skip — stay anonymous'**
  String get skipStayAnonymous;

  /// No description provided for @aggregatedDemandNote.
  ///
  /// In en, this message translates to:
  /// **'Whichever way you sign in, your MP\'s office only ever sees aggregated demand, never your identity.'**
  String get aggregatedDemandNote;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back — sign in with the phone number you signed up with.'**
  String get welcomeBack;

  /// No description provided for @noAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found for this number — please Sign Up first.'**
  String get noAccountFound;

  /// No description provided for @dontHaveAccountSignUp.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? Sign Up'**
  String get dontHaveAccountSignUp;

  /// No description provided for @yourName.
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get yourName;

  /// No description provided for @age.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get age;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @youAreSetUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re set up'**
  String get youAreSetUp;

  /// No description provided for @setUpBody.
  ///
  /// In en, this message translates to:
  /// **'You can now submit development suggestions and report problems in your area.'**
  String get setUpBody;

  /// No description provided for @enterApp.
  ///
  /// In en, this message translates to:
  /// **'Enter app'**
  String get enterApp;

  /// No description provided for @reportByVoice.
  ///
  /// In en, this message translates to:
  /// **'Report by Voice'**
  String get reportByVoice;

  /// No description provided for @suggestByVoice.
  ///
  /// In en, this message translates to:
  /// **'Suggest by Voice'**
  String get suggestByVoice;

  /// No description provided for @reRecord.
  ///
  /// In en, this message translates to:
  /// **'Re-record'**
  String get reRecord;

  /// No description provided for @convertingVoiceToText.
  ///
  /// In en, this message translates to:
  /// **'Converting your voice to text…'**
  String get convertingVoiceToText;

  /// No description provided for @yourWordsEditIfNeeded.
  ///
  /// In en, this message translates to:
  /// **'Your words (edit if needed)'**
  String get yourWordsEditIfNeeded;

  /// No description provided for @spokenReportAppearsHere.
  ///
  /// In en, this message translates to:
  /// **'Your spoken report appears here…'**
  String get spokenReportAppearsHere;

  /// No description provided for @couldNotConvertVoice.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t convert your voice to text — you can type it below or re-record.'**
  String get couldNotConvertVoice;

  /// No description provided for @tryConvertingAgain.
  ///
  /// In en, this message translates to:
  /// **'Try converting again'**
  String get tryConvertingAgain;

  /// No description provided for @pickCategoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Pick a category (optional)'**
  String get pickCategoryOptional;

  /// No description provided for @submitReport.
  ///
  /// In en, this message translates to:
  /// **'Submit Report'**
  String get submitReport;

  /// No description provided for @submitSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Submit Suggestion'**
  String get submitSuggestion;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'bn',
        'en',
        'gu',
        'hi',
        'kn',
        'ml',
        'mr',
        'pa',
        'ta',
        'te'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'bn':
      return AppLocalizationsBn();
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
    case 'kn':
      return AppLocalizationsKn();
    case 'ml':
      return AppLocalizationsMl();
    case 'mr':
      return AppLocalizationsMr();
    case 'pa':
      return AppLocalizationsPa();
    case 'ta':
      return AppLocalizationsTa();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
