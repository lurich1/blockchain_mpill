/// User roles as defined in the thesis (Section 3.6.5):
/// - System Administrator: Full system control, manage verifiers/institutions
/// - Issuing Institution: Upload and register documents (NIA, DVLA, GRA, etc.)
/// - Verifying Institution: Verify document authenticity
/// - General User: View, request verification, access shared documents
enum UserRole {
  systemAdmin,
  issuingInstitution,
  verifyingInstitution,
  generalUser,
}

/// Institutional sector affiliations (thesis Section 3.4.1)
enum InstitutionalSector {
  government,
  education,
  healthcare,
  corporate,
  legal,
  financial,
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final InstitutionalSector? sector;
  final String? organization;
  final String? institutionId;
  final String? phoneNumber;
  final String? walletAddress;
  final DateTime createdAt;
  final bool isVerified;
  final bool isActive;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.sector,
    this.organization,
    this.institutionId,
    this.phoneNumber,
    this.walletAddress,
    required this.createdAt,
    this.isVerified = false,
    this.isActive = true,
  });

  /// Check permission helpers based on thesis role-based access control
  /// All authenticated users can upload documents for verification;
  /// issuing institutions upload on behalf of agencies, general users
  /// submit personal documents (thesis Section 3.6.3).
  bool get canUploadDocuments =>
      role == UserRole.systemAdmin ||
      role == UserRole.issuingInstitution ||
      role == UserRole.generalUser;

  bool get canVerifyDocuments =>
      role == UserRole.systemAdmin || role == UserRole.verifyingInstitution;

  bool get canManageUsers => role == UserRole.systemAdmin;

  bool get canManageInstitutions => role == UserRole.systemAdmin;

  bool get canViewAuditTrail =>
      role == UserRole.systemAdmin ||
      role == UserRole.verifyingInstitution ||
      role == UserRole.issuingInstitution;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.name,
      'sector': sector?.name,
      'organization': organization,
      'institutionId': institutionId,
      'phoneNumber': phoneNumber,
      'walletAddress': walletAddress,
      'createdAt': createdAt.toIso8601String(),
      'isVerified': isVerified,
      'isActive': isActive,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.generalUser,
      ),
      sector: json['sector'] != null
          ? InstitutionalSector.values.firstWhere(
              (e) => e.name == json['sector'],
              orElse: () => InstitutionalSector.corporate,
            )
          : null,
      organization: json['organization'] as String?,
      institutionId: json['institutionId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      walletAddress: json['walletAddress'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    InstitutionalSector? sector,
    String? organization,
    String? institutionId,
    String? phoneNumber,
    String? walletAddress,
    DateTime? createdAt,
    bool? isVerified,
    bool? isActive,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      sector: sector ?? this.sector,
      organization: organization ?? this.organization,
      institutionId: institutionId ?? this.institutionId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      walletAddress: walletAddress ?? this.walletAddress,
      createdAt: createdAt ?? this.createdAt,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
    );
  }
}
