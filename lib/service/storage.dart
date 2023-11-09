import 'dart:convert';

import 'package:alarm/alarm.dart';
import 'package:alarm/model/alarm_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AlarmStorage {
  const AlarmStorage();

  bool get initialized;

  Future<void> init();

  /// Retrieve the alarm from local storage
  Future<AlarmSettings?> getAlarm(int id);

  /// Saves alarm info in local storage so we can restore it later
  /// in the case app is terminated.  Future<void> saveAlarm(AlarmSettings alarmSettings);
  Future<void> saveAlarm(AlarmSettings alarmSettings);

  /// Removes alarm from local storage.
  Future<bool> deleteAlarm(int obj);

  Future<List<bool>> deleteAll(List<int> objects);

  /// Returns all alarms info from local storage in the case app is terminated
  /// and we need to restore previously scheduled alarms.
  Future<List<AlarmSettings>> getAll();

  /// Saves on app kill notification custom [title] and [body].
  Future<void> setNotificationContentOnAppKill(String title, String body);

  /// Whether at least one alarm is set.
  Future<bool> get hasAlarm;

  /// Returns notification on app kill [title] and [body].
  Future<(String, String)> getNotificationOnAppKill();
}

class DefaultAlarmStorage implements AlarmStorage {
  static const prefix = '__alarm_id__';
  static const notificationOnAppKill = 'notificationOnAppKill';
  static const notificationOnAppKillTitleKey = 'notificationOnAppKillTitle';
  static const notificationOnAppKillBodyKey = 'notificationOnAppKillBody';

  late SharedPreferences prefs;
  bool _initialized = false;

  @override
  bool get initialized => _initialized;

  @override
  Future<void> init() async {
    if (initialized) return;
    prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  @override
  Future<void> saveAlarm(AlarmSettings alarmSettings) => prefs.setString(
        '$prefix${alarmSettings.id}',
        json.encode(alarmSettings.toJson()),
      );

  @override
  Future<bool> deleteAlarm(int id) => prefs.remove("$prefix$id");

  @override
  Future<bool> get hasAlarm async {
    final keys = prefs.getKeys();
    return keys.any((element) => element.startsWith(prefix));
  }

  @override
  Future<List<AlarmSettings>> getAll() async {
    final alarms = <AlarmSettings>[];
    final keys = prefs.getKeys();

    for (final key in keys) {
      if (key.startsWith(prefix)) {
        final res = prefs.getString(key);
        alarms.add(AlarmSettings.fromJson(json.decode(res!)));
      }
    }

    return alarms;
  }

  @override
  Future<void> setNotificationContentOnAppKill(
    String title,
    String body,
  ) =>
      Future.wait([
        prefs.setString(notificationOnAppKillTitleKey, title),
        prefs.setString(notificationOnAppKillBodyKey, body),
      ]);

  @override
  Future<(String, String)> getNotificationOnAppKill() async {
    return (
      prefs.getString(notificationOnAppKillTitleKey) ??
          'Your alarms may not ring',
      prefs.getString(notificationOnAppKillBodyKey) ??
          'You killed the app. Please reopen so your alarms can be rescheduled.'
    );
  }

  @override
  Future<List<bool>> deleteAll(List<int> objects) async {
    return Future.wait(objects.map((e) => "$prefix$e").map(prefs.remove));
  }

  @override
  Future<AlarmSettings?> getAlarm(int id) async {
    final res = prefs.getString("$prefix$id");
    if (res != null) {
      return AlarmSettings.fromJson(json.decode(res));
    }
    return null;
  }
}
