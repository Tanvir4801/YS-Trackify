import '../../models/labour_model.dart';

/// Helpers for contractor-scoped data isolation.
class ContractorUtils {
  /// Returns true if this labour belongs to the current supervisor.
  static bool labourBelongsToSupervisor(
      Labour labour, String uid, String contractorId) {
    return labour.supervisorId == uid ||
        labour.contractorId == uid ||
        (contractorId.isNotEmpty && labour.contractorId == contractorId);
  }

  /// Filter a list of labours for the current supervisor only.
  static List<Labour> filterForSupervisor(
      List<Labour> all, String uid, String contractorId) {
    return all
        .where((l) => l.isActive && labourBelongsToSupervisor(l, uid, contractorId))
        .toList();
  }
}
