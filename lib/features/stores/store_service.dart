import '../../core/network/api_client.dart';
import 'store_model.dart';

class StoreService {
  StoreService(this.api);
  final ApiClient api;

  Future<List<StoreModel>> listStores() async =>
      (await api.getList('/stores')).map(StoreModel.fromJson).toList();

  Future<StoreModel> createStore({
    required String name,
    required String ownerName,
    required String ownerUsername,
    required String ownerPassword,
    String? ownerEmail,
    String? slug,
    String? email,
    String? phone,
  }) async {
    final response = await api.postMap('/stores', {
      'name': name.trim(),
      if (slug != null && slug.trim().isNotEmpty) 'slug': slug.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      'ownerName': ownerName.trim(),
      'ownerUsername': ownerUsername.trim().toLowerCase(),
      if (ownerEmail != null && ownerEmail.trim().isNotEmpty)
        'ownerEmail': ownerEmail.trim(),
      'ownerPassword': ownerPassword,
    });
    return StoreModel.fromJson(response['store'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> deleteStore(String id, String confirmation) =>
      api.deleteMap('/stores/$id', {'confirmation': confirmation});
  Future<Map<String, dynamic>> resetOwnerPassword(String id, String password) =>
      api.postMap('/stores/$id/reset-owner-password', {'password': password});
  Future<StoreModel> setStatus(String id, bool isActive) async =>
      StoreModel.fromJson(
          await api.patchMap('/stores/$id/status', {'isActive': isActive}));
  Future<StoreModel> getMine() async =>
      StoreModel.fromJson(await api.getMap('/stores/me'));
  Future<StoreModel> updateMine(
          {required String name, String? email, String? phone}) async =>
      StoreModel.fromJson(await api.patchMap('/stores/me', {
        'name': name.trim(),
        'email': email?.trim() ?? '',
        'phone': phone?.trim() ?? '',
      }));
}
