class ImuSample {
  final DateTime timestamp;
  final double ax, ay, az;
  final double gx, gy, gz;
  final double roll, pitch, yaw;

  ImuSample({
    required this.timestamp,
    required this.ax,
    required this.ay,
    required this.az,
    required this.gx,
    required this.gy,
    required this.gz,
    required this.roll,
    required this.pitch,
    required this.yaw,
  });

  /// Convert to map for easy processing
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'ax': ax,
    'ay': ay,
    'az': az,
    'gx': gx,
    'gy': gy,
    'gz': gz,
    'roll': roll,
    'pitch': pitch,
    'yaw': yaw,
  };
}
