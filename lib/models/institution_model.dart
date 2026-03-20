/// Represents an institutional data source in the system
/// Maps to thesis Section 3.4.1 - Institutional Data Sources Layer
/// These are the national databases: NIA, DVLA, GRA, MOH, WAEC, RGD
class InstitutionModel {
  final String id;
  final String name;
  final String abbreviation;
  final InstitutionType type;
  final String? description;
  final String? walletAddress;
  final String? contactEmail;
  final String? contactPhone;
  final bool isVerified;
  final bool isActive;
  final DateTime registeredAt;
  final List<String> authorizedDocumentTypes;

  InstitutionModel({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.type,
    this.description,
    this.walletAddress,
    this.contactEmail,
    this.contactPhone,
    this.isVerified = false,
    this.isActive = true,
    required this.registeredAt,
    this.authorizedDocumentTypes = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'abbreviation': abbreviation,
      'type': type.name,
      'description': description,
      'walletAddress': walletAddress,
      'contactEmail': contactEmail,
      'contactPhone': contactPhone,
      'isVerified': isVerified,
      'isActive': isActive,
      'registeredAt': registeredAt.toIso8601String(),
      'authorizedDocumentTypes': authorizedDocumentTypes,
    };
  }

  factory InstitutionModel.fromJson(Map<String, dynamic> json) {
    return InstitutionModel(
      id: json['id'] as String,
      name: json['name'] as String,
      abbreviation: json['abbreviation'] as String,
      type: InstitutionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => InstitutionType.other,
      ),
      description: json['description'] as String?,
      walletAddress: json['walletAddress'] as String?,
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
      authorizedDocumentTypes:
          (json['authorizedDocumentTypes'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
    );
  }
}

/// Types of institutions as described in thesis Section 1.1 and 3.4.1
enum InstitutionType {
  governmentAgency,
  educationalInstitution,
  healthcareProvider,
  financialInstitution,
  legalEntity,
  corporateOrganization,
  regulatoryBody,
  other,
}

