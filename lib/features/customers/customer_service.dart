import 'dart:convert';
import '../../core/network/api_client.dart';
import 'customer_model.dart';

class CustomerService {
  CustomerService(this.api);
  final ApiClient api;

  Future<List<CustomerModel>> list([String search = '']) async {
    final query = search.trim().isEmpty
        ? ''
        : '?search=${Uri.encodeQueryComponent(search.trim())}';
    return (await api.getList('/customers$query'))
        .map(CustomerModel.fromJson)
        .toList();
  }

  Future<CustomerModel> create(
      {required String name,
      required String phone,
      String? email,
      String? notes,
      List<String> tags = const []}) async {
    return CustomerModel.fromJson(await api.postMap('/customers', {
      'name': name.trim(),
      'phone': phone.trim(),
      if (email?.trim().isNotEmpty == true) 'email': email!.trim(),
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      'tags': tags,
    }));
  }

  Future<CustomerModel> update(String id,
      {required String name,
      required String phone,
      String? email,
      String? notes,
      List<String> tags = const []}) async {
    return CustomerModel.fromJson(await api.patchMap('/customers/$id', {
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email?.trim() ?? '',
      'notes': notes?.trim() ?? '',
      'tags': tags,
    }));
  }

  static List<String> parseTags(String value) => value
      .split(RegExp(r'[,،]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();

  static String encodeTags(List<String> tags) =>
      const JsonEncoder().convert(tags);
}
