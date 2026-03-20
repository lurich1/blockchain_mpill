import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../services/local_storage_service.dart';
import 'document_provider.dart'; // for localStorageServiceProvider

/// Authentication state management.
/// Persists user session to local storage so the app can auto-login
/// on next launch and documents don't disappear on logout.
class AuthNotifier extends StateNotifier<UserModel?> {
  final LocalStorageService _storage;

  AuthNotifier(this._storage) : super(null) {
    _restoreSession();
  }

  /// Try to restore a previously saved session on startup.
  void _restoreSession() {
    final saved = _storage.loadUser();
    if (saved != null) {
      state = saved;
    }
  }

  void login(UserModel user) {
    state = user;
    _storage.saveUser(user);
  }

  void logout() {
    state = null;
    _storage.clearUser(); // only clear user session, NOT documents
  }

  void updateUser(UserModel user) {
    state = user;
    _storage.saveUser(user);
  }

  bool get isAuthenticated => state != null;

  /// Role-based permission checks (thesis Section 3.6.5)
  bool get canUploadDocuments => state?.canUploadDocuments ?? false;
  bool get canVerifyDocuments => state?.canVerifyDocuments ?? false;
  bool get canManageUsers => state?.canManageUsers ?? false;
  bool get canManageInstitutions => state?.canManageInstitutions ?? false;
  bool get canViewAuditTrail => state?.canViewAuditTrail ?? false;
}

final authProvider = StateNotifierProvider<AuthNotifier, UserModel?>((ref) {
  final storage = ref.watch(localStorageServiceProvider);
  return AuthNotifier(storage);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(authProvider);
  return user != null;
});

final userRoleProvider = Provider<UserRole?>((ref) {
  final user = ref.watch(authProvider);
  return user?.role;
});
