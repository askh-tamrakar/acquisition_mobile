class Packet {
  final int counter;
  final int ch0Raw;
  final int ch1Raw;
  final DateTime timestamp;

  Packet({
    required this.counter,
    required this.ch0Raw,
    required this.ch1Raw,
    required this.timestamp,
  });

  double toMicrovolts(int adcValue, {int adcBits = 14, double vref = 3300.0}) {
    return ((adcValue / (1 << adcBits)) * vref) - (vref / 2.0);
  }

  double get ch0Microvolts => toMicrovolts(ch0Raw);
  double get ch1Microvolts => toMicrovolts(ch1Raw);

  @override
  String toString() {
    return 'Packet(counter: $counter, ch0Raw: $ch0Raw, ch1Raw: $ch1Raw, timestamp: $timestamp)';
  }
}
