import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../models/audit_log_model.dart';
import 'blockchain_service.dart';
import 'ipfs_service.dart';
import 'audit_service.dart';

/// Document management service orchestrating the full document lifecycle
/// Maps to thesis Sections 3.6.3, 3.6.4, and 3.7
///
/// Workflow: File → IPFS (get CID) → Hash → Blockchain (store CID + hash)
class DocumentService {
  final BlockchainService _blockchainService;
  final IPFSService _ipfsService;
  final AuditService _auditService;
  final Uuid _uuid = const Uuid();

  DocumentService({
    required BlockchainService blockchainService,
    required IPFSService ipfsService,
    required AuditService auditService,
  })  : _blockchainService = blockchainService,
        _ipfsService = ipfsService,
        _auditService = auditService;

  /// Upload document: File → IPFS → Blockchain (thesis Section 3.6.3)
  /// "When a document is uploaded, it is first stored on IPFS, which
  /// generates a unique CID. The CID, along with document metadata,
  /// is then submitted to the smart contract."
  Future<DocumentModel> uploadDocument({
    required File file,
    required String userId,
    required DocumentType documentType,
    required GovernmentAgency issuingAgency,
    String? institutionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Read file bytes
      final fileBytes = await file.readAsBytes();

      // 2. Calculate SHA-256 hash of the file
      final fileHash = _blockchainService.calculateFileHash(fileBytes);

      // 3. Upload to IPFS → get CID (thesis Section 3.7)
      final ipfsCid = await _ipfsService.uploadFile(file);

      // 4. Store hash + CID on blockchain (thesis Section 3.6.3)
      final transactionHash = await _blockchainService.uploadDocumentHash(
        documentHash: fileHash,
        ipfsCid: ipfsCid,
        userId: userId,
        documentType: documentType.name,
        issuingAgency: issuingAgency.name,
        institutionId: institutionId ?? '',
      );

      // 5. Create document model
      final document = DocumentModel(
        id: _uuid.v4(),
        userId: userId,
        fileName: file.path.split(RegExp(r'[/\\]')).last,
        fileHash: fileHash,
        ipfsCid: ipfsCid,
        documentType: documentType,
        issuingAgency: issuingAgency,
        issuingInstitutionId: institutionId,
        status: DocumentStatus.pending,
        uploadedAt: DateTime.now(),
        transactionHash: transactionHash,
        metadata: metadata,
      );

      // 6. Log audit trail (thesis Section 3.6.6)
      _auditService.logAction(
        action: AuditAction.documentUploaded,
        performedBy: userId,
        documentId: document.id,
        institutionId: institutionId,
        transactionHash: transactionHash,
        details:
            'Document "${document.fileName}" uploaded to IPFS (CID: $ipfsCid) '
            'and registered on blockchain',
      );

      return document;
    } catch (e) {
      throw Exception('Failed to upload document: $e');
    }
  }

  /// Verify a document (thesis Section 3.6.4)
  /// "The document retrieved from IPFS is rehashed and compared
  /// with the hash stored on the blockchain."
  Future<bool> verifyDocument(DocumentModel document) async {
    try {
      // 1. Retrieve file from IPFS
      final ipfsBytes = await _ipfsService.retrieveFile(document.ipfsCid);

      // 2. Rehash the retrieved file
      final rehash =
          _blockchainService.calculateFileHash(ipfsBytes.toList());

      // 3. Compare with stored hash (thesis Section 3.6.4)
      final hashesMatch = rehash == document.fileHash;

      // 4. Check blockchain record
      final blockchainInfo =
          await _blockchainService.getDocumentInfo(document.fileHash);
      final onChainVerified = blockchainInfo['isVerified'] as bool;

      // 5. Log audit trail
      _auditService.logAction(
        action: AuditAction.verificationRequested,
        performedBy: document.userId,
        documentId: document.id,
        details:
            'Verification: hash match=$hashesMatch, '
            'on-chain verified=$onChainVerified',
      );

      return hashesMatch && onChainVerified;
    } catch (e) {
      throw Exception('Failed to verify document: $e');
    }
  }

  /// Get document info from blockchain
  Future<Map<String, dynamic>> getDocumentInfo(String documentHash) async {
    try {
      return await _blockchainService.getDocumentInfo(documentHash);
    } catch (e) {
      throw Exception('Failed to get document info: $e');
    }
  }

  /// Get IPFS URL for a document
  String getDocumentUrl(DocumentModel document) {
    return _ipfsService.getFileUrl(document.ipfsCid);
  }

  /// Retrieve document file from IPFS
  Future<List<int>> retrieveDocumentFile(DocumentModel document) async {
    try {
      final bytes = await _ipfsService.retrieveFile(document.ipfsCid);

      _auditService.logAction(
        action: AuditAction.documentAccessed,
        performedBy: document.userId,
        documentId: document.id,
        details: 'Document file retrieved from IPFS',
      );

      return bytes.toList();
    } catch (e) {
      throw Exception('Failed to retrieve document file: $e');
    }
  }

  /// Share document with an institution (thesis cross-institutional)
  Future<void> shareWithInstitution({
    required DocumentModel document,
    required String institutionId,
    required String grantedBy,
  }) async {
    try {
      final txHash = await _blockchainService.grantAccess(
        document.fileHash,
        institutionId,
      );

      _auditService.logAction(
        action: AuditAction.documentShared,
        performedBy: grantedBy,
        documentId: document.id,
        institutionId: institutionId,
        transactionHash: txHash,
        details:
            'Access granted to institution $institutionId for document "${document.fileName}"',
      );
    } catch (e) {
      throw Exception('Failed to share document: $e');
    }
  }

  /// Revoke institution access
  Future<void> revokeInstitutionAccess({
    required DocumentModel document,
    required String institutionId,
    required String revokedBy,
  }) async {
    try {
      final txHash = await _blockchainService.revokeAccess(
        document.fileHash,
        institutionId,
      );

      _auditService.logAction(
        action: AuditAction.accessRevoked,
        performedBy: revokedBy,
        documentId: document.id,
        institutionId: institutionId,
        transactionHash: txHash,
        details:
            'Access revoked for institution $institutionId on document "${document.fileName}"',
      );
    } catch (e) {
      throw Exception('Failed to revoke access: $e');
    }
  }
}
