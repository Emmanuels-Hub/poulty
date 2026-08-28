import '../../core/constants/enums.dart';

class DeviceModel {
  const DeviceModel({
    required this.id,
    required this.name,
    required this.localIp,
    required this.remoteUrl,
    this.mqttBroker,
    this.mqttTopicPrefix = 'poultry',

    this.cameraUrl,
    this.apiToken,
    this.lastSeen,
    this.connectionStatus = DeviceConnectionStatus.offline,
    this.firmwareVersion = '1.0.0',
    this.species = 'broiler',
  });

  final String id;
  final String name;
  final String localIp;
  final String remoteUrl;
  final String? mqttBroker;
  final String mqttTopicPrefix;

  final String? cameraUrl;
  final String? apiToken;
  final DateTime? lastSeen;
  final DeviceConnectionStatus connectionStatus;
  final String firmwareVersion;
  final String species;

  String get baseUrl {
    if (connectionStatus == DeviceConnectionStatus.local && localIp.isNotEmpty) {
      return 'http://$localIp';
    }
    return remoteUrl;
  }

  DeviceModel copyWith({
    String? id,
    String? name,
    String? localIp,
    String? remoteUrl,
    String? mqttBroker,
    String? mqttTopicPrefix,

    String? cameraUrl,
    String? apiToken,
    DateTime? lastSeen,
    DeviceConnectionStatus? connectionStatus,
    String? firmwareVersion,
    String? species,
  }) {
    return DeviceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      localIp: localIp ?? this.localIp,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      mqttTopicPrefix: mqttTopicPrefix ?? this.mqttTopicPrefix,

      cameraUrl: cameraUrl ?? this.cameraUrl,
      apiToken: apiToken ?? this.apiToken,
      lastSeen: lastSeen ?? this.lastSeen,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      species: species ?? this.species,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'localIp': localIp,
        'remoteUrl': remoteUrl,
        'mqttBroker': mqttBroker,
        'mqttTopicPrefix': mqttTopicPrefix,

        'cameraUrl': cameraUrl,
        'apiToken': apiToken,
        'lastSeen': lastSeen?.toIso8601String(),
        'connectionStatus': connectionStatus.name,
        'firmwareVersion': firmwareVersion,
        'species': species,
      };

  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
        id: json['id'] as String,
        name: json['name'] as String,
        localIp: json['localIp'] as String? ?? '',
        remoteUrl: json['remoteUrl'] as String? ?? '',
        mqttBroker: json['mqttBroker'] as String?,
        mqttTopicPrefix: json['mqttTopicPrefix'] as String? ?? 'poultry',

        cameraUrl: json['cameraUrl'] as String?,
        apiToken: json['apiToken'] as String?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
        connectionStatus: DeviceConnectionStatus.values
            .byName(json['connectionStatus'] as String? ?? 'offline'),
        firmwareVersion: json['firmwareVersion'] as String? ?? '1.0.0',
        species: json['species'] as String? ?? 'broiler',
      );
}
