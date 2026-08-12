import '../main.dart';
import 'qatar_time.dart';


class BoxLookupResult {
  final bool found;
  final Map<String, dynamic>? box;
  final Map<String, dynamic>? order;
  BoxLookupResult({required this.found, this.box, this.order});
}

class BoxStageResult {
  final bool orderCompleted;
  final int remaining;
  BoxStageResult({required this.orderCompleted, required this.remaining});
}

class BoxScanService {
  static Future<BoxLookupResult> lookup(String code) async {
    final box = await supabase
        .from('order_boxes')
        .select('''
          id, box_number, box_code, order_id, picked_up_at, sorted_at, out_for_delivery_at,
          order:orders(id, order_code, status, consignee_name, full_address, merchant_id,
            assigned_driver_id, delivery_date,
            driver:profiles!orders_assigned_driver_id_fkey(full_name),
            merchant:profiles!orders_merchant_id_fkey(full_name)
          )
        ''')
        .eq('box_code', code)
        .maybeSingle();

    if (box == null) return BoxLookupResult(found: false);
    return BoxLookupResult(found: true, box: box, order: box['order'] as Map<String, dynamic>?);
  }

  static bool alreadyScanned(Map<String, dynamic> box, String stage) => box['${stage}_at'] != null;

  /// stage must be one of: picked_up, sorted, out_for_delivery
  static Future<BoxStageResult> markStage(String boxId, String orderId, String stage) async {
    await supabase.from('order_boxes').update({'${stage}_at': QatarTime.nowUtcIso()}).eq('id', boxId);

    final remaining = await supabase
        .from('order_boxes')
        .select('id')
        .eq('order_id', orderId)
        .filter('${stage}_at', 'is', null);
    final remainingCount = (remaining as List).length;

    if (remainingCount == 0) {
      await supabase.from('orders').update({
        'status': stage,
        '${stage}_at': QatarTime.nowUtcIso(),
      }).eq('id', orderId);
    }

    return BoxStageResult(orderCompleted: remainingCount == 0, remaining: remainingCount);
  }
}