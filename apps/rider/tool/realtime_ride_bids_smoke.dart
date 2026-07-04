import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

final _runId = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
final _marker = 'codex_smoke_ride_bids_$_runId';

Future<void> main(List<String> args) async {
  final envPath = args.isNotEmpty ? args.first : '.env.scale.staging';
  final env = await _loadEnv(envPath);
  final url = _required(env, 'SUPABASE_URL');
  final serviceKey =
      env['SUPABASE_SERVICE_KEY'] ?? env['SUPABASE_SERVICE_ROLE_KEY'];
  if (serviceKey == null || serviceKey.trim().isEmpty) {
    throw StateError(
        'SUPABASE_SERVICE_KEY is required for synthetic staging smoke data.');
  }

  final rest = _RestClient(url: url, serviceKey: serviceKey);
  final supabase = SupabaseClient(url, serviceKey);
  final createdAuthUserIds = <String>[];
  final createdDriverIds = <String>[];
  String? riderIdentityId;
  String? rideRequestId;
  final events = <Map<String, dynamic>>[];

  RealtimeChannel? channel;

  try {
    final riderEmail = 'codex+rider+$_runId@heycaby.invalid';
    riderIdentityId = await rest.insertOne(
      'rider_identities',
      {
        'email': riderEmail,
        'booking_name': 'Codex Smoke Rider',
      },
    );

    final drivers = <String>[];
    for (var i = 1; i <= 4; i++) {
      final userId =
          await rest.createAuthUser('codex+driver+$i+$_runId@heycaby.invalid');
      createdAuthUserIds.add(userId);
      final driverId = await rest.insertOne(
        'drivers',
        {
          'user_id': userId,
          'full_name': 'Codex Smoke Driver $i',
          'vehicle_make': 'Smoke',
          'vehicle_model': 'Taxi',
          'vehicle_plate': 'SMK-$i',
          'profile_status': 'verified',
          'subscription_active': true,
          'status': 'available',
          'compliance_status': 'compliant',
        },
      );
      createdDriverIds.add(driverId);
      drivers.add(driverId);
    }

    rideRequestId = await rest.insertOne(
      'ride_requests',
      {
        'pickup_address': 'Codex Smoke Pickup',
        'destination_address': 'Codex Smoke Destination',
        'status': 'bidding',
        'booking_mode': 'marketplace',
        'marketplace_offered_fare': 42,
        'rider_identity_id': riderIdentityId,
        'rider_token': _marker,
        'is_market': true,
      },
    );

    final ready = Completer<void>();
    channel = supabase
        .channel('$_marker:ride_bids')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideRequestId,
          ),
          callback: (payload) {
            events.add({
              'event': payload.eventType.name,
              'id': payload.newRecord['id'] ?? payload.oldRecord['id'],
              'status': payload.newRecord['status'],
              'bid_amount': payload.newRecord['bid_amount'],
              'driver_id': payload.newRecord['driver_id'],
            });
          },
        )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed && !ready.isCompleted) {
        ready.complete();
      }
      if (status == RealtimeSubscribeStatus.channelError &&
          !ready.isCompleted) {
        ready.completeError(error ?? 'channel_error');
      }
      if (status == RealtimeSubscribeStatus.timedOut && !ready.isCompleted) {
        ready.completeError('realtime_subscribe_timeout');
      }
    });

    await ready.future.timeout(const Duration(seconds: 15));

    final bid1 = await rest.insertOne(
      'ride_bids',
      {
        'ride_request_id': rideRequestId,
        'driver_id': drivers[0],
        'bid_amount': 40,
        'eta_minutes': 7,
        'message': '$_marker initial offer',
        'driver_snapshot': {'name': 'Codex Smoke Driver 1'},
      },
    );
    await _waitFor(events, (e) => e['event'] == 'insert' && e['id'] == bid1,
        'insert bid1');

    await rest.patch(
      'ride_bids',
      {'bid_amount': 38, 'message': '$_marker updated offer'},
      {'id': 'eq.$bid1'},
    );
    await _waitFor(
        events,
        (e) =>
            e['event'] == 'update' &&
            e['id'] == bid1 &&
            (e['bid_amount'] as num?)?.toDouble() == 38.0,
        'update bid1');

    await rest.patch(
      'ride_bids',
      {'status': 'withdrawn'},
      {'id': 'eq.$bid1'},
    );
    await _waitFor(
        events,
        (e) =>
            e['event'] == 'update' &&
            e['id'] == bid1 &&
            e['status'] == 'withdrawn',
        'withdraw bid1');

    final beforeMulti = events.length;
    await Future.wait([
      for (var i = 1; i <= 3; i++)
        rest.insertOne(
          'ride_bids',
          {
            'ride_request_id': rideRequestId,
            'driver_id': drivers[i],
            'bid_amount': 39 + i,
            'eta_minutes': 5 + i,
            'message': '$_marker simultaneous offer $i',
            'driver_snapshot': {'name': 'Codex Smoke Driver ${i + 1}'},
          },
        ),
    ]);
    await _waitFor(
      events,
      (_) =>
          events
              .skip(beforeMulti)
              .where((e) => e['event'] == 'insert')
              .length >=
          3,
      'three simultaneous inserts',
      timeout: const Duration(seconds: 12),
    );

    final snapshot = await rest.select(
      'ride_bids',
      {
        'ride_request_id': 'eq.$rideRequestId',
        'select': 'id,status,bid_amount',
      },
    );

    final reconnectEvents = <Map<String, dynamic>>[];
    final reconnected = Completer<void>();
    final reconnectChannel = supabase
        .channel('$_marker:ride_bids_reconnect')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ride_bids',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'ride_request_id',
            value: rideRequestId,
          ),
          callback: (payload) {
            reconnectEvents.add({
              'event': payload.eventType.name,
              'id': payload.newRecord['id'] ?? payload.oldRecord['id'],
              'status': payload.newRecord['status'],
              'bid_amount': payload.newRecord['bid_amount'],
            });
          },
        )
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed &&
          !reconnected.isCompleted) {
        reconnected.complete();
      }
      if (status == RealtimeSubscribeStatus.channelError &&
          !reconnected.isCompleted) {
        reconnected.completeError(error ?? 'reconnect_channel_error');
      }
      if (status == RealtimeSubscribeStatus.timedOut &&
          !reconnected.isCompleted) {
        reconnected.completeError('reconnect_timeout');
      }
    });
    await reconnected.future.timeout(const Duration(seconds: 15));
    await rest.patch(
      'ride_bids',
      {'bid_amount': 37},
      {'id': 'eq.$bid1'},
    );
    await _waitFor(
      reconnectEvents,
      (e) =>
          e['event'] == 'update' &&
          e['id'] == bid1 &&
          (e['bid_amount'] as num?)?.toDouble() == 37.0,
      'reconnect update bid1',
    );
    await reconnectChannel.unsubscribe();
    await channel.unsubscribe();

    stdout.writeln(jsonEncode({
      'ok': true,
      'marker': _marker,
      'events_seen': events.length,
      'events': events,
      'current_snapshot_count': snapshot.length,
      'current_snapshot': snapshot,
      'reconnect_events_seen': reconnectEvents.length,
      'reconnect_events': reconnectEvents,
    }));
  } finally {
    try {
      await channel?.unsubscribe();
    } catch (_) {}
    await _cleanup(
      rest: rest,
      rideRequestId: rideRequestId,
      riderIdentityId: riderIdentityId,
      driverIds: createdDriverIds,
      authUserIds: createdAuthUserIds,
    );
  }
}

