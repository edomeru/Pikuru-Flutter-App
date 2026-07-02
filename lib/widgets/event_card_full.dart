import 'package:flutter/material.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventCardFull extends StatelessWidget {
  final Map<String, dynamic> event;
  /// 'en' or 'ja' — drives title/type localisation.
  final String lang;

  const EventCardFull({
    super.key,
    required this.event,
    this.lang = 'en',
  });

  bool get _isJa => lang == 'ja';

  static const Color _cardBg     = Color(0xFFFFFFFF);
  static const Color _border     = Color(0xFFE2EAE4);
  static const Color _green      = Color(0xFF3A7D44);
  static const Color _greenLight = Color(0xFFE8F4EB);
  static const Color _title      = Color(0xFF1A1D1B);
  static const Color _dateText   = Color(0xFF1A1D1B);
  static const Color _metaText   = Color(0xFF5C6B61);
  static const Color _addrText   = Color(0xFF9EB3A3);

  @override
  Widget build(BuildContext context) {
    final title = _isJa
        ? (event['event_title_jp'] ?? event['event_title'] ?? 'Untitled Event').toString()
        : (event['event_title'] ?? 'Untitled Event').toString();

    final rawType = (event['event_type'] ?? '').toString();
    final displayType = _isJa ? _localizeType(rawType) : rawType;
    final tags = _buildTypeTags(displayType);

    final dateStr = _formatDate(event['event_date']);
    final timeStr = _formatTime(event['event_time']);
    final location = _isJa
        ? (event['location_jp'] ?? event['location'] ?? event['event_venue_name'] ?? '').toString()
        : (event['location'] ?? event['event_venue_name'] ?? '').toString();
    final address = _isJa
        ? (event['event_address_jp'] ?? event['event_address'] ?? event['event_venue_address'] ?? '').toString()
        : (event['event_address'] ?? event['event_venue_address'] ?? '').toString();
    final orgName = _isJa
        ? (event['org_name_jp'] ?? event['org_name'] ?? event['event_org_name'] ?? '').toString()
        : (event['org_name'] ?? event['event_org_name'] ?? '').toString();

    final imageUrl =
        (event['event_pic'] ?? event['event_pic_thumbnail'] ?? event['event_image'] ?? '').toString();
    final regClosed = _isRegistrationClosed();

    return PressScale(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildImage(imageUrl),
                  ),
                ),
                if (regClosed)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE6D97706),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            _isJa ? '受付終了' : 'REGISTRATION CLOSED',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),

            // ── Card content (matches web EventCard) ──────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _title,
                      height: 1.25,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (dateStr.isNotEmpty)
                    _infoRow(Icons.calendar_today_rounded, dateStr, bold: true),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.access_time_rounded, timeStr),
                  ],
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _locationRow(location, address),
                  ],
                  if (orgName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _infoRow(Icons.person_outline_rounded, orgName, semibold: true),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: tags.take(2).map(_buildTypeChip).toList(),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: _green,
                          size: 16,
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

  Widget _buildImage(String imageUrl) {
    final url = imageUrl.trim();
    if (url.isEmpty) return _imagePlaceholder();

    return Image.network(
      url,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() => Container(
        width: double.infinity,
        color: _greenLight,
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.85,
          child: Image.asset(
            'assets/pickleball_ball_no_bg_1.png',
            width: 56,
            height: 56,
            fit: BoxFit.contain,
          ),
        ),
      );

  Widget _infoRow(IconData icon, String text, {bool bold = false, bool semibold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 13, color: _green),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: bold
                  ? FontWeight.w700
                  : semibold
                      ? FontWeight.w600
                      : FontWeight.w500,
              color: bold ? _dateText : semibold ? _metaText : _metaText,
              letterSpacing: bold ? 0.2 : 0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _locationRow(String location, String address) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.location_on_rounded, size: 13, color: _green),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _metaText,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (address.isNotEmpty && address != location) ...[
                const SizedBox(height: 2),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _addrText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _greenLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _green.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _green,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  List<String> _buildTypeTags(String displayType) {
    final rawTags = event['event_tags'];
    if (rawTags is List && rawTags.isNotEmpty) {
      return rawTags.map((t) => t.toString()).where((t) => t.isNotEmpty).toList();
    }
    if (displayType.isNotEmpty) return [displayType];
    return const [];
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return '';
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      return _isJa
          ? _formatDateJa(dt)
          : DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
    }
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        return _isJa
            ? _formatDateJa(dt)
            : DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
      } catch (_) {
        return rawDate.toUpperCase();
      }
    }
    return '';
  }

  String _formatTime(dynamic rawTime) {
    if (rawTime == null) return '';
    if (rawTime is Timestamp) {
      final t = rawTime.toDate();
      return _isJa
          ? '${t.hour}:${t.minute.toString().padLeft(2, '0')}'
          : DateFormat('h:mm a').format(t);
    }
    if (rawTime is String && rawTime.isNotEmpty) return rawTime;
    return '';
  }

  static String _formatDateJa(DateTime dt) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final wd = weekdays[dt.weekday - 1];
    return '${dt.year}年${dt.month}月${dt.day}日($wd)';
  }

  bool _isRegistrationClosed() {
    final raw = event['registration_deadline'];
    if (raw == null) return false;
    DateTime? deadline;
    if (raw is Timestamp) {
      deadline = raw.toDate();
    } else if (raw is DateTime) {
      deadline = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try {
        deadline = DateTime.parse(raw);
      } catch (_) {}
    }
    if (deadline == null) return false;
    return DateTime.now().isAfter(deadline);
  }

  String _localizeType(String key) {
    const m = {
      'Professional Tournament': 'プロトーナメント',
      'Global Tournament': 'グローバルトーナメント',
      'Japan Tournament': '日本トーナメント',
      'Open Play': 'オープンプレイ',
      'Trial Session': '体験セッション',
      'Local Event': 'ローカルイベント',
      'Lessons/Clinics': 'レッスン・クリニック',
      'Weekly Play / Recurring Play': '定期プレイ',
      'Tournament': 'トーナメント',
      'Camp/Lesson': 'キャンプ/レッスン',
      'Social': 'ソーシャル',
      'Other': 'その他',
    };
    return m[key] ?? key;
  }
}

// ── Custom Interactive Tap Scaling Wrapper ─────────────────────────────────
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const PressScale({super.key, required this.child, required this.onTap});

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
