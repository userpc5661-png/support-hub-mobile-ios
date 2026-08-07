import '../../core/network/api_client.dart';
import 'employee_model.dart';

class EmployeeService {
  EmployeeService(this.api);
  final ApiClient api;

  Future<List<EmployeeModel>> list() async =>
      (await api.getList('/employees')).map(EmployeeModel.fromJson).toList();

  Future<EmployeeModel> create({
    required String name,
    required String username,
    String? email,
    required String password,
    required String role,
    required List<String> permissions,
  }) async =>
      EmployeeModel.fromJson(await api.postMap('/employees', {
        'name': name.trim(),
        'username': username.trim().toLowerCase(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        'password': password,
        'role': role,
        'permissions': permissions,
      }));

  Future<EmployeeModel> update({
    required String id,
    required String name,
    required String username,
    String? email,
    required String role,
    required List<String> permissions,
  }) async =>
      EmployeeModel.fromJson(await api.patchMap('/employees/$id', {
        'name': name.trim(),
        'username': username.trim().toLowerCase(),
        'email': email?.trim() ?? '',
        'role': role,
        'permissions': permissions,
      }));

  Future<EmployeeModel> setStatus(String id, bool active) async =>
      EmployeeModel.fromJson(
        await api.patchMap('/employees/$id/status',
            {'status': active ? 'active' : 'suspended'}),
      );

  Future<void> resetPassword(String id, String password) async {
    await api.postMap('/employees/$id/reset-password', {'password': password});
  }
}
