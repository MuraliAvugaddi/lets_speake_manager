// =========================================================================
// 🔴 ADMIN MENU BADGES — red counts next to the menu items that need the admin
//
//   Students          new students waiting for stage access
//   Feedback          new feedback since the admin last opened Feedback
//   Fee Verification  fee screenshots waiting to be checked
//   Trainer Tests     tests trainers sent for approval
//   Student Requests  requests the trainer sent to the manager
//
// Updates live (socket events) + every 30 s as a safety net.
// =========================================================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';

class AdminBadges {
  AdminBadges._();

  // menu index (see Homescreen modules) → count
  static const int students = 0;
  static const int feedback = 5;
  static const int feeVerification = 7;
  static const int trainerTests = 14;
  static const int requests = 21;

  static final RxMap<int, int> counts = <int, int>{}.obs;

  static final GetStorage _box = GetStorage();
  static const String _feedbackSeenKey = 'admin_feedback_seen_at';
  static Timer? _poll;
  static void Function()? _stopLive;
  static bool _loading = false;

  static int of(int index) => counts[index] ?? 0;

  /// total for the ☰ menu button (mobile)
  static int get total => counts.values.fold(0, (a, b) => a + b);

  static void start() {
    if (_poll != null) return;
    // first time on this device → count feedback from now on (not every old one)
    if (_box.read(_feedbackSeenKey) == null) {
      _box.write(_feedbackSeenKey, DateTime.now().toUtc().toIso8601String());
    }
    load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => load());
    _stopLive = AdminLive.on(
      const [
        'student_update',
        'new_user_registered',
        'fee_update',
        'test_draft_new',
        'test_draft_updated',
        'request_update',
        'feedback_new',
        'feedback_deleted',
      ],
      load,
      debounce: const Duration(
        seconds: 6,
      ), // server keeps counts 5 s → ask after that
    );
  }

  static void stop() {
    _poll?.cancel();
    _poll = null;
    _stopLive?.call();
    _stopLive = null;
    counts.clear();
  }

  static Future<void> load() async {
    if (_loading || (ApiHeaders.token ?? '').isEmpty) return;
    _loading = true;
    try {
      final since = Uri.encodeQueryComponent(
        '${_box.read(_feedbackSeenKey) ?? ''}',
      );
      final res = await http
          .get(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/admin/badges?feedbackSince=$since',
            ),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return;
      final d = jsonDecode(res.body);
      if (d is! Map) return;
      int n(String k) => int.tryParse('${d[k] ?? 0}') ?? 0;
      counts.assignAll({
        students: n('students'),
        feedback: n('feedback'),
        feeVerification: n('feeVerification'),
        trainerTests: n('trainerTests'),
        requests: n('requests'),
      });
    } catch (_) {
      // offline → keep the old numbers
    } finally {
      _loading = false;
    }
  }

  /// The admin opened a menu item. Feedback counts as "read" now;
  /// the other badges go away by themselves when the work is done.
  static void opened(int index) {
    if (index == feedback) {
      _box.write(_feedbackSeenKey, DateTime.now().toUtc().toIso8601String());
      counts[feedback] = 0;
    }
  }
}

/// ☰ menu icon with a red dot when something in the menu needs the admin
/// (phone / tablet: the menu is closed, so the admin still sees it)
class AdminMenuIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  const AdminMenuIcon(this.icon, {super.key, this.color, this.size});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final n = AdminBadges.total;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: color, size: size),
          if (n > 0)
            Positioned(
              right: -6,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFFE45757),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  n > 99 ? '99+' : '$n',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}
