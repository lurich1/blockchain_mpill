import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/institution_model.dart';

/// Institution state management
/// Manages the Institutional Data Sources Layer (thesis Section 3.4.1)
class InstitutionNotifier extends StateNotifier<List<InstitutionModel>> {
  InstitutionNotifier() : super([]);

  Future<void> loadInstitutions() async {
    // TODO: Load institutions from backend/blockchain
    state = [];
  }

  void addInstitution(InstitutionModel institution) {
    state = [...state, institution];
  }

  void updateInstitution(InstitutionModel institution) {
    state =
        state.map((i) => i.id == institution.id ? institution : i).toList();
  }

  void removeInstitution(String institutionId) {
    state = state.where((i) => i.id != institutionId).toList();
  }

  InstitutionModel? getById(String id) {
    try {
      return state.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  List<InstitutionModel> getByType(InstitutionType type) {
    return state.where((i) => i.type == type).toList();
  }
}

final institutionsProvider =
    StateNotifierProvider<InstitutionNotifier, List<InstitutionModel>>((ref) {
  return InstitutionNotifier();
});

