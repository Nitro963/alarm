class AlarmSettings {
  /// Unique identifier associated with the alarm.
  final int id;

  final DateTime _dateTime;

  /// Date and time when the alarm will be triggered.
  DateTime get dateTime => _dateTime;

  /// Path to audio asset to be used as the alarm ringtone. Accepted formats:
  ///
  /// * Project asset: `assets/your_audio.mp3`.
  /// * Local asset: `/path/to/your/audio.mp3`, which is your `File.path`.
  final String assetAudioPath;

  /// If true, [assetAudioPath] will repeat indefinitely until alarm is stopped.
  final bool loopAudio;

  /// If true, device will vibrate for 500ms, pause for 500ms and repeat until
  /// alarm is stopped.
  ///
  /// If [loopAudio] is set to false, vibrations will stop when audio ends.
  final bool vibrate;

  /// If true, set system volume to maximum when [dateTime] is reached
  /// and set it back to its previous value when alarm is stopped.
  /// Else, use current system volume. Enabled by default.
  final bool volumeMax;

  /// Duration, in seconds, over which to fade the alarm ringtone.
  /// Set to 0.0 by default, which means no fade.
  final double fadeDuration;

  /// Title of the notification to be shown when alarm is triggered.
  /// Must not be null nor empty to show a notification.
  final String? notificationTitle;

  /// Body of the notification to be shown when alarm is triggered.
  /// Must not be null nor empty to show a notification.
  final String? notificationBody;

  /// Whether to show a notification when application is killed to warn
  /// the user that the alarms won't ring anymore. Enabled by default.
  final bool enableNotificationOnKill;

  /// Stops the alarm on opened notification.
  final bool stopOnNotificationOpen;

  /// Whether to turn screen on when android alarm notification is triggered. Enabled by default.
  ///
  /// [notificationTitle] and [notificationBody] must not be null nor empty.
  final bool androidFullScreenIntent;

  /// Whether to repeat the alarm on a weekly basis. Disabled by default and ignored if [repeatDaily] is enabled
  final bool repeatWeekly;

  /// Whether to repeat the alarm on a daily basis. Disabled by default
  /// Has priority over [repeatWeekly]
  final bool repeatDaily;

  /// The repeat day of week. Ignored if [repeatWeekly] is false or [repeatDaily] is true.
  final int dayOfWeek;

  /// Returns a hash code for this `AlarmSettings` instance using Jenkins hash function.
  @override
  int get hashCode {
    var hash = 0;

    hash = hash ^ id.hashCode;
    hash = hash ^ _dateTime.hashCode;
    hash = hash ^ assetAudioPath.hashCode;
    hash = hash ^ loopAudio.hashCode;
    hash = hash ^ vibrate.hashCode;
    hash = hash ^ volumeMax.hashCode;
    hash = hash ^ fadeDuration.hashCode;
    hash = hash ^ (notificationTitle?.hashCode ?? 0);
    hash = hash ^ (notificationBody?.hashCode ?? 0);
    hash = hash ^ enableNotificationOnKill.hashCode;
    hash = hash ^ stopOnNotificationOpen.hashCode;
    hash = hash ^ repeatWeekly.hashCode;
    hash = hash ^ dayOfWeek.hashCode;
    hash = hash & 0x3fffffff;

    return hash;
  }

  /// Model that contains all the settings to customize and set an alarm.
  ///
  ///
  /// Note that if you want to show a notification when alarm is triggered,
  /// both [notificationTitle] and [notificationBody] must not be null nor empty.
  AlarmSettings({
    required this.id,
    required DateTime dateTime,
    required this.assetAudioPath,
    this.loopAudio = true,
    this.vibrate = true,
    this.volumeMax = true,
    this.fadeDuration = 0.0,
    this.notificationTitle,
    this.notificationBody,
    this.enableNotificationOnKill = true,
    this.stopOnNotificationOpen = false,
    this.androidFullScreenIntent = true,
    this.repeatWeekly = false,
    this.repeatDaily = false,
    this.dayOfWeek = 1,
  }) : _dateTime =
            dateTime.copyWith(second: 0, microsecond: 0, millisecond: 0) {
    assert(dayOfWeek <= 7);
    assert(dayOfWeek > 0);
  }

  /// Constructs an `AlarmSettings` instance from the given JSON data.
  factory AlarmSettings.fromJson(Map<String, dynamic> json) => AlarmSettings(
        id: json['id'] as int,
        dateTime: DateTime.fromMicrosecondsSinceEpoch(json['dateTime'] as int),
        assetAudioPath: json['assetAudioPath'] as String,
        loopAudio: json['loopAudio'] as bool,
        vibrate: json['vibrate'] as bool,
        volumeMax: json['volumeMax'] as bool,
        fadeDuration: json['fadeDuration'] as double,
        notificationTitle: json['notificationTitle'] as String?,
        notificationBody: json['notificationBody'] as String?,
        enableNotificationOnKill: json['enableNotificationOnKill'] as bool,
        stopOnNotificationOpen: json['stopOnNotificationOpen'] as bool,
        repeatWeekly: json['repeatWeekly'] as bool,
        repeatDaily: json['repeatDaily'] as bool,
        dayOfWeek: json['dayOfWeek'] as int,
        androidFullScreenIntent:
            json['androidFullScreenIntent'] as bool? ?? false,
      );

  /// Creates a copy of `AlarmSettings` but with the given fields replaced with
  /// the new values.
  AlarmSettings copyWith(
      {int? id,
      DateTime? dateTime,
      String? assetAudioPath,
      bool? loopAudio,
      bool? vibrate,
      bool? volumeMax,
      double? fadeDuration,
      String? notificationTitle,
      String? notificationBody,
      bool? enableNotificationOnKill,
      bool? stopOnNotificationOpen,
      bool? androidFullScreenIntent,
      bool? repeatWeekly,
      bool? repeatDaily,
      int? dayOfWeek}) {
    return AlarmSettings(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      assetAudioPath: assetAudioPath ?? this.assetAudioPath,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      volumeMax: volumeMax ?? this.volumeMax,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      notificationTitle: notificationTitle ?? this.notificationTitle,
      notificationBody: notificationBody ?? this.notificationBody,
      repeatWeekly: repeatWeekly ?? this.repeatWeekly,
      repeatDaily: repeatDaily ?? this.repeatDaily,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      enableNotificationOnKill:
          enableNotificationOnKill ?? this.enableNotificationOnKill,
      stopOnNotificationOpen:
          stopOnNotificationOpen ?? this.stopOnNotificationOpen,
      androidFullScreenIntent:
          androidFullScreenIntent ?? this.androidFullScreenIntent,
    );
  }

  /// Converts this `AlarmSettings` instance to JSON data.
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.microsecondsSinceEpoch,
        'assetAudioPath': assetAudioPath,
        'loopAudio': loopAudio,
        'vibrate': vibrate,
        'volumeMax': volumeMax,
        'fadeDuration': fadeDuration,
        'notificationTitle': notificationTitle,
        'notificationBody': notificationBody,
        'enableNotificationOnKill': enableNotificationOnKill,
        'stopOnNotificationOpen': stopOnNotificationOpen,
        'androidFullScreenIntent': androidFullScreenIntent,
        'repeatWeekly': repeatWeekly,
        'repeatDaily': repeatDaily,
        'dayOfWeek': dayOfWeek,
      };

  /// Returns all the properties of `AlarmSettings` for debug purposes.
  @override
  String toString() {
    Map<String, dynamic> json = toJson();
    json['dateTime'] = DateTime.fromMicrosecondsSinceEpoch(json['dateTime']);

    return "AlarmSettings: ${json.toString()}";
  }

  /// Compares two AlarmSettings.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlarmSettings &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          dateTime == other.dateTime &&
          assetAudioPath == other.assetAudioPath &&
          loopAudio == other.loopAudio &&
          vibrate == other.vibrate &&
          volumeMax == other.volumeMax &&
          fadeDuration == other.fadeDuration &&
          notificationTitle == other.notificationTitle &&
          notificationBody == other.notificationBody &&
          repeatWeekly == other.repeatWeekly &&
          repeatDaily == other.repeatDaily &&
          dayOfWeek == other.dayOfWeek &&
          enableNotificationOnKill == other.enableNotificationOnKill &&
          stopOnNotificationOpen == other.stopOnNotificationOpen &&
          androidFullScreenIntent == other.androidFullScreenIntent;

  bool get stalled => repeatWeekly ? false : DateTime.now().isAfter(dateTime);
}
