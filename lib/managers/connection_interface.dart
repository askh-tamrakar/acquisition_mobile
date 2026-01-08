import 'dart:async';
import 'package:acquisition_mobile/models/packet.dart';

abstract class ConnectionInterface {
  Stream<Packet> get packetStream;
  Future<bool> connect(String address);
  Future<void> disconnect();
  Future<bool> start();
  Future<bool> stop();
  Future<void> dispose();
}
