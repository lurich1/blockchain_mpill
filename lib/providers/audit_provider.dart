import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log_model.dart';
import 'document_provider.dart';

/// Audit trail state management
/// Maps to thesis Section 3.4.6 - Monitoring and Audit Layer
final auditLogsProvider = Provider<List<AuditLogModel>>((ref) {
  final auditService = ref.watch(auditServiceProvider);
  return auditService.getRecentLogs();
});

final auditStatsProvider = Provider<Map<String, int>>((ref) {
  final auditService = ref.watch(auditServiceProvider);
  return auditService.getAuditStatistics();
});

