// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TEK · Sensor monitoring';

  @override
  String get appTitleShort => 'TEK · Monitoring';

  @override
  String get initializing => 'Initializing…';

  @override
  String get loading => 'Loading…';

  @override
  String get checking => 'Checking…';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get done => 'Done';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get clear => 'Clear';

  @override
  String get name => 'Name';

  @override
  String get info => 'Info';

  @override
  String get noData => 'No data';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get tokenCopied => 'Token copied';

  @override
  String get snippetCopied => 'Snippet copied';

  @override
  String get later => 'Later';

  @override
  String get allow => 'Allow';

  @override
  String get selectPlaceholder => '— select —';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortAlphabetical => 'Alphabetically';

  @override
  String get sortBySite => 'By site';

  @override
  String get sortByWorkshop => 'By workshop';

  @override
  String get sortByCreatedAt => 'By creation date';

  @override
  String get sortByRegistrationDate => 'By registration date';

  @override
  String get sortByRole => 'By role';

  @override
  String get sortAscending => 'Ascending';

  @override
  String get sortDescending => 'Descending';

  @override
  String get searchSensorsHint => 'Search by name, site, device ID…';

  @override
  String get searchWorkshopsHint => 'Search by name…';

  @override
  String get searchSitesHint => 'Search by name, workshop…';

  @override
  String get searchUsersHint => 'Search by login, role, email…';

  @override
  String searchResultsCount(int found, int total) {
    return 'Found: $found of $total';
  }

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get loadingNotifications => 'Loading notifications…';

  @override
  String get noNewNotifications => 'No new notifications';

  @override
  String get enableNotifications => 'Enable notifications';

  @override
  String get disableNotifications => 'Disable notifications';

  @override
  String get enableNotificationsAll => 'Enable notifications for all';

  @override
  String get disableNotificationsAll => 'Disable notifications for all';

  @override
  String get enableWorkshopNotifications => 'Enable workshop notifications';

  @override
  String get disableWorkshopNotifications => 'Disable workshop notifications';

  @override
  String get enableSiteNotifications => 'Enable site notifications';

  @override
  String get disableSiteNotifications => 'Disable site notifications';

  @override
  String get notificationsEnabledAllSensors =>
      'Notifications enabled for all sensors';

  @override
  String get notificationsDisabledAllSensors =>
      'Notifications disabled for all sensors';

  @override
  String get notificationsEnabledAllWorkshops =>
      'Notifications enabled for all workshops';

  @override
  String get notificationsDisabledAllWorkshops =>
      'Notifications disabled for all workshops';

  @override
  String get notificationsEnabledAllSites =>
      'Notifications enabled for all sites';

  @override
  String get notificationsDisabledAllSites =>
      'Notifications disabled for all sites';

  @override
  String get notificationsDisabledTitle => 'Notifications disabled';

  @override
  String get notificationsDisabledBody =>
      'To receive role change messages, allow notifications in system or browser settings.';

  @override
  String get notificationChannelName => 'Role changes';

  @override
  String get notificationChannelDescription => 'User promotions and demotions';

  @override
  String get loginTitle => 'Sign in to the sensor monitoring system';

  @override
  String get loginLabel => 'Login';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get noAccountRegister => 'No account? Register';

  @override
  String loginError(String error) {
    return 'Sign-in error: $error';
  }

  @override
  String get registerTitle => 'Registration';

  @override
  String get registerSubtitle => 'New users receive viewer permissions';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get passwordHelper => '8+ characters, digits and Latin letters';

  @override
  String get registerButton => 'Register';

  @override
  String get hasAccountLogin => 'Already have an account? Sign in';

  @override
  String get loginAvailable => 'Login is available';

  @override
  String get loginTaken => 'Login is taken';

  @override
  String get loginAlreadyTaken => 'Login is already taken';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordMinLength => 'At least 8 characters';

  @override
  String get passwordNeedsDigit => 'At least one digit is required';

  @override
  String get passwordNeedsLatin => 'Latin letters are required';

  @override
  String get emailVerificationTitle => 'Email verification';

  @override
  String get phoneVerificationTitle => 'Phone verification';

  @override
  String get emailCodeHint => 'Enter the code from the email';

  @override
  String get smsCodeHint => 'Enter the code from SMS';

  @override
  String get codeTooShort => 'Enter the code from email or SMS';

  @override
  String codeSentTo(String destination) {
    return 'Code sent to $destination';
  }

  @override
  String get profileTitle => 'Profile';

  @override
  String roleLabel(String role) {
    return 'Role: $role';
  }

  @override
  String get emailLabel => 'Email';

  @override
  String get emailChangeHelper =>
      'A verification code will be sent to your email when changed';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get phoneChangeHelper =>
      'After email (if changing both) — code via SMS';

  @override
  String get saveProfile => 'Save profile';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get confirmPasswordFieldLabel => 'Confirmation';

  @override
  String get changePasswordButton => 'Change password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get reduceMotionTitle => 'Reduce animations';

  @override
  String get reduceMotionSubtitle => 'Disables interface and chart effects';

  @override
  String get signOutAccount => 'Sign out';

  @override
  String get sensorFab => 'Sensor';

  @override
  String get newSensorTitle => 'New sensor';

  @override
  String get editSensorTitle => 'Edit sensor';

  @override
  String get deleteSensorTitle => 'Delete sensor?';

  @override
  String get sensorCreatedTitle => 'Sensor created';

  @override
  String get siteLabel => 'Site';

  @override
  String get noSite => 'No site';

  @override
  String get chartColorLabel => 'Chart color';

  @override
  String get idleDetectionTitle => 'Idle detection';

  @override
  String get idlePowerThresholdLabel => 'Power threshold, W (empty = default)';

  @override
  String get idleCurrentThresholdLabel => 'Current threshold, A (fallback)';

  @override
  String get idleDurationLabel => 'Idle duration, sec';

  @override
  String get copyToken => 'Copy token';

  @override
  String get copySnippet => 'Copy snippet';

  @override
  String get sensorInfoTitle => 'Sensor information';

  @override
  String colorValue(String color) {
    return 'Color: $color';
  }

  @override
  String createdAt(String date, String byLogin) {
    return 'Created: $date$byLogin';
  }

  @override
  String currentPlacement(String workshop, String site) {
    return 'Current placement: $workshop$site';
  }

  @override
  String get placementHistoryTitle => 'Placement history';

  @override
  String get placementHistoryEmpty => 'History is empty';

  @override
  String get tabWorkshops => 'Workshops';

  @override
  String get tabSites => 'Sites';

  @override
  String get noWorkshops => 'No workshops';

  @override
  String get noSites => 'No sites';

  @override
  String get fabWorkshop => 'Workshop';

  @override
  String get fabSite => 'Site';

  @override
  String get newWorkshopTitle => 'New workshop';

  @override
  String get editWorkshopTitle => 'Edit workshop';

  @override
  String get newSiteTitle => 'New site';

  @override
  String get editSiteTitle => 'Edit site';

  @override
  String get workshopLabel => 'Workshop';

  @override
  String get dashboardColorLabel => 'Dashboard color';

  @override
  String workshopFallback(int id) {
    return 'workshop #$id';
  }

  @override
  String siteWorkshopSubtitle(String workshopName) {
    return 'Workshop: $workshopName';
  }

  @override
  String get noUsers => 'No users';

  @override
  String get youChip => 'you';

  @override
  String get promoteToAdmin => 'Promote to admin';

  @override
  String get demoteToViewer => 'Demote to viewer';

  @override
  String promotedSnack(String login) {
    return '$login promoted to admin';
  }

  @override
  String demotedSnack(String login) {
    return '$login demoted to viewer';
  }

  @override
  String get chartsTitle => 'Charts';

  @override
  String get addChart => 'Add chart';

  @override
  String get connectionIssueBanner =>
      'No server connection — showing last known data';

  @override
  String get groupingLabel => 'Grouping';

  @override
  String get renameChartTitle => 'Chart title';

  @override
  String get renameChartHint => 'Chart 1';

  @override
  String defaultChartTitle(int index) {
    return 'Chart $index';
  }

  @override
  String get renameTooltip => 'Rename';

  @override
  String get removeChartTooltip => 'Remove chart';

  @override
  String get customRangeHelp => 'Custom range';

  @override
  String get periodLabel => 'Period:';

  @override
  String get customPeriod => 'Custom';

  @override
  String get loadDataErrorTitle => 'Failed to load data';

  @override
  String get noDataForPeriodTitle => 'No data for the selected period';

  @override
  String get noDataForPeriodSubtitle =>
      'Select a sensor or group and ensure telemetry is being received.';

  @override
  String chartStats(int pointsCount, int seriesCount) {
    return 'Phase current · $pointsCount points · $seriesCount series';
  }

  @override
  String get currentAxisTitle => 'Current, A';

  @override
  String get workshopsLabel => 'Workshops:';

  @override
  String get allWorkshops => 'All workshops';

  @override
  String get sitesLabel => 'Sites:';

  @override
  String get allSites => 'All sites';

  @override
  String get sensorsLabel => 'Sensors:';

  @override
  String get allSensors => 'All sensors';

  @override
  String get noSitesInGroup => 'No sites in the selected group';

  @override
  String get noSensorsInGroup => 'No sensors in the selected group';

  @override
  String workshopsLoadError(String error) {
    return 'Workshops: $error';
  }

  @override
  String sitesLoadError(String error) {
    return 'Sites: $error';
  }

  @override
  String sensorsLoadError(String error) {
    return 'Sensors: $error';
  }

  @override
  String downtimeOfflineChip(String sensorName) {
    return 'Offline · $sensorName';
  }

  @override
  String downtimeIdleChip(String sensorName) {
    return 'Idle · $sensorName';
  }

  @override
  String downtimeOfflineTotal(String duration) {
    return 'Offline: $duration';
  }

  @override
  String downtimeIdleTotal(String duration) {
    return 'Idle: $duration';
  }

  @override
  String workshopDowntimeChip(String workshopName, String duration) {
    return '$workshopName: $duration';
  }

  @override
  String get timePresetMinute => 'Min';

  @override
  String get timePresetHour => 'Hour';

  @override
  String get timePresetDay => 'Day';

  @override
  String get timePresetWeek => 'Week';

  @override
  String get timePresetMonth => 'Month';

  @override
  String get timePresetYear => 'Year';

  @override
  String get chartScaleSeconds => 'Sec';

  @override
  String get chartScaleMinutes => 'Min';

  @override
  String get chartScaleHours => 'H';

  @override
  String get chartScaleDays => 'D';

  @override
  String get chartScaleWeeks => 'Wk';

  @override
  String get chartScaleMonths => 'Mo';

  @override
  String get chartScaleYears => 'Yr';

  @override
  String durationSeconds(int count) {
    return '$count s';
  }

  @override
  String durationMinutes(int count) {
    return '$count min';
  }

  @override
  String durationHours(int hours) {
    return '$hours h';
  }

  @override
  String durationDays(int days) {
    return '$days d';
  }

  @override
  String get provisioningTitle => 'ESP pairing via BLE';

  @override
  String get provisioningUnavailableWeb =>
      'BLE pairing is unavailable in the browser — use a phone or desktop app';

  @override
  String get rescanTooltip => 'Scan again';

  @override
  String get scanInstructions =>
      'Find the ESP in pairing mode (name starts with TEC-ESP). Make sure Bluetooth is enabled.';

  @override
  String get scanning => 'Scanning…';

  @override
  String get noDevicesFound => 'No devices found';

  @override
  String connectFailed(String error) {
    return 'Failed to connect: $error';
  }

  @override
  String tokenFetchFailed(String error) {
    return 'Failed to fetch token: $error';
  }

  @override
  String get selectDeviceAndSensor => 'Select an ESP and a registered sensor';

  @override
  String get ssidRequired => 'Enter Wi-Fi SSID';

  @override
  String get onlineTimeout =>
      'Sensor did not go online within 90 s. Check Wi-Fi and server URL.';

  @override
  String connectedTo(String deviceName) {
    return 'Connected: $deviceName';
  }

  @override
  String get wifiSsidLabel => 'Wi-Fi SSID';

  @override
  String get wifiPasswordLabel => 'Wi-Fi password';

  @override
  String get ingestUrlLabel => 'Ingest URL';

  @override
  String get ingestUrlHelper => 'POST /api/v1/ingest — LAN IP, not localhost';

  @override
  String get systemSensorLabel => 'Sensor in system';

  @override
  String tokenLoaded(int length) {
    return 'Token loaded from server ($length chars)';
  }

  @override
  String get commitButton => 'Write and pair';

  @override
  String get selectOtherDevice => 'Select another device';

  @override
  String provisioningSensorsLoadError(String error) {
    return 'Failed to load sensors: $error';
  }

  @override
  String get waitingTelemetry => 'Waiting for first telemetry…';

  @override
  String get waitingDescription =>
      'ESP is connecting to Wi-Fi and sending data';

  @override
  String successOnline(String name) {
    return 'Sensor $name online';
  }

  @override
  String get bleServiceNotFound => 'Pairing service not found';

  @override
  String bleCharacteristicNotFound(String uuid) {
    return 'Characteristic $uuid not found';
  }

  @override
  String themeTooltip(String theme) {
    return 'Theme: $theme';
  }

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get hexColorFormat => 'Format: #RRGGBB';

  @override
  String get errorNoConnection => 'No server connection';

  @override
  String get errorAuthRequired => 'Sign-in required';

  @override
  String get errorForbidden => 'Insufficient permissions';

  @override
  String errorServer(int code) {
    return 'Server error ($code)';
  }

  @override
  String get errorNetwork => 'Network error';

  @override
  String get errorLoad => 'Load error';

  @override
  String get navMonitoring => 'Monitoring';

  @override
  String get navAppSubtitle => 'TEK · Sensor monitoring';

  @override
  String get bleProvisioningTooltip => 'ESP pairing via BLE';

  @override
  String get accountTooltip => 'Account';

  @override
  String get navSettings => 'Settings';

  @override
  String get signOut => 'Sign out';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navSensors => 'Sensors';

  @override
  String get navGroups => 'Groups';

  @override
  String get navUsers => 'Users';
}
