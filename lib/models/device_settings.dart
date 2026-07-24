/// Strongly-typed device settings models matching the TanE06 API schema.
///
/// Top-level [DeviceSettings] contains sub-objects for each settings section:
/// health, step, sleep, location, safety, call, watch.
///
/// Each model provides [fromJson] / [toJson] for API serialization.

// ---------------------------------------------------------------------------
// Top-Level Container
// ---------------------------------------------------------------------------

class DeviceSettings {
  final UserProfile profile;
  final HealthSettings health;
  final StepSettings step;
  final SleepSettings sleep;
  final LocationSettings location;
  final SafetySettings safety;
  final CallSettings call;
  final WatchSettings watch;

  const DeviceSettings({
    this.profile = const UserProfile(),
    required this.health,
    required this.step,
    required this.sleep,
    required this.location,
    required this.safety,
    required this.call,
    required this.watch,
  });

  factory DeviceSettings.fromJson(Map<String, dynamic> json) {
    return DeviceSettings(
      profile: UserProfile.fromJson(
          json['profile'] as Map<String, dynamic>? ?? {}),
      health: HealthSettings.fromJson(
          json['health'] as Map<String, dynamic>? ?? {}),
      step:
          StepSettings.fromJson(json['step'] as Map<String, dynamic>? ?? {}),
      sleep: SleepSettings.fromJson(
          json['sleep'] as Map<String, dynamic>? ?? {}),
      location: LocationSettings.fromJson(
          json['location'] as Map<String, dynamic>? ?? {}),
      safety: SafetySettings.fromJson(
          json['safety'] as Map<String, dynamic>? ?? {}),
      call:
          CallSettings.fromJson(json['call'] as Map<String, dynamic>? ?? {}),
      watch: WatchSettings.fromJson(
          json['watch'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'health': health.toJson(),
        'step': step.toJson(),
        'sleep': sleep.toJson(),
        'location': location.toJson(),
        'safety': safety.toJson(),
        'call': call.toJson(),
        'watch': watch.toJson(),
      };
}

class UserProfile {
  final int age;
  final String sex;
  final num height;
  final num weight;

  const UserProfile({
    this.age = 32,
    this.sex = 'Male',
    this.height = 175,
    this.weight = 70,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      age: json['age'] as int? ?? 32,
      sex: json['sex']?.toString() ?? 'Male',
      height: json['height'] as num? ?? 175,
      weight: json['weight'] as num? ?? 70,
    );
  }

  Map<String, dynamic> toJson() => {
        'age': age,
        'sex': sex,
        'height': height,
        'weight': weight,
      };
}

// ---------------------------------------------------------------------------
// Health Settings
// ---------------------------------------------------------------------------

class HealthSettings {
  final HeartRateSettings heartRate;
  final BloodPressureSettings bloodPressure;
  final BloodOxygenSettings bloodOxygen;
  final BodyTemperatureSettings bodyTemperature;

  const HealthSettings({
    required this.heartRate,
    required this.bloodPressure,
    required this.bloodOxygen,
    required this.bodyTemperature,
  });

  factory HealthSettings.fromJson(Map<String, dynamic> json) {
    return HealthSettings(
      heartRate: HeartRateSettings.fromJson(
          json['heart_rate'] as Map<String, dynamic>? ?? {}),
      bloodPressure: BloodPressureSettings.fromJson(
          json['blood_pressure'] as Map<String, dynamic>? ?? {}),
      bloodOxygen: BloodOxygenSettings.fromJson(
          json['blood_oxygen'] as Map<String, dynamic>? ?? {}),
      bodyTemperature: BodyTemperatureSettings.fromJson(
          json['body_temperature'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'heart_rate': heartRate.toJson(),
        'blood_pressure': bloodPressure.toJson(),
        'blood_oxygen': bloodOxygen.toJson(),
        'body_temperature': bodyTemperature.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Heart Rate
// ---------------------------------------------------------------------------

class WarningConfig {
  final int switchState;
  final num value;
  final int exerciseSwitchState;
  final int exerciseMin;
  final int exerciseMax;
  final int exerciseValue;

  const WarningConfig({
    this.switchState = 0,
    this.value = 0,
    this.exerciseSwitchState = 0,
    this.exerciseMin = 100,
    this.exerciseMax = 140,
    this.exerciseValue = 140,
  });

  factory WarningConfig.fromJson(Map<String, dynamic> json) {
    return WarningConfig(
      switchState: json['switch_state'] as int? ?? 0,
      value: json['value'] as num? ?? 0,
      exerciseSwitchState: json['exercise_switch_state'] as int? ?? 0,
      exerciseMin: json['exercise_min'] as int? ?? 100,
      exerciseMax: json['exercise_max'] as int? ?? 140,
      exerciseValue: json['exercise_value'] as int? ?? 140,
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'value': value,
        'exercise_switch_state': exerciseSwitchState,
        'exercise_min': exerciseMin,
        'exercise_max': exerciseMax,
        'exercise_value': exerciseValue,
      };
}

class HeartRateSettings {
  final String interval;
  final int switchState;
  final WarningConfig highWarning;
  final WarningConfig lowWarning;

  const HeartRateSettings({
    this.interval = '60',
    this.switchState = 1,
    this.highWarning = const WarningConfig(),
    this.lowWarning = const WarningConfig(),
  });

  factory HeartRateSettings.fromJson(Map<String, dynamic> json) {
    return HeartRateSettings(
      interval: json['interval'] as String? ?? '60',
      switchState: json['switch_state'] as int? ?? 1,
      highWarning: WarningConfig.fromJson(
          json['high_warning'] as Map<String, dynamic>? ?? {}),
      lowWarning: WarningConfig.fromJson(
          json['low_warning'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'switch_state': switchState,
        'high_warning': highWarning.toJson(),
        'low_warning': lowWarning.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Blood Pressure
// ---------------------------------------------------------------------------

class TimerMeasureConfig {
  final int switchState;
  final String amTime;
  final String pmTime;

  const TimerMeasureConfig({
    this.switchState = 1,
    this.amTime = '07:00',
    this.pmTime = '18:00',
  });

  factory TimerMeasureConfig.fromJson(Map<String, dynamic> json) {
    return TimerMeasureConfig(
      switchState: json['switch_state'] as int? ?? 1,
      amTime: json['am_time']?.toString() ?? '07:00',
      pmTime: json['pm_time']?.toString() ?? '18:00',
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'am_time': amTime,
        'pm_time': pmTime,
      };
}

class BpWarningConfig {
  final int switchState;
  final int high;
  final int low;

  const BpWarningConfig({
    this.switchState = 1,
    this.high = 135,
    this.low = 90,
  });

  factory BpWarningConfig.fromJson(Map<String, dynamic> json) {
    return BpWarningConfig(
      switchState: json['switch_state'] as int? ?? 1,
      high: json['high'] as int? ?? 135,
      low: json['low'] as int? ?? 90,
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'high': high,
        'low': low,
      };
}

class BloodPressureSettings {
  final String interval;
  final TimerMeasureConfig timerMeasure;
  final BpWarningConfig warning;

  const BloodPressureSettings({
    this.interval = '60',
    this.timerMeasure = const TimerMeasureConfig(),
    this.warning = const BpWarningConfig(),
  });

  factory BloodPressureSettings.fromJson(Map<String, dynamic> json) {
    return BloodPressureSettings(
      interval: json['interval'] as String? ?? '60',
      timerMeasure: TimerMeasureConfig.fromJson(
          json['timer_measure'] as Map<String, dynamic>? ?? {}),
      warning: BpWarningConfig.fromJson(
          json['warning'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'timer_measure': timerMeasure.toJson(),
        'warning': warning.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Blood Oxygen
// ---------------------------------------------------------------------------

class SimpleWarningConfig {
  final int switchState;
  final num value;

  const SimpleWarningConfig({this.switchState = 0, this.value = 0});

  factory SimpleWarningConfig.fromJson(Map<String, dynamic> json) {
    return SimpleWarningConfig(
      switchState: json['switch_state'] as int? ?? 0,
      value: json['value'] as num? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'value': value,
      };
}

class BloodOxygenSettings {
  final String interval;
  final int frequency;
  final int switchState;
  final SimpleWarningConfig lowWarning;

  const BloodOxygenSettings({
    this.interval = '60',
    this.frequency = 5,
    this.switchState = 1,
    this.lowWarning = const SimpleWarningConfig(),
  });

  factory BloodOxygenSettings.fromJson(Map<String, dynamic> json) {
    return BloodOxygenSettings(
      interval: json['interval'] as String? ?? '60',
      frequency: json['frequency'] as int? ?? 5,
      switchState: json['switch_state'] as int? ?? 1,
      lowWarning: SimpleWarningConfig.fromJson(
          json['low_warning'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'frequency': frequency,
        'switch_state': switchState,
        'low_warning': lowWarning.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Body Temperature
// ---------------------------------------------------------------------------

class BodyTemperatureSettings {
  final String interval;
  final int frequency;
  final int switchState;
  final SimpleWarningConfig highWarning;
  final SimpleWarningConfig lowWarning;

  const BodyTemperatureSettings({
    this.interval = '60',
    this.frequency = 5,
    this.switchState = 1,
    this.highWarning = const SimpleWarningConfig(),
    this.lowWarning = const SimpleWarningConfig(),
  });

  factory BodyTemperatureSettings.fromJson(Map<String, dynamic> json) {
    return BodyTemperatureSettings(
      interval: json['interval'] as String? ?? '60',
      frequency: json['frequency'] as int? ?? 5,
      switchState: json['switch_state'] as int? ?? 1,
      highWarning: SimpleWarningConfig.fromJson(
          json['high_warning'] as Map<String, dynamic>? ?? {}),
      lowWarning: SimpleWarningConfig.fromJson(
          json['low_warning'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'frequency': frequency,
        'switch_state': switchState,
        'high_warning': highWarning.toJson(),
        'low_warning': lowWarning.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Step Settings
// ---------------------------------------------------------------------------

class StepSettings {
  final String interval;
  final String stepTarget;
  final String exerciseTimeTarget;

  const StepSettings({
    this.interval = '60',
    this.stepTarget = '6000',
    this.exerciseTimeTarget = '30',
  });

  factory StepSettings.fromJson(Map<String, dynamic> json) {
    return StepSettings(
      interval: json['interval'] as String? ?? '60',
      stepTarget: json['step_target'] as String? ?? '6000',
      exerciseTimeTarget: json['exercise_time_target'] as String? ?? '30',
    );
  }

  Map<String, dynamic> toJson() => {
        'interval': interval,
        'step_target': stepTarget,
        'exercise_time_target': exerciseTimeTarget,
      };
}

// ---------------------------------------------------------------------------
// Sleep Settings
// ---------------------------------------------------------------------------

class SleepSettings {
  final int switchState;
  final String startTime;
  final String endTime;
  final int target;

  const SleepSettings({
    this.switchState = 1,
    this.startTime = '220000',
    this.endTime = '070000',
    this.target = 480,
  });

  factory SleepSettings.fromJson(Map<String, dynamic> json) {
    return SleepSettings(
      switchState: json['switch_state'] as int? ?? 1,
      startTime: json['start_time'] as String? ?? '220000',
      endTime: json['end_time'] as String? ?? '070000',
      target: json['target'] as int? ?? 480,
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'start_time': startTime,
        'end_time': endTime,
        'target': target,
      };
}

// ---------------------------------------------------------------------------
// Location Settings
// ---------------------------------------------------------------------------

class LocationSettings {
  final int interval;

  const LocationSettings({this.interval = 1440});

  factory LocationSettings.fromJson(Map<String, dynamic> json) {
    return LocationSettings(
      interval: json['interval'] as int? ?? 1440,
    );
  }

  Map<String, dynamic> toJson() => {'interval': interval};
}

// ---------------------------------------------------------------------------
// Safety Settings (SOS & Fall Detection)
// ---------------------------------------------------------------------------

class SosConfig {
  final int switchState;
  final String rotation;

  const SosConfig({this.switchState = 1, this.rotation = '3'});

  factory SosConfig.fromJson(Map<String, dynamic> json) {
    return SosConfig(
      switchState: json['switch_state'] as int? ?? 1,
      rotation: json['rotation'] as String? ?? '3',
    );
  }

  Map<String, dynamic> toJson() => {
        'switch_state': switchState,
        'rotation': rotation,
      };
}

class FallWarningConfig {
  final int switchState;

  const FallWarningConfig({this.switchState = 0});

  factory FallWarningConfig.fromJson(Map<String, dynamic> json) {
    return FallWarningConfig(
      switchState: json['switch_state'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {'switch_state': switchState};
}

class SafetySettings {
  final SosConfig sos;
  final FallWarningConfig fallWarning;

  const SafetySettings({
    this.sos = const SosConfig(),
    this.fallWarning = const FallWarningConfig(),
  });

  factory SafetySettings.fromJson(Map<String, dynamic> json) {
    return SafetySettings(
      sos: SosConfig.fromJson(json['sos'] as Map<String, dynamic>? ?? {}),
      fallWarning: FallWarningConfig.fromJson(
          json['fall_warning'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'sos': sos.toJson(),
        'fall_warning': fallWarning.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Call Settings
// ---------------------------------------------------------------------------

class CallSettings {
  final SwitchConfig message;
  final SwitchConfig incomingCallLimit;
  final ValueConfig answerMode;

  const CallSettings({
    this.message = const SwitchConfig(switchState: 1),
    this.incomingCallLimit = const SwitchConfig(),
    this.answerMode = const ValueConfig(value: 1),
  });

  factory CallSettings.fromJson(Map<String, dynamic> json) {
    return CallSettings(
      message: SwitchConfig.fromJson(
          json['message'] as Map<String, dynamic>? ?? {}),
      incomingCallLimit: SwitchConfig.fromJson(
          json['incoming_call_limit'] as Map<String, dynamic>? ?? {}),
      answerMode: ValueConfig.fromJson(
          json['answer_mode'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'message': message.toJson(),
        'incoming_call_limit': incomingCallLimit.toJson(),
        'answer_mode': answerMode.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Watch Settings
// ---------------------------------------------------------------------------

class WatchSettings {
  final ValueConfig sceneMode;
  final SwitchConfig dial;
  final SwitchConfig unlockPassword;
  final ValueConfig volume;
  final SwitchConfig wristLift;
  final ValueConfig timeFormatMode;
  final SwitchConfig findMyWatch;
  final SwitchConfig watchLost;
  final SwitchConfig powerSaveMode;
  final ValueConfig lowPowerBattery;
  final StringValueConfig language;

  const WatchSettings({
    this.sceneMode = const ValueConfig(value: 3),
    this.dial = const SwitchConfig(switchState: 1),
    this.unlockPassword = const SwitchConfig(switchState: 1),
    this.volume = const ValueConfig(value: 51),
    this.wristLift = const SwitchConfig(switchState: 1),
    this.timeFormatMode = const ValueConfig(value: 24),
    this.findMyWatch = const SwitchConfig(switchState: 1),
    this.watchLost = const SwitchConfig(),
    this.powerSaveMode = const SwitchConfig(),
    this.lowPowerBattery = const ValueConfig(value: 60),
    this.language = const StringValueConfig(value: 'cn'),
  });

  factory WatchSettings.fromJson(Map<String, dynamic> json) {
    return WatchSettings(
      sceneMode: ValueConfig.fromJson(
          json['scene_mode'] as Map<String, dynamic>? ?? {}),
      dial:
          SwitchConfig.fromJson(json['dial'] as Map<String, dynamic>? ?? {}),
      unlockPassword: SwitchConfig.fromJson(
          json['unlock_password'] as Map<String, dynamic>? ?? {}),
      volume: ValueConfig.fromJson(
          json['volume'] as Map<String, dynamic>? ?? {}),
      wristLift: SwitchConfig.fromJson(
          json['wrist_lift'] as Map<String, dynamic>? ?? {}),
      timeFormatMode: ValueConfig.fromJson(
          json['time_format_mode'] as Map<String, dynamic>? ?? {}),
      findMyWatch: SwitchConfig.fromJson(
          json['find_my_watch'] as Map<String, dynamic>? ?? {}),
      watchLost: SwitchConfig.fromJson(
          json['watch_lost'] as Map<String, dynamic>? ?? {}),
      powerSaveMode: SwitchConfig.fromJson(
          json['power_save_mode'] as Map<String, dynamic>? ?? {}),
      lowPowerBattery: ValueConfig.fromJson(
          json['low_power_battery'] as Map<String, dynamic>? ?? {}),
      language: StringValueConfig.fromJson(
          json['language'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'scene_mode': sceneMode.toJson(),
        'dial': dial.toJson(),
        'unlock_password': unlockPassword.toJson(),
        'volume': volume.toJson(),
        'wrist_lift': wristLift.toJson(),
        'time_format_mode': timeFormatMode.toJson(),
        'find_my_watch': findMyWatch.toJson(),
        'watch_lost': watchLost.toJson(),
        'power_save_mode': powerSaveMode.toJson(),
        'low_power_battery': lowPowerBattery.toJson(),
        'language': language.toJson(),
      };
}

// ---------------------------------------------------------------------------
// Shared Primitives
// ---------------------------------------------------------------------------

/// A settings field with a simple on/off `switch_state`.
class SwitchConfig {
  final int switchState;

  const SwitchConfig({this.switchState = 0});

  factory SwitchConfig.fromJson(Map<String, dynamic> json) {
    return SwitchConfig(switchState: json['switch_state'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() => {'switch_state': switchState};
}

/// A settings field with an integer `value`.
class ValueConfig {
  final int value;

  const ValueConfig({this.value = 0});

  factory ValueConfig.fromJson(Map<String, dynamic> json) {
    return ValueConfig(value: json['value'] as int? ?? 0);
  }

  Map<String, dynamic> toJson() => {'value': value};
}

/// A settings field with a string `value` (e.g. language code).
class StringValueConfig {
  final String value;

  const StringValueConfig({this.value = ''});

  factory StringValueConfig.fromJson(Map<String, dynamic> json) {
    return StringValueConfig(value: json['value'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'value': value};
}
