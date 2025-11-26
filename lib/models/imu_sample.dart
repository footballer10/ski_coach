class ImuSample {
  final double ax, ay, az;
  final double gx, gy, gz;
  final double roll, pitch, yaw;

  ImuSample({
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
}
