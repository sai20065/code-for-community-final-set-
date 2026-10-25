// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTagline => 'Voice of the People';

  @override
  String get tabCitizen => 'Citizen';

  @override
  String get tabMpOffice => 'Government access';

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
      'You stay anonymous to other citizens. No phone number, email or ID is needed — just a username. Your MP\'s office sees aggregated demand, not your identity.';

  @override
  String get newHereSignUp => 'New here? Sign Up';

  @override
  String get alreadyHaveAccountSignIn => 'I already have an account — Sign In';

  @override
  String get alreadyHaveAccountSignInShort =>
      'Already have an account? Sign In';

  @override
  String get camera => 'Camera';

  @override
  String get gallery => 'Gallery';

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
  String get couldNotContinue =>
      'Could not continue — check your connection and try again.';

  @override
  String get aggregatedDemandNote =>
      'Whichever way you sign in, your MP\'s office only ever sees aggregated demand, never your identity.';

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

  @override
  String get newSubmission => 'New submission';

  @override
  String get whatWouldYouLikeToDo => 'What would you like to do?';

  @override
  String get reportAProblem => 'Report a problem';

  @override
  String get reportProblemSubtitle => 'Something broken or unsafe near you';

  @override
  String get suggestDevelopmentWork => 'Suggest a development work';

  @override
  String get suggestSubtitle => 'Something new your area needs';

  @override
  String get shareYourSuggestion => 'Share Your Suggestion';

  @override
  String get describeTheProblem => 'Describe the Problem';

  @override
  String get suggestionHint =>
      'What development work would help your area? (e.g. A skilling centre near the bus stand)';

  @override
  String get problemHint =>
      'What\'s the problem? (e.g. Streetlight not working)';

  @override
  String get addAPhoto => 'Add a Photo';

  @override
  String get captionOptional => 'Add a caption (optional)';

  @override
  String get receiptCopied => 'Receipt number copied';

  @override
  String get badgeSuggestion => 'Suggestion';

  @override
  String get badgeReport => 'Report';

  @override
  String get savedInstantlyNote =>
      'Saved instantly. AI enrichment continues in the background — you\'ll see updates in Mine.';

  @override
  String get trackThisTicket => 'Track this ticket';

  @override
  String get copyReceipt => 'Copy receipt';

  @override
  String get backToHome => 'Back to Home';

  @override
  String routedTo(String constituency) {
    return 'Routed to $constituency';
  }

  @override
  String looksLike(String theme) {
    return 'Looks like: $theme';
  }

  @override
  String similarOpenProblems(int count) {
    return 'There are $count similar open problems in this booth — your report will be added';
  }

  @override
  String othersAskedToo(int count) {
    return '$count others nearby have asked for this too';
  }

  @override
  String greetingHi(String name) {
    return 'Hi, $name';
  }

  @override
  String homeAreaLabel(String area) {
    return 'Home: $area';
  }

  @override
  String boothLabel(String name) {
    return 'Booth $name';
  }

  @override
  String pincodeLabel(String pincode) {
    return 'Pincode $pincode';
  }

  @override
  String get myTickets => 'My tickets';

  @override
  String get trendingNearYou => 'Trending near you';

  @override
  String get emptyAreaSuggestions =>
      'Suggestions from your constituency will appear here once your area is confirmed.';

  @override
  String get couldNotLoadSuggestions => 'Could not load suggestions.';

  @override
  String get yourRecentReports => 'Your recent reports';

  @override
  String get noSuggestionsYet =>
      'No suggestions yet — be the first to submit one for your area.';

  @override
  String supportersCount(int count) {
    return '$count supporters';
  }

  @override
  String get supported => 'Supported';

  @override
  String get iSupportThis => 'I support this';

  @override
  String get suggestionUpper => 'SUGGESTION';

  @override
  String get myTicketsTitle => 'My Tickets';

  @override
  String get pleaseSignIn => 'Please sign in';

  @override
  String get noTicketsYet => 'No tickets yet';

  @override
  String receiptLabel(String token) {
    return 'Receipt: $token';
  }

  @override
  String get inDevelopmentPlan => 'In development plan';

  @override
  String get underReview => 'Under review';

  @override
  String get ticketNotFound => 'Ticket not found';

  @override
  String get ticketLabel => 'Ticket';

  @override
  String get noDescription => 'No description';

  @override
  String get seeDetails => 'See details (transcript/translation)';

  @override
  String get profileTitle => 'Profile';

  @override
  String get citizenDefault => 'Citizen';

  @override
  String get homeConstituency => 'Home constituency';

  @override
  String get notYetMatched => 'Not yet matched';

  @override
  String get homeBooth => 'Home booth';

  @override
  String get preferredLanguage => 'Preferred language';

  @override
  String get privacyStoreAddress =>
      'We store your home location to route your submissions to the right MP. We never ask for your phone number, email or any ID.';

  @override
  String get signOutClears => 'Sign out (clears this device)';

  @override
  String get couldNotLoadProfile => 'Could not load your profile.';

  @override
  String get statusFiled => 'Filed';

  @override
  String get statusAcknowledged => 'Acknowledged';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusResolved => 'Resolved';

  @override
  String get receiptWeGotThis => 'We\'ve got this';

  @override
  String get yourAddressStreet => 'Your address (street, area)';

  @override
  String get tapMapToMovePin =>
      'Tap anywhere on the map to move the pin to your exact location';

  @override
  String get homeAreaWillConfirm =>
      'Home constituency and booth will be confirmed once matched to your area.';

  @override
  String homeConstituencyBooth(String constituency, String booth) {
    return 'Home constituency: $constituency · Home booth: $booth';
  }

  @override
  String get looksRight => 'Looks right';

  @override
  String get thisIsntMe => 'This isn\'t me';

  @override
  String get pillCurrentLocation => 'Current location';

  @override
  String get pillAtMyHome => 'At my home';

  @override
  String get pillDropPin => 'Drop a pin';

  @override
  String get locationRoutedNote =>
      'Routed to your home MP · pin only sets where this shows on the map.';

  @override
  String get locationFailPickMap =>
      'Couldn\'t get your location — pick a spot on the map instead.';

  @override
  String get locationFailUseHome =>
      'Couldn\'t get your location — using your home address instead.';

  @override
  String get constituencyDashboard => 'Constituency Dashboard';

  @override
  String get notLinkedConstituency =>
      'Your account isn\'t linked to a constituency yet.';

  @override
  String get newThisWeek => 'New this week';

  @override
  String get resolvedRate => 'Resolved rate';

  @override
  String get avgResponseTime => 'Avg response time';

  @override
  String daysValue(String value) {
    return '$value days';
  }

  @override
  String get constituencyMap => 'Constituency Map';

  @override
  String get openConstituencyMap => 'Open constituency map';

  @override
  String get rankedWorks => 'Ranked Works';

  @override
  String get themesOverview => 'Themes Overview';

  @override
  String get problemReports => 'Problem Reports';

  @override
  String get ticketsByTheme => 'Tickets by theme';

  @override
  String get noClusteredTickets => 'No clustered tickets yet.';

  @override
  String get couldNotLoadThemes => 'Could not load themes.';

  @override
  String get weeklyTrend => 'Weekly trend';

  @override
  String get boothDemandMap => 'Booth-Level Demand Map';

  @override
  String get noBoothData =>
      'No booth reference data for this constituency yet.';

  @override
  String get couldNotLoadBooths => 'Could not load booths.';

  @override
  String get openIssueDensity => 'Open-issue density';

  @override
  String get densityHigh => 'High — needs attention';

  @override
  String get densityModerate => 'Moderate';

  @override
  String get densityLow => 'Low / mostly resolved';

  @override
  String get dotSizeVolume => 'Dot size = submission volume';

  @override
  String get hotspotFlameNote => '🔥 = urgent hotspot';

  @override
  String get searchByTicketId => 'Search by ticket ID';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get markInProgress => 'Mark In Progress';

  @override
  String get markResolved => 'Mark Resolved';

  @override
  String get noProblemReports => 'No problem reports yet.';

  @override
  String get couldNotLoadTickets => 'Could not load tickets.';

  @override
  String wardConstituency(String constituency) {
    return 'Ward · $constituency';
  }

  @override
  String submissionsCount(int count) {
    return '$count submissions';
  }

  @override
  String get otherRecurringThemes => 'Other recurring themes here';

  @override
  String get noOtherThemes => 'No other recurring themes clustered here yet.';

  @override
  String get couldNotLoadClusters => 'Could not load clusters.';

  @override
  String get sampleTickets => 'Sample tickets';

  @override
  String openCount(int count) {
    return '$count open';
  }

  @override
  String get whyItRecurs => 'WHY IT RECURS';

  @override
  String get whyHappeningHere => 'WHY IT\'S HAPPENING HERE';

  @override
  String whyRecursBody(int count, String booth, String summary) {
    return '$count citizens have reported this in $booth. \"$summary\"';
  }

  @override
  String themeIssuesReportedHere(String theme) {
    return '$theme issues reported here';
  }

  @override
  String get noLocalContext =>
      'No additional local context recorded for this booth yet.';

  @override
  String suggestedWork(String work) {
    return 'Suggested work: $work';
  }

  @override
  String get seeInRankedWorks => 'See in ranked works';

  @override
  String get aiGeneratedSummary => 'AI-generated summary · via Gemini';

  @override
  String priorityValue(String value) {
    return 'Priority $value';
  }

  @override
  String ticketsInBooth(String theme) {
    return '$theme tickets in this booth';
  }

  @override
  String get rankedDevelopmentWorks => 'Ranked Development Works';

  @override
  String get compare => 'Compare';

  @override
  String get noRankedWorks => 'No ranked works yet.';

  @override
  String get couldNotLoadRankedWorks => 'Could not load ranked works.';

  @override
  String get rankingWeightsAdjust => 'Ranking weights — adjust to re-rank';

  @override
  String get weightDemand => 'Demand';

  @override
  String get weightDemographic => 'Demographic';

  @override
  String get weightInfraGap => 'Infra gap';

  @override
  String get changesSavedAudit => 'Changes saved to audit log';

  @override
  String get whyExpand => '+ Why?';

  @override
  String get hideLabel => 'Hide';

  @override
  String ticketsShort(int count) {
    return '$count tickets';
  }

  @override
  String recurringDemand(String theme) {
    return '$theme — recurring demand';
  }

  @override
  String ticketsRecordedHere(int count) {
    return '$count tickets recorded here';
  }

  @override
  String fragDemand(String value) {
    return 'demand $value';
  }

  @override
  String fragDemographic(String value) {
    return 'demographic weight $value';
  }

  @override
  String fragInfraGap(String value) {
    return 'infra-gap $value';
  }

  @override
  String fragAffects(String range) {
    return 'affects $range';
  }

  @override
  String get compareProposals => 'Compare Proposals';

  @override
  String get needTwoToCompare => 'Need at least two ranked works to compare.';

  @override
  String get couldNotLoadProposals => 'Could not load proposals.';

  @override
  String get proposalA => 'Proposal A';

  @override
  String get proposalB => 'Proposal B';

  @override
  String recurringDemandShort(String theme) {
    return '$theme recurring demand';
  }

  @override
  String get statCitizenDemand => 'Citizen demand';

  @override
  String get statDemographicWeight => 'Demographic weight';

  @override
  String get statInfraGapWeight => 'Infra-gap weight';

  @override
  String get statTickets => 'Tickets';

  @override
  String get aiTradeOffBrief => 'AI trade-off brief';

  @override
  String get groundedInEvidence => 'grounded in evidence';

  @override
  String get briefWhoBenefits => 'Who benefits';

  @override
  String get briefWhatDataSays => 'What the data says';

  @override
  String get briefWhatDefers => 'What each defers';

  @override
  String benefitsWithRange(String name, String range, int count) {
    return '$name reaches $range ($count tickets recorded).';
  }

  @override
  String benefitsNoRange(String name, int count) {
    return '$name has $count citizen tickets behind it constituency-wide.';
  }

  @override
  String dataHigherComposite(String winner, String loser) {
    return '$winner has a higher overall composite score than $loser.';
  }

  @override
  String dataLeads(String winner, String loser, String reasons) {
    return '$winner leads $loser on $reasons.';
  }

  @override
  String reasonTickets(int winnerCount, int loserCount) {
    return '$winnerCount citizen tickets vs. $loserCount';
  }

  @override
  String reasonDemographic(String winner, String loser) {
    return 'a higher demographic-reach weight ($winner vs. $loser)';
  }

  @override
  String reasonInfra(String winner, String loser) {
    return 'a larger existing infrastructure gap ($winner vs. $loser)';
  }

  @override
  String defersLine(
      int count, String loser, String rangeSuffix, String winner) {
    return '$count tickets for $loser$rangeSuffix wait for a later cycle if $winner is prioritised now.';
  }

  @override
  String recommendationLine(String winner) {
    return 'Recommendation: prioritise $winner this cycle.';
  }

  @override
  String get yourMp => 'Your MP';

  @override
  String yourConstituency(String name) {
    return '$name constituency';
  }

  @override
  String get noMpAssignedYet =>
      'MP details aren\'t available for your area yet';

  @override
  String get couldNotSubmitTryAgain =>
      'Couldn\'t submit — please check your connection and try again';

  @override
  String get generateReport => 'Generate constituency report';

  @override
  String get couldNotGenerateReport =>
      'Couldn\'t generate the report — please try again';

  @override
  String get somethingWentWrong => 'Something went wrong — please try again';

  @override
  String get mpFirstTimeSetupTitle => 'First-time MP setup';

  @override
  String get mpForgotCredentialsTitle => 'Forgot credentials';

  @override
  String get mpFirstTimeSetupHint =>
      'Enter the unique identification number issued to your constituency and your email address — we\'ll send your login credentials to that email.';

  @override
  String get mpForgotCredentialsHint =>
      'Enter your constituency\'s unique identification number and the email you registered — we\'ll send your login credentials to that email.';

  @override
  String get mpUniqueId => 'Unique identification number';

  @override
  String get emailAddress => 'Email address';

  @override
  String get sendMyCredentials => 'Send my credentials';

  @override
  String credentialsSentTo(String email) {
    return 'Credentials sent to $email';
  }

  @override
  String get checkYourInbox =>
      'Check your inbox (and spam folder) for your login ID and password.';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get mapLayerFailed =>
      'Couldn\'t load part of the map. Some wards, booths or hotspots may be missing.';

  @override
  String get mapRetry => 'Retry';

  @override
  String hotspotsShownCount(int count) {
    return '$count hotspots';
  }

  @override
  String hotspotsOffMapCount(int count) {
    return '· $count off-map';
  }

  @override
  String get hotspotClusterSheetTitle => 'HOTSPOT';

  @override
  String get publicDashboardTitle => 'Public dashboard';

  @override
  String get exploreYourArea => 'Explore your area';

  @override
  String get noSignInNeeded => 'No sign-in needed';

  @override
  String get chooseConstituency => 'Choose a constituency';

  @override
  String get searchConstituency => 'Search constituencies';

  @override
  String get noConstituenciesFound => 'No constituencies match that search.';

  @override
  String get publicPrivacyNote =>
      'Only anonymous ticket IDs and approximate locations are shown here. No names, addresses or contact details are ever published.';

  @override
  String get trackedIssues => 'Tracked issues';

  @override
  String get totalReports => 'Total reports';

  @override
  String get officialActions => 'Official actions';

  @override
  String get officialActionsHint =>
      'Only you can see these — they need your official sign-in.';

  @override
  String get updateTicketStatuses => 'Update ticket statuses';

  @override
  String get generateReportExplainer =>
      'Generates an AI-written PDF briefing for your constituency: executive summary, recommended actions, and the top issues by priority with their Solution Card recommendations. Scoped to your own constituency and never shared publicly.';

  @override
  String get solutionCardTitle => 'Solution card';

  @override
  String get forCitizens => 'For citizens';

  @override
  String get forDepartment => 'For the department';

  @override
  String get escalatesTo => 'Escalates to';

  @override
  String get routingApproximate =>
      'No exact local body is mapped for this area yet, so this is a broader fallback.';

  @override
  String get estimatedCost => 'Estimated cost';

  @override
  String get costNotEstimated => 'Cost not estimated';

  @override
  String get householdsNotEstimated => 'Reach not estimated';

  @override
  String get expectedImpact => 'Expected impact';

  @override
  String get problemStatement => 'Problem statement';

  @override
  String get recommendedActions => 'Recommended actions';

  @override
  String get proposedInterventions => 'Proposed interventions';

  @override
  String get whatWeAreAskingFor => 'What is being asked for';

  @override
  String get quickWin => 'Quick win';

  @override
  String get prerequisites => 'Needed first';

  @override
  String get dataGaps => 'What we could not determine';

  @override
  String get sdgAlignment => 'UN Sustainable Development Goals';

  @override
  String get evidenceFrom => 'Evidence from citizen reports';

  @override
  String get analysisPending =>
      'No analysis yet. An issue gets a full solution card once enough neighbours have reported it.';

  @override
  String get analysisDegradedNote =>
      'Part of this analysis could not be completed automatically, so some sections are simplified.';

  @override
  String get aiGeneratedDisclaimer =>
      'AI-generated from citizen reports and typical municipal cost ranges. Verify against a site survey before acting or committing budget.';

  @override
  String get viewSolutionCard => 'View solution card';

  @override
  String get shareSolution => 'Share';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get viewAgentTranscript => 'Agent transcript';

  @override
  String get agentTranscriptTitle => 'How this was analysed';

  @override
  String get agentChainRun => 'Four-agent analysis run';

  @override
  String get agentTrigger => 'Triggered by';

  @override
  String get agentModel => 'Model';

  @override
  String get agentTotalTime => 'Total time';

  @override
  String get agentRunAt => 'Run at';

  @override
  String get agentRootCause => 'Root-cause agent';

  @override
  String get agentSolution => 'Solution agent';

  @override
  String get agentRouting => 'Routing agent';

  @override
  String get agentReportCompiler => 'Report compiler agent';

  @override
  String get agentOk => 'completed';

  @override
  String get agentUsedFallback => 'fell back';

  @override
  String get agentSystemRole => 'Instructions given';

  @override
  String get agentPrompt => 'Input';

  @override
  String get agentResponse => 'Raw response';

  @override
  String get agentError => 'Error';

  @override
  String agentFellBackNote(String agents) {
    return 'These agents did not complete and used a fallback: $agents. Treat the affected sections as placeholders, not findings.';
  }

  @override
  String agentAttempts(int count) {
    return '$count attempts';
  }

  @override
  String reportsFromResidents(int reports, int residents) {
    return '$reports reports from $residents residents';
  }

  @override
  String weeksRange(int min, int max) {
    return '$min–$max weeks';
  }

  @override
  String householdsAddressed(int count) {
    return '~$count households';
  }

  @override
  String get routedToDepartment => 'Routed to';

  @override
  String get yourCivicActivity => 'Your civic activity';

  @override
  String get activeWeeksStreak => 'Active weeks';

  @override
  String get longestStreak => 'Longest streak';

  @override
  String get levelMaxReached => 'Top level reached';

  @override
  String reportsToNextLevel(int count) {
    return '$count more to next level';
  }

  @override
  String levelLabel(int level) {
    return 'Level $level';
  }

  @override
  String get badgeFirstReport => 'First report';

  @override
  String get badgeWeekStreak => '2-week streak';

  @override
  String get badgeMonthActive => 'Month active';

  @override
  String get badgeMultiTheme => 'Multi-issue reporter';

  @override
  String get badgeResolvedTen => '10 resolved';

  @override
  String get badgePhotoReporter => 'Photo reporter';

  @override
  String get badgeVoiceReporter => 'Voice reporter';

  @override
  String get badgeLockedHint => 'keep reporting to unlock';

  @override
  String get consistencyEmptyNudge =>
      'Your first report will start showing up here.';

  @override
  String get contributionsInLast26Weeks => 'Reports in the last 26 weeks';

  @override
  String get seePublicDashboard => 'See your area\'s public dashboard';

  @override
  String get liveLabel => 'Live';

  @override
  String reportsNearYouThisWeek(int count) {
    return '$count reports near you this week';
  }

  @override
  String get beTheFirstThisWeek => 'Be the first to report this week';

  @override
  String get topHotspots => 'Top hotspots';

  @override
  String get latestSolutions => 'Latest solutions';

  @override
  String get noTrackedIssuesYet => 'No issues tracked yet for this area.';

  @override
  String reportsCountShort(int count) {
    return '$count reports';
  }

  @override
  String get hasSolutionLabel => 'Solution ready';

  @override
  String get openInGoogleMaps => 'Directions in Google Maps';

  @override
  String get openInGoogleMapsApprox => 'Directions to this area (Google Maps)';

  @override
  String get couldNotOpenMaps => 'Couldn\'t open Google Maps on this device.';

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHelper => '4–20 letters, numbers, _ or .';

  @override
  String get usernameTooShort => 'Username must be at least 4 characters.';

  @override
  String get usernameTooLong => 'Username can be at most 20 characters.';

  @override
  String get usernameBadCharacters =>
      'Use only letters, numbers, _ and . (no spaces).';

  @override
  String get usernameAvailable => 'Username is available';

  @override
  String get usernameTaken => 'That username is already taken. Try another.';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get passwordTooShort => 'Password must be at least 6 characters.';

  @override
  String get passwordsDontMatch => 'Passwords don\'t match.';

  @override
  String get authWrongCredentials => 'Wrong username or password.';

  @override
  String get authTooManyAttempts =>
      'Too many tries. Please wait a few minutes and try again.';

  @override
  String get authNetworkError =>
      'No internet connection. Check your network and try again.';

  @override
  String get nameRequired => 'Please enter your name.';

  @override
  String get createAccountTitle => 'Create your account';

  @override
  String get createAccountSubtitle =>
      'Just a username and password — no phone number, email or ID needed.';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get welcomeBackTitle => 'Welcome back';

  @override
  String get signInSubtitle => 'Sign in with your username and password.';

  @override
  String get forgotPasswordLink => 'Forgot password?';

  @override
  String get securityQuestionIntro =>
      'Pick a security question. If you ever forget your password, answering it lets you set a new one.';

  @override
  String get securityQuestionLabel => 'Security question';

  @override
  String get securityAnswerLabel => 'Your answer';

  @override
  String get securityAnswerHelper =>
      'Remember this answer. Capital letters don\'t matter.';

  @override
  String get securityAnswerRequired => 'Please enter an answer.';

  @override
  String get securityQuestionFirstSchool =>
      'What was the name of your first school?';

  @override
  String get securityQuestionMotherBirthplace =>
      'In which town or village was your mother born?';

  @override
  String get securityQuestionFavouriteFood => 'What is your favourite food?';

  @override
  String get securityQuestionChildhoodFriend =>
      'What is the name of your childhood best friend?';

  @override
  String get securityQuestionFirstVehicle =>
      'What was your first bicycle or vehicle?';

  @override
  String get forgotPasswordTitle => 'Reset your password';

  @override
  String get forgotPasswordStep1 => 'Enter your username to find your account.';

  @override
  String get forgotPasswordStep2 =>
      'Answer your security question and choose a new password.';

  @override
  String get passwordResetDone =>
      'Your password has been changed. Sign in with the new password.';

  @override
  String get resetPasswordButton => 'Set new password';

  @override
  String get recoveryNotMatched =>
      'That answer didn\'t match. Check it and try again.';

  @override
  String get recoveryLocked =>
      'Too many wrong answers. Password reset is locked for 15 minutes.';

  @override
  String get recoveryNoQuestion =>
      'We couldn\'t find a security question for that username.';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get changeSecurityQuestionTitle => 'Change security question';

  @override
  String get passwordChanged => 'Password changed.';

  @override
  String get securityQuestionSaved => 'Security question saved.';

  @override
  String get saveLabel => 'Save';

  @override
  String get statReportsFiled => 'Reports filed';

  @override
  String get statResolved => 'Resolved';

  @override
  String get statSupporters => 'Supporters';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get photoUpdated => 'Profile photo updated.';

  @override
  String get photoFailed =>
      'Couldn\'t upload the photo. Try a smaller picture.';

  @override
  String memberSince(String date) {
    return 'Member since $date';
  }

  @override
  String profileCompleteTitle(int percent) {
    return 'Profile $percent% complete';
  }

  @override
  String get completeAddPhoto => 'Add a profile photo';

  @override
  String get completeAddAge => 'Add your age';

  @override
  String get completeSetHome => 'Set your home location';

  @override
  String get completeSecurityQuestion => 'Set a security question';

  @override
  String get tapCameraToAddPhoto =>
      'Tap the camera on your picture to add a photo.';

  @override
  String get nudgeFirstReport =>
      'File your first report to earn your first badge and reach Level 1.';

  @override
  String nudgeNextLevel(int count, int level, String title) {
    return '$count more reports to reach Level $level · $title';
  }

  @override
  String get yourCivicJourney => 'Your civic journey';

  @override
  String get fileAReport => 'File a report';

  @override
  String get myPlaceTitle => 'My place';

  @override
  String get placeAddress => 'Address';

  @override
  String get placeBbmpWard => 'BBMP ward';

  @override
  String get placeGbaWard => 'GBA ward';

  @override
  String get placeTaluk => 'Taluk';

  @override
  String get placeDistrict => 'District';

  @override
  String get placeConstituency => 'Lok Sabha seat';

  @override
  String get changeLabel => 'Change';

  @override
  String get noHomeLocation => 'Home location not set yet.';

  @override
  String get myRepresentativesTitle => 'My representatives';

  @override
  String get mlaNotListed => 'MLA details coming soon';

  @override
  String assemblySegment(String name) {
    return 'Assembly: $name';
  }

  @override
  String get seeAll => 'See all';

  @override
  String get accountSettingsTitle => 'Account & settings';

  @override
  String get editNameAge => 'Edit name & age';

  @override
  String get recoveryIsSetUp => 'Password recovery is set up';

  @override
  String get recoveryNotSetUp => 'Not set — you can\'t recover your password';

  @override
  String get enterValidAge => 'Enter a valid age (10–120).';

  @override
  String get levelTitle1 => 'New Voice';

  @override
  String get levelTitle2 => 'Active Citizen';

  @override
  String get levelTitle3 => 'Community Voice';

  @override
  String get levelTitle4 => 'Neighbourhood Champion';

  @override
  String get levelTitle5 => 'Civic Leader';

  @override
  String get goToHome => 'Go to Home';

  @override
  String get viewMyProfile => 'View my profile';

  @override
  String revealWelcome(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get revealSubtitle => 'Your civic profile is ready.';

  @override
  String placeConstituencyShort(String name) {
    return '$name Lok Sabha';
  }

  @override
  String get yourAreaTitle => 'Your area';

  @override
  String get yourAreaNote =>
      'Everything you report or suggest is counted for this area.';

  @override
  String get firstStepsTitle => 'Your first 3 steps';

  @override
  String get stepFirstReport => 'File your first report';

  @override
  String get stepFirstReportBody =>
      'Voice, text or photo — it takes 20 seconds.';

  @override
  String get stepSupport => 'Support a suggestion near you';

  @override
  String get stepSupportBody => 'Back what your neighbours are asking for.';

  @override
  String get stepExploreMap => 'Explore your area\'s map';

  @override
  String get stepExploreMapBody => 'See what\'s being reported around you.';

  @override
  String get welcomeCitizenTitle => 'Citizens';

  @override
  String get welcomeCitizenBody =>
      'Report problems and suggest development work for your area — by voice, text or photo, in your language.';

  @override
  String get welcomeGovTitle => 'MPs, MLAs & Officers';

  @override
  String get welcomeGovBody =>
      'Government dashboard for your area: reports, hotspots, AI briefings and downloadable reports.';

  @override
  String get welcomeGovRegister => 'New MLA or officer? Register';

  @override
  String get welcomeAdminTitle => 'Prajadhwani Admin';

  @override
  String get welcomeAdminBody =>
      'Platform administration and official approvals';

  @override
  String get welcomeJustBrowsing =>
      'Just browsing? See your area\'s public dashboard';

  @override
  String get composeSubtitleProblem =>
      'Speak, type or snap a photo — it reaches the officials for your area.';

  @override
  String get composeSubtitleSuggestion =>
      'Share your idea by voice, text or photo — it goes to your representative.';

  @override
  String get stepWhatsTheIssue => 'What\'s the issue?';

  @override
  String get stepYourIdea => 'What\'s your idea?';

  @override
  String get tapMicToSpeak => 'Tap the mic to speak instead of typing';

  @override
  String get listeningTapToStop => 'Listening… tap to stop';

  @override
  String get voiceNoteAdded => 'Voice note added';

  @override
  String get stepAddPhoto => 'Add a photo (optional)';

  @override
  String get photoHelpsOfficials =>
      'A photo helps officials see the problem quickly';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get stepCategory => 'Category';

  @override
  String get stepWhere => 'Where is it?';

  @override
  String get includedText => 'Text';

  @override
  String get includedVoice => 'Voice';

  @override
  String get includedPhoto => 'Photo';

  @override
  String get addTextOrPhotoToSubmit => 'Type, speak or add a photo to submit';

  @override
  String get officerFixMessage =>
      'Your problem is registered! Our officers will get it fixed.';

  @override
  String get officerSuggestionMessage =>
      'Thank you! Your idea goes straight to your representative.';

  @override
  String yourTicketIs(String tokenId) {
    return 'Your ticket: $tokenId';
  }

  @override
  String get profileSaveFailed =>
      'Couldn\'t save — check your connection and try again.';

  @override
  String get areaNotMatchedYet =>
      'We couldn\'t match your exact area right now. You can update it later from Profile.';

  @override
  String get liveReportMap => 'Karnataka live report map';

  @override
  String get liveReportMapSubtitle =>
      'Every report across the state, updated live';

  @override
  String get seeOnLiveMap => 'See it on the live map';

  @override
  String get suggestedOfficeTitle => 'Suggested office to file the problem';

  @override
  String get findingOffice => 'Finding the right office for your problem…';

  @override
  String get officialWebsite => 'Official website';

  @override
  String get emailOffice => 'Email the office';

  @override
  String callOffice(String phone) {
    return 'Call $phone';
  }

  @override
  String get suggestedOfficeNote =>
      'Contacts are from official government sources. Office suggested by AI — please check before you file.';
}
