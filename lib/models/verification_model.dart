/// Verification record model
/// Maps to thesis Section 3.6.4 - Document Verification Logic
/// "The verification logic allows authorized users or institutions to confirm
/// the authenticity of a document."
class VerificationModel {
  final String id;
  final String documentId;
  final String verifierId;
  final String? verifierInstitutionId;
  final bool isVerified;
  final DateTime verifiedAt;
  final String transactionHash;
  final String? notes;
  final VerificationMethod method;
  final VerificationResult result;

  VerificationModel({
    required this.id,
    required this.documentId,
    required this.verifierId,
    this.verifierInstitutionId,
    required this.isVerified,
    required this.verifiedAt,
    required this.transactionHash,
    this.notes,
    required this.method,
    this.result = VerificationResult.pending,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'documentId': documentId,
      'verifierId': verifierId,
      'verifierInstitutionId': verifierInstitutionId,
      'isVerified': isVerified,
      'verifiedAt': verifiedAt.toIso8601String(),
      'transactionHash': transactionHash,
      'notes': notes,
      'method': method.name,
      'result': result.name,
    };
  }

  factory VerificationModel.fromJson(Map<String, dynamic> json) {
    return VerificationModel(
      id: json['id'] as String,
      documentId: json['documentId'] as String,
      verifierId: json['verifierId'] as String,
      verifierInstitutionId: json['verifierInstitutionId'] as String?,
      isVerified: json['isVerified'] as bool,
      verifiedAt: DateTime.parse(json['verifiedAt'] as String),
      transactionHash: json['transactionHash'] as String,
      notes: json['notes'] as String?,
      method: VerificationMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => VerificationMethod.blockchain,
      ),
      result: VerificationResult.values.firstWhere(
        (e) => e.name == json['result'],
        orElse: () => VerificationResult.pending,
      ),
    );
  }
}

/// Thesis Section 3.6.4: "The document retrieved from IPFS is rehashed
/// and compared with the hash stored on the blockchain."
enum VerificationMethod {
  blockchain,    // On-chain hash comparison
  hashComparison, // IPFS CID re-hash comparison
  manual,        // Manual institutional verification
  crossInstitutional, // Cross-institutional verification
}

enum VerificationResult {
  pending,
  authentic,       // Hash match confirmed
  tampered,        // Hash mismatch detected
  notFound,        // Document not on blockchain
  expired,         // Document has expired
  revoked,         // Document was revoked
}
