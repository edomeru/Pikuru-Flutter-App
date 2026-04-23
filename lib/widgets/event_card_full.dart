import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventCardFull extends ConsumerWidget {
  final Map<String, dynamic> event;
  /// 'en' or 'ja' — drives title/type localisation.
  /// Defaults to 'en' for backward-compatibility.
  final String lang;

  const EventCardFull({
    super.key,
    required this.event,
    this.lang = 'en',
  });

  bool get _isJa => lang == 'ja';

  // ── Light-mode palette (matches EventsScreen) ─────────────────────────────
  static const Color _green      = Color(0xFF3A7D44);
  static const Color _greenLight = Color(0xFFE8F4EB);
  static const Color _textDark   = Color(0xFF1A1D1B);
  static const Color _textMid    = Color(0xFF5C6B61);
  static const Color _textLight  = Color(0xFF9EB3A3);
  static const Color _border     = Color(0xFFE2EAE4);
  static const Color _cardBg     = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    // ── Title: prefer JP field when lang == 'ja' ──────────────────────────
    final title = _isJa
        ? ((event['event_title_jp'] ?? event['event_title'] ?? 'Untitled Event').toString())
        : ((event['event_title'] ?? 'Untitled Event').toString());

    // ── Event type: localise for JP display ───────────────────────────────
    final rawType = (event['event_type'] ?? '').toString();
    final displayType = _isJa ? _localizeType(rawType) : rawType;

    // ── Date ──────────────────────────────────────────────────────────────
    final rawDate = event['event_date'];
    String dateStr = '';
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      dateStr = _isJa ? _formatDateJa(dt) : DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        dateStr = _isJa ? _formatDateJa(dt) : DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
      } catch (_) {
        dateStr = rawDate.toUpperCase();
      }
    }

    // ── Time ──────────────────────────────────────────────────────────────
    final rawTime = event['event_time'];
    String timeStr = '';
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      timeStr = _isJa
          ? '${t.hour}:${t.minute.toString().padLeft(2, '0')}'
          : DateFormat('h:mm a').format(t);
    } else if (rawTime is String && rawTime.isNotEmpty) {
      timeStr = rawTime;
    }

    final tags = _buildTagStrings();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Hero image ────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft:  Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Image.network(
                    (event['event_pic'] ?? event['event_pic_thumbnail'] ?? '').toString(),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 190,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft:  Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        color: _greenLight,
                      ),
                      child: const Center(
                        child: Icon(Icons.event_rounded, size: 56, color: _green),
                      ),
                    ),
                  ),
                ),

                // ── Date badge overlay (top-left, matching screenshot) ────
                if (dateStr.isNotEmpty)
                  Positioned(
                    top: 12, left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _green.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 11, color: Colors.white),
                        const SizedBox(width: 5),
                        Text(
                          timeStr.isNotEmpty ? '$dateStr · $timeStr' : dateStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ]),
                    ),
                  ),

                // ── Event type badge top-right ────────────────────────────
                if (displayType.isNotEmpty)
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        displayType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Card content ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _textDark,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 10),

                  // Location row
                  _buildLocation(ref),

                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) => _buildTag(tag)).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _green,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location resolver ─────────────────────────────────────────────────────
  Widget _buildLocation(WidgetRef ref) {
    final eventLocId = (event['event_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(eventLocId));

    return locationAsync.when(
      data: (location) {
        // When JP, prefer JP location fields baked into the event map
        String displayLoc = location;
        if (_isJa) {
          final jpCity = (event['_city_jp'] ?? event['loc_city_jp'] ?? '').toString().trim();
          final jpPref = (event['_prefecture_jp'] ?? event['loc_prefecture_jp'] ?? '').toString().trim();
          if (jpCity.isNotEmpty && jpPref.isNotEmpty) {
            displayLoc = '$jpPref$jpCity';
          } else if (jpPref.isNotEmpty) {
            displayLoc = jpPref;
          } else if (jpCity.isNotEmpty) {
            displayLoc = jpCity;
          }
        }
        return Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 13, color: _textLight),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                displayLoc,
                style: const TextStyle(
                    fontSize: 12, color: _textMid, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
      loading: () => const Text('…',
          style: TextStyle(fontSize: 12, color: _textLight)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  // ── Japanese date formatter (no locale initialisation needed) ────────────
  static String _formatDateJa(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = weekdays[dt.weekday - 1]; // Monday==1 … Sunday==7
    return '${dt.year}年${dt.month}月${dt.day}日($wd)';
  }

  // ── Tag helpers ───────────────────────────────────────────────────────────
  List<String> _buildTagStrings() {
    final tags = <String>[];

    if (_isJa) {
      if (event['event_skill_level_pro']      == true) tags.add('上級');
      if (event['event_skill_level_amateur']   == true) tags.add('中級');
      if (event['event_skill_level_beginner']  == true) tags.add('初級');
      if (event['event_category_juniors']      == true) tags.add('ジュニア');
      if (event['event_category_seniors']      == true) tags.add('シニア');
      if (event['event_category_collegiate']   == true) tags.add('学生');
      if (event['event_category_mixeddoubles'] == true) tags.add('ミックス');
      if (event['event_category_mensdoubles']  == true) tags.add('男子ダブルス');
      if (event['event_category_womensdoubles']== true) tags.add('女子ダブルス');
      if (event['event_category_menssingle']   == true) tags.add('男子シングルス');
      if (event['event_category_womenssingle'] == true) tags.add('女子シングルス');
    } else {
      if (event['event_skill_level_pro']      == true) tags.add('PRO');
      if (event['event_skill_level_amateur']   == true) tags.add('AMATEUR');
      if (event['event_skill_level_beginner']  == true) tags.add('BEGINNER');
      if (event['event_category_juniors']      == true) tags.add('JUNIORS');
      if (event['event_category_seniors']      == true) tags.add('SENIORS');
      if (event['event_category_collegiate']   == true) tags.add('COLLEGIATE');
      if (event['event_category_mixeddoubles'] == true) tags.add('MIXED DOUBLES');
      if (event['event_category_mensdoubles']  == true) tags.add("MEN'S DOUBLES");
      if (event['event_category_womensdoubles']== true) tags.add("WOMEN'S DOUBLES");
      if (event['event_category_menssingle']   == true) tags.add("MEN'S SINGLES");
      if (event['event_category_womenssingle'] == true) tags.add("WOMEN'S SINGLES");
    }

    if (tags.isEmpty) {
      final oldSkill = (event['event_skill_level'] ?? '').toString();
      if (oldSkill.isNotEmpty) tags.add(oldSkill.toUpperCase());
    }
    return tags;
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ── Event-type localiser (mirrors web app T object) ───────────────────────
  String _localizeType(String key) {
    const m = {
      'Professional Tournament': 'プロトーナメント',
      'Global Tournament':       'グローバルトーナメント',
      'Japan Tournament':        '日本トーナメント',
      'Open Play':               'オープンプレイ',
      'Trial Session':           '体験セッション',
      'Local Event':             'ローカルイベント',
      'Lessons/Clinics':         'レッスン・クリニック',
      'Weekly Play / Recurring Play': '定期プレイ',
      'Tournament':              'トーナメント',
      'Camp/Lesson':             'キャンプ/レッスン',
      'Social':                  'ソーシャル',
      'Other':                   'その他',
    };
    return m[key] ?? key;
  }
}