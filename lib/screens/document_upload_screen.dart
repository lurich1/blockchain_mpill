import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../models/document_model.dart';
import '../providers/document_provider.dart';
import '../constants/app_constants.dart';

/// Document Upload Screen (thesis Section 3.6.3)
/// "When a document is uploaded, it is first stored on IPFS, which
/// generates a unique CID. The CID, along with document metadata,
/// is then submitted to the smart contract."
class DocumentUploadScreen extends ConsumerStatefulWidget {
  final String userId;
  final String? institutionId;

  const DocumentUploadScreen({
    super.key,
    required this.userId,
    this.institutionId,
  });

  @override
  ConsumerState<DocumentUploadScreen> createState() =>
      _DocumentUploadScreenState();
}

class _DocumentUploadScreenState extends ConsumerState<DocumentUploadScreen> {
  File? _selectedFile;
  DocumentType? _selectedDocumentType;
  GovernmentAgency? _selectedAgency;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.allowedFileTypes,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file')),
      );
      return;
    }

    if (_selectedDocumentType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select document type')),
      );
      return;
    }

    if (_selectedAgency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select issuing agency')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final documentService = ref.read(documentServiceProvider);
      final document = await documentService.uploadDocument(
        file: _selectedFile!,
        userId: widget.userId,
        documentType: _selectedDocumentType!,
        issuingAgency: _selectedAgency!,
        institutionId: widget.institutionId,
      );

      // Add uploaded document to the global documents list
      ref.read(documentsProvider.notifier).addDocument(document);

      if (mounted) {
        final isDemoMode = AppConstants.isDemoMode;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDemoMode
                  ? 'Document uploaded successfully (Demo Mode)'
                  : 'Document uploaded successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, document);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Document'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Demo mode banner
            if (AppConstants.isDemoMode)
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.science, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Demo Mode: Uploads are simulated locally. '
                          'To use real IPFS/blockchain, add your Pinata JWT '
                          'in app_constants.dart',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (AppConstants.isDemoMode) const SizedBox(height: 8),

            // Upload workflow info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Files are stored on IPFS and verified on the Ethereum blockchain.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // File picker
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.upload_file,
                        size: 64, color: Color(0xFF1976D2)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.folder_open),
                      label: const Text('Select File'),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.insert_drive_file,
                              size: 20, color: Colors.green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              _selectedFile!.path.split(RegExp(r'[/\\]')).last,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
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
            const SizedBox(height: 24),

            // Document type
            DropdownButtonFormField<DocumentType>(
              decoration: const InputDecoration(
                labelText: 'Document Type',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              initialValue: _selectedDocumentType,
              items: DocumentType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    AppConstants.documentTypes[type.name] ?? type.name,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDocumentType = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Issuing agency
            DropdownButtonFormField<GovernmentAgency>(
              decoration: const InputDecoration(
                labelText: 'Issuing Agency',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              initialValue: _selectedAgency,
              items: GovernmentAgency.values.map((agency) {
                return DropdownMenuItem(
                  value: agency,
                  child: Text(
                    AppConstants.governmentAgencies[agency.name] ?? agency.name,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedAgency = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // Upload button
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadDocument,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Upload to Blockchain',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),

            const SizedBox(height: 24),

            // Process explanation
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upload Process',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    _buildProcessStep(
                        '1', 'File is hashed using SHA-256', Icons.tag),
                    _buildProcessStep(
                        '2', 'Document stored on IPFS (gets CID)', Icons.cloud),
                    _buildProcessStep(
                        '3', 'Hash + CID recorded on blockchain', Icons.link),
                    _buildProcessStep('4', 'Transaction confirmed & logged',
                        Icons.check_circle),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessStep(String number, String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF1976D2),
            child: Text(number,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
