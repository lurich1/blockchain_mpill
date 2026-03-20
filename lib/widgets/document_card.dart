import 'package:flutter/material.dart';
import '../models/document_model.dart';
import '../constants/app_constants.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback? onTap;

  const DocumentCard({
    super.key,
    required this.document,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getDocumentIcon(),
                    size: 40,
                    color: _getStatusColor(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.fileName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppConstants
                                  .documentTypes[document.documentType.name] ??
                              document.documentType.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _getStatusChip(),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.business, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    AppConstants
                            .governmentAgencies[document.issuingAgency.name] ??
                        document.issuingAgency.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(document.uploadedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (document.transactionHash != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.link, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Tx: ${document.transactionHash!.substring(0, 10)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  IconData _getDocumentIcon() {
    switch (document.documentType) {
      case DocumentType.nationalId:
        return Icons.badge;
      case DocumentType.driverLicense:
        return Icons.credit_card;
      case DocumentType.birthCertificate:
        return Icons.description;
      case DocumentType.educationalCertificate:
        return Icons.school;
      case DocumentType.taxDocument:
        return Icons.receipt;
      case DocumentType.businessRegistration:
        return Icons.business;
      case DocumentType.medicalRecord:
        return Icons.medical_services;
      default:
        return Icons.description;
    }
  }

  Color _getStatusColor() {
    switch (document.status) {
      case DocumentStatus.verified:
        return Colors.green;
      case DocumentStatus.pending:
        return Colors.orange;
      case DocumentStatus.rejected:
        return Colors.red;
      case DocumentStatus.expired:
        return Colors.grey;
      case DocumentStatus.revoked:
        return Colors.red.shade900;
    }
  }

  Widget _getStatusChip() {
    return Chip(
      label: Text(
        _getStatusText(),
        style: const TextStyle(fontSize: 12),
      ),
      backgroundColor: _getStatusColor().withValues(alpha: 0.1),
      labelStyle: TextStyle(color: _getStatusColor()),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _getStatusText() {
    switch (document.status) {
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

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