Future<Map<String, String>> _loadEnv(String path) async {
  final file = File(path);
  if (!file.existsSync()) throw StateError('Env file not found: $path');
  final out = <String, String>{};
  for (final raw in await file.readAsLines()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final idx = line.indexOf('=');
    final key = line.substring(0, idx).trim();
    var value = line.substring(idx + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    out[key] = value;
  }
  return out;
}

String _required(Map<String, String> env, String key) {
  final value = env[key];
  if (value == null || value.trim().isEmpty) {
    throw StateError('$key is required');
  }
  return value.trim();
}

Future<void> _waitFor(
  List<Map<String, dynamic>> events,
  bool Function(Map<String, dynamic>) match,
  String label, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (events.any(match)) return;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }
  throw TimeoutException(
    'Timed out waiting for realtime event: $label; events=${jsonEncode(events)}',
  );
}

Future<void> _cleanup({
  required _RestClient rest,
  required String? rideRequestId,
  required String? riderIdentityId,
  required List<String> driverIds,
  required List<String> authUserIds,
}) async {
  if (rideRequestId != null) {
    await rest.delete('ride_bids', {'ride_request_id': 'eq.$rideRequestId'});
    await rest.delete('ride_requests', {'id': 'eq.$rideRequestId'});
  }
  for (final driverId in driverIds) {
    await rest.delete('drivers', {'id': 'eq.$driverId'});
  }
  if (riderIdentityId != null) {
    await rest.delete('rider_identities', {'id': 'eq.$riderIdentityId'});
  }
  for (final userId in authUserIds) {
    await rest.deleteAuthUser(userId);
  }
}

