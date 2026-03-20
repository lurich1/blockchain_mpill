import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/audit_log_model.dart';
import '../providers/audit_provider.dart';

/// Audit Trail Screen - Monitoring and Audit Layer (Thesis Section 3.4.6)
/// "The monitoring and audit layer provides transparency and accountability
/// through blockchain explorers and logging tools."
class AuditTrailScreen extends ConsumerWidget {
  const AuditTrailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auditLogs = ref.watch(auditLogsProvider);

    return auditLogs.isEmpty
        ? _buildEmptyState()
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: auditLogs.length,
            itemBuilder: (context, index) {
              return _buildAuditLogItem(context, auditLogs[index]);
            },
          );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No audit entries yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'All document transactions will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditLogItem(BuildContext context, AuditLogModel log) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(log.action).withValues(alpha: 0.1),
          child: Icon(
            _getActionIcon(log.action),
            color: _getActionColor(log.action),
            size: 20,
          ),
        ),
        title: Text(
          _getActionLabel(log.action),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          _formatTimestamp(log.timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.performedByName != null)
                  _buildDetailRow('Performed by', log.performedByName!),
                if (log.documentId != null)
                  _buildDetailRow('Document ID', log.documentId!),
                if (log.institutionId != null)
                  _buildDetailRow('Institution', log.institutionId!),
                if (log.transactionHash != null)
                  _buildDetailRow('Transaction', log.transactionHash!),
                if (log.details != null)
                  _buildDetailRow('Details', log.details!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(AuditAction action) {
    switch (action) {
      case AuditAction.documentUploaded:
        return Icons.upload_file;
      case AuditAction.documentVerified:
        return Icons.verified;
      case AuditAction.documentRejected:
        return Icons.cancel;
      case AuditAction.documentShared:
        return Icons.share;
      case AuditAction.documentAccessed:
        return Icons.visibility;
      case AuditAction.documentRevoked:
        return Icons.block;
      case AuditAction.verificationRequested:
        return Icons.pending;
      case AuditAction.accessGranted:
        return Icons.lock_open;
      case AuditAction.accessRevoked:
        return Icons.lock;
      case AuditAction.userRegistered:
        return Icons.person_add;
      case AuditAction.userRoleChanged:
        return Icons.manage_accounts;
      case AuditAction.institutionRegistered:
        return Icons.business;
      case AuditAction.institutionVerified:
        return Icons.verified_user;
      case AuditAction.systemConfigChanged:
        return Icons.settings;
      case AuditAction.other:
        return Icons.info;
    }
  }

  Color _getActionColor(AuditAction action) {
    switch (action) {
      case AuditAction.documentUploaded:
        return Colors.blue;
      case AuditAction.documentVerified:
      case AuditAction.institutionVerified:
        return Colors.green;
      case AuditAction.documentRejected:
      case AuditAction.documentRevoked:
      case AuditAction.accessRevoked:
        return Colors.red;
      case AuditAction.documentShared:
      case AuditAction.accessGranted:
        return Colors.teal;
      case AuditAction.documentAccessed:
        return Colors.indigo;
      case AuditAction.verificationRequested:
        return Colors.orange;
      case AuditAction.userRegistered:
      case AuditAction.institutionRegistered:
        return Colors.purple;
      case AuditAction.userRoleChanged:
      case AuditAction.systemConfigChanged:
        return Colors.brown;
      case AuditAction.other:
        return Colors.grey;
    }
  }

  String _getActionLabel(AuditAction action) {
    switch (action) {
      case AuditAction.documentUploaded:
        return 'Document Uploaded';
      case AuditAction.documentVerified:
        return 'Document Verified';
      case AuditAction.documentRejected:
        return 'Document Rejected';
      case AuditAction.documentShared:
        return 'Document Shared';
      case AuditAction.documentAccessed:
        return 'Document Accessed';
      case AuditAction.documentRevoked:
        return 'Document Revoked';
      case AuditAction.verificationRequested:
        return 'Verification Requested';
      case AuditAction.accessGranted:
        return 'Access Granted';
      case AuditAction.accessRevoked:
        return 'Access Revoked';
      case AuditAction.userRegistered:
        return 'User Registered';
      case AuditAction.userRoleChanged:
        return 'User Role Changed';
      case AuditAction.institutionRegistered:
        return 'Institution Registered';
      case AuditAction.institutionVerified:
        return 'Institution Verified';
      case AuditAction.systemConfigChanged:
        return 'System Config Changed';
      case AuditAction.other:
        return 'Other';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    return '${timestamp.day}/${timestamp.month}/${timestamp.year} '
        '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}';
  }
}

