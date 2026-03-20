import 'package:uuid/uuid.dart';
import '../models/audit_log_model.dart';

/// Monitoring and Audit Layer service (Thesis Section 3.4.6)
/// "All transactions, including document uploads and verification requests,
/// are permanently recorded and can be audited by authorized stakeholders."
///
/// "This layer enhances trust in the system by enabling real-time monitoring,
/// compliance checks, and forensic analysis in the event of disputes or
/// suspected fraud."
class AuditService {
  final Uuid _uuid = const Uuid();
  final List<AuditLogModel> _auditLogs = [];

  /// Callback that is invoked every time the log list changes,
  /// so the caller (provider) can persist it.
  void Function(List<AuditLogModel>)? onLogsChanged;

  /// Restore previously persisted logs (called once at startup).
  void restoreLogs(List<AuditLogModel> logs) {
    _auditLogs.addAll(logs);
  }

  /// Get all audit logs
  List<AuditLogModel> get auditLogs => List.unmodifiable(_auditLogs);

  /// Get audit logs for a specific document
  List<AuditLogModel> getLogsForDocument(String documentId) {
    return _auditLogs.where((log) => log.documentId == documentId).toList();
  }

  /// Get audit logs for a specific institution
  List<AuditLogModel> getLogsForInstitution(String institutionId) {
    return _auditLogs
        .where((log) => log.institutionId == institutionId)
        .toList();
  }

  /// Get audit logs for a specific user
  List<AuditLogModel> getLogsForUser(String userId) {
    return _auditLogs.where((log) => log.performedBy == userId).toList();
  }

  /// Get audit logs filtered by action type
  List<AuditLogModel> getLogsByAction(AuditAction action) {
    return _auditLogs.where((log) => log.action == action).toList();
  }

  /// Get recent audit logs
  List<AuditLogModel> getRecentLogs({int limit = 50}) {
    final sorted = List<AuditLogModel>.from(_auditLogs)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(limit).toList();
  }

  /// Log an audit action (thesis Section 3.6.6)
  /// "Smart contracts generate events for key actions such as document
  /// registration and verification requests."
  AuditLogModel logAction({
    required AuditAction action,
    required String performedBy,
    String? performedByName,
    String? documentId,
    String? institutionId,
    String? transactionHash,
    String? details,
    Map<String, dynamic>? metadata,
  }) {
    final log = AuditLogModel(
      id: _uuid.v4(),
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      documentId: documentId,
      institutionId: institutionId,
      transactionHash: transactionHash,
      timestamp: DateTime.now(),
      details: details,
      metadata: metadata,
    );

    _auditLogs.add(log);
    onLogsChanged?.call(List.unmodifiable(_auditLogs));
    return log;
  }

  /// Get audit statistics for dashboard
  Map<String, int> getAuditStatistics() {
    final stats = <String, int>{};
    for (final action in AuditAction.values) {
      final count = _auditLogs.where((log) => log.action == action).length;
      if (count > 0) {
        stats[action.name] = count;
      }
    }
    return stats;
  }

  /// Get total number of audit entries
  int get totalEntries => _auditLogs.length;
}

