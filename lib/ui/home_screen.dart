import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:acquisition_mobile/view_models/main_view_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acquisition Mobile')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            _buildConnectionCard(context),
            const SizedBox(height: 10),
            Expanded(child: _buildChart(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 1. Connection Type Selector using Tabs/Segmented Control look
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTypeButton(
                  context,
                  ConnectionType.serial,
                  "Serial",
                  Icons.usb,
                ),
                _buildTypeButton(
                  context,
                  ConnectionType.wifi,
                  "WiFi",
                  Icons.wifi,
                ),
                _buildTypeButton(
                  context,
                  ConnectionType.ble,
                  "Bluetooth",
                  Icons.bluetooth,
                ),
              ],
            ),
            const Divider(),

            // 2. Specific Connection Inputs
            if (!viewModel.isConnected) _buildInputsForType(context, viewModel),

            // 3. Status
            if (viewModel.isConnected)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      "Connected (${viewModel.selectedConnectionType.name.toUpperCase()})",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // 4. Action Buttons (Connect/Disconnect & Start/Stop)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: viewModel.isConnected
                        ? viewModel.disconnect
                        : viewModel.connect,
                    icon: Icon(
                      viewModel.isConnected ? Icons.close : Icons.link,
                    ),
                    label: Text(
                      viewModel.isConnected ? "Disconnect" : "Connect",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: viewModel.isConnected
                          ? Colors.red.shade100
                          : Colors.blue.shade100,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: !viewModel.isConnected
                        ? null
                        : (viewModel.isAcquiring
                              ? viewModel.stopAcquisition
                              : viewModel.startAcquisition),
                    icon: Icon(
                      viewModel.isAcquiring ? Icons.stop : Icons.play_arrow,
                    ),
                    label: Text(viewModel.isAcquiring ? "Stop" : "Start"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: viewModel.isAcquiring
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton(
    BuildContext context,
    ConnectionType type,
    String label,
    IconData icon,
  ) {
    final viewModel = Provider.of<MainViewModel>(context);
    final isSelected = viewModel.selectedConnectionType == type;

    return InkWell(
      onTap: () => viewModel.setConnectionType(type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected ? Border.all(color: Colors.blue) : null,
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputsForType(BuildContext context, MainViewModel viewModel) {
    switch (viewModel.selectedConnectionType) {
      case ConnectionType.serial:
        return Row(
          children: [
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: viewModel.selectedSerialPort,
                  hint: const Text("Select Serial Port"),
                  items: viewModel.availableSerialPorts.map((port) {
                    return DropdownMenuItem(value: port, child: Text(port));
                  }).toList(),
                  onChanged: viewModel.selectSerialPort,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: viewModel.refreshPorts,
            ),
          ],
        );
      case ConnectionType.wifi:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                initialValue: viewModel.wifiIp,
                decoration: const InputDecoration(
                  labelText: "IP Address",
                  border: OutlineInputBorder(),
                ),
                onChanged: viewModel.setWifiIp,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextFormField(
                initialValue: viewModel.wifiPort,
                decoration: const InputDecoration(
                  labelText: "Port",
                  border: OutlineInputBorder(),
                ),
                onChanged: viewModel.setWifiPort,
              ),
            ),
          ],
        );
      case ConnectionType.ble:
        return Column(
          children: [
            if (viewModel.isScanning) const LinearProgressIndicator(),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<ScanResult>(
                      isExpanded: true,
                      value: viewModel.selectedBleDevice,
                      hint: const Text("Select Bluetooth Device"),
                      items: viewModel.bleDevices.map((r) {
                        return DropdownMenuItem(
                          value: r,
                          child: Text(
                            r.device.platformName.isNotEmpty
                                ? r.device.platformName
                                : r.device.remoteId.str,
                          ),
                        );
                      }).toList(),
                      onChanged: viewModel.selectBleDevice,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () => viewModel.scanBleDevices(),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildChart(BuildContext context) {
    final viewModel = Provider.of<MainViewModel>(context);
    return LineChart(
      LineChartData(
        lineTouchData: const LineTouchData(
          enabled: false,
        ), // Disable touch for performance
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.shade300),
        ),
        lineBarsData: [
          _buildLineChartBarData(viewModel.packets, 0),
          _buildLineChartBarData(viewModel.packets, 1),
        ],
        // Optimize rendering by limiting X-range window logic managed in ViewModel (fixed packet list)
      ),
    );
  }

  LineChartBarData _buildLineChartBarData(List<dynamic> packets, int channel) {
    return LineChartBarData(
      spots: packets.asMap().entries.map((entry) {
        final index = entry.key;
        final packet = entry.value;
        final value = channel == 0
            ? packet.ch0Raw.toDouble()
            : packet.ch1Raw.toDouble();
        return FlSpot(index.toDouble(), value);
      }).toList(),
      isCurved: false, // Performance
      color: channel == 0 ? Colors.red : Colors.blue,
      dotData: const FlDotData(show: false),
      barWidth: 1.5,
    );
  }
}
