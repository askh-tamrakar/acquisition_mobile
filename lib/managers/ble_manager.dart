import 'dart:async';
import 'package:acquisition_mobile/managers/connection_interface.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleManager implements Sink {
  BluetoothDevice? _device;
  BluetoothCharacteristic?
  _rxCharacteristic; // For sending data (Write to device)
  StreamSubscription? _connectionSubscription;

  // Standard UART Service UUIDs (Nordic UART Service)
  // Usually RX on the central is TX on the peripheral, but if we act as a "Sender",
  // we write to the characteristic that the remote device listens to.
  // Assuming remote device (PC Central) listens on RX or similar.
  // Standard NUS:
  // - Service: 6E400001-...
  // - RX (Write): 6E400002-... <--- We write here
  // - TX (Notify): 6E400003-...

  static const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Write

  // Scanning helper
  static Future<List<ScanResult>> scanForDevices() async {
    if (FlutterBluePlus.isScanningNow) {
      await FlutterBluePlus.stopScan();
    }

    final results = <ScanResult>[];
    final subscription = FlutterBluePlus.scanResults.listen((r) {
      for (final result in r) {
        if (result.device.platformName.isNotEmpty) {
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
    await FlutterBluePlus.isScanning.where((val) => val == false).first;

    subscription.cancel();
    return results;
  }

  @override
  Future<bool> connect(String address) async {
    await disconnect();
    try {
      _device = BluetoothDevice.fromId(address);
      await _device!.connect(autoConnect: false);

      _connectionSubscription = _device!.connectionState.listen((
        BluetoothConnectionState state,
      ) {
        if (state == BluetoothConnectionState.disconnected) {
          disconnect();
        }
      });

      List<BluetoothService> services = await _device!.discoverServices();
      BluetoothService? uartService;

      for (var s in services) {
        if (s.uuid.toString().toUpperCase() == serviceUuid) {
          uartService = s;
          break;
        }
      }

      if (uartService == null) {
        print("BLE: UART Service not found");
        return false;
      }

      for (var c in uartService.characteristics) {
        if (c.uuid.toString().toUpperCase() == rxUuid) {
          _rxCharacteristic = c;
          break;
        }
      }

      return _rxCharacteristic != null;
    } catch (e) {
      print("BLE Connection Error: $e");
      await disconnect();
      return false;
    }
  }

  @override
  Future<void> send(List<int> data) async {
    if (_rxCharacteristic != null) {
      try {
        // writeWithoutResponse is faster for streaming
        await _rxCharacteristic!.write(data, withoutResponse: true);
      } catch (e) {
        print("BLE Send Error: $e");
      }
    }
  }

  @override
  Future<void> disconnect() async {
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
    _rxCharacteristic = null;
  }

  @override
  Future<void> dispose() async {
    await disconnect();
  }
}
