import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:alarm/alarm.dart';
import 'package:alarm/service/storage.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:vibration/vibration.dart';
import 'package:volume_controller/volume_controller.dart';

import '../service/notification.dart';

/// For Android support, [AndroidAlarmManager] is used to trigger a callback
/// when the given time is reached. The callback will run in an isolate if app
/// is in background.
class AndroidAlarm {
  static const ringPort = 'alarm-ring';
  static const stopPort = 'alarm-stop';

  static const platform =
      MethodChannel('com.gdelataillade.alarm/notifOnAppKill');

  static bool ringing = false;
  static bool vibrationsActive = false;
  static double? previousVolume;

  static bool get isRinging => ringing;

  static Future<bool> get hasOtherAlarms async =>
      alarmStorage.getAll().then((value) => value.length > 1);

  static late AlarmStorage alarmStorage;

  /// Initializes AndroidAlarmManager dependency.
  static Future<void> init(AlarmStorage storage) async {
    alarmStorage = storage;
    await AndroidAlarmManager.initialize();
  }

  /// Creates isolate communication channel and set alarm at given [dateTime].
  static Future<bool> set(
    AlarmSettings settings,
    void Function()? onRing,
  ) async {
    final id = settings.id;
    try {
      final port = ReceivePort();
      final success = IsolateNameServer.registerPortWithName(
        port.sendPort,
        "$ringPort-$id",
      );

      if (!success) {
        IsolateNameServer.removePortNameMapping("$ringPort-$id");
        IsolateNameServer.registerPortWithName(port.sendPort, "$ringPort-$id");
      }
      port.listen((message) {
        alarmPrint('$message');
        if (message == 'ring') {
          ringing = true;
          if (settings.volumeMax) setMaximumVolume();
          onRing?.call();
        } else {
          if (settings.vibrate &&
              message is String &&
              message.startsWith('vibrate')) {
            final audioDuration = message.split('-').last;

            if (int.tryParse(audioDuration) != null) {
              final duration = Duration(seconds: int.parse(audioDuration));
              triggerVibrations(duration: settings.loopAudio ? null : duration);
            }
          }
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }

    late final bool res;
    late DateTime scheduledDate;
    if (settings.repeatWeekly || settings.repeatDaily) {
      DateTime now = DateTime.now();
      late Duration interval;
      if (settings.repeatDaily) {
        interval = const Duration(days: 1);
        scheduledDate = now.copyWith(
            hour: settings.dateTime.hour,
            minute: settings.dateTime.minute,
            second: 0,
            microsecond: 0,
            millisecond: 0);
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.add(interval);
        }
      } else {
        interval = const Duration(days: 7);
        scheduledDate = settings.dateTime;
        if (scheduledDate.isBefore(now)) {
          scheduledDate = scheduledDate.next(settings.dayOfWeek);
        }
      }
    } else {
      scheduledDate = settings.dateTime;
    }
    if (scheduledDate.difference(DateTime.now()).inSeconds <= 1) {
      await playAlarm(id, {
        "assetAudioPath": settings.assetAudioPath,
        "loopAudio": settings.loopAudio,
        "fadeDuration": settings.fadeDuration,
        'notificationTitle': settings.notificationTitle,
        'notificationBody': settings.notificationBody,
        'androidFullScreenIntent': settings.androidFullScreenIntent,
      });
      return true;
    }

    res = await AndroidAlarmManager.oneShotAt(
      scheduledDate,
      id,
      AndroidAlarm.playAlarm,
      alarmClock: true,
      allowWhileIdle: true,
      exact: true,
      rescheduleOnReboot: true,
      wakeup: true,
      params: {
        'assetAudioPath': settings.assetAudioPath,
        'loopAudio': settings.loopAudio,
        'fadeDuration': settings.fadeDuration,
        'notificationTitle': settings.notificationTitle,
        'notificationBody': settings.notificationBody,
        'androidFullScreenIntent': settings.androidFullScreenIntent,
      },
    );
    alarmPrint(
      'Alarm with id $id scheduled ${res ? 'successfully' : 'failed'} at $scheduledDate',
    );

    if (settings.enableNotificationOnKill && !await hasOtherAlarms) {
      try {
        final (notificationOnAppKillTitle, notificationOnAppKillBody) =
            await alarmStorage.getNotificationOnAppKill();
        await platform.invokeMethod(
          'setNotificationOnKillService',
          {
            'title': notificationOnAppKillTitle,
            'description': notificationOnAppKillBody,
          },
        );
        alarmPrint('NotificationOnKillService set with success');
      } catch (e) {
        throw AlarmException('NotificationOnKillService error: $e');
      }
    }

    return res;
  }

  /// Callback triggered when alarmDateTime is reached.
  /// The message `ring` is sent to the main thread in order to
  /// tell the device that the alarm is starting to ring.
  /// Alarm is played with AudioPlayer and stopped when the message `stop`
  /// is received from the main thread.
  @pragma('vm:entry-point')
  static Future<void> playAlarm(int id, Map<String, dynamic> data) async {
    DartPluginRegistrant.ensureInitialized();
    await AlarmNotification.instance.init();
    final notificationTitle = data['notificationTitle'];
    final notificationBody = data['notificationBody'];
    final androidFullScreenIntent = data['androidFullScreenIntent'];

    if ((notificationTitle?.isNotEmpty ?? false) &&
        (notificationBody?.isNotEmpty ?? false)) {
      await AlarmNotification.instance.showAlarmNotif(
        id: id,
        title: notificationTitle!,
        body: notificationBody!,
        fullScreenIntent: androidFullScreenIntent ?? false,
      );
    }

    final audioPlayer = AudioPlayer();

    final res = IsolateNameServer.lookupPortByName("$ringPort-$id");
    if (res == null) throw const AlarmException('Isolate port not found');

    final send = res;
    send.send('ring');

    try {
      final assetAudioPath = data['assetAudioPath'] as String;
      Duration? audioDuration;

      if (assetAudioPath.startsWith('http')) {
        send.send('Network URL not supported. Please provide local asset.');
        return;
      }

      audioDuration = assetAudioPath.startsWith('assets/')
          ? await audioPlayer.setAsset(assetAudioPath)
          : await audioPlayer.setFilePath(assetAudioPath);

      send.send('vibrate-${audioDuration?.inSeconds}');

      final loopAudio = data['loopAudio'] as bool;
      if (loopAudio) audioPlayer.setLoopMode(LoopMode.all);

      send.send('Alarm data received in isolate: $data');

      final fadeDuration = data['fadeDuration'];

      send.send('Alarm fadeDuration: $fadeDuration seconds');

      if (fadeDuration > 0.0) {
        int counter = 0;

        audioPlayer.setVolume(0.1);
        audioPlayer.play();

        send.send('Alarm playing with fadeDuration ${fadeDuration}s');

        Timer.periodic(
          Duration(milliseconds: fadeDuration * 1000 ~/ 10),
          (timer) {
            counter++;
            audioPlayer.setVolume(counter / 10);
            if (counter >= 10) timer.cancel();
          },
        );
      } else {
        audioPlayer.play();
        send.send('Alarm with id $id starts playing.');
      }
    } catch (e) {
      await AudioPlayer.clearAssetCache();
      send.send('Asset cache reset. Please try again.');
      throw AlarmException(
        "Alarm with id $id and asset path '${data['assetAudioPath']}' error: $e",
      );
    }

    try {
      final port = ReceivePort();
      final success =
          IsolateNameServer.registerPortWithName(port.sendPort, stopPort);

      if (!success) {
        IsolateNameServer.removePortNameMapping(stopPort);
        IsolateNameServer.registerPortWithName(port.sendPort, stopPort);
      }

      port.listen((message) async {
        send.send('(isolate) received: $message');
        if (message == 'stop') {
          AlarmNotification.instance.localNotif.cancel(id);
          await audioPlayer.stop();
          await audioPlayer.dispose();
          port.close();
        }
      });
    } catch (e) {
      throw AlarmException('Isolate error: $e');
    }
  }

  /// Triggers vibrations when alarm is ringing if [vibrationsActive] is true.
  ///
  /// If [loopAudio] is false, vibrations are triggered repeatedly during
  /// [duration] which is the duration of the audio.
  static Future<void> triggerVibrations({Duration? duration}) async {
    final hasVibrator = await Vibration.hasVibrator() ?? false;

    if (!hasVibrator) {
      alarmPrint('Vibrations are not available on this device.');
      return;
    }

    vibrationsActive = true;

    if (duration == null) {
      while (vibrationsActive) {
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    } else {
      final endTime = DateTime.now().add(duration);
      while (vibrationsActive && DateTime.now().isBefore(endTime)) {
        Vibration.vibrate();
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  /// Sets the device volume to the maximum.
  static Future<void> setMaximumVolume() async {
    previousVolume = await VolumeController().getVolume();
    VolumeController().setVolume(1.0, showSystemUI: false);
  }

  /// Sends the message `stop` to the isolate so the audio player
  /// can stop playing and dispose.
  static Future<bool> stop(int id) async {
    ringing = false;
    vibrationsActive = false;

    final send = IsolateNameServer.lookupPortByName(stopPort);

    if (send != null) {
      send.send('stop');
      alarmPrint('Alarm with id $id stopped');
    }

    if (previousVolume != null) {
      VolumeController().setVolume(previousVolume!, showSystemUI: false);
      previousVolume = null;
    }

    if (!await hasOtherAlarms) stopNotificationOnKillService();

    return true;
  }

  /// Dispose alarm.
  static Future<bool> cancel(int id) async {
    final res = await AndroidAlarmManager.cancel(id);
    if (res) alarmPrint('Alarm with id $id cancelled');
    return res;
  }

  static Future<void> stopNotificationOnKillService() async {
    try {
      await platform.invokeMethod('stopNotificationOnKillService');
      alarmPrint('NotificationOnKillService stopped with success');
    } catch (e) {
      throw AlarmException('NotificationOnKillService error: $e');
    }
  }
}
