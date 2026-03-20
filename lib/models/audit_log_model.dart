/// Represents an audit trail entry for the Monitoring and Audit Layer
/// Maps to thesis Section 3.4.6 - Monitoring and Audit Layer
/// "All transactions, including document uploads and verification requests,
/// are permanently recorded and can be audited by authorized stakeholders."
class AuditLogModel {
  final String id;
  final AuditAction action;
  final String performedBy;
  final String? performedByName;
  final String? documentId;
  final String? institutionId;
  final String? transactionHash;
  final DateTime timestamp;
  final String? details;
  final Map<String, dynamic>? metadata;

  AuditLogModel({
    required this.id,
    required this.action,
    required this.performedBy,
    this.performedByName,
    this.documentId,
    this.institutionId,
    this.transactionHash,
    required this.timestamp,
    this.details,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.name,
      'performedBy': performedBy,
      'performedByName': performedByName,
      'documentId': documentId,
      'institutionId': institutionId,
      'transactionHash': transactionHash,
      'timestamp': timestamp.toIso8601String(),
      'details': details,
      'metadata': metadata,
    };
  }

  factory AuditLogModel.fromJson(Map<String, dynamic> json) {
    return AuditLogModel(
      id: json['id'] as String,
      action: AuditAction.values.firstWhere(
        (e) => e.name == json['action'],
        orElse: () => AuditAction.other,
      ),
      performedBy: json['performedBy'] as String,
      performedByName: json['performedByName'] as String?,
      documentId: json['documentId'] as String?,
      institutionId: json['institutionId'] as String?,
      transactionHash: json['transactionHash'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Audit actions as per thesis Section 3.6.6 - Event Logging and Auditability
/// "Smart contracts generate events for key actions such as document
/// registration and verification requests."
enum AuditAction {
  documentUploaded,
  documentVerified,
  documentRejected,
  documentShared,
  documentAccessed,
  documentRevoked,
  verificationRequested,
  accessGranted,
  accessRevoked,
  userRegistered,
  userRoleChanged,
  institutionRegistered,
  institutionVerified,
  systemConfigChanged,
  other,
}
