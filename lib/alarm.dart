// ignore_for_file: avoid_print

import 'dart:async';

import 'package:alarm/model/alarm_settings.dart';
import 'package:alarm/service/notification.dart';
import 'package:alarm/service/storage.dart';
import 'package:alarm/src/android_alarm.dart';
import 'package:alarm/src/ios_alarm.dart';
import 'package:flutter/foundation.dart';

export 'package:alarm/model/alarm_settings.dart';
export 'package:alarm/src/android_alarm.dart';

/// Custom print function designed for Alarm plugin.
DebugPrintCallback alarmPrint = debugPrintThrottled;

extension DateTimeExtension on DateTime {
  DateTime next(int day) {
    if (day == weekday) {
      return add(const Duration(days: 7));
    } else {
      return add(
        Duration(
          days: (day - weekday) % DateTime.daysPerWeek,
        ),
      );
    }
  }

  DateTime previous(int day) {
    if (day == weekday) {
      return subtract(const Duration(days: 7));
    } else {
      return subtract(
        Duration(
          days: (weekday - day) % DateTime.daysPerWeek,
        ),
      );
    }
  }
}

class Alarm {
  /// Whether it's iOS device.
  static bool get iOS => defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether it's Android device.
  static bool get android => defaultTargetPlatform == TargetPlatform.android;

  /// Stream of the ringing status.
  static final ringStream = StreamController<AlarmSettings>();
  static late AlarmStorage storage;

  /// Initializes Alarm services.
  ///
  /// Also calls [checkAlarm] asynchronously to reschedule alarms that were set before
  /// app termination.
  ///
  /// Set [showDebugLogs] to `false` to hide all the logs from the plugin.
  static Future<void> init(
      {bool showDebugLogs = true, AlarmStorage? db}) async {
    alarmPrint = (String? message, {int? wrapWidth}) {
      if (kDebugMode && showDebugLogs) {
        print("[Alarm] $message");
      }
    };
    storage = db ?? DefaultAlarmStorage();
    if (!storage.initialized) {
      await storage.init();
    }
    await Future.wait([
      if (android) AndroidAlarm.init(storage),
      if (iOS) IOSAlarm.init(storage),
      AlarmNotification.instance.init(),
    ]);
    checkAlarm();
  }

  /// Checks if some alarms were set on previous session.
  /// If it's the case then reschedules them.
  static Future<void> checkAlarm() async {
    final alarms = await storage.getAll();
    final futures = List<Future<bool>>.empty(growable: true);
    for (final alarm in alarms) {
      final now = DateTime.now();
      if (alarm.dateTime.isAfter(now)) {
        futures.add(set(alarmSettings: alarm));
        continue;
      } else {
        if (alarm.stalled) {
          futures.add(storage.deleteAlarm(alarm.id));
          continue;
        }
      }
      if (alarm.repeatWeekly || alarm.repeatDaily) {
        futures.add(scheduleRepeatedAlarm(alarm));
      }
    }
    await Future.wait(futures);
  }

  /// Schedules an alarm with given [alarmSettings].
  ///
  /// If you set an alarm for the same [dateTime] as an existing one,
  /// the new alarm will replace the existing one.
  ///
  /// Also, schedules notification if [notificationTitle] and [notificationBody]
  /// are not null nor empty.
  static Future<bool> set({required AlarmSettings alarmSettings}) async {
    if (!alarmSettings.assetAudioPath.contains('.')) {
      throw AlarmException(
        'Provided asset audio file does not have extension: ${alarmSettings.assetAudioPath}',
      );
    }
    final alarms = await storage.getAll();
    for (final alarm in alarms) {
      if (alarm.id == alarmSettings.id ||
          (alarm.dateTime.day == alarmSettings.dateTime.day &&
              alarm.dateTime.hour == alarmSettings.dateTime.hour &&
              alarm.dateTime.minute == alarmSettings.dateTime.minute)) {
        await Alarm.stop(alarm.id);
      }
    }

    await storage.saveAlarm(alarmSettings);

    if (alarmSettings.enableNotificationOnKill) {
      await AlarmNotification.instance.requestPermission();
    }

    if (iOS) {
      return IOSAlarm.setAlarm(
        alarmSettings,
        () async {
          final notificationTitle = alarmSettings.notificationTitle;
          final notificationBody = alarmSettings.notificationBody;

          if ((notificationTitle?.isNotEmpty ?? false) &&
              (notificationBody?.isNotEmpty ?? false)) {
            try{
              await AlarmNotification.instance.showAlarmNotif(
                id: alarmSettings.id,
                title: notificationTitle!,
                body: notificationBody!,
                fullScreenIntent: false,
              );
            } catch(e){
              alarmPrint(
                'Failed to show notification for alarm with id ${alarmSettings.id}',
              );
            }
          }

          return ringStream.add(alarmSettings);
        },
      );
    } else if (android) {
      return await AndroidAlarm.set(
        alarmSettings,
        () => ringStream.add(alarmSettings),
      );
    }

    return false;
  }

  /// Stops alarm.
  static Future<bool> stop(int id) async {
    return (iOS ? IOSAlarm.stopAlarm(id) : AndroidAlarm.stop(id))
        .then((_) => storage.getAlarm(id))
        .then((alarm) =>
            alarm?.stalled == true ? cancel(id) : Future.value(true));
  }

  /// Stops alarm.
  static Future<bool> cancel(int id) async {
    AlarmNotification.instance.cancel(id);

    // TODO add ios dispose alarm method
    return iOS ? IOSAlarm.stopAlarm(id) : AndroidAlarm.cancel(id);
  }

  /// Stops all the alarms.
  static Future<void> stopAll() async {
    final alarms = await storage.getAll();
    final futures = List<Future<void>>.empty(growable: true);
    for (final alarm in alarms) {
      futures.add(stop(alarm.id));
    }
    await Future.wait(futures);
  }

  /// Whether the alarm is ringing.
  static Future<bool> isRinging(int id) async =>
      iOS ? await IOSAlarm.checkIfRinging(id) : AndroidAlarm.isRinging;

  /// Whether an alarm is set.
  static Future<bool> get hasAlarm async => storage.hasAlarm;

  /// Returns alarm by given id. Returns null if not found.
  static Future<AlarmSettings?> getAlarm(int id) async {
    List<AlarmSettings> alarms = await storage.getAll();

    for (final alarm in alarms) {
      if (alarm.id == id) return alarm;
    }
    alarmPrint('Alarm with id $id not found.');

    return null;
  }

  static Future<bool> scheduleRepeatedAlarm(AlarmSettings settings) async {
    if (!settings.repeatDaily && !settings.repeatWeekly) return true;
    final now = DateTime.now();
    return Alarm.set(
        alarmSettings: settings.copyWith(
            repeatWeekly: false,
            repeatDaily: false,
            dateTime: settings.repeatWeekly
                ? now.next(settings.dayOfWeek).copyWith(
                    hour: settings.dateTime.hour,
                    minute: settings.dateTime.minute)
                : settings.repeatDaily
                    ? now.copyWith(
                        hour: settings.dateTime.hour,
                        minute: settings.dateTime.minute)
                    : throw const AlarmException(
                        'Scheduling a one shot alarm is illegal')));
  }
}

class AlarmException implements Exception {
  final String message;

  const AlarmException(this.message);

  @override
  String toString() => message;
}