class _RestClient {
  _RestClient({required this.url, required this.serviceKey});

  final String url;
  final String serviceKey;
  final _http = HttpClient();

  Future<String> createAuthUser(String email) async {
    final body = await _requestJson(
      'POST',
      Uri.parse('$url/auth/v1/admin/users'),
      body: {
        'email': email,
        'password': 'CodexSmoke${DateTime.now().millisecondsSinceEpoch}!',
        'email_confirm': true,
      },
    );
    final id = body['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Auth user create did not return id');
    }
    return id;
  }

  Future<void> deleteAuthUser(String id) async {
    await _requestText('DELETE', Uri.parse('$url/auth/v1/admin/users/$id'));
  }

  Future<String> insertOne(String table, Map<String, dynamic> body) async {
    final rows = await _requestJsonList(
      'POST',
      Uri.parse('$url/rest/v1/$table?select=id'),
      body: body,
      prefer: 'return=representation',
    );
    final id = rows.isEmpty
        ? null
        : (rows.first as Map<String, dynamic>)['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Insert into $table did not return id');
    }
    return id;
  }

  Future<void> patch(
    String table,
    Map<String, dynamic> body,
    Map<String, String> query,
  ) async {
    await _requestText(
      'PATCH',
      Uri.parse('$url/rest/v1/$table').replace(queryParameters: query),
      body: body,
    );
  }

  Future<List<dynamic>> select(String table, Map<String, String> query) async {
    return _requestJsonList(
      'GET',
      Uri.parse('$url/rest/v1/$table').replace(queryParameters: query),
    );
  }

  Future<void> delete(String table, Map<String, String> query) async {
    await _requestText(
      'DELETE',
      Uri.parse('$url/rest/v1/$table').replace(queryParameters: query),
    );
  }

  Future<Map<String, dynamic>> _requestJson(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
  }) async {
    final text = await _requestText(method, uri, body: body);
    return jsonDecode(text) as Map<String, dynamic>;
  }

  Future<List<dynamic>> _requestJsonList(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? prefer,
  }) async {
    final text = await _requestText(method, uri, body: body, prefer: prefer);
    return jsonDecode(text) as List<dynamic>;
  }

  Future<String> _requestText(
    String method,
    Uri uri, {
    Map<String, dynamic>? body,
    String? prefer,
  }) async {
    final req = await _http.openUrl(method, uri);
    req.headers
      ..set('apikey', serviceKey)
      ..set('Authorization', 'Bearer $serviceKey')
      ..set('Content-Type', 'application/json');
    if (prefer != null) req.headers.set('Prefer', prefer);
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final text = await utf8.decodeStream(res);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException('HTTP ${res.statusCode} $method $uri: $text');
    }
    return text;
  }
}
