import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../models/profile.dart';
import '../repositories/profile_repository.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repo;

  Profile? profile;
  List<HrZone> zones = <HrZone>[];
  bool loading = false;
  bool saving = false;
  String? error;

  ProfileProvider(this._repo);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await _repo.getProfile();
      try {
        zones = await _repo.getZones();
      } catch (_) {
        zones = profile?.hrZones ?? <HrZone>[];
      }
    } catch (e) {
      error = apiErrorMessage(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(Profile updated) async {
    saving = true;
    error = null;
    notifyListeners();
    try {
      profile = await _repo.updateProfile(updated);
      try {
        zones = await _repo.getZones();
      } catch (_) {
        zones = profile?.hrZones ?? zones;
      }
      return true;
    } catch (e) {
      error = apiErrorMessage(e);
      return false;
    } finally {
      saving = false;
      notifyListeners();
    }
  }
}
