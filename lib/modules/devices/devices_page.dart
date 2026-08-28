import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/enum_labels.dart';
import '../../data/models/device_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

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
        if (devices.isEmpty) {
          return const EmptyState(
            icon: Icons.memory,
            message: 'No controllers yet. Add one, then pair it over '
                'Bluetooth from Settings.',
          );
        }

        return ListView.builder(
          itemCount: devices.length,
          itemBuilder: (context, index) {
            final device = devices[index];
            final isActive = telemetry.activeDevice.value?.id == device.id;
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.memory,
                  color: isActive ? AppTheme.successGreen : null,
                ),
                title: Text(device.name),
                subtitle: Text(
                  '${EnumLabels.connectionStatus(device.connectionStatus)}\n'
                  'Bluetooth: ${device.isPaired ? device.bleId : 'not paired'}\n'
                  'Camera: ${device.cameraUrl?.isEmpty ?? true ? '—' : device.cameraUrl}',
                ),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'activate') {
                      telemetry.activeDevice.value = device;
                      if (device.isPaired) {
                        await telemetry.connectToDevice(device);
                      }
                    }
                    if (value == 'edit') _showDeviceDialog(device: device);
                    if (value == 'delete') {
                      await telemetry.deleteDevice(device.id);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'activate',
                      child: Text('Set Active'),
                    ),
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
    final cameraUrlController = TextEditingController(
      text: device?.cameraUrl ?? '',
    );
    var species = device?.species ?? 'broiler';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Controller' : 'Add Controller'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: cameraUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Camera Stream URL (optional)',
                    hintText: 'http://192.168.1.100:81/stream',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: species,
                  decoration: const InputDecoration(labelText: 'Species'),
                  items: const [
                    DropdownMenuItem(
                      value: 'broiler',
                      child: Text('Broiler Chicken'),
                    ),
                    DropdownMenuItem(
                      value: 'layer',
                      child: Text('Layer Chicken'),
                    ),
                    DropdownMenuItem(value: 'turkey', child: Text('Turkey')),
                  ],
                  onChanged: (v) => setDialogState(() => species = v ?? species),
                ),
                const SizedBox(height: 12),
                Text(
                  'Pair the controller over Bluetooth from the Settings tab.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final camera = cameraUrlController.text.trim();
                final model =
                    (device ??
                            DeviceModel(
                              id: DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              name: '',
                            ))
                        .copyWith(
                          name: nameController.text.trim().isEmpty
                              ? 'Coop Controller'
                              : nameController.text.trim(),
                          cameraUrl: camera,
                          species: species,
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
