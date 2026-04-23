import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart'; // ← global lang
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/modal/share_event_modal.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n strings  (mirrors web app T object exactly)
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final String lang;
  const _S(this.lang);
  bool get isJa => lang == kLangJa;

  String get loading         => isJa ? 'イベントを読み込み中...'  : 'Loading event...';
  String get notFound        => isJa ? 'イベントが見つかりませんでした' : 'Event not found';
  String get backLabel       => isJa ? 'イベント'              : 'Events';
  String get dateTime        => isJa ? '日時'                  : 'Date & Time';
  String get categories      => isJa ? 'カテゴリ＆スキルレベル'  : 'Categories & Skill Level';
  String get location        => isJa ? '場所'                  : 'Location';
  String get about           => isJa ? 'イベントについて'        : 'About this Event';
  String get organizedBy     => isJa ? '主催者'                : 'Organized by';
  String get entryFee        => isJa ? '参加費'                : 'Entry Fee';
  String get save            => isJa ? '保存'                  : 'Save';
  String get free            => isJa ? '無料'                  : 'Free';
  String get viewMap         => isJa ? 'Googleマップで見る'     : 'View on Google Maps';
  String get ends            => isJa ? '終了日'                : 'Ends';
  String get limit           => isJa ? '定員'                  : 'Participant limit';
  String get contact         => isJa ? '連絡先'                : 'Contact';
  String get loginToSave     => isJa ? '保存するにはログインしてください' : 'Log in to save events';
  String get saveAndMore     => isJa ? '保存＆詳細情報'         : 'Save & More Information';
  String get savedMyEvents   => isJa ? 'My Events に保存済み'  : 'Saved to My Events';
  String get savedInterested => isJa ? 'Interested に登録済み' : 'Marked as Interested';
  String get updateStatus    => isJa ? 'イベントのステータスを更新' : 'Update Event Status';
  String get saveThisEvent   => isJa ? 'このイベントを保存'     : 'Save this Event';
  String get changeCategory  => isJa ? '保存カテゴリーを変更するか削除します。' : 'Change how this event is saved, or remove it.';
  String get chooseCategory  => isJa ? 'カテゴリーを選択してください。保存後にイベントページへ移動します。' : "Choose a category — you'll be taken to the event page right after.";
  String get myEventsTitle   => isJa ? 'My Events'            : 'My Events';
  String get myEventsSub     => isJa ? '参加予定のイベント'     : "Events you're planning to join";
  String get interestedTitle => isJa ? 'Interested'           : 'Interested';
  String get interestedSub   => isJa ? '気になるイベント'       : "Events you'd like to keep an eye on";
  String get removeFromSaved => isJa ? '保存済みから削除'       : 'Remove from saved events';
  String get disclaimer      => isJa
      ? 'イベントの詳細は変更または不正確な場合があります。最新情報は公式イベントウェブサイトをご確認ください。'
      : 'Event details may change or be inaccurate. Please refer to the official event website for the most up-to-date information.';
  String get noLocation      => isJa ? '場所未設定'            : 'No location set';
  String get loadingLoc      => isJa ? '読み込み中...'         : 'Loading...';
  String get map             => isJa ? 'マップ'                : 'Map';

  // Tags — mirrors web app T.ja exactly
  String get tagPro           => isJa ? 'プロ'         : 'PRO';
  String get tagAmateur       => isJa ? 'アマチュア'    : 'AMATEUR';
  String get tagBeginner      => isJa ? '初級者'        : 'BEGINNER';
  String get tagMensSingles   => isJa ? '男子シングルス' : "MEN'S SINGLES";
  String get tagWomensSingles => isJa ? '女子シングルス' : "WOMEN'S SINGLES";
  String get tagMixedDoubles  => isJa ? '混合ダブルス'   : 'MIXED DOUBLES';
  String get tagMensDoubles   => isJa ? '男子ダブルス'   : "MEN'S DOUBLES";
  String get tagWomensDoubles => isJa ? '女子ダブルス'   : "WOMEN'S DOUBLES";
  String get tagJuniors       => isJa ? 'ジュニア'      : 'JUNIORS';
  String get tagCollegiate    => isJa ? '大学生'        : 'COLLEGIATE';
  String get tagSeniors       => isJa ? 'シニア'        : 'SENIORS';

  // Event-type localiser — mirrors web app exactly
  String localizeType(String key) {
    if (!isJa) return key;
    const m = {
      'Professional Tournament':       'プロトーナメント',
      'Global Tournament':             'グローバルトーナメント',
      'Japan Tournament':              '日本トーナメント',
      'Open Play':                     'オープンプレイ',
      'Trial Session':                 '体験セッション',
      'Local Event':                   'ローカルイベント',
      'Lessons/Clinics':               'レッスン・クリニック',
      'Weekly Play / Recurring Play':  '定期プレイ',
      'Tournament':                    'トーナメント',
      'Camp/Lesson':                   'キャンプ/レッスン',
      'Social':                        'ソーシャル',
      'Other':                         'その他',
    };
    return m[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Save status
// ─────────────────────────────────────────────────────────────────────────────
enum _SaveStatus { none, myEvents, interested }

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class EventDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;
  const EventDetailScreen({super.key, required this.event});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  GoogleMapController? _mapController;
  _SaveStatus _saveStatus  = _SaveStatus.none;
  bool        _saveLoading = true;

  // ── Helpers ───────────────────────────────────────────────────────────────
  _S get s => _S(ref.watch(appLangProvider));

  String get locId   => (widget.event['event_loc_id']  ?? '').toString();
  String get eventId => (widget.event['event_id'] ?? widget.event['_doc_id'] ?? '').toString();

  // ── Date formatting (no locale init required) ─────────────────────────────
  String _formatDate(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp)            dt = raw.toDate();
    else if (raw is String && raw.isNotEmpty) {
      try { dt = DateTime.parse(raw); } catch (_) {}
    }
    if (dt == null) return '';
    if (s.isJa) {
      const wd = ['月','火','水','木','金','土','日'];
      return '${dt.year}年${dt.month}月${dt.day}日(${wd[dt.weekday-1]})';
    }
    return DateFormat('EEE, MMM d, yyyy').format(dt);
  }

  String _formatTime(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp)            dt = raw.toDate();
    else if (raw is String && raw.isNotEmpty) return raw;
    if (dt == null) return '';
    if (s.isJa) return '${dt.hour}:${dt.minute.toString().padLeft(2,'0')}';
    return DateFormat('h:mm a').format(dt);
  }

  String _formatFee(dynamic fee) {
    if (fee == null) return s.free;
    final v = fee.toString();
    if (v.isEmpty || v == '0' || v == '0.0') return s.free;
    return '¥$v';
  }

  double? _parseCoord(dynamic v) {
    if (v == null)    return null;
    if (v is double)  return v;
    if (v is int)     return v.toDouble();
    if (v is String)  return double.tryParse(v);
    return null;
  }

  // ── Save helpers ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadSaveStatus();
  }

  Future<void> _loadSaveStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) { setState(() => _saveLoading = false); return; }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_events').doc('${uid}_$eventId').get();
      if (doc.exists) {
        final status = (doc.data()?['status'] ?? '').toString();
        setState(() => _saveStatus = status == 'my_events'
            ? _SaveStatus.myEvents
            : status == 'interested' ? _SaveStatus.interested : _SaveStatus.none);
      }
    } catch (_) {}
    if (mounted) setState(() => _saveLoading = false);
  }

  Future<void> _setSaveStatus(_SaveStatus next) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() => _saveStatus = next);
    final docRef = FirebaseFirestore.instance
        .collection('user_events').doc('${uid}_$eventId');
    if (next == _SaveStatus.none) {
      await docRef.delete();
    } else {
      await docRef.set({
        'user_id':     uid,
        'event_id':    eventId,
        'status':      next == _SaveStatus.myEvents ? 'my_events' : 'interested',
        'event_title': widget.event['event_title'] ?? '',
        'event_pic':   widget.event['event_pic']   ?? '',
        'saved_at':    FieldValue.serverTimestamp(),
      });
    }
  }

  void _showSaveSheet() {
    final eventLink = (widget.event['event_link'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaveBottomSheet(
        s: s,
        currentStatus: _saveStatus,
        eventLink: eventLink,
        onSelect: (status) async {
          Navigator.pop(context);
          await _setSaveStatus(status);
          if (eventLink.isNotEmpty) {
            await Future.delayed(const Duration(milliseconds: 200));
            _openEventLink(eventLink);
          }
        },
        onRemove: () async {
          Navigator.pop(context);
          await _setSaveStatus(_SaveStatus.none);
        },
      ),
    );
  }

  // ── URL helpers ───────────────────────────────────────────────────────────
  Future<void> _openEventLink(String link) async {
    if (link.isEmpty) return;
    try {
      final raw = link.startsWith('http') ? link : 'https://$link';
      await launchUrl(Uri.parse(raw), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  // ── Firestore fetches ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>?> _fetchLocation() async {
    if (locId.isEmpty) return null;
    try {
      final q = await FirebaseFirestore.instance
          .collection('locations').where('loc_id', isEqualTo: locId).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
      final d = await FirebaseFirestore.instance.collection('locations').doc(locId).get();
      if (d.exists) return d.data();
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOrganizer() async {
    final orgId = (widget.event['event_org_id'] ?? '').toString();
    if (orgId.isEmpty) return null;
    try {
      final q = await FirebaseFirestore.instance
          .collection('organizations').where('org_id', isEqualTo: orgId).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first.data();
      final d = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
      if (d.exists) return d.data();
    } catch (_) {}
    return null;
  }

  @override
  void dispose() { _mapController?.dispose(); super.dispose(); }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch global lang so entire screen rebuilds on lang change
    ref.watch(appLangProvider);

    final e          = widget.event;
    // ── Title: prefer _jp field when Japanese — mirrors web app exactly ────
    final title      = s.isJa
        ? (e['event_title_jp'] ?? e['event_title'] ?? 'Untitled Event').toString()
        : (e['event_title'] ?? 'Untitled Event').toString();
    // ── Description: mirrors web app event_description_jp / _en fields ────
    final desc       = s.isJa
        ? (e['event_description_jp'] ?? e['event_description_en'] ?? e['event_description'] ?? '').toString()
        : (e['event_description_en'] ?? e['event_description'] ?? '').toString();
    final imageUrl   = (e['event_pic'] ?? e['event_pic_thumbnail'] ?? '').toString();
    final eventLink  = (e['event_link'] ?? '').toString();
    final rawType    = (e['event_type'] ?? '').toString();
    final dateStr    = _formatDate(e['event_date']);
    final timeStr    = _formatTime(e['event_time']);
    final endDateStr = _formatDate(e['event_date_end']);
    final feeStr     = _formatFee(e['event_fee']);
    final limitStr   = e['event_limit'] != null ? e['event_limit'].toString() : '';
    final contactStr = (e['event_contact'] ?? '').toString().trim();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [

          // ── Hero AppBar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => ShareEventModal.show(context, event: e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Icon(Icons.event_rounded, size: 80,
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                  if (rawType.isNotEmpty)
                    Positioned(
                      bottom: 16, left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          s.localizeType(rawType).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Title / Date / Tags card ─────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D), height: 1.2, letterSpacing: -0.4),
                    ),
                    if (dateStr.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.calendar_today_rounded,
                              color: AppColors.primary, size: 26),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(dateStr, style: const TextStyle(fontSize: 17,
                                fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(timeStr, style: const TextStyle(
                                  fontSize: 15, color: Colors.black54,
                                  fontWeight: FontWeight.w500)),
                            ],
                            if (endDateStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('${s.ends}: $endDateStr',
                                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
                            ],
                            if (limitStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('${s.limit}: $limitStr',
                                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
                            ],
                            if (contactStr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('${s.contact}: $contactStr',
                                  style: const TextStyle(fontSize: 13, color: Colors.black45)),
                            ],
                          ],
                        )),
                      ]),
                    ],
                    const SizedBox(height: 20),
                    _buildTags(),
                  ],
                )),

                // ── Location + Map card ──────────────────────────────────
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLocation(),
                  builder: (context, snap) {
                    final loc = snap.data;
                    // Prefer JP fields when Japanese — mirrors web app loc_name_jp, loc_address_jp
                    final locName = s.isJa
                        ? (loc?['loc_name_jp'] ?? loc?['loc_name'] ?? '').toString()
                        : (loc?['loc_name'] ?? '').toString();
                    final locAddress = s.isJa
                        ? (loc?['loc_address_jp'] ?? loc?['loc_address'] ?? '').toString()
                        : (loc?['loc_address'] ?? '').toString();
                    final googleLink = (loc?['loc_googlelink'] ?? '').toString();
                    final lat = _parseCoord(loc?['loc_latitude']);
                    final lng = _parseCoord(loc?['loc_longitude']);
                    final isLoading = snap.connectionState == ConnectionState.waiting;

                    return _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(s.location),
                        const SizedBox(height: 16),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.location_on_rounded,
                                color: AppColors.primary, size: 26),
                          ),
                          const SizedBox(width: 16),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              if (locName.isNotEmpty)
                                Text(locName, style: const TextStyle(fontSize: 17,
                                    fontWeight: FontWeight.bold, color: Color(0xFF0D0D0D))),
                              if (locAddress.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(locAddress, style: const TextStyle(
                                    fontSize: 14, color: Colors.black54)),
                              ],
                              if (locName.isEmpty && locAddress.isEmpty)
                                Text(isLoading ? s.loadingLoc : s.noLocation,
                                    style: const TextStyle(fontSize: 15, color: Colors.black45)),
                            ],
                          )),
                          if (lat != null && lng != null) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => _openGoogleMaps(lat, lng),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.arrow_forward,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          ],
                        ]),
                        if (googleLink.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse(googleLink),
                                mode: LaunchMode.externalApplication),
                            child: Row(children: [
                              Icon(Icons.map_rounded, color: AppColors.primary, size: 15),
                              const SizedBox(width: 6),
                              Text(s.viewMap, style: TextStyle(
                                fontSize: 13, color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              )),
                            ]),
                          ),
                        ],
                        if (lat != null && lng != null) ...[
                          const SizedBox(height: 20),
                          _sectionLabel(s.map),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () => _openGoogleMaps(lat, lng),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: SizedBox(
                                height: 200,
                                child: AbsorbPointer(
                                  child: GoogleMap(
                                    initialCameraPosition:
                                    CameraPosition(target: LatLng(lat, lng), zoom: 15),
                                    markers: {
                                      Marker(markerId: const MarkerId('loc'),
                                          position: LatLng(lat, lng)),
                                    },
                                    zoomControlsEnabled: false,
                                    mapToolbarEnabled: false,
                                    myLocationButtonEnabled: false,
                                    onMapCreated: (c) => _mapController = c,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ));
                  },
                ),

                // ── Description card ─────────────────────────────────────
                if (desc.isNotEmpty)
                  _card(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(s.about),
                      const SizedBox(height: 12),
                      Text(desc, style: const TextStyle(
                          fontSize: 15, color: Color(0xFF444444), height: 1.7)),
                    ],
                  )),

                // ── Organizer card ───────────────────────────────────────
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchOrganizer(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting ||
                        snap.data == null) return const SizedBox.shrink();
                    final org = snap.data!;
                    // Prefer JP org name — mirrors web app org_name_jp field
                    final orgName = s.isJa
                        ? (org['org_name_jp'] ?? org['org_name'] ?? '').toString()
                        : (org['org_name'] ?? '').toString();
                    final orgLogo = (org['org_logo'] ?? '').toString();
                    if (orgName.isEmpty) return const SizedBox.shrink();

                    return _card(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel(s.organizedBy),
                        const SizedBox(height: 16),
                        Row(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: orgLogo.isNotEmpty
                                ? Image.network(orgLogo, width: 52, height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _orgPlaceholder())
                                : _orgPlaceholder(),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(orgName,
                            style: const TextStyle(fontSize: 16,
                                fontWeight: FontWeight.w700, color: Color(0xFF0D0D0D)),
                          )),
                        ]),
                      ],
                    ));
                  },
                ),

                // ── Fee + Save card ──────────────────────────────────────
                _card(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.entryFee,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: Colors.black.withOpacity(0.4), letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(feeStr,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800,
                            color: feeStr == s.free
                                ? Colors.green.shade600
                                : const Color(0xFF0D0D0D))),
                    const SizedBox(height: 20),
                    _saveLoading
                        ? const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: CircularProgressIndicator(strokeWidth: 2)))
                        : _buildSaveWidget(eventLink),
                  ],
                )),

                // ── Disclaimer ───────────────────────────────────────────
                _DisclaimerCard(text: s.disclaimer),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Save widget ───────────────────────────────────────────────────────────
  Widget _buildSaveWidget(String eventLink) {
    switch (_saveStatus) {
      case _SaveStatus.none:
        return _SaveNoneWidget(label: s.saveAndMore,
            hasLink: eventLink.isNotEmpty, onTap: _showSaveSheet);
      case _SaveStatus.myEvents:
        return _SavedWidget(label: s.savedMyEvents,
            icon: Icons.bookmark_rounded,
            color: AppColors.primary, onTap: _showSaveSheet);
      case _SaveStatus.interested:
        return _SavedWidget(label: s.savedInterested,
            icon: Icons.star_rounded,
            color: const Color(0xFFE6A817), onTap: _showSaveSheet);
    }
  }

  // ── Tags ──────────────────────────────────────────────────────────────────
  Widget _buildTags() {
    final e = widget.event;
    final tags = <String>[];
    if (e['event_skill_level_pro']       == true) tags.add(s.tagPro);
    if (e['event_skill_level_amateur']    == true) tags.add(s.tagAmateur);
    if (e['event_skill_level_beginner']   == true) tags.add(s.tagBeginner);
    if (e['event_category_menssingle']    == true) tags.add(s.tagMensSingles);
    if (e['event_category_womenssingle']  == true) tags.add(s.tagWomensSingles);
    if (e['event_category_mixeddoubles']  == true) tags.add(s.tagMixedDoubles);
    if (e['event_category_mensdoubles']   == true) tags.add(s.tagMensDoubles);
    if (e['event_category_womensdoubles'] == true) tags.add(s.tagWomensDoubles);
    if (e['event_category_juniors']       == true) tags.add(s.tagJuniors);
    if (e['event_category_collegiate']    == true) tags.add(s.tagCollegiate);
    if (e['event_category_seniors']       == true) tags.add(s.tagSeniors);
    if (tags.isEmpty) {
      final old = (e['event_skill_level'] ?? '').toString();
      if (old.isNotEmpty) tags.add(old.toUpperCase());
    }
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 7, runSpacing: 7,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(tag, style: TextStyle(
            color: AppColors.primary, fontSize: 11,
            fontWeight: FontWeight.w700, letterSpacing: 0.4)),
      )).toList(),
    );
  }

  // ── Layout helpers ────────────────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity, color: Colors.white,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
    child: child,
  );

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary));

  Widget _orgPlaceholder() => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(Icons.groups_rounded, color: AppColors.primary, size: 28),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Disclaimer card
