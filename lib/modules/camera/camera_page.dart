import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart';
import 'package:get/get.dart';

import '../../core/services/esp32_api_service.dart';
import '../../core/theme/app_theme.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  final _api = Get.find<Esp32ApiService>();
  bool _isLive = true;

  @override
  void dispose() {
    _isLive = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = _api.activeDevice;
    final cameraUrl = device?.cameraUrl;

    // Default URL if the cameraUrl is not set but localIp is set.
    // Port 81 is standard for ESP32-CAM MJPEG stream.
    final defaultUrl = device?.localIp.isNotEmpty == true 
        ? 'http://${device!.localIp}:81/stream' 
        : null;

    final streamUrl = (cameraUrl != null && cameraUrl.isNotEmpty) ? cameraUrl : defaultUrl;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera Feed'),
        actions: [
          IconButton(
            icon: Icon(_isLive ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                _isLive = !_isLive;
              });
            },
            tooltip: _isLive ? 'Pause Stream' : 'Resume Stream',
          ),
        ],
      ),
      body: Center(
        child: streamUrl == null
            ? _buildNoUrlState()
            : _buildVideoFeed(streamUrl),
      ),
    );
  }

  Widget _buildNoUrlState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.videocam_off, size: 64, color: AppTheme.textSecondary),
        const SizedBox(height: 16),
        Text(
          'No Camera Configured',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Configure a camera URL in Device Management\nor ensure the active device has a local IP.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildVideoFeed(String url) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 800),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
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
              loading: (context) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Source: $url',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
          const Text('Connection Failed', style: TextStyle(color: AppTheme.criticalRed)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              error.toString(),
              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
