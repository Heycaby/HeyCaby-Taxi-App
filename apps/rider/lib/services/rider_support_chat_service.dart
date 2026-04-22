import 'package:flutter/foundation.dart';
import 'package:heycaby_api/heycaby_api.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

/// Result of Edge Function `rider-support-chat` (AI rider support).
@immutable
class RiderSupportChatResult {
  const RiderSupportChatResult({
    required this.ok,
    this.reply,
    this.error,
    this.ticketId,
    this.usedLocalFallback = false,
  });

  final bool ok;
  final String? reply;
  final String? error;
  final String? ticketId;
  final bool usedLocalFallback;
}

/// Invokes Supabase Edge Function `rider-support-chat` with JWT. No LLM keys in the app.
class RiderSupportChatService {
  RiderSupportChatService._();

  static final _client = HeyCabySupabase.client;

  static const _noLocalFallbackErrors = {
    'forbidden',
    'ticket_not_found',
    'ticket_closed',
    'not_signed_in',
    'empty_message',
    'session_expired',
  };

  static RiderSupportChatResult _fromFunctionException(FunctionException e) {
    final raw = e.details;
    if (raw is Map) {
      final err = raw['error'];
      if (err != null) {
        return RiderSupportChatResult(
          ok: false,
          error: err.toString(),
        );
      }
    }
    return RiderSupportChatResult(ok: false, error: 'edge_${e.status}');
  }

  static RiderSupportChatResult _parseResponse(dynamic res) {
    final code = res.status as int;
    final data = res.data;
    if (code != 200) {
      if (data is Map && data['error'] != null) {
        return RiderSupportChatResult(
          ok: false,
          error: data['error'].toString(),
        );
      }
      return RiderSupportChatResult(
        ok: false,
        error: data?.toString() ?? 'HTTP $code',
      );
    }
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (map['error'] != null) {
        return RiderSupportChatResult(
          ok: false,
          error: map['error'].toString(),
        );
      }
      final tid = map['ticket_id'] as String? ?? map['ticketId'] as String?;
      return RiderSupportChatResult(
        ok: true,
        reply: map['reply'] as String?,
        ticketId: tid,
      );
    }
    return const RiderSupportChatResult(ok: true);
  }

  static String _fallbackAssistantCopy(String? edgeError) {
    if (edgeError == 'ai_not_configured') {
      return 'De AI-assistent is tijdelijk niet beschikbaar. Je bericht is opgeslagen; '
          'ons team kan verder helpen. / The AI assistant is temporarily unavailable. '
          'Your message was saved; our team can pick it up.';
    }
    return 'We konden de assistent nu niet bereiken, maar je bericht is opgeslagen. '
        'Probeer het zo opnieuw of wacht op een reactie. / We could not reach the '
        'assistant right now, but your message was saved. Try again shortly or wait for a reply.';
  }

  static bool _shouldSkipLocalFallback(String? error) {
    if (error == null) return false;
    return _noLocalFallbackErrors.contains(error);
  }

  static Future<RiderSupportChatResult?> _appendLocally({
    required String ticketId,
    required String userText,
    required String assistantText,
  }) async {
    try {
      if (_client.auth.currentSession == null) return null;

      final row = await _client
          .from('tickets')
          .select('messages, status')
          .eq('id', ticketId)
          .maybeSingle();
      if (row == null) return null;
      final status = row['status'] as String? ?? 'open';
      if (status == 'closed' || status == 'resolved') return null;

      final existing = row['messages'];
      final list = existing is List ? List<dynamic>.from(existing) : <dynamic>[];
      final now = DateTime.now().toUtc().toIso8601String();
      list.add(<String, dynamic>{'role': 'user', 'content': userText, 'ts': now});
      list.add(<String, dynamic>{
        'role': 'assistant',
        'content': assistantText,
        'ts': DateTime.now().toUtc().toIso8601String(),
      });

      await _client.from('tickets').update({
        'messages': list,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', ticketId);

      return RiderSupportChatResult(
        ok: true,
        reply: assistantText,
        ticketId: ticketId,
        usedLocalFallback: true,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('rider-support-chat local fallback: $e\n$st');
      }
      return null;
    }
  }

  static Future<RiderSupportChatResult> _maybeFallback({
    required String trimmed,
    String? ticketId,
    required RiderSupportChatResult outcome,
  }) async {
    if (outcome.ok) return outcome;
    if (ticketId == null || ticketId.isEmpty) return outcome;
    if (_shouldSkipLocalFallback(outcome.error)) return outcome;

    final assistant = _fallbackAssistantCopy(outcome.error);
    final local = await _appendLocally(
      ticketId: ticketId,
      userText: trimmed,
      assistantText: assistant,
    );
    return local ?? outcome;
  }

  static Future<RiderSupportChatResult> sendMessage({
    required String message,
    String? ticketId,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return const RiderSupportChatResult(ok: false, error: 'empty_message');
    }
    final body = <String, dynamic>{'message': trimmed};
    if (ticketId != null && ticketId.isNotEmpty) {
      body['ticket_id'] = ticketId;
    }

    Future<dynamic> invokeWithSessionToken() async {
      final session = _client.auth.currentSession;
      if (session == null) return null;
      return _client.functions.invoke(
        'rider-support-chat',
        body: body,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );
    }

    try {
      if (_client.auth.currentSession == null) {
        return const RiderSupportChatResult(ok: false, error: 'not_signed_in');
      }

      dynamic res;
      try {
        res = await invokeWithSessionToken();
      } on FunctionException catch (e) {
        if (e.status == 401) {
          try {
            await _client.auth.refreshSession();
          } catch (err) {
            if (kDebugMode) {
              debugPrint('rider-support-chat: refresh failed: $err');
            }
          }
          res = await invokeWithSessionToken();
        } else {
          return _maybeFallback(
            trimmed: trimmed,
            ticketId: ticketId,
            outcome: _fromFunctionException(e),
          );
        }
      }

      if (res == null) {
        return const RiderSupportChatResult(ok: false, error: 'not_signed_in');
      }

      var status = res.status as int;
      if (status == 401) {
        try {
          await _client.auth.refreshSession();
        } catch (_) {}
        res = await invokeWithSessionToken();
        if (res == null) {
          return const RiderSupportChatResult(ok: false, error: 'not_signed_in');
        }
        status = res.status as int;
      }

      final parsed = _parseResponse(res);
      return _maybeFallback(
        trimmed: trimmed,
        ticketId: ticketId,
        outcome: parsed,
      );
    } on FunctionException catch (e, st) {
      if (kDebugMode) {
        debugPrint('rider-support-chat: $e\n$st');
      }
      if (e.status == 401) {
        return const RiderSupportChatResult(
          ok: false,
          error: 'session_expired',
        );
      }
      return _maybeFallback(
        trimmed: trimmed,
        ticketId: ticketId,
        outcome: _fromFunctionException(e),
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('rider-support-chat: $e\n$st');
      }
      return _maybeFallback(
        trimmed: trimmed,
        ticketId: ticketId,
        outcome: RiderSupportChatResult(ok: false, error: e.toString()),
      );
    }
  }
}
