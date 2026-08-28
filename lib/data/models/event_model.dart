import '../../core/constants/enums.dart';

class SystemEvent {
  const SystemEvent({
    required this.id,
    required this.timestamp,
    required this.category,
    required this.message,
    this.details,
  });

  final String id;
  final DateTime timestamp;
  final EventCategory category;
  final String message;
  final String? details;

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'category': category.name,
        'message': message,
        'details': details,
      };

  factory SystemEvent.fromJson(Map<String, dynamic> json) => SystemEvent(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        category: EventCategory.values.byName(json['category'] as String),
        message: json['message'] as String,
        details: json['details'] as String?,
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isActive = true,
    this.isRead = false,
    this.clearedAt,
  });

  final String id;
  final AlertType type;
  final AlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isActive;
  final bool isRead;
  final DateTime? clearedAt;

  AppNotification copyWith({
    String? id,
    AlertType? type,
    AlertSeverity? severity,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isActive,
    bool? isRead,
    DateTime? clearedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isActive: isActive ?? this.isActive,
      isRead: isRead ?? this.isRead,
      clearedAt: clearedAt ?? this.clearedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'severity': severity.name,
        'title': title,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'isActive': isActive,
        'isRead': isRead,
        'clearedAt': clearedAt?.toIso8601String(),
      };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: AlertType.values.byName(json['type'] as String),
        severity: AlertSeverity.values.byName(json['severity'] as String),
        title: json['title'] as String,
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isActive: json['isActive'] as bool? ?? true,
        isRead: json['isRead'] as bool? ?? false,
        clearedAt: json['clearedAt'] != null
            ? DateTime.parse(json['clearedAt'] as String)
            : null,
      );
}

class QueuedCommand {
  const QueuedCommand({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.createdAt,
    this.description = '',
  });

  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String description;

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
        'description': description,
      };

  factory QueuedCommand.fromJson(Map<String, dynamic> json) => QueuedCommand(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        payload: Map<String, dynamic>.from(json['payload'] as Map),
        createdAt: DateTime.parse(json['createdAt'] as String),
        description: json['description'] as String? ?? '',
      );
}
