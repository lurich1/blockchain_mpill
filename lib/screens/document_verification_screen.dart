import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/document_model.dart';
import '../providers/document_provider.dart';

/// Document Verification Screen (thesis Section 3.6.4)
/// Allows users to enter a document hash, IPFS CID, or transaction hash
/// to look up its verification status from the shared blockchain ledger
/// and local document list.
class DocumentVerificationScreen extends ConsumerStatefulWidget {
  const DocumentVerificationScreen({super.key});

  @override
  ConsumerState<DocumentVerificationScreen> createState() =>
      _DocumentVerificationScreenState();
}

class _DocumentVerificationScreenState
    extends ConsumerState<DocumentVerificationScreen> {
  final _hashController = TextEditingController();
  bool _isVerifying = false;
  _VerificationResult? _result;

  /// Look up the document using multiple strategies:
  /// 1. Check local documents by fileHash
  /// 2. Check local documents by IPFS CID
  /// 3. Check local documents by transaction hash
  /// 4. Check the blockchain service demo store by hash
  Future<void> _verifyDocument() async {
    final query = _hashController.text.trim();

    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please enter a document hash, IPFS CID, or transaction hash')),
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _result = null;
    });

    try {
      final documents = ref.read(documentsProvider);
      final blockchainService = ref.read(blockchainServiceProvider);

      // Strategy 1: Match by file hash (SHA-256)
      DocumentModel? match = documents.cast<DocumentModel?>().firstWhere(
            (d) => d!.fileHash == query,
            orElse: () => null,
          );

      // Strategy 2: Match by IPFS CID
      match ??= documents.cast<DocumentModel?>().firstWhere(
            (d) => d!.ipfsCid == query,
            orElse: () => null,
          );

      // Strategy 3: Match by transaction hash
      match ??= documents.cast<DocumentModel?>().firstWhere(
            (d) => d!.transactionHash == query,
            orElse: () => null,
          );

      if (match != null) {
        // We found the document locally — also pull blockchain record
        Map<String, dynamic>? chainInfo;
        try {
          chainInfo = await blockchainService.getDocumentInfo(match.fileHash);
        } catch (_) {}

        final isOnChainVerified = chainInfo?['isVerified'] == true;

        setState(() {
          _result = _VerificationResult(
            found: true,
            verified:
                match!.status == DocumentStatus.verified || isOnChainVerified,
            document: match,
            chainInfo: chainInfo,
          );
        });
      } else {
        // Not in local list — try blockchain directly by hash
        final chainInfo = await blockchainService.getDocumentInfo(query);
        final exists =
            chainInfo['uploadedAt'] != null && chainInfo['uploadedAt'] != 0;

        setState(() {
          _result = _VerificationResult(
            found: exists,
            verified: chainInfo['isVerified'] == true,
            document: null,
            chainInfo: exists ? chainInfo : null,
          );
        });
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
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  @override
  void dispose() {
    _hashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Search Card ──
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.verified_user,
                        size: 48, color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verify Document',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the document hash, IPFS CID, or transaction hash\nto check its verification status on the blockchain.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _hashController,
                    decoration: InputDecoration(
                      labelText: 'Document Hash / IPFS CID / Tx Hash',
                      hintText: 'Paste hash here…',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.fingerprint),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.paste),
                        tooltip: 'Paste from clipboard',
                        onPressed: () async {
                          final clipboardData =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          if (clipboardData?.text != null) {
                            _hashController.text = clipboardData!.text!;
                          }
                        },
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isVerifying ? null : _verifyDocument,
                      icon: _isVerifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search),
                      label: Text(
                        _isVerifying
                            ? 'Checking blockchain…'
                            : 'Verify Document',
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Result Card ──
          if (_result != null) ...[
            const SizedBox(height: 24),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final r = _result!;

    if (!r.found) {
      return _buildNotFoundCard();
    }

    final isVerified = r.verified;
    final doc = r.document;
    final chain = r.chainInfo;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isVerified ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status banner
            Row(
              children: [
                Icon(
                  isVerified ? Icons.check_circle : Icons.hourglass_top,
                  color: isVerified ? Colors.green : Colors.orange,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVerified
                            ? 'Document Verified ✓'
                            : 'Document Pending Verification',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isVerified
                              ? Colors.green.shade800
                              : Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isVerified
                            ? 'This document has been verified on the blockchain.'
                            : 'This document is registered but not yet verified by an authority.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isVerified
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Document details
            if (doc != null) ...[
              _infoRow(Icons.description, 'File Name', doc.fileName),
              _infoRow(
                  Icons.category, 'Type', doc.documentType.name.toUpperCase()),
              _infoRow(Icons.account_balance, 'Issuing Agency',
                  doc.issuingAgency.name.toUpperCase()),
              _infoRow(
                Icons.info_outline,
                'Status',
                doc.status.name[0].toUpperCase() + doc.status.name.substring(1),
              ),
              _infoRow(
                Icons.calendar_today,
                'Uploaded At',
                DateFormat('MMM dd, yyyy  HH:mm').format(doc.uploadedAt),
              ),
              if (doc.verifiedAt != null)
                _infoRow(
                  Icons.verified,
                  'Verified At',
                  DateFormat('MMM dd, yyyy  HH:mm').format(doc.verifiedAt!),
                ),
            ],

            _hashRow('File Hash', doc?.fileHash ?? chain?['hash'] ?? 'N/A'),
            _hashRow('IPFS CID', doc?.ipfsCid ?? chain?['ipfsCid'] ?? 'N/A'),
            _hashRow(
              'Transaction Hash',
              doc?.transactionHash ?? chain?['transactionHash'] ?? 'N/A',
            ),

            if (chain != null && chain['verifier'] != null)
              _hashRow('Verifier', chain['verifier'].toString()),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFoundCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.cancel, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 12),
            Text(
              'Document Not Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No document matching this hash / CID was found on the blockchain or in local records.\n\n'
              'Make sure you are entering the correct document hash, IPFS CID, or transaction hash.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _hashRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                if (value != 'N/A')
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('$label copied'),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Icon(Icons.copy, size: 16, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Internal result model for the verification lookup
class _VerificationResult {
  final bool found;
  final bool verified;
  final DocumentModel? document;
  final Map<String, dynamic>? chainInfo;

  _VerificationResult({
    required this.found,
    required this.verified,
    this.document,
    this.chainInfo,
  });
}
