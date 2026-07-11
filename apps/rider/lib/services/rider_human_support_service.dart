import 'package:heycaby_api/heycaby_api.dart';

class RiderHumanSupportService {
  const RiderHumanSupportService._();

  static Future<String> createTicket({
    required String category,
    required String content,
  }) async {
    final result = await HeyCabySupabase.client.rpc(
      'fn_rider_support_create_ticket',
      params: {
        'p_category': category,
        'p_content': content,
      },
    );
    final ticketId = result?.toString().trim() ?? '';
    if (ticketId.isEmpty) throw StateError('support_ticket_not_created');
    return ticketId;
  }

  static Future<void> appendMessage({
    required String ticketId,
    required String content,
  }) async {
    await HeyCabySupabase.client.rpc(
      'fn_rider_support_append_message',
      params: {
        'p_ticket_id': ticketId,
        'p_content': content,
      },
    );
  }

  static Future<void> resolveTicket(String ticketId) async {
    await HeyCabySupabase.client.rpc(
      'fn_rider_support_resolve_ticket',
      params: {'p_ticket_id': ticketId},
    );
  }
}
