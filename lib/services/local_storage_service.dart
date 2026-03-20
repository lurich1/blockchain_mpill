import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/document_model.dart';
import '../models/user_model.dart';
import '../models/audit_log_model.dart';
import '../models/blockchain_transaction_model.dart';

/// Local persistence service using SharedPreferences.
/// Keeps documents, user session, audit logs, and blockchain transactions
/// alive across logouts and app restarts.
class LocalStorageService {
  static const String _userKey = 'persisted_user';
  static const String _documentsKey = 'persisted_documents';
  static const String _auditLogsKey = 'persisted_audit_logs';
  static const String _transactionsKey = 'persisted_transactions';

  late final SharedPreferences _prefs;

  /// Must be called once before any other method (e.g. in main()).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ─── User Session ───────────────────────────────────────────

  /// Save the currently logged-in user so we can auto-login on next launch.
  Future<void> saveUser(UserModel user) async {
    final json = jsonEncode(user.toJson());
    await _prefs.setString(_userKey, json);
  }

  /// Load the persisted user (null if not logged in).
  UserModel? loadUser() {
    final raw = _prefs.getString(_userKey);
    if (raw == null) return null;
    try {
      return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Clear the saved user (on logout).
  Future<void> clearUser() async {
    await _prefs.remove(_userKey);
  }

  // ─── Documents ──────────────────────────────────────────────

  /// Persist the full document list.
  Future<void> saveDocuments(List<DocumentModel> documents) async {
    final list = documents.map((d) => d.toJson()).toList();
    await _prefs.setString(_documentsKey, jsonEncode(list));
  }

  /// Load persisted documents.
  List<DocumentModel> loadDocuments() {
    final raw = _prefs.getString(_documentsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => DocumentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear persisted documents.
  Future<void> clearDocuments() async {
    await _prefs.remove(_documentsKey);
  }

  // ─── Audit Logs ─────────────────────────────────────────────

  /// Persist the audit log list.
  Future<void> saveAuditLogs(List<AuditLogModel> logs) async {
    final list = logs.map((l) => l.toJson()).toList();
    await _prefs.setString(_auditLogsKey, jsonEncode(list));
  }

  /// Load persisted audit logs.
  List<AuditLogModel> loadAuditLogs() {
    final raw = _prefs.getString(_auditLogsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => AuditLogModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear persisted audit logs.
  Future<void> clearAuditLogs() async {
    await _prefs.remove(_auditLogsKey);
  }

  // ─── Blockchain Transactions ────────────────────────────────

  /// Persist the blockchain transaction list.
  Future<void> saveTransactions(List<BlockchainTransaction> txns) async {
    final list = txns.map((t) => t.toJson()).toList();
    await _prefs.setString(_transactionsKey, jsonEncode(list));
  }

  /// Load persisted blockchain transactions.
  List<BlockchainTransaction> loadTransactions() {
    final raw = _prefs.getString(_transactionsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) =>
              BlockchainTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clear persisted transactions.
  Future<void> clearTransactions() async {
    await _prefs.remove(_transactionsKey);
  }

  // ─── Registered Users ──────────────────────────────────────

  static const String _registeredUsersKey = 'registered_users';

  /// Save a newly registered user to the registry.
  Future<void> registerUser(UserModel user) async {
    final users = loadRegisteredUsers();
    // Replace if email already exists, else add
    users.removeWhere((u) => u.email.toLowerCase() == user.email.toLowerCase());
    users.add(user);
    final list = users.map((u) => u.toJson()).toList();
    await _prefs.setString(_registeredUsersKey, jsonEncode(list));
  }

  /// Load all registered users.
  List<UserModel> loadRegisteredUsers() {
    final raw = _prefs.getString(_registeredUsersKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => UserModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Find a registered user by email (case-insensitive).
  UserModel? findUserByEmail(String email) {
    final users = loadRegisteredUsers();
    try {
      return users.firstWhere(
        (u) => u.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Seed default demo accounts if none exist yet.
  Future<void> seedDemoAccounts() async {
    final existing = loadRegisteredUsers();
    if (existing.isNotEmpty) return; // Already seeded

    final now = DateTime.now();
    final demoUsers = [
      UserModel(
        id: 'demo_admin_1',
        email: 'admin@gov.gh',
        name: 'System Admin',
        role: UserRole.systemAdmin,
        organization: 'Ghana eGov Authority',
        sector: InstitutionalSector.government,
        institutionId: null, // sees all agencies
        createdAt: now,
        isVerified: true,
      ),
      UserModel(
        id: 'demo_nia_1',
        email: 'officer@nia.gov.gh',
        name: 'NIA Officer',
        role: UserRole.issuingInstitution,
        organization: 'National Identification Authority',
        sector: InstitutionalSector.government,
        institutionId: 'nia',
        createdAt: now,
        isVerified: true,
      ),
      UserModel(
        id: 'demo_gra_1',
        email: 'officer@gra.gov.gh',
        name: 'GRA Officer',
        role: UserRole.issuingInstitution,
        organization: 'Ghana Revenue Authority',
        sector: InstitutionalSector.government,
        institutionId: 'gra',
        createdAt: now,
        isVerified: true,
      ),
      UserModel(
        id: 'demo_dvla_1',
        email: 'officer@dvla.gov.gh',
        name: 'DVLA Officer',
        role: UserRole.issuingInstitution,
        organization: 'Driver and Vehicle Licensing Authority',
        sector: InstitutionalSector.government,
        institutionId: 'dvla',
        createdAt: now,
        isVerified: true,
      ),
      UserModel(
        id: 'demo_verifier_1',
        email: 'verifier@gcb.com.gh',
        name: 'Bank Verifier',
        role: UserRole.verifyingInstitution,
        organization: 'Ghana Commercial Bank',
        sector: InstitutionalSector.financial,
        institutionId: 'gcb',
        createdAt: now,
        isVerified: true,
      ),
      UserModel(
        id: 'demo_user_1',
        email: 'user@gmail.com',
        name: 'Kofi Mensah',
        role: UserRole.generalUser,
        createdAt: now,
        isVerified: true,
      ),
    ];

    for (final user in demoUsers) {
      await registerUser(user);
    }
  }

  // ─── Clear All ──────────────────────────────────────────────

  /// Wipe everything (factory reset).
  Future<void> clearAll() async {
    // Preserve registered users across logouts
    final registeredUsersJson = _prefs.getString(_registeredUsersKey);
    await _prefs.clear();
    if (registeredUsersJson != null) {
      await _prefs.setString(_registeredUsersKey, registeredUsersJson);
    }
  }
}

