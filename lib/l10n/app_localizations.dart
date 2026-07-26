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
  /// **'Voice of the People'**
  String get appTagline;

  /// No description provided for @tabCitizen.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get tabCitizen;

  /// No description provided for @tabMpOffice.
  ///
  /// In en, this message translates to:
  /// **'Government access'**
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

  /// No description provided for @newSubmission.
  ///
  /// In en, this message translates to:
  /// **'New submission'**
  String get newSubmission;

  /// No description provided for @whatWouldYouLikeToDo.
  ///
  /// In en, this message translates to:
  /// **'What would you like to do?'**
  String get whatWouldYouLikeToDo;

  /// No description provided for @reportAProblem.
  ///
  /// In en, this message translates to:
  /// **'Report a problem'**
  String get reportAProblem;

  /// No description provided for @reportProblemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Something broken or unsafe near you'**
  String get reportProblemSubtitle;

  /// No description provided for @suggestDevelopmentWork.
  ///
  /// In en, this message translates to:
  /// **'Suggest a development work'**
  String get suggestDevelopmentWork;

  /// No description provided for @suggestSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Something new your area needs'**
  String get suggestSubtitle;

  /// No description provided for @shareYourSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Share Your Suggestion'**
  String get shareYourSuggestion;

  /// No description provided for @describeTheProblem.
  ///
  /// In en, this message translates to:
  /// **'Describe the Problem'**
  String get describeTheProblem;

  /// No description provided for @suggestionHint.
  ///
  /// In en, this message translates to:
  /// **'What development work would help your area? (e.g. A skilling centre near the bus stand)'**
  String get suggestionHint;

  /// No description provided for @problemHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s the problem? (e.g. Streetlight not working)'**
  String get problemHint;

  /// No description provided for @addAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a Photo'**
  String get addAPhoto;

  /// No description provided for @captionOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a caption (optional)'**
  String get captionOptional;

  /// No description provided for @receiptCopied.
  ///
  /// In en, this message translates to:
  /// **'Receipt number copied'**
  String get receiptCopied;

  /// No description provided for @badgeSuggestion.
  ///
  /// In en, this message translates to:
  /// **'Suggestion'**
  String get badgeSuggestion;

  /// No description provided for @badgeReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get badgeReport;

  /// No description provided for @savedInstantlyNote.
  ///
  /// In en, this message translates to:
  /// **'Saved instantly. AI enrichment continues in the background — you\'ll see updates in Mine.'**
  String get savedInstantlyNote;

  /// No description provided for @trackThisTicket.
  ///
  /// In en, this message translates to:
  /// **'Track this ticket'**
  String get trackThisTicket;

  /// No description provided for @copyReceipt.
  ///
  /// In en, this message translates to:
  /// **'Copy receipt'**
  String get copyReceipt;

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to Home'**
  String get backToHome;

  /// No description provided for @routedTo.
  ///
  /// In en, this message translates to:
  /// **'Routed to {constituency}'**
  String routedTo(String constituency);

  /// No description provided for @looksLike.
  ///
  /// In en, this message translates to:
  /// **'Looks like: {theme}'**
  String looksLike(String theme);

  /// No description provided for @similarOpenProblems.
  ///
  /// In en, this message translates to:
  /// **'There are {count} similar open problems in this booth — your report will be added'**
  String similarOpenProblems(int count);

  /// No description provided for @othersAskedToo.
  ///
  /// In en, this message translates to:
  /// **'{count} others nearby have asked for this too'**
  String othersAskedToo(int count);

  /// No description provided for @greetingHi.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String greetingHi(String name);

  /// No description provided for @homeAreaLabel.
  ///
  /// In en, this message translates to:
  /// **'Home: {area}'**
  String homeAreaLabel(String area);

  /// No description provided for @boothLabel.
  ///
  /// In en, this message translates to:
  /// **'Booth {name}'**
  String boothLabel(String name);

  /// No description provided for @pincodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Pincode {pincode}'**
  String pincodeLabel(String pincode);

  /// No description provided for @myTickets.
  ///
  /// In en, this message translates to:
  /// **'My tickets'**
  String get myTickets;

  /// No description provided for @trendingNearYou.
  ///
  /// In en, this message translates to:
  /// **'Trending near you'**
  String get trendingNearYou;

  /// No description provided for @emptyAreaSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions from your constituency will appear here once your area is confirmed.'**
  String get emptyAreaSuggestions;

  /// No description provided for @couldNotLoadSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Could not load suggestions.'**
  String get couldNotLoadSuggestions;

  /// No description provided for @yourRecentReports.
  ///
  /// In en, this message translates to:
  /// **'Your recent reports'**
  String get yourRecentReports;

  /// No description provided for @noSuggestionsYet.
  ///
  /// In en, this message translates to:
  /// **'No suggestions yet — be the first to submit one for your area.'**
  String get noSuggestionsYet;

  /// No description provided for @supportersCount.
  ///
  /// In en, this message translates to:
  /// **'{count} supporters'**
  String supportersCount(int count);

  /// No description provided for @supported.
  ///
  /// In en, this message translates to:
  /// **'Supported'**
  String get supported;

  /// No description provided for @iSupportThis.
  ///
  /// In en, this message translates to:
  /// **'I support this'**
  String get iSupportThis;

  /// No description provided for @suggestionUpper.
  ///
  /// In en, this message translates to:
  /// **'SUGGESTION'**
  String get suggestionUpper;

  /// No description provided for @myTicketsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Tickets'**
  String get myTicketsTitle;

  /// No description provided for @pleaseSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get pleaseSignIn;

  /// No description provided for @noTicketsYet.
  ///
  /// In en, this message translates to:
  /// **'No tickets yet'**
  String get noTicketsYet;

  /// No description provided for @receiptLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt: {token}'**
  String receiptLabel(String token);

  /// No description provided for @inDevelopmentPlan.
  ///
  /// In en, this message translates to:
  /// **'In development plan'**
  String get inDevelopmentPlan;

  /// No description provided for @underReview.
  ///
  /// In en, this message translates to:
  /// **'Under review'**
  String get underReview;

  /// No description provided for @ticketNotFound.
  ///
  /// In en, this message translates to:
  /// **'Ticket not found'**
  String get ticketNotFound;

  /// No description provided for @ticketLabel.
  ///
  /// In en, this message translates to:
  /// **'Ticket'**
  String get ticketLabel;

  /// No description provided for @noDescription.
  ///
  /// In en, this message translates to:
  /// **'No description'**
  String get noDescription;

  /// No description provided for @seeDetails.
  ///
  /// In en, this message translates to:
  /// **'See details (transcript/translation)'**
  String get seeDetails;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @citizenDefault.
  ///
  /// In en, this message translates to:
  /// **'Citizen'**
  String get citizenDefault;

  /// No description provided for @homeConstituency.
  ///
  /// In en, this message translates to:
  /// **'Home constituency'**
  String get homeConstituency;

  /// No description provided for @notYetMatched.
  ///
  /// In en, this message translates to:
  /// **'Not yet matched'**
  String get notYetMatched;

  /// No description provided for @homeBooth.
  ///
  /// In en, this message translates to:
  /// **'Home booth'**
  String get homeBooth;

  /// No description provided for @preferredLanguage.
  ///
  /// In en, this message translates to:
  /// **'Preferred language'**
  String get preferredLanguage;

  /// No description provided for @privacyStoreAddress.
  ///
  /// In en, this message translates to:
  /// **'We store your address to route your submissions to the right MP. Your 12-digit Aadhaar number is never stored.'**
  String get privacyStoreAddress;

  /// No description provided for @signOutClears.
  ///
  /// In en, this message translates to:
  /// **'Sign out (clears this device)'**
  String get signOutClears;

  /// No description provided for @couldNotLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Could not load your profile.'**
  String get couldNotLoadProfile;

  /// No description provided for @statusFiled.
  ///
  /// In en, this message translates to:
  /// **'Filed'**
  String get statusFiled;

  /// No description provided for @statusAcknowledged.
  ///
  /// In en, this message translates to:
  /// **'Acknowledged'**
  String get statusAcknowledged;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get statusResolved;

  /// No description provided for @receiptWeGotThis.
  ///
  /// In en, this message translates to:
  /// **'We\'ve got this'**
  String get receiptWeGotThis;

  /// No description provided for @yourAddressStreet.
  ///
  /// In en, this message translates to:
  /// **'Your address (street, area)'**
  String get yourAddressStreet;

  /// No description provided for @tapMapToMovePin.
  ///
  /// In en, this message translates to:
  /// **'Tap anywhere on the map to move the pin to your exact location'**
  String get tapMapToMovePin;

  /// No description provided for @homeAreaWillConfirm.
  ///
  /// In en, this message translates to:
  /// **'Home constituency and booth will be confirmed once matched to your area.'**
  String get homeAreaWillConfirm;

  /// No description provided for @homeConstituencyBooth.
  ///
  /// In en, this message translates to:
  /// **'Home constituency: {constituency} · Home booth: {booth}'**
  String homeConstituencyBooth(String constituency, String booth);

  /// No description provided for @looksRight.
  ///
  /// In en, this message translates to:
  /// **'Looks right'**
  String get looksRight;

  /// No description provided for @thisIsntMe.
  ///
  /// In en, this message translates to:
  /// **'This isn\'t me'**
  String get thisIsntMe;

  /// No description provided for @pillCurrentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get pillCurrentLocation;

  /// No description provided for @pillAtMyHome.
  ///
  /// In en, this message translates to:
  /// **'At my home'**
  String get pillAtMyHome;

  /// No description provided for @pillDropPin.
  ///
  /// In en, this message translates to:
  /// **'Drop a pin'**
  String get pillDropPin;

  /// No description provided for @locationRoutedNote.
  ///
  /// In en, this message translates to:
  /// **'Routed to your home MP · pin only sets where this shows on the map.'**
  String get locationRoutedNote;

  /// No description provided for @locationFailPickMap.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location — pick a spot on the map instead.'**
  String get locationFailPickMap;

  /// No description provided for @locationFailUseHome.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get your location — using your home address instead.'**
  String get locationFailUseHome;

  /// No description provided for @constituencyDashboard.
  ///
  /// In en, this message translates to:
  /// **'Constituency Dashboard'**
  String get constituencyDashboard;

  /// No description provided for @notLinkedConstituency.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t linked to a constituency yet.'**
  String get notLinkedConstituency;

  /// No description provided for @newThisWeek.
  ///
  /// In en, this message translates to:
  /// **'New this week'**
  String get newThisWeek;

  /// No description provided for @resolvedRate.
  ///
  /// In en, this message translates to:
  /// **'Resolved rate'**
  String get resolvedRate;

  /// No description provided for @avgResponseTime.
  ///
  /// In en, this message translates to:
  /// **'Avg response time'**
  String get avgResponseTime;

  /// No description provided for @daysValue.
  ///
  /// In en, this message translates to:
  /// **'{value} days'**
  String daysValue(String value);

  /// No description provided for @constituencyMap.
  ///
  /// In en, this message translates to:
  /// **'Constituency Map'**
  String get constituencyMap;

  /// No description provided for @openConstituencyMap.
  ///
  /// In en, this message translates to:
  /// **'Open constituency map'**
  String get openConstituencyMap;

  /// No description provided for @rankedWorks.
  ///
  /// In en, this message translates to:
  /// **'Ranked Works'**
  String get rankedWorks;

  /// No description provided for @themesOverview.
  ///
  /// In en, this message translates to:
  /// **'Themes Overview'**
  String get themesOverview;

  /// No description provided for @problemReports.
  ///
  /// In en, this message translates to:
  /// **'Problem Reports'**
  String get problemReports;

  /// No description provided for @ticketsByTheme.
  ///
  /// In en, this message translates to:
  /// **'Tickets by theme'**
  String get ticketsByTheme;

  /// No description provided for @noClusteredTickets.
  ///
  /// In en, this message translates to:
  /// **'No clustered tickets yet.'**
  String get noClusteredTickets;

  /// No description provided for @couldNotLoadThemes.
  ///
  /// In en, this message translates to:
  /// **'Could not load themes.'**
  String get couldNotLoadThemes;

  /// No description provided for @weeklyTrend.
  ///
  /// In en, this message translates to:
  /// **'Weekly trend'**
  String get weeklyTrend;

  /// No description provided for @boothDemandMap.
  ///
  /// In en, this message translates to:
  /// **'Booth-Level Demand Map'**
  String get boothDemandMap;

  /// No description provided for @noBoothData.
  ///
  /// In en, this message translates to:
  /// **'No booth reference data for this constituency yet.'**
  String get noBoothData;

  /// No description provided for @couldNotLoadBooths.
  ///
  /// In en, this message translates to:
  /// **'Could not load booths.'**
  String get couldNotLoadBooths;

  /// No description provided for @openIssueDensity.
  ///
  /// In en, this message translates to:
  /// **'Open-issue density'**
  String get openIssueDensity;

  /// No description provided for @densityHigh.
  ///
  /// In en, this message translates to:
  /// **'High — needs attention'**
  String get densityHigh;

  /// No description provided for @densityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get densityModerate;

  /// No description provided for @densityLow.
  ///
  /// In en, this message translates to:
  /// **'Low / mostly resolved'**
  String get densityLow;

  /// No description provided for @dotSizeVolume.
  ///
  /// In en, this message translates to:
  /// **'Dot size = submission volume'**
  String get dotSizeVolume;

  /// No description provided for @hotspotFlameNote.
  ///
  /// In en, this message translates to:
  /// **'🔥 = urgent hotspot'**
  String get hotspotFlameNote;

  /// No description provided for @searchByTicketId.
  ///
  /// In en, this message translates to:
  /// **'Search by ticket ID'**
  String get searchByTicketId;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(int count);

  /// No description provided for @markInProgress.
  ///
  /// In en, this message translates to:
  /// **'Mark In Progress'**
  String get markInProgress;

  /// No description provided for @markResolved.
  ///
  /// In en, this message translates to:
  /// **'Mark Resolved'**
  String get markResolved;

  /// No description provided for @noProblemReports.
  ///
  /// In en, this message translates to:
  /// **'No problem reports yet.'**
  String get noProblemReports;

  /// No description provided for @couldNotLoadTickets.
  ///
  /// In en, this message translates to:
  /// **'Could not load tickets.'**
  String get couldNotLoadTickets;

  /// No description provided for @wardConstituency.
  ///
  /// In en, this message translates to:
  /// **'Ward · {constituency}'**
  String wardConstituency(String constituency);

  /// No description provided for @submissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} submissions'**
  String submissionsCount(int count);

  /// No description provided for @otherRecurringThemes.
  ///
  /// In en, this message translates to:
  /// **'Other recurring themes here'**
  String get otherRecurringThemes;

  /// No description provided for @noOtherThemes.
  ///
  /// In en, this message translates to:
  /// **'No other recurring themes clustered here yet.'**
  String get noOtherThemes;

  /// No description provided for @couldNotLoadClusters.
  ///
  /// In en, this message translates to:
  /// **'Could not load clusters.'**
  String get couldNotLoadClusters;

  /// No description provided for @sampleTickets.
  ///
  /// In en, this message translates to:
  /// **'Sample tickets'**
  String get sampleTickets;

  /// No description provided for @openCount.
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String openCount(int count);

  /// No description provided for @whyItRecurs.
  ///
  /// In en, this message translates to:
  /// **'WHY IT RECURS'**
  String get whyItRecurs;

  /// No description provided for @whyHappeningHere.
  ///
  /// In en, this message translates to:
  /// **'WHY IT\'S HAPPENING HERE'**
  String get whyHappeningHere;

  /// No description provided for @whyRecursBody.
  ///
  /// In en, this message translates to:
  /// **'{count} citizens have reported this in {booth}. \"{summary}\"'**
  String whyRecursBody(int count, String booth, String summary);

  /// No description provided for @themeIssuesReportedHere.
  ///
  /// In en, this message translates to:
  /// **'{theme} issues reported here'**
  String themeIssuesReportedHere(String theme);

  /// No description provided for @noLocalContext.
  ///
  /// In en, this message translates to:
  /// **'No additional local context recorded for this booth yet.'**
  String get noLocalContext;

  /// No description provided for @suggestedWork.
  ///
  /// In en, this message translates to:
  /// **'Suggested work: {work}'**
  String suggestedWork(String work);

  /// No description provided for @seeInRankedWorks.
  ///
  /// In en, this message translates to:
  /// **'See in ranked works'**
  String get seeInRankedWorks;

  /// No description provided for @aiGeneratedSummary.
  ///
  /// In en, this message translates to:
  /// **'AI-generated summary · via Gemini'**
  String get aiGeneratedSummary;

  /// No description provided for @priorityValue.
  ///
  /// In en, this message translates to:
  /// **'Priority {value}'**
  String priorityValue(String value);

  /// No description provided for @ticketsInBooth.
  ///
  /// In en, this message translates to:
  /// **'{theme} tickets in this booth'**
  String ticketsInBooth(String theme);

  /// No description provided for @rankedDevelopmentWorks.
  ///
  /// In en, this message translates to:
  /// **'Ranked Development Works'**
  String get rankedDevelopmentWorks;

  /// No description provided for @compare.
  ///
  /// In en, this message translates to:
  /// **'Compare'**
  String get compare;

  /// No description provided for @noRankedWorks.
  ///
  /// In en, this message translates to:
  /// **'No ranked works yet.'**
  String get noRankedWorks;

  /// No description provided for @couldNotLoadRankedWorks.
  ///
  /// In en, this message translates to:
  /// **'Could not load ranked works.'**
  String get couldNotLoadRankedWorks;

  /// No description provided for @rankingWeightsAdjust.
  ///
  /// In en, this message translates to:
  /// **'Ranking weights — adjust to re-rank'**
  String get rankingWeightsAdjust;

  /// No description provided for @weightDemand.
  ///
  /// In en, this message translates to:
  /// **'Demand'**
  String get weightDemand;

  /// No description provided for @weightDemographic.
  ///
  /// In en, this message translates to:
  /// **'Demographic'**
  String get weightDemographic;

  /// No description provided for @weightInfraGap.
  ///
  /// In en, this message translates to:
  /// **'Infra gap'**
  String get weightInfraGap;

  /// No description provided for @changesSavedAudit.
  ///
  /// In en, this message translates to:
  /// **'Changes saved to audit log'**
  String get changesSavedAudit;

  /// No description provided for @whyExpand.
  ///
  /// In en, this message translates to:
  /// **'+ Why?'**
  String get whyExpand;

  /// No description provided for @hideLabel.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get hideLabel;

  /// No description provided for @ticketsShort.
  ///
  /// In en, this message translates to:
  /// **'{count} tickets'**
  String ticketsShort(int count);

  /// No description provided for @recurringDemand.
  ///
  /// In en, this message translates to:
  /// **'{theme} — recurring demand'**
  String recurringDemand(String theme);

  /// No description provided for @ticketsRecordedHere.
  ///
  /// In en, this message translates to:
  /// **'{count} tickets recorded here'**
  String ticketsRecordedHere(int count);

  /// No description provided for @fragDemand.
  ///
  /// In en, this message translates to:
  /// **'demand {value}'**
  String fragDemand(String value);

  /// No description provided for @fragDemographic.
  ///
  /// In en, this message translates to:
  /// **'demographic weight {value}'**
  String fragDemographic(String value);

  /// No description provided for @fragInfraGap.
  ///
  /// In en, this message translates to:
  /// **'infra-gap {value}'**
  String fragInfraGap(String value);

  /// No description provided for @fragAffects.
  ///
  /// In en, this message translates to:
  /// **'affects {range}'**
  String fragAffects(String range);

  /// No description provided for @compareProposals.
  ///
  /// In en, this message translates to:
  /// **'Compare Proposals'**
  String get compareProposals;

  /// No description provided for @needTwoToCompare.
  ///
  /// In en, this message translates to:
  /// **'Need at least two ranked works to compare.'**
  String get needTwoToCompare;

  /// No description provided for @couldNotLoadProposals.
  ///
  /// In en, this message translates to:
  /// **'Could not load proposals.'**
  String get couldNotLoadProposals;

  /// No description provided for @proposalA.
  ///
  /// In en, this message translates to:
  /// **'Proposal A'**
  String get proposalA;

  /// No description provided for @proposalB.
  ///
  /// In en, this message translates to:
  /// **'Proposal B'**
  String get proposalB;

  /// No description provided for @recurringDemandShort.
  ///
  /// In en, this message translates to:
  /// **'{theme} recurring demand'**
  String recurringDemandShort(String theme);

  /// No description provided for @statCitizenDemand.
  ///
  /// In en, this message translates to:
  /// **'Citizen demand'**
  String get statCitizenDemand;

  /// No description provided for @statDemographicWeight.
  ///
  /// In en, this message translates to:
  /// **'Demographic weight'**
  String get statDemographicWeight;

  /// No description provided for @statInfraGapWeight.
  ///
  /// In en, this message translates to:
  /// **'Infra-gap weight'**
  String get statInfraGapWeight;

  /// No description provided for @statTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get statTickets;

  /// No description provided for @aiTradeOffBrief.
  ///
  /// In en, this message translates to:
  /// **'AI trade-off brief'**
  String get aiTradeOffBrief;

  /// No description provided for @groundedInEvidence.
  ///
  /// In en, this message translates to:
  /// **'grounded in evidence'**
  String get groundedInEvidence;

  /// No description provided for @briefWhoBenefits.
  ///
  /// In en, this message translates to:
  /// **'Who benefits'**
  String get briefWhoBenefits;

  /// No description provided for @briefWhatDataSays.
  ///
  /// In en, this message translates to:
  /// **'What the data says'**
  String get briefWhatDataSays;

  /// No description provided for @briefWhatDefers.
  ///
  /// In en, this message translates to:
  /// **'What each defers'**
  String get briefWhatDefers;

  /// No description provided for @benefitsWithRange.
  ///
  /// In en, this message translates to:
  /// **'{name} reaches {range} ({count} tickets recorded).'**
  String benefitsWithRange(String name, String range, int count);

  /// No description provided for @benefitsNoRange.
  ///
  /// In en, this message translates to:
  /// **'{name} has {count} citizen tickets behind it constituency-wide.'**
  String benefitsNoRange(String name, int count);

  /// No description provided for @dataHigherComposite.
  ///
  /// In en, this message translates to:
  /// **'{winner} has a higher overall composite score than {loser}.'**
  String dataHigherComposite(String winner, String loser);

  /// No description provided for @dataLeads.
  ///
  /// In en, this message translates to:
  /// **'{winner} leads {loser} on {reasons}.'**
  String dataLeads(String winner, String loser, String reasons);

  /// No description provided for @reasonTickets.
  ///
  /// In en, this message translates to:
  /// **'{winnerCount} citizen tickets vs. {loserCount}'**
  String reasonTickets(int winnerCount, int loserCount);

  /// No description provided for @reasonDemographic.
  ///
  /// In en, this message translates to:
  /// **'a higher demographic-reach weight ({winner} vs. {loser})'**
  String reasonDemographic(String winner, String loser);

  /// No description provided for @reasonInfra.
  ///
  /// In en, this message translates to:
  /// **'a larger existing infrastructure gap ({winner} vs. {loser})'**
  String reasonInfra(String winner, String loser);

  /// No description provided for @defersLine.
  ///
  /// In en, this message translates to:
  /// **'{count} tickets for {loser}{rangeSuffix} wait for a later cycle if {winner} is prioritised now.'**
  String defersLine(int count, String loser, String rangeSuffix, String winner);

  /// No description provided for @recommendationLine.
  ///
  /// In en, this message translates to:
  /// **'Recommendation: prioritise {winner} this cycle.'**
  String recommendationLine(String winner);

  /// No description provided for @yourMp.
  ///
  /// In en, this message translates to:
  /// **'Your MP'**
  String get yourMp;

  /// No description provided for @yourConstituency.
  ///
  /// In en, this message translates to:
  /// **'{name} constituency'**
  String yourConstituency(String name);

  /// No description provided for @noMpAssignedYet.
  ///
  /// In en, this message translates to:
  /// **'MP details aren\'t available for your area yet'**
  String get noMpAssignedYet;

  /// No description provided for @couldNotSubmitTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit — please check your connection and try again'**
  String get couldNotSubmitTryAgain;

  /// No description provided for @generateReport.
  ///
  /// In en, this message translates to:
  /// **'Generate constituency report'**
  String get generateReport;

  /// No description provided for @couldNotGenerateReport.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate the report — please try again'**
  String get couldNotGenerateReport;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong — please try again'**
  String get somethingWentWrong;

  /// No description provided for @mpFirstTimeSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'First-time MP setup'**
  String get mpFirstTimeSetupTitle;

  /// No description provided for @mpForgotCredentialsTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot credentials'**
  String get mpForgotCredentialsTitle;

  /// No description provided for @mpFirstTimeSetupHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the unique identification number issued to your constituency and your email address — we\'ll send your login credentials to that email.'**
  String get mpFirstTimeSetupHint;

  /// No description provided for @mpForgotCredentialsHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your constituency\'s unique identification number and the email you registered — we\'ll send your login credentials to that email.'**
  String get mpForgotCredentialsHint;

  /// No description provided for @mpUniqueId.
  ///
  /// In en, this message translates to:
  /// **'Unique identification number'**
  String get mpUniqueId;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailAddress;

  /// No description provided for @sendMyCredentials.
  ///
  /// In en, this message translates to:
  /// **'Send my credentials'**
  String get sendMyCredentials;

  /// No description provided for @credentialsSentTo.
  ///
  /// In en, this message translates to:
  /// **'Credentials sent to {email}'**
  String credentialsSentTo(String email);

  /// No description provided for @checkYourInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox (and spam folder) for your login ID and password.'**
  String get checkYourInbox;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @aadhaarErrorAuthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in isn\'t available right now, so we couldn\'t run the reader. You can still type your details below.'**
  String get aadhaarErrorAuthUnavailable;

  /// No description provided for @aadhaarErrorNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please try again, or type your details below.'**
  String get aadhaarErrorNotSignedIn;

  /// No description provided for @aadhaarErrorImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'That photo is too large to process. Try a closer, smaller shot of the card.'**
  String get aadhaarErrorImageTooLarge;

  /// No description provided for @aadhaarErrorUnreadable.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t read that card. Try better lighting and a flat, glare-free shot — or type your details below.'**
  String get aadhaarErrorUnreadable;

  /// No description provided for @aadhaarErrorModelBusy.
  ///
  /// In en, this message translates to:
  /// **'Our reader is busy right now. Try again in a moment, or type your details below.'**
  String get aadhaarErrorModelBusy;

  /// No description provided for @aadhaarErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t reach the network. Check your connection and try again, or type your details below.'**
  String get aadhaarErrorNetwork;

  /// No description provided for @aadhaarErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong reading the card. You can type your details below instead.'**
  String get aadhaarErrorUnknown;

  /// No description provided for @aadhaarPartialExtracted.
  ///
  /// In en, this message translates to:
  /// **'We read part of your card. Please check the details below and fill in anything missing.'**
  String get aadhaarPartialExtracted;

  /// No description provided for @aadhaarBackImageSkippedTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The back photo was too large, so we read the front only. Please check the address below.'**
  String get aadhaarBackImageSkippedTooLarge;

  /// No description provided for @mapLayerFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load part of the map. Some wards, booths or hotspots may be missing.'**
  String get mapLayerFailed;

  /// No description provided for @mapRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get mapRetry;

  /// No description provided for @hotspotsShownCount.
  ///
  /// In en, this message translates to:
  /// **'{count} hotspots'**
  String hotspotsShownCount(int count);

  /// No description provided for @hotspotsOffMapCount.
  ///
  /// In en, this message translates to:
  /// **'· {count} off-map'**
  String hotspotsOffMapCount(int count);

  /// No description provided for @hotspotClusterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'HOTSPOT'**
  String get hotspotClusterSheetTitle;

  /// No description provided for @publicDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Public dashboard'**
  String get publicDashboardTitle;

  /// No description provided for @exploreYourArea.
  ///
  /// In en, this message translates to:
  /// **'Explore your area'**
  String get exploreYourArea;

  /// No description provided for @noSignInNeeded.
  ///
  /// In en, this message translates to:
  /// **'No sign-in needed'**
  String get noSignInNeeded;

  /// No description provided for @chooseConstituency.
  ///
  /// In en, this message translates to:
  /// **'Choose a constituency'**
  String get chooseConstituency;

  /// No description provided for @searchConstituency.
  ///
  /// In en, this message translates to:
  /// **'Search constituencies'**
  String get searchConstituency;

  /// No description provided for @noConstituenciesFound.
  ///
  /// In en, this message translates to:
  /// **'No constituencies match that search.'**
  String get noConstituenciesFound;

  /// No description provided for @publicPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Only anonymous ticket IDs and approximate locations are shown here. No names, addresses or contact details are ever published.'**
  String get publicPrivacyNote;

  /// No description provided for @trackedIssues.
  ///
  /// In en, this message translates to:
  /// **'Tracked issues'**
  String get trackedIssues;

  /// No description provided for @totalReports.
  ///
  /// In en, this message translates to:
  /// **'Total reports'**
  String get totalReports;

  /// No description provided for @officialActions.
  ///
  /// In en, this message translates to:
  /// **'Official actions'**
  String get officialActions;

  /// No description provided for @officialActionsHint.
  ///
  /// In en, this message translates to:
  /// **'Only you can see these — they need your official sign-in.'**
  String get officialActionsHint;

  /// No description provided for @updateTicketStatuses.
  ///
  /// In en, this message translates to:
  /// **'Update ticket statuses'**
  String get updateTicketStatuses;

  /// No description provided for @generateReportExplainer.
  ///
  /// In en, this message translates to:
  /// **'Generates an AI-written PDF briefing for your constituency: executive summary, recommended actions, and the top issues by priority with their Solution Card recommendations. Scoped to your own constituency and never shared publicly.'**
  String get generateReportExplainer;

  /// No description provided for @solutionCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Solution card'**
  String get solutionCardTitle;

  /// No description provided for @forCitizens.
  ///
  /// In en, this message translates to:
  /// **'For citizens'**
  String get forCitizens;

  /// No description provided for @forDepartment.
  ///
  /// In en, this message translates to:
  /// **'For the department'**
  String get forDepartment;

  /// No description provided for @escalatesTo.
  ///
  /// In en, this message translates to:
  /// **'Escalates to'**
  String get escalatesTo;

  /// No description provided for @routingApproximate.
  ///
  /// In en, this message translates to:
  /// **'No exact local body is mapped for this area yet, so this is a broader fallback.'**
  String get routingApproximate;

  /// No description provided for @estimatedCost.
  ///
  /// In en, this message translates to:
  /// **'Estimated cost'**
  String get estimatedCost;

  /// No description provided for @costNotEstimated.
  ///
  /// In en, this message translates to:
  /// **'Cost not estimated'**
  String get costNotEstimated;

  /// No description provided for @householdsNotEstimated.
  ///
  /// In en, this message translates to:
  /// **'Reach not estimated'**
  String get householdsNotEstimated;

  /// No description provided for @expectedImpact.
  ///
  /// In en, this message translates to:
  /// **'Expected impact'**
  String get expectedImpact;

  /// No description provided for @problemStatement.
  ///
  /// In en, this message translates to:
  /// **'Problem statement'**
  String get problemStatement;

  /// No description provided for @recommendedActions.
  ///
  /// In en, this message translates to:
  /// **'Recommended actions'**
  String get recommendedActions;

  /// No description provided for @proposedInterventions.
  ///
  /// In en, this message translates to:
  /// **'Proposed interventions'**
  String get proposedInterventions;

  /// No description provided for @whatWeAreAskingFor.
  ///
  /// In en, this message translates to:
  /// **'What is being asked for'**
  String get whatWeAreAskingFor;

  /// No description provided for @quickWin.
  ///
  /// In en, this message translates to:
  /// **'Quick win'**
  String get quickWin;

  /// No description provided for @prerequisites.
  ///
  /// In en, this message translates to:
  /// **'Needed first'**
  String get prerequisites;

  /// No description provided for @dataGaps.
  ///
  /// In en, this message translates to:
  /// **'What we could not determine'**
  String get dataGaps;

  /// No description provided for @sdgAlignment.
  ///
  /// In en, this message translates to:
  /// **'UN Sustainable Development Goals'**
  String get sdgAlignment;

  /// No description provided for @evidenceFrom.
  ///
  /// In en, this message translates to:
  /// **'Evidence from citizen reports'**
  String get evidenceFrom;

  /// No description provided for @analysisPending.
  ///
  /// In en, this message translates to:
  /// **'No analysis yet. An issue gets a full solution card once enough neighbours have reported it.'**
  String get analysisPending;

  /// No description provided for @analysisDegradedNote.
  ///
  /// In en, this message translates to:
  /// **'Part of this analysis could not be completed automatically, so some sections are simplified.'**
  String get analysisDegradedNote;

  /// No description provided for @aiGeneratedDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'AI-generated from citizen reports and typical municipal cost ranges. Verify against a site survey before acting or committing budget.'**
  String get aiGeneratedDisclaimer;

  /// No description provided for @viewSolutionCard.
  ///
  /// In en, this message translates to:
  /// **'View solution card'**
  String get viewSolutionCard;

  /// No description provided for @shareSolution.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareSolution;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @viewAgentTranscript.
  ///
  /// In en, this message translates to:
  /// **'Agent transcript'**
  String get viewAgentTranscript;

  /// No description provided for @agentTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'How this was analysed'**
  String get agentTranscriptTitle;

  /// No description provided for @agentChainRun.
  ///
  /// In en, this message translates to:
  /// **'Four-agent analysis run'**
  String get agentChainRun;

  /// No description provided for @agentTrigger.
  ///
  /// In en, this message translates to:
  /// **'Triggered by'**
  String get agentTrigger;

  /// No description provided for @agentModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get agentModel;

  /// No description provided for @agentTotalTime.
  ///
  /// In en, this message translates to:
  /// **'Total time'**
  String get agentTotalTime;

  /// No description provided for @agentRunAt.
  ///
  /// In en, this message translates to:
  /// **'Run at'**
  String get agentRunAt;

  /// No description provided for @agentRootCause.
  ///
  /// In en, this message translates to:
  /// **'Root-cause agent'**
  String get agentRootCause;

  /// No description provided for @agentSolution.
  ///
  /// In en, this message translates to:
  /// **'Solution agent'**
  String get agentSolution;

  /// No description provided for @agentRouting.
  ///
  /// In en, this message translates to:
  /// **'Routing agent'**
  String get agentRouting;

  /// No description provided for @agentReportCompiler.
  ///
  /// In en, this message translates to:
  /// **'Report compiler agent'**
  String get agentReportCompiler;

  /// No description provided for @agentOk.
  ///
  /// In en, this message translates to:
  /// **'completed'**
  String get agentOk;

  /// No description provided for @agentUsedFallback.
  ///
  /// In en, this message translates to:
  /// **'fell back'**
  String get agentUsedFallback;

  /// No description provided for @agentSystemRole.
  ///
  /// In en, this message translates to:
  /// **'Instructions given'**
  String get agentSystemRole;

  /// No description provided for @agentPrompt.
  ///
  /// In en, this message translates to:
  /// **'Input'**
  String get agentPrompt;

  /// No description provided for @agentResponse.
  ///
  /// In en, this message translates to:
  /// **'Raw response'**
  String get agentResponse;

  /// No description provided for @agentError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get agentError;

  /// No description provided for @agentFellBackNote.
  ///
  /// In en, this message translates to:
  /// **'These agents did not complete and used a fallback: {agents}. Treat the affected sections as placeholders, not findings.'**
  String agentFellBackNote(String agents);

  /// No description provided for @agentAttempts.
  ///
  /// In en, this message translates to:
  /// **'{count} attempts'**
  String agentAttempts(int count);

  /// No description provided for @reportsFromResidents.
  ///
  /// In en, this message translates to:
  /// **'{reports} reports from {residents} residents'**
  String reportsFromResidents(int reports, int residents);

  /// No description provided for @weeksRange.
  ///
  /// In en, this message translates to:
  /// **'{min}–{max} weeks'**
  String weeksRange(int min, int max);

  /// No description provided for @householdsAddressed.
  ///
  /// In en, this message translates to:
  /// **'~{count} households'**
  String householdsAddressed(int count);

  /// No description provided for @routedToDepartment.
  ///
  /// In en, this message translates to:
  /// **'Routed to'**
  String get routedToDepartment;

  /// No description provided for @yourCivicActivity.
  ///
  /// In en, this message translates to:
  /// **'Your civic activity'**
  String get yourCivicActivity;

  /// No description provided for @activeWeeksStreak.
  ///
  /// In en, this message translates to:
  /// **'Active weeks'**
  String get activeWeeksStreak;

  /// No description provided for @longestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get longestStreak;

  /// No description provided for @levelMaxReached.
  ///
  /// In en, this message translates to:
  /// **'Top level reached'**
  String get levelMaxReached;

  /// No description provided for @reportsToNextLevel.
  ///
  /// In en, this message translates to:
  /// **'{count} more to next level'**
  String reportsToNextLevel(int count);

  /// No description provided for @levelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelLabel(int level);

  /// No description provided for @badgeFirstReport.
  ///
  /// In en, this message translates to:
  /// **'First report'**
  String get badgeFirstReport;

  /// No description provided for @badgeWeekStreak.
  ///
  /// In en, this message translates to:
  /// **'2-week streak'**
  String get badgeWeekStreak;

  /// No description provided for @badgeMonthActive.
  ///
  /// In en, this message translates to:
  /// **'Month active'**
  String get badgeMonthActive;

  /// No description provided for @badgeMultiTheme.
  ///
  /// In en, this message translates to:
  /// **'Multi-issue reporter'**
  String get badgeMultiTheme;

  /// No description provided for @badgeResolvedTen.
  ///
  /// In en, this message translates to:
  /// **'10 resolved'**
  String get badgeResolvedTen;

  /// No description provided for @badgePhotoReporter.
  ///
  /// In en, this message translates to:
  /// **'Photo reporter'**
  String get badgePhotoReporter;

  /// No description provided for @badgeVoiceReporter.
  ///
  /// In en, this message translates to:
  /// **'Voice reporter'**
  String get badgeVoiceReporter;

  /// No description provided for @badgeLockedHint.
  ///
  /// In en, this message translates to:
  /// **'keep reporting to unlock'**
  String get badgeLockedHint;

  /// No description provided for @consistencyEmptyNudge.
  ///
  /// In en, this message translates to:
  /// **'Your first report will start showing up here.'**
  String get consistencyEmptyNudge;

  /// No description provided for @contributionsInLast26Weeks.
  ///
  /// In en, this message translates to:
  /// **'Reports in the last 26 weeks'**
  String get contributionsInLast26Weeks;

  /// No description provided for @seePublicDashboard.
  ///
  /// In en, this message translates to:
  /// **'See your area\'s public dashboard'**
  String get seePublicDashboard;

  /// No description provided for @liveLabel.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get liveLabel;

  /// No description provided for @reportsNearYouThisWeek.
  ///
  /// In en, this message translates to:
  /// **'{count} reports near you this week'**
  String reportsNearYouThisWeek(int count);

  /// No description provided for @beTheFirstThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Be the first to report this week'**
  String get beTheFirstThisWeek;

  /// No description provided for @topHotspots.
  ///
  /// In en, this message translates to:
  /// **'Top hotspots'**
  String get topHotspots;

  /// No description provided for @latestSolutions.
  ///
  /// In en, this message translates to:
  /// **'Latest solutions'**
  String get latestSolutions;

  /// No description provided for @noTrackedIssuesYet.
  ///
  /// In en, this message translates to:
  /// **'No issues tracked yet for this area.'**
  String get noTrackedIssuesYet;

  /// No description provided for @reportsCountShort.
  ///
  /// In en, this message translates to:
  /// **'{count} reports'**
  String reportsCountShort(int count);

  /// No description provided for @hasSolutionLabel.
  ///
  /// In en, this message translates to:
  /// **'Solution ready'**
  String get hasSolutionLabel;
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
