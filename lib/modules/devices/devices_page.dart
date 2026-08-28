import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/enums.dart';
import '../../core/utils/enum_labels.dart';
import '../../data/models/device_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';

class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  final telemetry = Get.find<TelemetryController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Device Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showDeviceDialog(),
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        final devices = telemetry.devices;
        return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final isActive = telemetry.activeDevice.value?.id == device.id;
            return Card(
              color: isActive ? Colors.green.shade50 : null,
              child: ListTile(
                leading: Icon(
                  Icons.memory,
                  color: isActive ? Colors.green : null,
                ),
                title: Text(device.name),
                subtitle: Text(
                  '${EnumLabels.connectionStatus(device.connectionStatus)}\n'
                  'Local: ${device.localIp.isEmpty ? '—' : device.localIp} · '
                  'Remote: ${device.remoteUrl.isEmpty ? '—' : device.remoteUrl}\n'
                  'Camera: ${device.cameraUrl?.isEmpty ?? true ? '—' : device.cameraUrl}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'activate') {
                      telemetry.activeDevice.value = device;
                      await telemetry.refreshNow();
                    }
                    if (value == 'edit') _showDeviceDialog(device: device);
                    if (value == 'delete') {
                      await telemetry.deleteDevice(device.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'activate', child: Text('Set Active')),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }

  Future<void> _showDeviceDialog({DeviceModel? device}) async {
    final isEdit = device != null;
    final nameController = TextEditingController(text: device?.name ?? '');
    final localIpController = TextEditingController(text: device?.localIp ?? '');
    final remoteUrlController = TextEditingController(text: device?.remoteUrl ?? '');
    final cameraUrlController = TextEditingController(text: device?.cameraUrl ?? '');
    final mqttController = TextEditingController(text: device?.mqttBroker ?? '');
    var species = device?.species ?? 'broiler';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Device' : 'Add Device'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Device Name'),
                ),
                TextField(
                  controller: localIpController,
                  decoration: const InputDecoration(labelText: 'Local IP'),
                ),
                TextField(
                  controller: remoteUrlController,
                  decoration: const InputDecoration(labelText: 'Remote URL'),
                ),
                TextField(
                  controller: cameraUrlController,
                  decoration: const InputDecoration(labelText: 'Camera Stream URL (Optional)'),
                ),
                TextField(
                  controller: mqttController,
                  decoration: const InputDecoration(labelText: 'MQTT Broker'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: species,
                  decoration: const InputDecoration(labelText: 'Species'),
                  items: const [
                    DropdownMenuItem(value: 'broiler', child: Text('Broiler Chicken')),
                    DropdownMenuItem(value: 'layer', child: Text('Layer Chicken')),
                    DropdownMenuItem(value: 'turkey', child: Text('Turkey')),
                  ],
                  onChanged: (v) => setDialogState(() => species = v ?? species),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final model = DeviceModel(
                  id: device?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  localIp: localIpController.text.trim(),
                  remoteUrl: remoteUrlController.text.trim(),
                  cameraUrl: cameraUrlController.text.trim().isEmpty ? null : cameraUrlController.text.trim(),
                  mqttBroker: mqttController.text.trim().isEmpty
                      ? null
                      : mqttController.text.trim(),
                  species: species,
                  connectionStatus: device?.connectionStatus ??
                      DeviceConnectionStatus.offline,
                  firmwareVersion: device?.firmwareVersion ?? '1.0.0',
                );
                await telemetry.saveDevice(model);
                if (context.mounted) Navigator.pop(ctx);
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }
}
