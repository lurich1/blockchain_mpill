import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/document_model.dart';
import '../services/document_service.dart';
import '../services/blockchain_service.dart';
import '../services/ipfs_service.dart';
import '../services/audit_service.dart';
import '../services/local_storage_service.dart';

/// ─── Singleton providers for services ────────────────────────

final localStorageServiceProvider = Provider<LocalStorageService>((ref) {
  return LocalStorageService();
});

final auditServiceProvider = Provider<AuditService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final service = AuditService();
  // Restore persisted audit logs
  final saved = storage.loadAuditLogs();
  service.restoreLogs(saved);
  // Auto-persist whenever a new log is added
  service.onLogsChanged = (logs) => storage.saveAuditLogs(logs);
  return service;
});

final blockchainServiceProvider = Provider<BlockchainService>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  final service = BlockchainService();
  // Restore persisted transactions
  final saved = storage.loadTransactions();
  service.restoreTransactions(saved);
  // Auto-persist whenever a new transaction is recorded
  service.onTransactionsChanged = (txns) => storage.saveTransactions(txns);
  return service;
});

final ipfsServiceProvider = Provider<IPFSService>((ref) {
  return IPFSService();
});

final documentServiceProvider = Provider<DocumentService>((ref) {
  return DocumentService(
    blockchainService: ref.watch(blockchainServiceProvider),
    ipfsService: ref.watch(ipfsServiceProvider),
    auditService: ref.watch(auditServiceProvider),
  );
});

/// ─── Documents state ─────────────────────────────────────────

final documentsProvider =
    StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>((ref) {
  final docService = ref.watch(documentServiceProvider);
  final storage = ref.watch(localStorageServiceProvider);
  return DocumentsNotifier(docService, storage);
});

/// Manages the list of documents with CRUD operations.
/// Automatically persists every change to local storage so data
/// survives logout / app restart.
class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  final DocumentService documentService;
  final LocalStorageService _storage;

  DocumentsNotifier(this.documentService, this._storage) : super([]) {
    _loadFromStorage();
  }

  /// Hydrate state from local storage on creation.
  void _loadFromStorage() {
    final saved = _storage.loadDocuments();
    if (saved.isNotEmpty) {
      state = saved;
    }
  }

  /// Persist the current state to disk.
  Future<void> _persist() async {
    await _storage.saveDocuments(state);
  }

  Future<void> loadDocuments() async {
    _loadFromStorage();
  }

  Future<void> addDocument(DocumentModel document) async {
    state = [...state, document];
    await _persist();
  }

  Future<void> updateDocument(DocumentModel document) async {
    state = state.map((d) => d.id == document.id ? document : d).toList();
    await _persist();
  }

  Future<void> deleteDocument(String documentId) async {
    state = state.where((d) => d.id != documentId).toList();
    await _persist();
  }

  /// Get documents by status
  List<DocumentModel> getByStatus(DocumentStatus status) {
    return state.where((d) => d.status == status).toList();
  }

  /// Get documents by agency
  List<DocumentModel> getByAgency(GovernmentAgency agency) {
    return state.where((d) => d.issuingAgency == agency).toList();
  }

  /// Get verified document count
  int get verifiedCount =>
      state.where((d) => d.status == DocumentStatus.verified).length;

  /// Get pending document count
  int get pendingCount =>
      state.where((d) => d.status == DocumentStatus.pending).length;
}
