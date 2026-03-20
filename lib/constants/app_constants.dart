/// Application-wide constants aligned with the thesis:
/// "A Blockchain-Based Framework for Secure and Unified Document
/// Verification and Access"
class AppConstants {
  // ─── Blockchain Configuration (Thesis Section 3.4.2) ───
  static const String defaultEthRpcUrl =
      'https://sepolia.infura.io/v3/YOUR_PROJECT_ID';
  static const String defaultSmartContractAddress =
      '0x0000000000000000000000000000000000000000';
  static const int chainId = 11155111; // Sepolia testnet

  // ─── IPFS Configuration (Thesis Section 3.4.4 & 3.7) ───
  // Using Pinata as IPFS pinning service (Infura IPFS was discontinued Aug 2023)
  // Sign up free at https://app.pinata.cloud to get your JWT token.
  static const String ipfsGateway = 'https://gateway.pinata.cloud/ipfs/';
  static const String ipfsApiUrl = 'https://api.pinata.cloud';

  static const String pinataJwt =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VySW5mb3JtYXRpb24iOnsiaWQiOiJiNzdhNzNiOS03YjU4LTRjMWQtYWY5MC1iNzMzNmY2ZGJhMzAiLCJlbWFpbCI6ImRldkB0ZWNocmV0YWluZXIuY29tIiwiZW1haWxfdmVyaWZpZWQiOnRydWUsInBpbl9wb2xpY3kiOnsicmVnaW9ucyI6W3siZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiRlJBMSJ9LHsiZGVzaXJlZFJlcGxpY2F0aW9uQ291bnQiOjEsImlkIjoiTllDMSJ9XSwidmVyc2lvbiI6MX0sIm1mYV9lbmFibGVkIjpmYWxzZSwic3RhdHVzIjoiQUNUSVZFIn0sImF1dGhlbnRpY2F0aW9uVHlwZSI6InNjb3BlZEtleSIsInNjb3BlZEtleUtleSI6ImE1YTFlNGM0NjkzODRlN2UxMGIyIiwic2NvcGVkS2V5U2VjcmV0IjoiZmIyNWM4NjUwYmQyNjMyMmIxNTdmN2ZkMWU4ODFjNDQyYzVlMmJlOGIzODc1YTU0MjNjNzFlNjNiOGUxYTk1MCIsImV4cCI6MTgwMjY5NjAyMn0.bymwn48-8q9n93OTaxy-o5Qou7QT0CxZXOUbUxPIopQ';
  static const String pinataApiKey = 'a5a1e4c469384e7e10b2';
  static const String pinataApiSecret =
      'fb25c8650bd26322b157f7fd1e881c442c5e2be8b3875a5423c71e63b8e1a950';

  /// Whether to use demo mode (no real IPFS upload)
  /// Automatically true when Pinata JWT is empty
  static bool get isDemoMode => pinataJwt.isEmpty;

  // ─── App Configuration ───
  static const String appName = 'Ghana Document Verification';
  static const String appDescription =
      'A Blockchain-Based Framework for Secure and Unified Document Verification and Access';
  static const String appVersion = '1.0.0';

  // ─── File Upload ───
  static const int maxFileSize = 10 * 1024 * 1024; // 10MB
  static const List<String> allowedFileTypes = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'doc',
    'docx',
  ];

  // ─── Government Agencies (Thesis Section 1.1) ───
  // "NIA, DVLA, GRA, MOH, WAEC, RGD" operate independently
  static const Map<String, String> governmentAgencies = {
    'nia': 'National Identification Authority',
    'dvla': 'Driver and Vehicle Licensing Authority',
    'gra': 'Ghana Revenue Authority',
    'moh': 'Ministry of Health',
    'waec': 'West African Examinations Council',
    'rgd': 'Registrar General\'s Department',
    'ssnit': 'Social Security and National Insurance Trust',
  };

  // ─── Document Types (Thesis Section 1.5) ───
  static const Map<String, String> documentTypes = {
    'nationalId': 'National ID Card (Ghana Card)',
    'driverLicense': 'Driver\'s License',
    'birthCertificate': 'Birth Certificate',
    'educationalCertificate': 'Educational Certificate',
    'taxDocument': 'Tax Document',
    'businessRegistration': 'Business Registration',
    'medicalRecord': 'Medical Record',
    'propertyRecord': 'Property Record',
    'other': 'Other',
  };

  // ─── User Role Display Names (Thesis Section 3.6.5) ───
  static const Map<String, String> userRoleNames = {
    'systemAdmin': 'System Administrator',
    'issuingInstitution': 'Issuing Institution',
    'verifyingInstitution': 'Verifying Institution',
    'generalUser': 'General User',
  };

  // ─── Institutional Sectors (Thesis Section 2.3) ───
  static const Map<String, String> institutionalSectors = {
    'government': 'Government & Public Administration',
    'education': 'Education',
    'healthcare': 'Healthcare',
    'corporate': 'Corporate & Business',
    'legal': 'Legal Services',
    'financial': 'Banking & Financial Services',
  };

  // ─── Storage Keys ───
  static const String userStorageKey = 'current_user';
  static const String walletPrivateKeyKey = 'wallet_private_key';
  static const String isLoggedInKey = 'is_logged_in';
  static const String institutionStorageKey = 'current_institution';
}
