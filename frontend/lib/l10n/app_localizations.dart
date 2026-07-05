import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

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
    Locale('en'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In ru, this message translates to:
  /// **'ТЭК · Мониторинг датчиков'**
  String get appTitle;

  /// No description provided for @appTitleShort.
  ///
  /// In ru, this message translates to:
  /// **'ТЭК · Мониторинг'**
  String get appTitleShort;

  /// No description provided for @initializing.
  ///
  /// In ru, this message translates to:
  /// **'Инициализация…'**
  String get initializing;

  /// No description provided for @loading.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка…'**
  String get loading;

  /// No description provided for @checking.
  ///
  /// In ru, this message translates to:
  /// **'Проверка…'**
  String get checking;

  /// No description provided for @cancel.
  ///
  /// In ru, this message translates to:
  /// **'Отмена'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @create.
  ///
  /// In ru, this message translates to:
  /// **'Создать'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get edit;

  /// No description provided for @done.
  ///
  /// In ru, this message translates to:
  /// **'Готово'**
  String get done;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @confirm.
  ///
  /// In ru, this message translates to:
  /// **'Подтвердить'**
  String get confirm;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Название'**
  String get name;

  /// No description provided for @info.
  ///
  /// In ru, this message translates to:
  /// **'Информация'**
  String get info;

  /// No description provided for @noData.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных'**
  String get noData;

  /// No description provided for @copiedToClipboard.
  ///
  /// In ru, this message translates to:
  /// **'Скопировано в буфер обмена'**
  String get copiedToClipboard;

  /// No description provided for @tokenCopied.
  ///
  /// In ru, this message translates to:
  /// **'Токен скопирован'**
  String get tokenCopied;

  /// No description provided for @snippetCopied.
  ///
  /// In ru, this message translates to:
  /// **'Сниппет скопирован'**
  String get snippetCopied;

  /// No description provided for @later.
  ///
  /// In ru, this message translates to:
  /// **'Позже'**
  String get later;

  /// No description provided for @allow.
  ///
  /// In ru, this message translates to:
  /// **'Разрешить'**
  String get allow;

  /// No description provided for @selectPlaceholder.
  ///
  /// In ru, this message translates to:
  /// **'— выберите —'**
  String get selectPlaceholder;

  /// No description provided for @sortLabel.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get sortLabel;

  /// No description provided for @sortAlphabetical.
  ///
  /// In ru, this message translates to:
  /// **'По алфавиту'**
  String get sortAlphabetical;

  /// No description provided for @sortBySite.
  ///
  /// In ru, this message translates to:
  /// **'По площадке'**
  String get sortBySite;

  /// No description provided for @sortByWorkshop.
  ///
  /// In ru, this message translates to:
  /// **'По цеху'**
  String get sortByWorkshop;

  /// No description provided for @sortByCreatedAt.
  ///
  /// In ru, this message translates to:
  /// **'По дате создания'**
  String get sortByCreatedAt;

  /// No description provided for @sortByRegistrationDate.
  ///
  /// In ru, this message translates to:
  /// **'По дате регистрации'**
  String get sortByRegistrationDate;

  /// No description provided for @sortByRole.
  ///
  /// In ru, this message translates to:
  /// **'По роли'**
  String get sortByRole;

  /// No description provided for @sortAscending.
  ///
  /// In ru, this message translates to:
  /// **'По возрастанию'**
  String get sortAscending;

  /// No description provided for @sortDescending.
  ///
  /// In ru, this message translates to:
  /// **'По убыванию'**
  String get sortDescending;

  /// No description provided for @searchSensorsHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию, площадке, device ID…'**
  String get searchSensorsHint;

  /// No description provided for @searchWorkshopsHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию…'**
  String get searchWorkshopsHint;

  /// No description provided for @searchSitesHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по названию, цеху…'**
  String get searchSitesHint;

  /// No description provided for @searchUsersHint.
  ///
  /// In ru, this message translates to:
  /// **'Поиск по логину, роли, email…'**
  String get searchUsersHint;

  /// No description provided for @searchResultsCount.
  ///
  /// In ru, this message translates to:
  /// **'Найдено: {found} из {total}'**
  String searchResultsCount(int found, int total);

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// No description provided for @notificationsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все'**
  String get markAllRead;

  /// No description provided for @loadingNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Загрузка уведомлений…'**
  String get loadingNotifications;

  /// No description provided for @noNewNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Нет новых уведомлений'**
  String get noNewNotifications;

  /// No description provided for @enableNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления'**
  String get enableNotifications;

  /// No description provided for @disableNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Отключить уведомления'**
  String get disableNotifications;

  /// No description provided for @enableNotificationsAll.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления у всех'**
  String get enableNotificationsAll;

  /// No description provided for @disableNotificationsAll.
  ///
  /// In ru, this message translates to:
  /// **'Отключить уведомления у всех'**
  String get disableNotificationsAll;

  /// No description provided for @enableWorkshopNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления цеха'**
  String get enableWorkshopNotifications;

  /// No description provided for @disableWorkshopNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Отключить уведомления цеха'**
  String get disableWorkshopNotifications;

  /// No description provided for @enableSiteNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Включить уведомления площадки'**
  String get enableSiteNotifications;

  /// No description provided for @disableSiteNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Отключить уведомления площадки'**
  String get disableSiteNotifications;

  /// No description provided for @notificationsEnabledAllSensors.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления включены для всех датчиков'**
  String get notificationsEnabledAllSensors;

  /// No description provided for @notificationsDisabledAllSensors.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления отключены для всех датчиков'**
  String get notificationsDisabledAllSensors;

  /// No description provided for @notificationsEnabledAllWorkshops.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления включены для всех цехов'**
  String get notificationsEnabledAllWorkshops;

  /// No description provided for @notificationsDisabledAllWorkshops.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления отключены для всех цехов'**
  String get notificationsDisabledAllWorkshops;

  /// No description provided for @notificationsEnabledAllSites.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления включены для всех площадок'**
  String get notificationsEnabledAllSites;

  /// No description provided for @notificationsDisabledAllSites.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления отключены для всех площадок'**
  String get notificationsDisabledAllSites;

  /// No description provided for @notificationsDisabledTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления отключены'**
  String get notificationsDisabledTitle;

  /// No description provided for @notificationsDisabledBody.
  ///
  /// In ru, this message translates to:
  /// **'Чтобы получать сообщения о повышении и понижении прав, разрешите уведомления в настройках системы или браузера.'**
  String get notificationsDisabledBody;

  /// No description provided for @notificationChannelName.
  ///
  /// In ru, this message translates to:
  /// **'Изменения прав'**
  String get notificationChannelName;

  /// No description provided for @notificationChannelDescription.
  ///
  /// In ru, this message translates to:
  /// **'Повышение и понижение пользователей'**
  String get notificationChannelDescription;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в систему мониторинга датчиков'**
  String get loginTitle;

  /// No description provided for @loginLabel.
  ///
  /// In ru, this message translates to:
  /// **'Логин'**
  String get loginLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @noAccountRegister.
  ///
  /// In ru, this message translates to:
  /// **'Нет аккаунта? Зарегистрироваться'**
  String get noAccountRegister;

  /// No description provided for @loginError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка входа: {error}'**
  String loginError(String error);

  /// No description provided for @registerTitle.
  ///
  /// In ru, this message translates to:
  /// **'Регистрация'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый пользователь получает права viewer'**
  String get registerSubtitle;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение пароля'**
  String get confirmPasswordLabel;

  /// No description provided for @passwordHelper.
  ///
  /// In ru, this message translates to:
  /// **'8+ символов, цифры и латиница'**
  String get passwordHelper;

  /// No description provided for @registerButton.
  ///
  /// In ru, this message translates to:
  /// **'Зарегистрироваться'**
  String get registerButton;

  /// No description provided for @hasAccountLogin.
  ///
  /// In ru, this message translates to:
  /// **'Уже есть аккаунт? Войти'**
  String get hasAccountLogin;

  /// No description provided for @loginAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Логин свободен'**
  String get loginAvailable;

  /// No description provided for @loginTaken.
  ///
  /// In ru, this message translates to:
  /// **'Логин занят'**
  String get loginTaken;

  /// No description provided for @loginAlreadyTaken.
  ///
  /// In ru, this message translates to:
  /// **'Логин уже занят'**
  String get loginAlreadyTaken;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In ru, this message translates to:
  /// **'Пароли не совпадают'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordMinLength.
  ///
  /// In ru, this message translates to:
  /// **'Минимум 8 символов'**
  String get passwordMinLength;

  /// No description provided for @passwordNeedsDigit.
  ///
  /// In ru, this message translates to:
  /// **'Нужна хотя бы одна цифра'**
  String get passwordNeedsDigit;

  /// No description provided for @passwordNeedsLatin.
  ///
  /// In ru, this message translates to:
  /// **'Нужны латинские буквы'**
  String get passwordNeedsLatin;

  /// No description provided for @emailVerificationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение email'**
  String get emailVerificationTitle;

  /// No description provided for @phoneVerificationTitle.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение телефона'**
  String get phoneVerificationTitle;

  /// No description provided for @emailCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из письма'**
  String get emailCodeHint;

  /// No description provided for @smsCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из SMS'**
  String get smsCodeHint;

  /// No description provided for @codeTooShort.
  ///
  /// In ru, this message translates to:
  /// **'Введите код из письма или SMS'**
  String get codeTooShort;

  /// No description provided for @codeSentTo.
  ///
  /// In ru, this message translates to:
  /// **'Код отправлен на {destination}'**
  String codeSentTo(String destination);

  /// No description provided for @profileTitle.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get profileTitle;

  /// No description provided for @roleLabel.
  ///
  /// In ru, this message translates to:
  /// **'Роль: {role}'**
  String roleLabel(String role);

  /// No description provided for @emailLabel.
  ///
  /// In ru, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailChangeHelper.
  ///
  /// In ru, this message translates to:
  /// **'При изменении придёт код подтверждения на почту'**
  String get emailChangeHelper;

  /// No description provided for @phoneLabel.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phoneLabel;

  /// No description provided for @phoneChangeHelper.
  ///
  /// In ru, this message translates to:
  /// **'После email (если меняете оба) — код в SMS'**
  String get phoneChangeHelper;

  /// No description provided for @saveProfile.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить профиль'**
  String get saveProfile;

  /// No description provided for @profileSaved.
  ///
  /// In ru, this message translates to:
  /// **'Профиль сохранён'**
  String get profileSaved;

  /// No description provided for @changePasswordTitle.
  ///
  /// In ru, this message translates to:
  /// **'Смена пароля'**
  String get changePasswordTitle;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Текущий пароль'**
  String get currentPasswordLabel;

  /// No description provided for @newPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Новый пароль'**
  String get newPasswordLabel;

  /// No description provided for @confirmPasswordFieldLabel.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждение'**
  String get confirmPasswordFieldLabel;

  /// No description provided for @changePasswordButton.
  ///
  /// In ru, this message translates to:
  /// **'Сменить пароль'**
  String get changePasswordButton;

  /// No description provided for @passwordChanged.
  ///
  /// In ru, this message translates to:
  /// **'Пароль изменён'**
  String get passwordChanged;

  /// No description provided for @appearanceTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оформление'**
  String get appearanceTitle;

  /// No description provided for @languageTitle.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get languageTitle;

  /// No description provided for @languageRussian.
  ///
  /// In ru, this message translates to:
  /// **'Русский'**
  String get languageRussian;

  /// No description provided for @languageEnglish.
  ///
  /// In ru, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @reduceMotionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить анимации'**
  String get reduceMotionTitle;

  /// No description provided for @reduceMotionSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Отключает эффекты интерфейса и графиков'**
  String get reduceMotionSubtitle;

  /// No description provided for @signOutAccount.
  ///
  /// In ru, this message translates to:
  /// **'Выйти из аккаунта'**
  String get signOutAccount;

  /// No description provided for @sensorFab.
  ///
  /// In ru, this message translates to:
  /// **'Датчик'**
  String get sensorFab;

  /// No description provided for @newSensorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый датчик'**
  String get newSensorTitle;

  /// No description provided for @editSensorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить датчик'**
  String get editSensorTitle;

  /// No description provided for @deleteSensorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Удалить датчик?'**
  String get deleteSensorTitle;

  /// No description provided for @sensorCreatedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Датчик создан'**
  String get sensorCreatedTitle;

  /// No description provided for @siteLabel.
  ///
  /// In ru, this message translates to:
  /// **'Площадка'**
  String get siteLabel;

  /// No description provided for @noSite.
  ///
  /// In ru, this message translates to:
  /// **'Без площадки'**
  String get noSite;

  /// No description provided for @chartColorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цвет на графике'**
  String get chartColorLabel;

  /// No description provided for @idleDetectionTitle.
  ///
  /// In ru, this message translates to:
  /// **'Детекция простоя'**
  String get idleDetectionTitle;

  /// No description provided for @idlePowerThresholdLabel.
  ///
  /// In ru, this message translates to:
  /// **'Порог мощности, Вт (пусто = по умолчанию)'**
  String get idlePowerThresholdLabel;

  /// No description provided for @idleCurrentThresholdLabel.
  ///
  /// In ru, this message translates to:
  /// **'Порог тока, А (фолбэк)'**
  String get idleCurrentThresholdLabel;

  /// No description provided for @idleDurationLabel.
  ///
  /// In ru, this message translates to:
  /// **'Длительность простоя, сек'**
  String get idleDurationLabel;

  /// No description provided for @copyToken.
  ///
  /// In ru, this message translates to:
  /// **'Копировать токен'**
  String get copyToken;

  /// No description provided for @copySnippet.
  ///
  /// In ru, this message translates to:
  /// **'Копировать сниппет'**
  String get copySnippet;

  /// No description provided for @sensorInfoTitle.
  ///
  /// In ru, this message translates to:
  /// **'Информация о датчике'**
  String get sensorInfoTitle;

  /// No description provided for @colorValue.
  ///
  /// In ru, this message translates to:
  /// **'Цвет: {color}'**
  String colorValue(String color);

  /// No description provided for @createdAt.
  ///
  /// In ru, this message translates to:
  /// **'Создан: {date}{byLogin}'**
  String createdAt(String date, String byLogin);

  /// No description provided for @currentPlacement.
  ///
  /// In ru, this message translates to:
  /// **'Текущее размещение: {workshop}{site}'**
  String currentPlacement(String workshop, String site);

  /// No description provided for @placementHistoryTitle.
  ///
  /// In ru, this message translates to:
  /// **'История размещения'**
  String get placementHistoryTitle;

  /// No description provided for @placementHistoryEmpty.
  ///
  /// In ru, this message translates to:
  /// **'История пуста'**
  String get placementHistoryEmpty;

  /// No description provided for @tabWorkshops.
  ///
  /// In ru, this message translates to:
  /// **'Цеха'**
  String get tabWorkshops;

  /// No description provided for @tabSites.
  ///
  /// In ru, this message translates to:
  /// **'Площадки'**
  String get tabSites;

  /// No description provided for @noWorkshops.
  ///
  /// In ru, this message translates to:
  /// **'Нет цехов'**
  String get noWorkshops;

  /// No description provided for @noSites.
  ///
  /// In ru, this message translates to:
  /// **'Нет площадок'**
  String get noSites;

  /// No description provided for @fabWorkshop.
  ///
  /// In ru, this message translates to:
  /// **'Цех'**
  String get fabWorkshop;

  /// No description provided for @fabSite.
  ///
  /// In ru, this message translates to:
  /// **'Площадка'**
  String get fabSite;

  /// No description provided for @newWorkshopTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новый цех'**
  String get newWorkshopTitle;

  /// No description provided for @editWorkshopTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить цех'**
  String get editWorkshopTitle;

  /// No description provided for @newSiteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Новая площадка'**
  String get newSiteTitle;

  /// No description provided for @editSiteTitle.
  ///
  /// In ru, this message translates to:
  /// **'Изменить площадку'**
  String get editSiteTitle;

  /// No description provided for @workshopLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цех'**
  String get workshopLabel;

  /// No description provided for @dashboardColorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цвет на дашборде'**
  String get dashboardColorLabel;

  /// No description provided for @workshopFallback.
  ///
  /// In ru, this message translates to:
  /// **'цех #{id}'**
  String workshopFallback(int id);

  /// No description provided for @siteWorkshopSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Цех: {workshopName}'**
  String siteWorkshopSubtitle(String workshopName);

  /// No description provided for @noUsers.
  ///
  /// In ru, this message translates to:
  /// **'Нет пользователей'**
  String get noUsers;

  /// No description provided for @youChip.
  ///
  /// In ru, this message translates to:
  /// **'вы'**
  String get youChip;

  /// No description provided for @promoteToAdmin.
  ///
  /// In ru, this message translates to:
  /// **'Назначить admin'**
  String get promoteToAdmin;

  /// No description provided for @demoteToViewer.
  ///
  /// In ru, this message translates to:
  /// **'Понизить до viewer'**
  String get demoteToViewer;

  /// No description provided for @promotedSnack.
  ///
  /// In ru, this message translates to:
  /// **'{login} назначен admin'**
  String promotedSnack(String login);

  /// No description provided for @demotedSnack.
  ///
  /// In ru, this message translates to:
  /// **'{login} понижен до viewer'**
  String demotedSnack(String login);

  /// No description provided for @chartsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Графики'**
  String get chartsTitle;

  /// No description provided for @addChart.
  ///
  /// In ru, this message translates to:
  /// **'Добавить график'**
  String get addChart;

  /// No description provided for @connectionIssueBanner.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером — показаны последние известные данные'**
  String get connectionIssueBanner;

  /// No description provided for @groupingLabel.
  ///
  /// In ru, this message translates to:
  /// **'Группировка'**
  String get groupingLabel;

  /// No description provided for @renameChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'Название графика'**
  String get renameChartTitle;

  /// No description provided for @renameChartHint.
  ///
  /// In ru, this message translates to:
  /// **'График 1'**
  String get renameChartHint;

  /// No description provided for @defaultChartTitle.
  ///
  /// In ru, this message translates to:
  /// **'График {index}'**
  String defaultChartTitle(int index);

  /// No description provided for @renameTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Переименовать'**
  String get renameTooltip;

  /// No description provided for @removeChartTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Удалить график'**
  String get removeChartTooltip;

  /// No description provided for @customRangeHelp.
  ///
  /// In ru, this message translates to:
  /// **'Произвольный диапазон'**
  String get customRangeHelp;

  /// No description provided for @periodLabel.
  ///
  /// In ru, this message translates to:
  /// **'Период:'**
  String get periodLabel;

  /// No description provided for @customPeriod.
  ///
  /// In ru, this message translates to:
  /// **'Свой'**
  String get customPeriod;

  /// No description provided for @loadDataErrorTitle.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось загрузить данные'**
  String get loadDataErrorTitle;

  /// No description provided for @noDataForPeriodTitle.
  ///
  /// In ru, this message translates to:
  /// **'Нет данных за выбранный период'**
  String get noDataForPeriodTitle;

  /// No description provided for @noDataForPeriodSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Выберите датчик или группу и убедитесь, что телеметрия поступает.'**
  String get noDataForPeriodSubtitle;

  /// No description provided for @chartStats.
  ///
  /// In ru, this message translates to:
  /// **'Ток фазы · {pointsCount} точек · {seriesCount} ряд(ов)'**
  String chartStats(int pointsCount, int seriesCount);

  /// No description provided for @currentAxisTitle.
  ///
  /// In ru, this message translates to:
  /// **'Ток, А'**
  String get currentAxisTitle;

  /// No description provided for @workshopsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Цеха:'**
  String get workshopsLabel;

  /// No description provided for @allWorkshops.
  ///
  /// In ru, this message translates to:
  /// **'Все цеха'**
  String get allWorkshops;

  /// No description provided for @sitesLabel.
  ///
  /// In ru, this message translates to:
  /// **'Площадки:'**
  String get sitesLabel;

  /// No description provided for @allSites.
  ///
  /// In ru, this message translates to:
  /// **'Все площадки'**
  String get allSites;

  /// No description provided for @sensorsLabel.
  ///
  /// In ru, this message translates to:
  /// **'Датчики:'**
  String get sensorsLabel;

  /// No description provided for @allSensors.
  ///
  /// In ru, this message translates to:
  /// **'Все датчики'**
  String get allSensors;

  /// No description provided for @noSitesInGroup.
  ///
  /// In ru, this message translates to:
  /// **'Нет площадок в выбранной группе'**
  String get noSitesInGroup;

  /// No description provided for @noSensorsInGroup.
  ///
  /// In ru, this message translates to:
  /// **'Нет датчиков в выбранной группе'**
  String get noSensorsInGroup;

  /// No description provided for @workshopsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Цеха: {error}'**
  String workshopsLoadError(String error);

  /// No description provided for @sitesLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Площадки: {error}'**
  String sitesLoadError(String error);

  /// No description provided for @sensorsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Датчики: {error}'**
  String sensorsLoadError(String error);

  /// No description provided for @downtimeOfflineChip.
  ///
  /// In ru, this message translates to:
  /// **'Offline · {sensorName}'**
  String downtimeOfflineChip(String sensorName);

  /// No description provided for @downtimeIdleChip.
  ///
  /// In ru, this message translates to:
  /// **'Простой · {sensorName}'**
  String downtimeIdleChip(String sensorName);

  /// No description provided for @downtimeOfflineTotal.
  ///
  /// In ru, this message translates to:
  /// **'Offline: {duration}'**
  String downtimeOfflineTotal(String duration);

  /// No description provided for @downtimeIdleTotal.
  ///
  /// In ru, this message translates to:
  /// **'Простой: {duration}'**
  String downtimeIdleTotal(String duration);

  /// No description provided for @workshopDowntimeChip.
  ///
  /// In ru, this message translates to:
  /// **'{workshopName}: {duration}'**
  String workshopDowntimeChip(String workshopName, String duration);

  /// No description provided for @timePresetMinute.
  ///
  /// In ru, this message translates to:
  /// **'Мин'**
  String get timePresetMinute;

  /// No description provided for @timePresetHour.
  ///
  /// In ru, this message translates to:
  /// **'Час'**
  String get timePresetHour;

  /// No description provided for @timePresetDay.
  ///
  /// In ru, this message translates to:
  /// **'День'**
  String get timePresetDay;

  /// No description provided for @timePresetWeek.
  ///
  /// In ru, this message translates to:
  /// **'Неделя'**
  String get timePresetWeek;

  /// No description provided for @timePresetMonth.
  ///
  /// In ru, this message translates to:
  /// **'Месяц'**
  String get timePresetMonth;

  /// No description provided for @timePresetYear.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get timePresetYear;

  /// No description provided for @chartScaleSeconds.
  ///
  /// In ru, this message translates to:
  /// **'Сек'**
  String get chartScaleSeconds;

  /// No description provided for @chartScaleMinutes.
  ///
  /// In ru, this message translates to:
  /// **'Мин'**
  String get chartScaleMinutes;

  /// No description provided for @chartScaleHours.
  ///
  /// In ru, this message translates to:
  /// **'Ч'**
  String get chartScaleHours;

  /// No description provided for @chartScaleDays.
  ///
  /// In ru, this message translates to:
  /// **'Дн'**
  String get chartScaleDays;

  /// No description provided for @chartScaleWeeks.
  ///
  /// In ru, this message translates to:
  /// **'Нед'**
  String get chartScaleWeeks;

  /// No description provided for @chartScaleMonths.
  ///
  /// In ru, this message translates to:
  /// **'Мес'**
  String get chartScaleMonths;

  /// No description provided for @chartScaleYears.
  ///
  /// In ru, this message translates to:
  /// **'Год'**
  String get chartScaleYears;

  /// No description provided for @durationSeconds.
  ///
  /// In ru, this message translates to:
  /// **'{count} с'**
  String durationSeconds(int count);

  /// No description provided for @durationMinutes.
  ///
  /// In ru, this message translates to:
  /// **'{count} мин'**
  String durationMinutes(int count);

  /// No description provided for @durationHours.
  ///
  /// In ru, this message translates to:
  /// **'{hours} ч'**
  String durationHours(int hours);

  /// No description provided for @durationDays.
  ///
  /// In ru, this message translates to:
  /// **'{days} д'**
  String durationDays(int days);

  /// No description provided for @provisioningTitle.
  ///
  /// In ru, this message translates to:
  /// **'Привязка ESP по BLE'**
  String get provisioningTitle;

  /// No description provided for @provisioningUnavailableWeb.
  ///
  /// In ru, this message translates to:
  /// **'BLE-привязка недоступна в браузере — используйте телефон или десктоп-приложение'**
  String get provisioningUnavailableWeb;

  /// No description provided for @rescanTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Сканировать снова'**
  String get rescanTooltip;

  /// No description provided for @scanInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Найдите ESP в режиме привязки (имя начинается с TEC-ESP). Убедитесь, что Bluetooth включён.'**
  String get scanInstructions;

  /// No description provided for @scanning.
  ///
  /// In ru, this message translates to:
  /// **'Сканирование…'**
  String get scanning;

  /// No description provided for @noDevicesFound.
  ///
  /// In ru, this message translates to:
  /// **'Устройства не найдены'**
  String get noDevicesFound;

  /// No description provided for @connectFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось подключиться: {error}'**
  String connectFailed(String error);

  /// No description provided for @tokenFetchFailed.
  ///
  /// In ru, this message translates to:
  /// **'Не удалось получить токен: {error}'**
  String tokenFetchFailed(String error);

  /// No description provided for @selectDeviceAndSensor.
  ///
  /// In ru, this message translates to:
  /// **'Выберите ESP и зарегистрированный датчик'**
  String get selectDeviceAndSensor;

  /// No description provided for @ssidRequired.
  ///
  /// In ru, this message translates to:
  /// **'Укажите SSID Wi-Fi'**
  String get ssidRequired;

  /// No description provided for @onlineTimeout.
  ///
  /// In ru, this message translates to:
  /// **'Датчик не перешёл в online за 90 с. Проверьте Wi-Fi и URL сервера.'**
  String get onlineTimeout;

  /// No description provided for @connectedTo.
  ///
  /// In ru, this message translates to:
  /// **'Подключено: {deviceName}'**
  String connectedTo(String deviceName);

  /// No description provided for @wifiSsidLabel.
  ///
  /// In ru, this message translates to:
  /// **'SSID Wi-Fi'**
  String get wifiSsidLabel;

  /// No description provided for @wifiPasswordLabel.
  ///
  /// In ru, this message translates to:
  /// **'Пароль Wi-Fi'**
  String get wifiPasswordLabel;

  /// No description provided for @ingestUrlLabel.
  ///
  /// In ru, this message translates to:
  /// **'URL приёма (ingest)'**
  String get ingestUrlLabel;

  /// No description provided for @ingestUrlHelper.
  ///
  /// In ru, this message translates to:
  /// **'POST /api/v1/ingest — LAN-IP, не localhost'**
  String get ingestUrlHelper;

  /// No description provided for @systemSensorLabel.
  ///
  /// In ru, this message translates to:
  /// **'Датчик в системе'**
  String get systemSensorLabel;

  /// No description provided for @tokenLoaded.
  ///
  /// In ru, this message translates to:
  /// **'Токен загружен с сервера ({length} симв.)'**
  String tokenLoaded(int length);

  /// No description provided for @commitButton.
  ///
  /// In ru, this message translates to:
  /// **'Записать и привязать'**
  String get commitButton;

  /// No description provided for @selectOtherDevice.
  ///
  /// In ru, this message translates to:
  /// **'Выбрать другое устройство'**
  String get selectOtherDevice;

  /// No description provided for @provisioningSensorsLoadError.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки датчиков: {error}'**
  String provisioningSensorsLoadError(String error);

  /// No description provided for @waitingTelemetry.
  ///
  /// In ru, this message translates to:
  /// **'Ожидание первой телеметрии…'**
  String get waitingTelemetry;

  /// No description provided for @waitingDescription.
  ///
  /// In ru, this message translates to:
  /// **'ESP подключается к Wi-Fi и отправляет данные'**
  String get waitingDescription;

  /// No description provided for @successOnline.
  ///
  /// In ru, this message translates to:
  /// **'Датчик {name} online'**
  String successOnline(String name);

  /// No description provided for @bleServiceNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Сервис привязки не найден'**
  String get bleServiceNotFound;

  /// No description provided for @bleCharacteristicNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Характеристика {uuid} не найдена'**
  String bleCharacteristicNotFound(String uuid);

  /// No description provided for @themeTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Тема: {theme}'**
  String themeTooltip(String theme);

  /// No description provided for @themeSystem.
  ///
  /// In ru, this message translates to:
  /// **'Системная'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In ru, this message translates to:
  /// **'Светлая'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In ru, this message translates to:
  /// **'Тёмная'**
  String get themeDark;

  /// No description provided for @hexColorFormat.
  ///
  /// In ru, this message translates to:
  /// **'Формат: #RRGGBB'**
  String get hexColorFormat;

  /// No description provided for @errorNoConnection.
  ///
  /// In ru, this message translates to:
  /// **'Нет связи с сервером'**
  String get errorNoConnection;

  /// No description provided for @errorAuthRequired.
  ///
  /// In ru, this message translates to:
  /// **'Требуется вход'**
  String get errorAuthRequired;

  /// No description provided for @errorForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав'**
  String get errorForbidden;

  /// No description provided for @errorServer.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сервера ({code})'**
  String errorServer(int code);

  /// No description provided for @errorNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка сети'**
  String get errorNetwork;

  /// No description provided for @errorLoad.
  ///
  /// In ru, this message translates to:
  /// **'Ошибка загрузки'**
  String get errorLoad;

  /// No description provided for @navMonitoring.
  ///
  /// In ru, this message translates to:
  /// **'Мониторинг'**
  String get navMonitoring;

  /// No description provided for @navAppSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'ТЭК · Мониторинг датчиков'**
  String get navAppSubtitle;

  /// No description provided for @bleProvisioningTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Привязка ESP по BLE'**
  String get bleProvisioningTooltip;

  /// No description provided for @accountTooltip.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get accountTooltip;

  /// No description provided for @navSettings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get navSettings;

  /// No description provided for @signOut.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get signOut;

  /// No description provided for @navDashboard.
  ///
  /// In ru, this message translates to:
  /// **'Дашборд'**
  String get navDashboard;

  /// No description provided for @navSensors.
  ///
  /// In ru, this message translates to:
  /// **'Датчики'**
  String get navSensors;

  /// No description provided for @navGroups.
  ///
  /// In ru, this message translates to:
  /// **'Группы'**
  String get navGroups;

  /// No description provided for @navUsers.
  ///
  /// In ru, this message translates to:
  /// **'Пользователи'**
  String get navUsers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
