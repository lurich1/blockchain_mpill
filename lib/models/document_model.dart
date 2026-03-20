/// Document types as defined in thesis Section 1.5 and AppConstants
enum DocumentType {
  nationalId,
  driverLicense,
  birthCertificate,
  educationalCertificate,
  taxDocument,
  businessRegistration,
  medicalRecord,
  propertyRecord,
  other,
}

/// Document verification statuses
enum DocumentStatus {
  pending,
  verified,
  rejected,
  expired,
  revoked,
}

/// Government agencies as described in thesis Section 1.1:
/// NIA, DVLA, GRA, MOH, WAEC, RGD (and SSNIT)
enum GovernmentAgency {
  nia,   // National Identification Authority
  dvla,  // Driver and Vehicle Licensing Authority
  gra,   // Ghana Revenue Authority
  moh,   // Ministry of Health
  waec,  // West African Examinations Council
  rgd,   // Registrar General's Department
  ssnit, // Social Security and National Insurance Trust
  other,
}

/// Represents a document in the system
/// Maps to thesis Section 3.6.3 - Document Registration Logic
class DocumentModel {
  final String id;
  final String userId;
  final String fileName;
  final String fileHash;       // SHA-256 hash of the document
  final String ipfsCid;        // IPFS Content Identifier (CID) - thesis Section 3.7
  final DocumentType documentType;
  final GovernmentAgency issuingAgency;
  final String? issuingInstitutionId;
  final DocumentStatus status;
  final DateTime uploadedAt;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final String? transactionHash;   // Blockchain transaction hash
  final String? verifierId;
  final String? verifierInstitutionId;
  final String? rejectionReason;
  final Map<String, dynamic>? metadata;
  final List<String> sharedWithInstitutions;  // Cross-institutional access

  DocumentModel({
    required this.id,
    required this.userId,
    required this.fileName,
    required this.fileHash,
    required this.ipfsCid,
    required this.documentType,
    required this.issuingAgency,
    this.issuingInstitutionId,
    required this.status,
    required this.uploadedAt,
    this.verifiedAt,
    this.expiresAt,
    this.transactionHash,
    this.verifierId,
    this.verifierInstitutionId,
    this.rejectionReason,
    this.metadata,
    this.sharedWithInstitutions = const [],
  });

  /// Thesis Section 3.6.4: Verification check via hash comparison
  bool get isAuthentic => status == DocumentStatus.verified;

  /// Check if document has expired
  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'fileName': fileName,
      'fileHash': fileHash,
      'ipfsCid': ipfsCid,
      'documentType': documentType.name,
      'issuingAgency': issuingAgency.name,
      'issuingInstitutionId': issuingInstitutionId,
      'status': status.name,
      'uploadedAt': uploadedAt.toIso8601String(),
      'verifiedAt': verifiedAt?.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'transactionHash': transactionHash,
      'verifierId': verifierId,
      'verifierInstitutionId': verifierInstitutionId,
      'rejectionReason': rejectionReason,
      'metadata': metadata,
      'sharedWithInstitutions': sharedWithInstitutions,
    };
  }

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      fileName: json['fileName'] as String,
      fileHash: json['fileHash'] as String,
      ipfsCid: (json['ipfsCid'] ?? json['ipfsHash']) as String,
      documentType: DocumentType.values.firstWhere(
        (e) => e.name == json['documentType'],
        orElse: () => DocumentType.other,
      ),
      issuingAgency: GovernmentAgency.values.firstWhere(
        (e) => e.name == json['issuingAgency'],
        orElse: () => GovernmentAgency.other,
      ),
      issuingInstitutionId: json['issuingInstitutionId'] as String?,
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DocumentStatus.pending,
      ),
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      transactionHash: json['transactionHash'] as String?,
      verifierId: json['verifierId'] as String?,
      verifierInstitutionId: json['verifierInstitutionId'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      sharedWithInstitutions:
          (json['sharedWithInstitutions'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
    );
  }

  DocumentModel copyWith({
    String? id,
    String? userId,
    String? fileName,
    String? fileHash,
    String? ipfsCid,
    DocumentType? documentType,
    GovernmentAgency? issuingAgency,
    String? issuingInstitutionId,
    DocumentStatus? status,
    DateTime? uploadedAt,
    DateTime? verifiedAt,
    DateTime? expiresAt,
    String? transactionHash,
    String? verifierId,
    String? verifierInstitutionId,
    String? rejectionReason,
    Map<String, dynamic>? metadata,
    List<String>? sharedWithInstitutions,
  }) {
    return DocumentModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fileName: fileName ?? this.fileName,
      fileHash: fileHash ?? this.fileHash,
      ipfsCid: ipfsCid ?? this.ipfsCid,
      documentType: documentType ?? this.documentType,
      issuingAgency: issuingAgency ?? this.issuingAgency,
      issuingInstitutionId: issuingInstitutionId ?? this.issuingInstitutionId,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      transactionHash: transactionHash ?? this.transactionHash,
      verifierId: verifierId ?? this.verifierId,
      verifierInstitutionId:
          verifierInstitutionId ?? this.verifierInstitutionId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      metadata: metadata ?? this.metadata,
      sharedWithInstitutions:
          sharedWithInstitutions ?? this.sharedWithInstitutions,
    );
  }
}
