import 'dart:async';
import 'package:acquisition_mobile/models/packet.dart';

abstract class DeviceManager {
  Future<bool> connect(String address);
  Future<void> disconnect();
  Future<void> dispose();
}

abstract class Source extends DeviceManager {
  Stream<Packet> get packetStream;
  Future<bool> start();
  Future<bool> stop();
}

abstract class Sink extends DeviceManager {
  Future<void> send(List<int> data);
}
