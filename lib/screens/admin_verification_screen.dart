import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/document_model.dart';
import '../models/audit_log_model.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import 'document_detail_screen.dart';

/// Admin Verification Panel — only visible to System Admin & Verifying Institution.
/// Shows all pending documents in a queue for efficient review.
class AdminVerificationScreen extends ConsumerStatefulWidget {
  const AdminVerificationScreen({super.key});

  @override
  ConsumerState<AdminVerificationScreen> createState() =>
      _AdminVerificationScreenState();
}

class _AdminVerificationScreenState
    extends ConsumerState<AdminVerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final documents = ref.watch(documentsProvider);
    final pending = documents
        .where((d) => d.status == DocumentStatus.pending)
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
    final verified = documents
        .where((d) => d.status == DocumentStatus.verified)
        .toList()
      ..sort((a, b) => (b.verifiedAt ?? b.uploadedAt)
          .compareTo(a.verifiedAt ?? a.uploadedAt));
    final rejected = documents
        .where((d) => d.status == DocumentStatus.rejected)
        .toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    return Column(
      children: [
        // ── Stats bar ──
        _buildStatsBar(
          total: documents.length,
          pending: pending.length,
          verified: verified.length,
          rejected: rejected.length,
        ),

        // ── Tabs ──
        Material(
          color: Theme.of(context).cardColor,
          elevation: 1,
          child: TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: [
              Tab(
                icon: Badge(
                  isLabelVisible: pending.isNotEmpty,
                  label: Text('${pending.length}'),
                  child: const Icon(Icons.pending_actions),
                ),
                text: 'Pending',
              ),
              const Tab(icon: Icon(Icons.checklist), text: 'All'),
              const Tab(icon: Icon(Icons.verified), text: 'Verified'),
              const Tab(icon: Icon(Icons.cancel), text: 'Rejected'),
            ],
          ),
        ),

        // ── Tab content ──
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildDocumentList(pending, isPendingTab: true),
              _buildDocumentList(documents.toList()
                ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt))),
              _buildDocumentList(verified),
              _buildDocumentList(rejected),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Stats bar at top ───
  Widget _buildStatsBar({
    required int total,
    required int pending,
    required int verified,
    required int rejected,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('Total', total, Colors.white),
          _statItem('Pending', pending, Colors.orange.shade200),
          _statItem('Verified', verified, Colors.green.shade200),
          _statItem('Rejected', rejected, Colors.red.shade200),
        ],
      ),
    );
  }

  Widget _statItem(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
      ],
    );
  }

  // ─── Document list ───
  Widget _buildDocumentList(List<DocumentModel> docs,
      {bool isPendingTab = false}) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPendingTab ? Icons.check_circle_outline : Icons.folder_open,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              isPendingTab
                  ? 'No documents pending verification'
                  : 'No documents found',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            if (isPendingTab) ...[
              const SizedBox(height: 8),
              Text(
                'All caught up! 🎉',
                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        final doc = docs[index];
        return _buildDocumentReviewCard(doc, isPendingTab: isPendingTab);
      },
    );
  }

  // ─── Individual document card with quick actions ───
  Widget _buildDocumentReviewCard(DocumentModel doc,
      {bool isPendingTab = false}) {
    final isPending = doc.status == DocumentStatus.pending;
    final statusColor = _getStatusColor(doc.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isPending
            ? BorderSide(color: Colors.orange.shade300, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentDetailScreen(document: doc),
            ),
          );
          // Refresh after returning from detail screen
          if (result != null || mounted) {
            setState(() {});
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Document type icon
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _getDocTypeIcon(doc.documentType),
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // File name & type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppConstants.documentTypes[doc.documentType.name] ??
                              doc.documentType.name,
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  // Status chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusLabel(doc.status),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Info row
              Row(
                children: [
                  Icon(Icons.account_balance, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    AppConstants.governmentAgencies[doc.issuingAgency.name] ??
                        doc.issuingAgency.name,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy – HH:mm').format(doc.uploadedAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              // Quick action buttons for pending docs
              if (isPending && isPendingTab) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _quickApprove(doc),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _quickReject(doc),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Reject'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DocumentDetailScreen(document: doc),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ─── Quick approve from list ───
  Future<void> _quickApprove(DocumentModel doc) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    try {
      // 1. Verify on blockchain
      final blockchainService = ref.read(blockchainServiceProvider);
      final txHash = await blockchainService.verifyDocument(doc.fileHash);

      // 2. Audit log
      final auditService = ref.read(auditServiceProvider);
      auditService.logAction(
        action: AuditAction.documentVerified,
        performedBy: user.id,
        documentId: doc.id,
        institutionId: user.institutionId,
        transactionHash: txHash,
        details:
            'Document "${doc.fileName}" approved by ${user.name} '
            '(${user.organization ?? user.role.name})',
      );

      // 3. Update local document
      final updatedDoc = doc.copyWith(
        status: DocumentStatus.verified,
        verifiedAt: DateTime.now(),
        verifierId: user.id,
        verifierInstitutionId: user.institutionId,
      );
      ref.read(documentsProvider.notifier).updateDocument(updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "${doc.fileName}" verified successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ─── Quick reject from list ───
  Future<void> _quickReject(DocumentModel doc) async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final reason = await _showRejectReasonDialog(doc.fileName);
    if (reason == null) return;

    try {
      // Audit log
      final auditService = ref.read(auditServiceProvider);
      auditService.logAction(
        action: AuditAction.documentRejected,
        performedBy: user.id,
        documentId: doc.id,
        institutionId: user.institutionId,
        details:
            'Document "${doc.fileName}" rejected by ${user.name}. '
            'Reason: $reason',
      );

      final updatedDoc = doc.copyWith(
        status: DocumentStatus.rejected,
        rejectionReason: reason,
        verifierId: user.id,
        verifierInstitutionId: user.institutionId,
      );
      ref.read(documentsProvider.notifier).updateDocument(updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${doc.fileName}" rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rejection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showRejectReasonDialog(String fileName) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject "$fileName"'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Blurry image, wrong document type…',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx, text.isEmpty ? 'No reason given' : text);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───

  Color _getStatusColor(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.pending:
        return Colors.orange;
      case DocumentStatus.verified:
        return Colors.green;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.expired:
        return Colors.grey;
      case DocumentStatus.revoked:
        return Colors.red.shade900;
    }
  }

  String _getStatusLabel(DocumentStatus status) {
    switch (status) {
      case DocumentStatus.pending:
        return 'Pending';
      case DocumentStatus.verified:
        return 'Verified';
      case DocumentStatus.rejected:
        return 'Rejected';
      case DocumentStatus.expired:
        return 'Expired';
      case DocumentStatus.revoked:
        return 'Revoked';
    }
  }

  IconData _getDocTypeIcon(DocumentType type) {
    switch (type) {
      case DocumentType.nationalId:
        return Icons.badge;
      case DocumentType.driverLicense:
        return Icons.directions_car;
      case DocumentType.birthCertificate:
        return Icons.child_care;
      case DocumentType.educationalCertificate:
        return Icons.school;
      case DocumentType.taxDocument:
        return Icons.receipt_long;
      case DocumentType.businessRegistration:
        return Icons.business;
      case DocumentType.medicalRecord:
        return Icons.medical_services;
      case DocumentType.propertyRecord:
        return Icons.home;
      case DocumentType.other:
        return Icons.description;
    }
  }
}

