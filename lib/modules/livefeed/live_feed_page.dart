import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:get/get.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/device_model.dart';
import '../../modules/telemetry/telemetry_controller.dart';
import '../../widgets/common_widgets.dart';

/// Live MJPEG video from the ESP32-CAM in the coop.
class LiveFeedPage extends StatefulWidget {
  const LiveFeedPage({super.key});

  @override
  State<LiveFeedPage> createState() => _LiveFeedPageState();
}

class _LiveFeedPageState extends State<LiveFeedPage> {
  final _c = Get.find<TelemetryController>();
  bool _isLive = true;

  @override
  void dispose() {
    _isLive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final device = _c.activeDevice.value;
      final streamUrl = device?.cameraUrl?.trim();

      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Live Feed',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (streamUrl != null && streamUrl.isNotEmpty)
                  IconButton(
                    icon: Icon(_isLive ? Icons.pause : Icons.play_arrow),
                    tooltip: _isLive ? 'Pause stream' : 'Resume stream',
                    onPressed: () => setState(() => _isLive = !_isLive),
                  ),
              ],
            ),
          ),
          if (streamUrl == null || streamUrl.isEmpty)
            _buildNoUrlState(device)
          else
            _buildVideoFeed(streamUrl),
        ],
      );
    });
  }

  Widget _buildNoUrlState(DeviceModel? device) {
    return Column(
      children: [
        const EmptyState(
          icon: Icons.videocam_off,
          message: 'No camera configured.\nAdd the ESP32-CAM stream URL to '
              'show the live feed here.',
        ),
        if (_c.canControl)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Set camera URL'),
              onPressed: device == null ? null : () => _editCameraUrl(device),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoFeed(String url) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.hairline(context)),
            borderRadius: BorderRadius.circular(12),
            color: Colors.black,
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: Mjpeg(
              isLive: _isLive,
              stream: url,
              error: (context, error, stack) => _buildErrorState(error),
              loading: (context) =>
                  const Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Source: $url',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: 12,
                  ),
                ),
              ),
              if (_c.canControl)
                TextButton(
                  onPressed: () {
                    final device = _c.activeDevice.value;
                    if (device != null) _editCameraUrl(device);
                  },
                  child: const Text('Change'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.criticalRed, size: 48),
          const SizedBox(height: 8),
          const Text(
            'Stream unavailable',
            style: TextStyle(color: AppTheme.criticalRed),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toString(),
              style: const TextStyle(fontSize: 10, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editCameraUrl(DeviceModel device) async {
    final controller = TextEditingController(text: device.cameraUrl ?? '');

    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Camera stream URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'MJPEG URL',
            hintText: 'http://192.168.1.100:81/stream',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (url == null) return;
    await _c.saveDevice(device.copyWith(cameraUrl: url));
    if (mounted) setState(() => _isLive = true);
  }
}
