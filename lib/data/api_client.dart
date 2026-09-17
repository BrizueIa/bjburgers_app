import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'device_store.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class BjApiClient {
  BjApiClient(this._store, {http.Client? client})
    : _client = client ?? http.Client();
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bj-40-233-29-16.sslip.io/api/v1',
  );
  final DeviceStore _store;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: query);

  Future<Map<String, String>> _headers({bool protected = true}) async {
    final headers = <String, String>{
      'content-type': 'application/json',
      'accept': 'application/json',
    };
    if (protected) {
      final credential = await _store.credential();
      if (credential == null) {
        throw const ApiException('Este dispositivo aún no está vinculado.');
      }
      headers['authorization'] = 'Bearer $credential';
    }
    return headers;
  }

  Future<Map<String, dynamic>> _decode(http.Response response) async {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (!response.statusCode.isSuccessful) {
      final message = body['message'];
      throw ApiException(
        message is String ? message : 'No fue posible completar la operación.',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Future<void> activateDevice({
    required String deviceId,
    required String pairingCode,
  }) async {
    final response = await _client.post(
      _uri('/operator/devices/activate'),
      headers: await _headers(protected: false),
      body: jsonEncode({
        'deviceId': deviceId.trim(),
        'pairingCode': pairingCode.trim(),
      }),
    );
    final body = await _decode(response);
    final device = body['device'] as Map<String, dynamic>;
    await _store.save(
      credential: body['credential'] as String,
      deviceName: device['name'] as String,
    );
  }

  Future<CatalogData> catalog() async {
    final response = await _client.get(
      _uri('/catalog'),
      headers: await _headers(protected: false),
    );
    return CatalogData.fromJson(await _decode(response));
  }

  Future<List<Order>> orders({String? status}) async {
    final response = await _client.get(
      _uri('/operator/orders', status == null ? null : {'status': status}),
      headers: await _headers(),
    );
    final body = await _decode(response);
    return (body['orders'] as List<dynamic>)
        .map((item) => Order.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Order> order(String id) async {
    final response = await _client.get(
      _uri('/operator/orders/$id'),
      headers: await _headers(),
    );
    return Order.fromJson(
      (await _decode(response))['order'] as Map<String, dynamic>,
    );
  }

  Future<OrderDraft> parseDraft(String rawMessage) async {
    final response = await _client.post(
      _uri('/operator/order-drafts/parse'),
      headers: await _headers(),
      body: jsonEncode({'rawMessage': rawMessage}),
    );
    return OrderDraft.fromJson(await _decode(response));
  }

  Future<Order> createOrder(OrderDraft draft) async {
    final response = await _client.post(
      _uri('/operator/orders'),
      headers: await _headers(),
      body: jsonEncode({
        'rawMessage': draft.rawMessage,
        'customerName': draft.customerName,
        'neighborhood': draft.neighborhood,
        'streetAndNumber': draft.streetAndNumber,
        'references': draft.references,
        'deliveryNotes': draft.deliveryNotes,
        'items': draft.items.map((item) => item.toJson()).toList(),
        'idempotencyKey': _uuid.v4(),
      }),
    );
    return Order.fromJson(
      (await _decode(response))['order'] as Map<String, dynamic>,
    );
  }

  Future<Order> updateStatus(
    String id,
    String status, {
    String note = '',
  }) async {
    final response = await _client.patch(
      _uri('/operator/orders/$id/status'),
      headers: await _headers(),
      body: jsonEncode({'status': status, 'note': note}),
    );
    return Order.fromJson(
      (await _decode(response))['order'] as Map<String, dynamic>,
    );
  }

  Future<({String code, DateTime? expiresAt, bool reused})> issueSpinCode(
    String id,
  ) async {
    final response = await _client.post(
      _uri('/operator/orders/$id/spin-code'),
      headers: await _headers(),
      body: jsonEncode({'idempotencyKey': _uuid.v4()}),
    );
    final body = await _decode(response);
    return (
      code: body['code'] as String,
      expiresAt: body['expiresAt'] == null
          ? null
          : DateTime.parse(body['expiresAt'] as String),
      reused: body['reused'] as bool,
    );
  }

  Stream<void> orderEvents() async* {
    final request = http.Request('GET', _uri('/operator/orders/stream'));
    request.headers.addAll(await _headers());
    final response = await _client.send(request);
    if (!response.statusCode.isSuccessful) {
      throw const ApiException('No se pudo conectar a actualizaciones.');
    }
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.startsWith('event: order')) yield null;
    }
  }
}

extension on int {
  bool get isSuccessful => this >= 200 && this < 300;
}
