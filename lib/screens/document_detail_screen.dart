import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../models/audit_log_model.dart';
import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';

/// Document Detail Screen - shows full document info with verification data
/// Maps to thesis Section 3.6.4 - verification info display
///
/// KEY: Users with [canVerifyDocuments] (System Admin, Verifying Institution)
/// see an "Approve" button to move a document from PENDING → VERIFIED.
class DocumentDetailScreen extends ConsumerStatefulWidget {
  final DocumentModel document;

  const DocumentDetailScreen({super.key, required this.document});

  @override
  ConsumerState<DocumentDetailScreen> createState() =>
      _DocumentDetailScreenState();
}

class _DocumentDetailScreenState extends ConsumerState<DocumentDetailScreen> {
  late DocumentModel _document;
  bool _isVerifying = false;
  bool _isRejecting = false;

  @override
  void initState() {
    super.initState();
    _document = widget.document;
  }

  // ─── Approve (verify) the document on the blockchain ───
  Future<void> _approveDocument() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _isVerifying = true);

    try {
      // 1. Call blockchain verifyDocument
      final blockchainService = ref.read(blockchainServiceProvider);
      final txHash =
          await blockchainService.verifyDocument(_document.fileHash);

      // 2. Log the audit action
      final auditService = ref.read(auditServiceProvider);
      auditService.logAction(
        action: AuditAction.documentVerified,
        performedBy: user.id,
        documentId: _document.id,
        institutionId: user.institutionId,
        transactionHash: txHash,
        details:
            'Document "${_document.fileName}" verified by ${user.name} '
            '(${user.organization ?? user.role.name})',
      );

      // 3. Update local document model
      final updatedDoc = _document.copyWith(
        status: DocumentStatus.verified,
        verifiedAt: DateTime.now(),
        verifierId: user.id,
        verifierInstitutionId: user.institutionId,
      );

      // 4. Update in global state
      ref.read(documentsProvider.notifier).updateDocument(updatedDoc);

      setState(() => _document = updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Document verified successfully!'),
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
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  // ─── Reject the document ───
  Future<void> _rejectDocument() async {
    final user = ref.read(authProvider);
    if (user == null) return;

    final reason = await _showRejectReasonDialog();
    if (reason == null) return; // user cancelled

    setState(() => _isRejecting = true);

    try {
      // Log the audit action
      final auditService = ref.read(auditServiceProvider);
      auditService.logAction(
        action: AuditAction.documentRejected,
        performedBy: user.id,
        documentId: _document.id,
        institutionId: user.institutionId,
        details:
            'Document "${_document.fileName}" rejected by ${user.name}. '
            'Reason: $reason',
      );

      final updatedDoc = _document.copyWith(
        status: DocumentStatus.rejected,
        rejectionReason: reason,
        verifierId: user.id,
        verifierInstitutionId: user.institutionId,
      );

      ref.read(documentsProvider.notifier).updateDocument(updatedDoc);
      setState(() => _document = updatedDoc);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document rejected'),
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
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Future<String?> _showRejectReasonDialog() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Document'),
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
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final canVerify = user?.canVerifyDocuments ?? false;
    final isPending = _document.status == DocumentStatus.pending;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Details'),
        actions: [
          if (_document.status == DocumentStatus.verified)
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _showShareDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            _buildStatusBanner(),
            const SizedBox(height: 20),

            // ── VERIFY / REJECT BUTTONS (only for authorized users + pending docs) ──
            if (canVerify && isPending) ...[
              _buildVerificationActions(),
              const SizedBox(height: 20),
            ],

            // Document info card
            _buildDocumentInfoCard(),
            const SizedBox(height: 16),

            // Blockchain info card
            _buildBlockchainInfoCard(context),
            const SizedBox(height: 16),

            // IPFS info card
            _buildIpfsInfoCard(context),
            const SizedBox(height: 16),

            // Verification info
            if (_document.verifiedAt != null) _buildVerificationCard(),

            // Rejection info
            if (_document.status == DocumentStatus.rejected &&
                _document.rejectionReason != null)
              _buildRejectionCard(),

            const SizedBox(height: 16),

            // Shared institutions
            if (_document.sharedWithInstitutions.isNotEmpty)
              _buildSharedInstitutionsCard(),
          ],
        ),
      ),
    );
  }

  // ─── Approve / Reject action bar ───
  Widget _buildVerificationActions() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gavel, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Verification Action Required',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'As a verifying authority you can approve or reject this document. '
              'Approval records a verification transaction on the blockchain.',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isVerifying ? null : _approveDocument,
                    icon: _isVerifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle),
                    label:
                        Text(_isVerifying ? 'Verifying…' : 'Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isRejecting ? null : _rejectDocument,
                    icon: _isRejecting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel),
                    label:
                        Text(_isRejecting ? 'Rejecting…' : 'Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor;
    Color textColor;
    IconData icon;
    String statusText;

    switch (_document.status) {
      case DocumentStatus.verified:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        icon = Icons.verified;
        statusText = 'Document Verified on Blockchain';
        break;
      case DocumentStatus.pending:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        icon = Icons.pending;
        statusText = 'Pending Verification';
        break;
      case DocumentStatus.rejected:
        bgColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        statusText = 'Verification Rejected';
        break;
      case DocumentStatus.expired:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        icon = Icons.access_time;
        statusText = 'Document Expired';
        break;
      case DocumentStatus.revoked:
        bgColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        icon = Icons.block;
        statusText = 'Document Revoked';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Document Information',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildInfoRow('File Name', _document.fileName),
            _buildInfoRow(
              'Document Type',
              AppConstants.documentTypes[_document.documentType.name] ??
                  _document.documentType.name,
            ),
            _buildInfoRow(
              'Issuing Agency',
              AppConstants.governmentAgencies[_document.issuingAgency.name] ??
                  _document.issuingAgency.name,
            ),
            _buildInfoRow(
              'Uploaded',
              _formatDateTime(_document.uploadedAt),
            ),
            if (_document.expiresAt != null)
              _buildInfoRow(
                'Expires',
                _formatDateTime(_document.expiresAt!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockchainInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.link, size: 20),
                SizedBox(width: 8),
                Text(
                  'Blockchain Record',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildCopyableRow(
                context, 'File Hash (SHA-256)', _document.fileHash),
            if (_document.transactionHash != null)
              _buildCopyableRow(
                  context, 'Transaction Hash', _document.transactionHash!),
          ],
        ),
      ),
    );
  }

  Widget _buildIpfsInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud, size: 20),
                SizedBox(width: 8),
                Text(
                  'IPFS Storage',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            _buildCopyableRow(
                context, 'Content Identifier (CID)', _document.ipfsCid),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Open IPFS gateway URL
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('View on IPFS Gateway'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Verification Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            _buildInfoRow(
              'Verified At',
              _formatDateTime(_document.verifiedAt!),
            ),
            if (_document.verifierId != null)
              _buildInfoRow('Verifier ID', _document.verifierId!),
            if (_document.verifierInstitutionId != null)
              _buildInfoRow(
                  'Verifier Institution', _document.verifierInstitutionId!),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectionCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Rejection Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (_document.verifierId != null)
              _buildInfoRow('Rejected By', _document.verifierId!),
            if (_document.verifierInstitutionId != null)
              _buildInfoRow('Institution', _document.verifierInstitutionId!),
            _buildInfoRow('Reason', _document.rejectionReason!),
          ],
        ),
      ),
    );
  }

  Widget _buildSharedInstitutionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shared With Institutions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ..._document.sharedWithInstitutions.map((id) => ListTile(
                  leading: const Icon(Icons.business),
                  title: Text(id),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyableRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: value));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Grant access to an institution for cross-institutional verification.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...AppConstants.governmentAgencies.entries.map(
              (entry) => ListTile(
                leading: const Icon(Icons.business),
                title: Text(entry.value),
                subtitle: Text(entry.key.toUpperCase()),
                dense: true,
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Access granted to ${entry.value}'),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime date) {
    return '${date.day}/${date.month}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }
}
