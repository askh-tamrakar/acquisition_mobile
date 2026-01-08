import 'dart:async';
import 'package:acquisition_mobile/managers/connection_interface.dart';
import 'package:acquisition_mobile/managers/packet_parser.dart';
import 'package:acquisition_mobile/models/packet.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager implements ConnectionInterface {
  final _parser = PacketParser();
  final _packetController = StreamController<Packet>.broadcast();

  BluetoothDevice? _device;
  BluetoothCharacteristic?
  _txCharacteristic; // For receiving data (Notification)
  BluetoothCharacteristic? _rxCharacteristic; // For sending commands (Write)
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notifySubscription;

  // Standard UART Service UUIDs (Nordic UART Service)
  // Modify these if your device uses different UUIDs
  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write
  static const String txUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Notify

  @override
  Stream<Packet> get packetStream => _packetController.stream;

  // Scanning helper
  static Future<List<ScanResult>> scanForDevices() async {
    // Start scanning
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    final results = <ScanResult>[];
    final subscription = FlutterBluePlus.scanResults.listen((r) {
      for (final result in r) {
        if (result.device.platformName.isNotEmpty) {
          // Dedup
          final index = results.indexWhere(
            (e) => e.device.remoteId == result.device.remoteId,
          );
          if (index >= 0) {
            results[index] = result;
          } else {
            results.add(result);
          }
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    await FlutterBluePlus.isScanning
        .where((val) => val == false)
        .first; // Wait for scan to end

    subscription.cancel();
    return results;
  }

  @override
  Future<bool> connect(String address) async {
    // Address here is the RemoteId string
    await disconnect();
    try {
      _device = BluetoothDevice.fromId(address);

      // Connect
      await _device!.connect(autoConnect: false);

      _connectionSubscription = _device!.connectionState.listen((
        BluetoothConnectionState state,
      ) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      // Discover Services
      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? uartService;

      // Find UART service (fuzzy match or exact)
      for (var s in services) {
        if (s.uuid.toString().toUpperCase() == serviceUuid) {
          uartService = s;
          break;
        }
      }

      // If standard UART not found, try to find ANY service with Write + Notify
      if (uartService == null) {
        // Fallback logic could go here
        print("BLE: UART Service not found");
        return false;
      }

      for (var c in uartService.characteristics) {
        if (c.uuid.toString().toUpperCase() == txUuid) {
          _txCharacteristic = c;
        } else if (c.uuid.toString().toUpperCase() == rxUuid) {
          _rxCharacteristic = c;
        }
      }

      if (_txCharacteristic != null) {
        await _txCharacteristic!.setNotifyValue(true);
        _notifySubscription = _txCharacteristic!.lastValueStream.listen((data) {
          _parser.addData(data);
          while (true) {
            final packet = _parser.parse();
            if (packet != null) {
              _packetController.add(packet);
            } else {
              break;
            }
          }
        });
      }

      return true;
    } catch (e) {
      print("BLE Connection Error: $e");
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> disconnect() async {
    _notifySubscription?.cancel();
    _notifySubscription = null;

    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (e) {
        // ignore
      }
    }
    _device = null;
    _txCharacteristic = null;
    _rxCharacteristic = null;
  }

  @override
  Future<bool> start() async {
    return _sendCommand("START");
  }

  @override
  Future<bool> stop() async {
    return _sendCommand("STOP");
  }

  Future<bool> _sendCommand(String cmd) async {
    if (_rxCharacteristic == null) return false;
    try {
      await _rxCharacteristic!.write(
        "$cmd\n".codeUnits,
        withoutResponse: false,
      );
      return true;
    } catch (e) {
      print("BLE Send Error: $e");
      return false;
    }
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    _packetController.close();
  }
}
