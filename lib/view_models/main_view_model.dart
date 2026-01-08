import 'dart:async';
import 'package:flutter/material.dart';
import 'package:acquisition_mobile/managers/connection_interface.dart';
import 'package:acquisition_mobile/managers/serial_manager.dart';
import 'package:acquisition_mobile/managers/wifi_manager.dart';
import 'package:acquisition_mobile/managers/ble_manager.dart';
import 'package:acquisition_mobile/models/packet.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

enum ConnectionType { serial, wifi, ble }

class MainViewModel extends ChangeNotifier {
  // Connection Managers
  SerialManager? _serialManager;
  WifiManager? _wifiManager;
  BleManager? _bleManager;
  ConnectionInterface? _currentConnection;

  // State
  ConnectionType _selectedConnectionType = ConnectionType.serial;
  bool _isConnected = false;
  bool _isAcquiring = false;
  final List<Packet> _packets = [];

  // Inputs
  List<String> _availableSerialPorts = [];
  String? _selectedSerialPort;

  String _wifiIp = "192.168.1.100";
  String _wifiPort = "8080";

  List<ScanResult> _bleDevices = [];
  ScanResult? _selectedBleDevice;
  bool _isScanning = false;

  // Getters
  ConnectionType get selectedConnectionType => _selectedConnectionType;
  bool get isConnected => _isConnected;
  bool get isAcquiring => _isAcquiring;
  List<Packet> get packets => _packets;

  List<String> get availableSerialPorts => _availableSerialPorts;
  String? get selectedSerialPort => _selectedSerialPort;

  String get wifiIp => _wifiIp;
  String get wifiPort => _wifiPort;

  List<ScanResult> get bleDevices => _bleDevices;
  ScanResult? get selectedBleDevice => _selectedBleDevice;
  bool get isScanning => _isScanning;

  MainViewModel() {
    _initSerial();
  }

  void _initSerial() {
    try {
      _serialManager = SerialManager();
      _refreshSerialPorts();
    } catch (e) {
      print("Serial not supported (possibly on Web?): $e");
    }
  }

  void setConnectionType(ConnectionType type) {
    if (_isConnected) return; // Must disconnect first
    _selectedConnectionType = type;
    notifyListeners();
  }

  // Serial Methods
  void _refreshSerialPorts() {
    if (_serialManager != null) {
      _availableSerialPorts = _serialManager!.getAvailablePorts();
      _selectedSerialPort = _availableSerialPorts.isNotEmpty
          ? _availableSerialPorts.first
          : null;
      notifyListeners();
    }
  }

  void refreshPorts() => _refreshSerialPorts(); // Public alias

  void selectSerialPort(String? port) {
    _selectedSerialPort = port;
    notifyListeners();
  }

  // WiFi Methods
  void setWifiIp(String ip) {
    _wifiIp = ip;
    notifyListeners();
  }

  void setWifiPort(String port) {
    _wifiPort = port;
    notifyListeners();
  }

  // BLE Methods
  Future<void> scanBleDevices() async {
    if (_isScanning) return;
    _isScanning = true;
    notifyListeners();

    try {
      _bleDevices = await BleManager.scanForDevices();
    } catch (e) {
      print("Scan Error: $e");
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  void selectBleDevice(ScanResult? device) {
    _selectedBleDevice = device;
    notifyListeners();
  }

  // Common Connection Methods
  Future<void> connect() async {
    _currentConnection?.dispose();
    _currentConnection = null;

    bool success = false;

    switch (_selectedConnectionType) {
      case ConnectionType.serial:
        if (_serialManager == null) _initSerial(); // Lazy init retry
        if (_serialManager != null && _selectedSerialPort != null) {
          _currentConnection = _serialManager;
          success = await _currentConnection!.connect(_selectedSerialPort!);
        }
        break;

      case ConnectionType.wifi:
        _wifiManager ??= WifiManager();
        _currentConnection = _wifiManager;
        success = await _currentConnection!.connect("$_wifiIp:$_wifiPort");
        break;

      case ConnectionType.ble:
        _bleManager ??= BleManager();
        if (_selectedBleDevice != null) {
          _currentConnection = _bleManager;
          success = await _currentConnection!.connect(
            _selectedBleDevice!.device.remoteId.str,
          );
        }
        break;
    }

    if (success && _currentConnection != null) {
      _isConnected = true;
      _currentConnection!.packetStream.listen((packet) {
        _packets.add(packet);
        if (_packets.length > 512 * 5) {
          // Keep 5 seconds of data
          _packets.removeAt(0);
        }
        notifyListeners();
      });
    } else {
      _isConnected = false;
      _currentConnection = null;
    }
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (_isAcquiring) {
      await stopAcquisition();
    }
    await _currentConnection?.disconnect();
    _isConnected = false;
    notifyListeners();
  }

  Future<void> startAcquisition() async {
    if (_currentConnection != null && _isConnected) {
      if (await _currentConnection!.start()) {
        _isAcquiring = true;
        _packets.clear(); // Clear old data on start
        notifyListeners();
      }
    }
  }

  Future<void> stopAcquisition() async {
    if (_currentConnection != null && _isConnected) {
      if (await _currentConnection!.stop()) {
        _isAcquiring = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _serialManager?.dispose();
    _wifiManager?.dispose();
    _bleManager?.dispose();
    super.dispose();
  }
}
