/// Represents a single blockchain transaction in the explorer
/// Maps to the "Blockchain Explorer" component in the architecture diagram,
/// which sits between the Ethereum Blockchain and verifying entities.
class BlockchainTransaction {
  final String transactionHash;
  final String method; // e.g. uploadDocument, verifyDocument, grantAccess
  final TransactionType type;
  final TransactionStatus status;
  final DateTime timestamp;
  final int blockNumber;
  final String fromAddress;
  final String? toAddress;
  final double gasUsed;
  final String? documentHash;
  final String? ipfsCid;
  final String? documentType;
  final String? issuingAgency;
  final String? institutionId;
  final String? userId;
  final Map<String, dynamic>? parameters;

  BlockchainTransaction({
    required this.transactionHash,
    required this.method,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.blockNumber,
    required this.fromAddress,
    this.toAddress,
    required this.gasUsed,
    this.documentHash,
    this.ipfsCid,
    this.documentType,
    this.issuingAgency,
    this.institutionId,
    this.userId,
    this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'transactionHash': transactionHash,
      'method': method,
      'type': type.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      'blockNumber': blockNumber,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'gasUsed': gasUsed,
      'documentHash': documentHash,
      'ipfsCid': ipfsCid,
      'documentType': documentType,
      'issuingAgency': issuingAgency,
      'institutionId': institutionId,
      'userId': userId,
      'parameters': parameters,
    };
  }

  factory BlockchainTransaction.fromJson(Map<String, dynamic> json) {
    return BlockchainTransaction(
      transactionHash: json['transactionHash'] as String,
      method: json['method'] as String,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.documentUpload,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.confirmed,
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      blockNumber: json['blockNumber'] as int,
      fromAddress: json['fromAddress'] as String,
      toAddress: json['toAddress'] as String?,
      gasUsed: (json['gasUsed'] as num).toDouble(),
      documentHash: json['documentHash'] as String?,
      ipfsCid: json['ipfsCid'] as String?,
      documentType: json['documentType'] as String?,
      issuingAgency: json['issuingAgency'] as String?,
      institutionId: json['institutionId'] as String?,
      userId: json['userId'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>?,
    );
  }
}

enum TransactionType {
  documentUpload,
  documentVerification,
  accessGrant,
  accessRevoke,
  institutionRegistration,
  roleAssignment,
  verificationRequest,
}

enum TransactionStatus {
  confirmed,
  pending,
  failed,
}