// ═════════════════════════════════════════════════════════════════════════════
class _DisclaimerCard extends StatelessWidget {
  final String text;
  const _DisclaimerCard({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, color: Colors.white,
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.info_outline_rounded, size: 15, color: Colors.grey.shade400),
      const SizedBox(width: 10),
      Expanded(child: Text(text,
          style: const TextStyle(fontSize: 12, color: Colors.black38, height: 1.5))),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Save None widget
// ═════════════════════════════════════════════════════════════════════════════
class _SaveNoneWidget extends StatelessWidget {
  final String label;
  final bool hasLink;
  final VoidCallback onTap;
  const _SaveNoneWidget({required this.label, required this.hasLink, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: hasLink ? AppColors.primary : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
        boxShadow: hasLink ? [BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12, offset: const Offset(0, 4))] : [],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.bookmark_add_outlined,
            color: hasLink ? Colors.white : Colors.grey, size: 19),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: hasLink ? Colors.white : Colors.grey)),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Saved widget
// ═════════════════════════════════════════════════════════════════════════════
class _SavedWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SavedWidget({required this.label, required this.icon,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 54,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
            color: color)),
        const SizedBox(width: 8),
        Icon(Icons.edit_rounded, color: color.withOpacity(0.55), size: 15),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Save bottom sheet
// ═════════════════════════════════════════════════════════════════════════════
class _SaveBottomSheet extends StatelessWidget {
  final _S s;
  final _SaveStatus currentStatus;
  final String eventLink;
  final void Function(_SaveStatus) onSelect;
  final VoidCallback onRemove;
  const _SaveBottomSheet({required this.s, required this.currentStatus,
    required this.eventLink, required this.onSelect, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isAlreadySaved = currentStatus != _SaveStatus.none;
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text(isAlreadySaved ? s.updateStatus : s.saveThisEvent,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                  color: Color(0xFF0D0D0D), letterSpacing: -0.4)),
          const SizedBox(height: 6),
          Text(isAlreadySaved ? s.changeCategory : s.chooseCategory,
              style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.45))),
          const SizedBox(height: 24),
          _OptionTile(
            icon: Icons.bookmark_rounded, iconColor: AppColors.primary,
            title: s.myEventsTitle, subtitle: s.myEventsSub,
            isSelected: currentStatus == _SaveStatus.myEvents,
            onTap: () => onSelect(_SaveStatus.myEvents),
          ),
          const SizedBox(height: 10),
          _OptionTile(
            icon: Icons.star_rounded, iconColor: const Color(0xFFE6A817),
            title: s.interestedTitle, subtitle: s.interestedSub,
            isSelected: currentStatus == _SaveStatus.interested,
            onTap: () => onSelect(_SaveStatus.interested),
          ),
          if (isAlreadySaved) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onRemove,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.red, size: 22),
                ),
                const SizedBox(width: 14),
                Text(s.removeFromSaved, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Option tile
// ═════════════════════════════════════════════════════════════════════════════
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final bool muted;
  const _OptionTile({required this.icon, required this.iconColor,
    required this.title, required this.subtitle,
    required this.isSelected, required this.onTap, this.muted = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? iconColor.withOpacity(0.07) : const Color(0xFFF7F7F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSelected ? iconColor.withOpacity(0.45) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(isSelected ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: muted ? Colors.black54 : const Color(0xFF0D0D0D))),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 12.5,
              color: Colors.black.withOpacity(0.4))),
        ])),
        isSelected
            ? Icon(Icons.check_circle_rounded, color: iconColor, size: 22)
            : Icon(Icons.chevron_right_rounded,
            color: Colors.black.withOpacity(0.18), size: 22),
      ]),
    ),
  );
}