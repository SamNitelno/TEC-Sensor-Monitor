// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'ТЭК · Мониторинг датчиков';

  @override
  String get appTitleShort => 'ТЭК · Мониторинг';

  @override
  String get initializing => 'Инициализация…';

  @override
  String get loading => 'Загрузка…';

  @override
  String get checking => 'Проверка…';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get create => 'Создать';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get done => 'Готово';

  @override
  String get close => 'Закрыть';

  @override
  String get confirm => 'Подтвердить';

  @override
  String get clear => 'Очистить';

  @override
  String get name => 'Название';

  @override
  String get info => 'Информация';

  @override
  String get noData => 'Нет данных';

  @override
  String get copiedToClipboard => 'Скопировано в буфер обмена';

  @override
  String get tokenCopied => 'Токен скопирован';

  @override
  String get snippetCopied => 'Сниппет скопирован';

  @override
  String get later => 'Позже';

  @override
  String get allow => 'Разрешить';

  @override
  String get selectPlaceholder => '— выберите —';

  @override
  String get sortLabel => 'Сортировка';

  @override
  String get sortAlphabetical => 'По алфавиту';

  @override
  String get sortBySite => 'По площадке';

  @override
  String get sortByWorkshop => 'По цеху';

  @override
  String get sortByCreatedAt => 'По дате создания';

  @override
  String get sortByRegistrationDate => 'По дате регистрации';

  @override
  String get sortByRole => 'По роли';

  @override
  String get sortAscending => 'По возрастанию';

  @override
  String get sortDescending => 'По убыванию';

  @override
  String get searchSensorsHint => 'Поиск по названию, площадке, device ID…';

  @override
  String get searchWorkshopsHint => 'Поиск по названию…';

  @override
  String get searchSitesHint => 'Поиск по названию, цеху…';

  @override
  String get searchUsersHint => 'Поиск по логину, роли, email…';

  @override
  String searchResultsCount(int found, int total) {
    return 'Найдено: $found из $total';
  }

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get notificationsTitle => 'Уведомления';

  @override
  String get markAllRead => 'Прочитать все';

  @override
  String get loadingNotifications => 'Загрузка уведомлений…';

  @override
  String get noNewNotifications => 'Нет новых уведомлений';

  @override
  String get enableNotifications => 'Включить уведомления';

  @override
  String get disableNotifications => 'Отключить уведомления';

  @override
  String get enableNotificationsAll => 'Включить уведомления у всех';

  @override
  String get disableNotificationsAll => 'Отключить уведомления у всех';

  @override
  String get enableWorkshopNotifications => 'Включить уведомления цеха';

  @override
  String get disableWorkshopNotifications => 'Отключить уведомления цеха';

  @override
  String get enableSiteNotifications => 'Включить уведомления площадки';

  @override
  String get disableSiteNotifications => 'Отключить уведомления площадки';

  @override
  String get notificationsEnabledAllSensors =>
      'Уведомления включены для всех датчиков';

  @override
  String get notificationsDisabledAllSensors =>
      'Уведомления отключены для всех датчиков';

  @override
  String get notificationsEnabledAllWorkshops =>
      'Уведомления включены для всех цехов';

  @override
  String get notificationsDisabledAllWorkshops =>
      'Уведомления отключены для всех цехов';

  @override
  String get notificationsEnabledAllSites =>
      'Уведомления включены для всех площадок';

  @override
  String get notificationsDisabledAllSites =>
      'Уведомления отключены для всех площадок';

  @override
  String get notificationsDisabledTitle => 'Уведомления отключены';

  @override
  String get notificationsDisabledBody =>
      'Чтобы получать сообщения о повышении и понижении прав, разрешите уведомления в настройках системы или браузера.';

  @override
  String get notificationChannelName => 'Изменения прав';

  @override
  String get notificationChannelDescription =>
      'Повышение и понижение пользователей';

  @override
  String get loginTitle => 'Вход в систему мониторинга датчиков';

  @override
  String get loginLabel => 'Логин';

  @override
  String get passwordLabel => 'Пароль';

  @override
  String get signIn => 'Войти';

  @override
  String get forgotPassword => 'Забыли пароль?';

  @override
  String get forgotPasswordTitle => 'Сброс пароля';

  @override
  String get forgotPasswordSubtitle =>
      'Укажите email или телефон, привязанный к аккаунту';

  @override
  String get sendResetCode => 'Отправить код';

  @override
  String get resetPasswordTitle => 'Новый пароль';

  @override
  String get resetPasswordButton => 'Сохранить пароль';

  @override
  String get passwordResetSuccess => 'Пароль изменён. Войдите с новым паролем.';

  @override
  String get resetCodeSent => 'Если контакт привязан к аккаунту, код отправлен';

  @override
  String get adminResetPassword => 'Сбросить пароль';

  @override
  String adminResetPasswordTitle(String login) {
    return 'Новый пароль для $login';
  }

  @override
  String get adminPasswordResetSuccess => 'Пароль пользователя обновлён';

  @override
  String get errorFeatureInDevelopment =>
      'Функция в разработке, приносим извинения';

  @override
  String get errorRateLimited =>
      'Слишком много попыток. Подождите и повторите.';

  @override
  String get errorVerificationCodeInvalid => 'Неверный или просроченный код';

  @override
  String get errorDeliveryFailed =>
      'Не удалось отправить код. Обратитесь к администратору.';

  @override
  String get errorEmailTaken => 'Этот email уже используется';

  @override
  String get errorPhoneTaken => 'Этот телефон уже используется';

  @override
  String get noAccountRegister => 'Нет аккаунта? Зарегистрироваться';

  @override
  String loginError(String error) {
    return 'Ошибка входа: $error';
  }

  @override
  String get errorInvalidCredentials => 'Неверный логин или пароль';

  @override
  String get errorRegistrationDisabled =>
      'Регистрация отключена администратором';

  @override
  String get registrationDisabled =>
      'Регистрация новых пользователей отключена. Обратитесь к администратору.';

  @override
  String get errorWrongCurrentPassword => 'Неверный текущий пароль';

  @override
  String get errorPasswordRequired => 'Введите пароль';

  @override
  String get registerTitle => 'Регистрация';

  @override
  String get registerSubtitle => 'Новый пользователь получает права viewer';

  @override
  String get confirmPasswordLabel => 'Подтверждение пароля';

  @override
  String get passwordHelper => '8+ символов, цифры и латиница';

  @override
  String get registerButton => 'Зарегистрироваться';

  @override
  String get hasAccountLogin => 'Уже есть аккаунт? Войти';

  @override
  String get loginAvailable => 'Логин свободен';

  @override
  String get loginTaken => 'Логин занят';

  @override
  String get loginMinLength => 'Минимум 3 символа';

  @override
  String get loginAlreadyTaken => 'Логин уже занят';

  @override
  String get passwordsDoNotMatch => 'Пароли не совпадают';

  @override
  String get passwordMinLength => 'Минимум 8 символов';

  @override
  String get passwordNeedsDigit => 'Нужна хотя бы одна цифра';

  @override
  String get passwordNeedsLatin => 'Нужны латинские буквы';

  @override
  String get emailVerificationTitle => 'Подтверждение email';

  @override
  String get phoneVerificationTitle => 'Подтверждение телефона';

  @override
  String get emailCodeHint => 'Введите код из письма';

  @override
  String get smsCodeHint => 'Введите код из SMS';

  @override
  String get codeTooShort => 'Введите код из письма или SMS';

  @override
  String codeSentTo(String destination) {
    return 'Код отправлен на $destination';
  }

  @override
  String get profileTitle => 'Профиль';

  @override
  String roleLabel(String role) {
    return 'Роль: $role';
  }

  @override
  String get emailLabel => 'Email';

  @override
  String get emailChangeHelper =>
      'При изменении придёт код подтверждения на почту';

  @override
  String get phoneLabel => 'Телефон';

  @override
  String get phoneChangeHelper => 'После email (если меняете оба) — код в SMS';

  @override
  String get saveProfile => 'Сохранить профиль';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get changePasswordTitle => 'Смена пароля';

  @override
  String get currentPasswordLabel => 'Текущий пароль';

  @override
  String get newPasswordLabel => 'Новый пароль';

  @override
  String get confirmPasswordFieldLabel => 'Подтверждение';

  @override
  String get changePasswordButton => 'Сменить пароль';

  @override
  String get passwordChanged => 'Пароль изменён';

  @override
  String get appearanceTitle => 'Оформление';

  @override
  String get languageTitle => 'Язык';

  @override
  String get languageRussian => 'Русский';

  @override
  String get languageEnglish => 'English';

  @override
  String get reduceMotionTitle => 'Уменьшить анимации';

  @override
  String get reduceMotionSubtitle => 'Отключает эффекты интерфейса и графиков';

  @override
  String get signOutAccount => 'Выйти из аккаунта';

  @override
  String get sensorFab => 'Датчик';

  @override
  String get newSensorTitle => 'Новый датчик';

  @override
  String get editSensorTitle => 'Изменить датчик';

  @override
  String get deleteSensorTitle => 'Удалить датчик?';

  @override
  String get sensorCreatedTitle => 'Датчик создан';

  @override
  String get siteLabel => 'Площадка';

  @override
  String get noSite => 'Без площадки';

  @override
  String get chartColorLabel => 'Цвет на графике';

  @override
  String get idleDetectionTitle => 'Детекция простоя';

  @override
  String get idlePowerThresholdLabel =>
      'Порог мощности, Вт (пусто = по умолчанию)';

  @override
  String get idleCurrentThresholdLabel => 'Порог тока, А (фолбэк)';

  @override
  String get idleDurationLabel => 'Длительность простоя, сек';

  @override
  String get copyToken => 'Копировать токен';

  @override
  String get copySnippet => 'Копировать сниппет';

  @override
  String get sensorInfoTitle => 'Информация о датчике';

  @override
  String colorValue(String color) {
    return 'Цвет: $color';
  }

  @override
  String createdAt(String date, String byLogin) {
    return 'Создан: $date$byLogin';
  }

  @override
  String currentPlacement(String workshop, String site) {
    return 'Текущее размещение: $workshop$site';
  }

  @override
  String get placementHistoryTitle => 'История размещения';

  @override
  String get placementHistoryEmpty => 'История пуста';

  @override
  String get tabWorkshops => 'Цеха';

  @override
  String get tabSites => 'Площадки';

  @override
  String get noWorkshops => 'Нет цехов';

  @override
  String get noSites => 'Нет площадок';

  @override
  String get fabWorkshop => 'Цех';

  @override
  String get fabSite => 'Площадка';

  @override
  String get newWorkshopTitle => 'Новый цех';

  @override
  String get editWorkshopTitle => 'Изменить цех';

  @override
  String get newSiteTitle => 'Новая площадка';

  @override
  String get editSiteTitle => 'Изменить площадку';

  @override
  String get workshopLabel => 'Цех';

  @override
  String get dashboardColorLabel => 'Цвет на дашборде';

  @override
  String workshopFallback(int id) {
    return 'цех #$id';
  }

  @override
  String siteWorkshopSubtitle(String workshopName) {
    return 'Цех: $workshopName';
  }

  @override
  String get noUsers => 'Нет пользователей';

  @override
  String get youChip => 'вы';

  @override
  String get promoteToAdmin => 'Назначить admin';

  @override
  String get demoteToViewer => 'Понизить до viewer';

  @override
  String promotedSnack(String login) {
    return '$login назначен admin';
  }

  @override
  String demotedSnack(String login) {
    return '$login понижен до viewer';
  }

  @override
  String get chartsTitle => 'Графики';

  @override
  String get addChart => 'Добавить график';

  @override
  String get connectionIssueBanner =>
      'Нет связи с сервером — показаны последние известные данные';

  @override
  String get groupingLabel => 'Группировка';

  @override
  String get renameChartTitle => 'Название графика';

  @override
  String get renameChartHint => 'График 1';

  @override
  String defaultChartTitle(int index) {
    return 'График $index';
  }

  @override
  String get renameTooltip => 'Переименовать';

  @override
  String get removeChartTooltip => 'Удалить график';

  @override
  String get customRangeHelp => 'Произвольный диапазон';

  @override
  String get periodLabel => 'Период:';

  @override
  String get customPeriod => 'Свой';

  @override
  String get loadDataErrorTitle => 'Не удалось загрузить данные';

  @override
  String get noDataForPeriodTitle => 'Нет данных за выбранный период';

  @override
  String get noDataForPeriodSubtitle =>
      'Выберите датчик или группу и убедитесь, что телеметрия поступает.';

  @override
  String chartStats(int pointsCount, int seriesCount) {
    return 'Ток фазы · $pointsCount точек · $seriesCount ряд(ов)';
  }

  @override
  String get currentAxisTitle => 'Ток, А';

  @override
  String get workshopsLabel => 'Цеха:';

  @override
  String get allWorkshops => 'Все цеха';

  @override
  String get sitesLabel => 'Площадки:';

  @override
  String get allSites => 'Все площадки';

  @override
  String get sensorsLabel => 'Датчики:';

  @override
  String get allSensors => 'Все датчики';

  @override
  String get noSitesInGroup => 'Нет площадок в выбранной группе';

  @override
  String get noSensorsInGroup => 'Нет датчиков в выбранной группе';

  @override
  String workshopsLoadError(String error) {
    return 'Цеха: $error';
  }

  @override
  String sitesLoadError(String error) {
    return 'Площадки: $error';
  }

  @override
  String sensorsLoadError(String error) {
    return 'Датчики: $error';
  }

  @override
  String downtimeOfflineChip(String sensorName) {
    return 'Offline · $sensorName';
  }

  @override
  String downtimeIdleChip(String sensorName) {
    return 'Простой · $sensorName';
  }

  @override
  String downtimeOfflineTotal(String duration) {
    return 'Offline: $duration';
  }

  @override
  String downtimeIdleTotal(String duration) {
    return 'Простой: $duration';
  }

  @override
  String workshopDowntimeChip(String workshopName, String duration) {
    return '$workshopName: $duration';
  }

  @override
  String get timePresetMinute => 'Мин';

  @override
  String get timePresetHour => 'Час';

  @override
  String get timePresetDay => 'День';

  @override
  String get timePresetWeek => 'Неделя';

  @override
  String get timePresetMonth => 'Месяц';

  @override
  String get timePresetYear => 'Год';

  @override
  String get chartScaleSeconds => 'Сек';

  @override
  String get chartScaleMinutes => 'Мин';

  @override
  String get chartScaleHours => 'Ч';

  @override
  String get chartScaleDays => 'Дн';

  @override
  String get chartScaleWeeks => 'Нед';

  @override
  String get chartScaleMonths => 'Мес';

  @override
  String get chartScaleYears => 'Год';

  @override
  String durationSeconds(int count) {
    return '$count с';
  }

  @override
  String durationMinutes(int count) {
    return '$count мин';
  }

  @override
  String durationHours(int hours) {
    return '$hours ч';
  }

  @override
  String durationDays(int days) {
    return '$days д';
  }

  @override
  String get provisioningTitle => 'Привязка ESP по BLE';

  @override
  String get provisioningUnavailableWeb =>
      'BLE-привязка недоступна в браузере — используйте телефон или десктоп-приложение';

  @override
  String get rescanTooltip => 'Сканировать снова';

  @override
  String get scanInstructions =>
      'Найдите ESP в режиме привязки (имя начинается с TEC-ESP). Убедитесь, что Bluetooth включён.';

  @override
  String get scanning => 'Сканирование…';

  @override
  String get noDevicesFound => 'Устройства не найдены';

  @override
  String connectFailed(String error) {
    return 'Не удалось подключиться: $error';
  }

  @override
  String tokenFetchFailed(String error) {
    return 'Не удалось получить токен: $error';
  }

  @override
  String get selectDeviceAndSensor =>
      'Выберите ESP и зарегистрированный датчик';

  @override
  String get ssidRequired => 'Укажите SSID Wi-Fi';

  @override
  String get onlineTimeout =>
      'Датчик не перешёл в online за 90 с. Проверьте Wi-Fi и URL сервера.';

  @override
  String connectedTo(String deviceName) {
    return 'Подключено: $deviceName';
  }

  @override
  String get wifiSsidLabel => 'SSID Wi-Fi';

  @override
  String get wifiPasswordLabel => 'Пароль Wi-Fi';

  @override
  String get ingestUrlLabel => 'URL приёма (ingest)';

  @override
  String get ingestUrlHelper => 'POST /api/v1/ingest — LAN-IP, не localhost';

  @override
  String get systemSensorLabel => 'Датчик в системе';

  @override
  String tokenLoaded(int length) {
    return 'Токен загружен с сервера ($length симв.)';
  }

  @override
  String get commitButton => 'Записать и привязать';

  @override
  String get selectOtherDevice => 'Выбрать другое устройство';

  @override
  String provisioningSensorsLoadError(String error) {
    return 'Ошибка загрузки датчиков: $error';
  }

  @override
  String get waitingTelemetry => 'Ожидание первой телеметрии…';

  @override
  String get waitingDescription =>
      'ESP подключается к Wi-Fi и отправляет данные';

  @override
  String successOnline(String name) {
    return 'Датчик $name online';
  }

  @override
  String get bleServiceNotFound => 'Сервис привязки не найден';

  @override
  String bleCharacteristicNotFound(String uuid) {
    return 'Характеристика $uuid не найдена';
  }

  @override
  String themeTooltip(String theme) {
    return 'Тема: $theme';
  }

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get hexColorFormat => 'Формат: #RRGGBB';

  @override
  String get serverUrlLabel => 'Адрес сервера';

  @override
  String get serverUrlHelper =>
      'URL API-сервера (http или https, с портом при необходимости)';

  @override
  String get saveServerUrl => 'Сохранить адрес';

  @override
  String get serverUrlSaved => 'Адрес сервера сохранён';

  @override
  String get errorInvalidServerUrl =>
      'Укажите корректный URL (http:// или https://)';

  @override
  String errorNoConnectionTo(String url) {
    return 'Нет связи с сервером $url';
  }

  @override
  String get errorNoConnection => 'Нет связи с сервером';

  @override
  String get errorAuthRequired => 'Требуется вход';

  @override
  String get errorForbidden => 'Недостаточно прав';

  @override
  String errorServer(int code) {
    return 'Ошибка сервера ($code)';
  }

  @override
  String get errorNetwork => 'Ошибка сети';

  @override
  String get errorLoad => 'Ошибка загрузки';

  @override
  String get navMonitoring => 'Мониторинг';

  @override
  String get navAppSubtitle => 'ТЭК · Мониторинг датчиков';

  @override
  String get bleProvisioningTooltip => 'Привязка ESP по BLE';

  @override
  String get accountTooltip => 'Аккаунт';

  @override
  String get navSettings => 'Настройки';

  @override
  String get signOut => 'Выйти';

  @override
  String get navDashboard => 'Дашборд';

  @override
  String get navSensors => 'Датчики';

  @override
  String get navGroups => 'Группы';

  @override
  String get navUsers => 'Пользователи';
}
