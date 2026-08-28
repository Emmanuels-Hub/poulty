import '../../core/constants/enums.dart';

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    this.bleId = '',
    this.cameraUrl,
    this.lastSeen,
    this.connectionStatus = DeviceConnectionStatus.disconnected,
    this.firmwareVersion = '1.0.0',
    this.species = 'broiler',
  });

  final String id;
  final String name;

  /// BLE remote id (MAC on Android, UUID on iOS) of the paired ESP32.
  final String bleId;

  /// HTTP MJPEG endpoint of the ESP32-CAM, used by the live feed.
  final String? cameraUrl;
  final DateTime? lastSeen;
  final DeviceConnectionStatus connectionStatus;
  final String firmwareVersion;
  final String species;

  bool get isPaired => bleId.isNotEmpty;

  DeviceModel copyWith({
    String? id,
    String? name,
    String? bleId,
    String? cameraUrl,
    DateTime? lastSeen,
    DeviceConnectionStatus? connectionStatus,
    String? firmwareVersion,
    String? species,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      bleId: bleId ?? this.bleId,
      cameraUrl: cameraUrl ?? this.cameraUrl,
      lastSeen: lastSeen ?? this.lastSeen,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      species: species ?? this.species,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bleId': bleId,
        'cameraUrl': cameraUrl,
        'lastSeen': lastSeen?.toIso8601String(),
        'connectionStatus': connectionStatus.name,
        'firmwareVersion': firmwareVersion,
        'species': species,
      };

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        bleId: json['bleId'] as String? ?? '',
        cameraUrl: json['cameraUrl'] as String?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
        connectionStatus: DeviceConnectionStatus.values.firstWhere(
          (s) => s.name == (json['connectionStatus'] as String? ?? ''),
          orElse: () => DeviceConnectionStatus.disconnected,
        ),
        firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
        species: json['species'] as String? ?? 'broiler',
      );
}
