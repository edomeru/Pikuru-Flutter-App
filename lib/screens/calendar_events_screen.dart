import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Filter state (mirrors _AdvFilter in events_screen.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _CalFilter {
  String country;
  String prefecture;
  String city;
  String type;
  bool skillPro;
  bool skillAmateur;
  bool skillBeginner;
  bool catMx, catMd, catMs, catWs, catWd, catSe, catJu, catCo;
  bool tourist;

  _CalFilter({
    this.country       = '',
    this.prefecture    = '',
    this.city          = '',
    this.type          = '',
    this.skillPro      = false,
    this.skillAmateur  = false,
    this.skillBeginner = false,
    this.catMx = false, this.catMd = false, this.catMs = false,
    this.catWs = false, this.catWd = false, this.catSe = false,
    this.catJu = false, this.catCo = false,
    this.tourist = false,
  });

  _CalFilter copyWith({
    String? country, String? prefecture, String? city, String? type,
    bool? skillPro, bool? skillAmateur, bool? skillBeginner,
    bool? catMx, bool? catMd, bool? catMs, bool? catWs,
    bool? catWd, bool? catSe, bool? catJu, bool? catCo,
    bool? tourist,
  }) => _CalFilter(
    country:       country       ?? this.country,
    prefecture:    prefecture    ?? this.prefecture,
    city:          city          ?? this.city,
    type:          type          ?? this.type,
    skillPro:      skillPro      ?? this.skillPro,
    skillAmateur:  skillAmateur  ?? this.skillAmateur,
    skillBeginner: skillBeginner ?? this.skillBeginner,
    catMx: catMx ?? this.catMx, catMd: catMd ?? this.catMd,
    catMs: catMs ?? this.catMs, catWs: catWs ?? this.catWs,
    catWd: catWd ?? this.catWd, catSe: catSe ?? this.catSe,
    catJu: catJu ?? this.catJu, catCo: catCo ?? this.catCo,
    tourist: tourist ?? this.tourist,
  );

  bool get hasNonLocationFilters =>
      type.isNotEmpty ||
          skillPro || skillAmateur || skillBeginner ||
          catMx || catMd || catMs || catWs || catWd || catSe || catJu || catCo ||
          tourist;

  bool get isActive =>
      hasNonLocationFilters ||
          country.isNotEmpty || prefecture.isNotEmpty || city.isNotEmpty;
}

// ─────────────────────────────────────────────────────────────────────────────
// CalendarEventsScreen
// ─────────────────────────────────────────────────────────────────────────────
class CalendarEventsScreen extends ConsumerStatefulWidget {
  const CalendarEventsScreen({super.key});

  @override
  ConsumerState<CalendarEventsScreen> createState() =>
      _CalendarEventsScreenState();
}

class _CalendarEventsScreenState extends ConsumerState<CalendarEventsScreen>
    with TickerProviderStateMixin {

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg       = Color(0xFFF7F8FA);
  static const Color _surface  = Colors.white;
  static const Color _border   = Color(0xFFEEEFF1);
  static const Color _textDark = Color(0xFF0D0D0D);
  static const Color _cardBg   = Color(0xFFF2F3F5);
  static const Color _borderMd = Color(0xFFDDDEE1);
  static const Color _textMid  = Color(0xFF555760);
  static const Color _textLight= Color(0xFF888A90);

  // ── Filter state (single source of truth) ─────────────────────────────────
  _CalFilter _filter = _CalFilter(country: 'Japan', prefecture: 'Tokyo');

  static const List<String> _eventTypes = [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];

  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideCtrl;
  late final Animation<Offset>   _slideAnim;

  static const List<String> _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];
  static const List<String> _weekdays = ['SU','MO','TU','WE','TH','FR','SA'];

  @override
  void initState() {
    super.initState();
    final now     = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380))
      ..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ── Location label shown in the header ────────────────────────────────────
  String get _locationLabel {
    if (_filter.prefecture.isNotEmpty) return _filter.prefecture;
    if (_filter.country.isNotEmpty)    return _filter.country;
    return 'All Countries';
  }

  // ── Full location matching ────────────────────────────────────────────────
  bool _matchesLocation(Map<String, dynamic> event) {
    if (_filter.country.isEmpty) return true;

    final targetCountry = _filter.country.toLowerCase();
    final targetPref    = _filter.prefecture.isNotEmpty
        ? _filter.prefecture.toLowerCase() : null;
    final targetCity    = _filter.city.isNotEmpty
        ? _filter.city.toLowerCase() : null;

    final country =
    (event['_resolvedCountry'] ?? '').toString().trim().toLowerCase();
    if (country.isEmpty) return false;
    if (!country.contains(targetCountry) &&
        !targetCountry.contains(country)) return false;

    if (targetPref != null && targetPref.isNotEmpty) {
      final pref =
      (event['_resolvedPrefecture'] ?? '').toString().trim().toLowerCase();
      if (pref.isEmpty) return false;
      if (!pref.contains(targetPref) && !targetPref.contains(pref)) {
        return false;
      }
    }

    if (targetCity != null && targetCity.isNotEmpty) {
      final city =
      (event['_resolvedCity'] ?? '').toString().trim().toLowerCase();
      if (city.isEmpty) return false;
      if (!city.contains(targetCity) && !targetCity.contains(city)) {
        return false;
      }
    }

    return true;
  }

  // ── All filters ───────────────────────────────────────────────────────────
  bool _matchesAllFilters(Map<String, dynamic> e) {
    if (!_matchesLocation(e)) return false;

    if (_filter.type.isNotEmpty &&
        (e['event_type'] ?? '').toString() != _filter.type) return false;

    if (_filter.skillPro || _filter.skillAmateur || _filter.skillBeginner) {
      final match =
          (_filter.skillPro      && e['event_skill_level_pro']      == true) ||
              (_filter.skillAmateur  && e['event_skill_level_amateur']   == true) ||
              (_filter.skillBeginner && e['event_skill_level_beginner']  == true);
      if (!match) return false;
    }

    if (_filter.catMx || _filter.catMd || _filter.catMs || _filter.catWs ||
        _filter.catWd || _filter.catSe || _filter.catJu || _filter.catCo) {
      final match =
          (_filter.catMx && e['event_category_mixeddoubles']  == true) ||
              (_filter.catMd && e['event_category_mensdoubles']   == true) ||
              (_filter.catMs && e['event_category_menssingle']    == true) ||
              (_filter.catWs && e['event_category_womenssingle']  == true) ||
              (_filter.catWd && e['event_category_womensdoubles'] == true) ||
              (_filter.catSe && e['event_category_seniors']       == true) ||
              (_filter.catJu && e['event_category_juniors']       == true) ||
              (_filter.catCo && e['event_category_collegiate']    == true);
      if (!match) return false;
    }

    if (_filter.tourist && e['event_touristfriendly'] != true) return false;

    return true;
  }

  // ── Enrich events with resolved location data ─────────────────────────────
  Future<List<Map<String, dynamic>>> _enrichEvents(
      List<Map<String, dynamic>> raw) async {
    final locIds = raw
        .map((e) => (e['event_loc_id'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final locCache = <String, Map<String, dynamic>>{};
    for (final locId in locIds) {
      try {
        final q1 = await FirebaseFirestore.instance
            .collection('locations')
            .where('loc_id', isEqualTo: locId)
            .limit(1)
            .get();
        if (q1.docs.isNotEmpty) {
          locCache[locId] = q1.docs.first.data();
          continue;
        }
        final doc = await FirebaseFirestore.instance
            .collection('locations')
            .doc(locId)
            .get();
        if (doc.exists) locCache[locId] = doc.data()!;
      } catch (_) {}
    }

    return raw.map((e) {
      final locId = (e['event_loc_id'] ?? '').toString().trim();
      final loc   = locId.isNotEmpty
          ? (locCache[locId] ?? <String, dynamic>{})
          : <String, dynamic>{};

      String get(String key) =>
          ((loc.isNotEmpty ? loc[key] : null) ?? e[key] ?? '')
              .toString().trim();

      final pref = [
        get('loc_prefecture_en'), get('loc_prefecture'),
        get('loc_prefecture_jp'), get('event_prefecture'),
        get('prefecture'), get('event_venue_address'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

      final resolvedCountry = get('loc_country');

      final cityEn  = get('loc_city_en');
      final cityFb  = get('loc_city');
      final city    = cityEn.isNotEmpty ? cityEn : cityFb;

      final label = city.isNotEmpty && pref.isNotEmpty
          ? '$city, $pref'
          : city.isNotEmpty ? city
          : pref.isNotEmpty ? pref
          : resolvedCountry;

      final googleLink = [
        get('loc_googlelink'), get('event_googlelink'),
        get('event_venue_link'),
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

      final orgName = [get('org_name'), get('event_org_name')]
          .firstWhere((v) => v.isNotEmpty, orElse: () => '');

      return {
        ...e,
        'location':            label.isNotEmpty ? label : get('event_venue_name'),
        'event_address':       get('loc_address').isNotEmpty
            ? get('loc_address') : get('event_venue_address'),
        'event_googlelink':    googleLink,
        'org_name':            orgName,
        '_resolvedPrefecture': pref,
        '_resolvedCountry':    resolvedCountry,
        '_resolvedCity':       city,
      };
    }).toList();
  }

  // ── Build location map from enriched events ───────────────────────────────
  Map<String, List<Map<String, String>>> _buildLocationMapFromEvents(
      List<Map<String, dynamic>> enrichedEvents) {
    final map = <String, List<Map<String, String>>>{};
    for (final e in enrichedEvents) {
      final country = (e['_resolvedCountry'] ?? '').toString().trim();
      if (country.isEmpty) continue;
      final pref = (e['_resolvedPrefecture'] ?? '').toString().trim();
      if (pref.isEmpty) continue;
      map.putIfAbsent(country, () => []);
      if (!map[country]!.any((p) => p['en'] == pref)) {
        map[country]!.add({'en': pref, 'jp': ''});
      }
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    for (final prefs in sorted.values) {
      prefs.sort((a, b) => a['en']!.compareTo(b['en']!));
    }
    return sorted;
  }

  // ── Build event map with multi-day spanning ───────────────────────────────
  Map<DateTime, List<Map<String, dynamic>>> _buildEventMap(
      List<Map<String, dynamic>> events) {
    final map = <DateTime, List<Map<String, dynamic>>>{};
    for (final e in events) {
      if (!_matchesAllFilters(e)) continue;

      final tsStart = e['event_date'] ?? e['event_start_date'];
      if (tsStart == null) continue;
      final dtStart  = (tsStart as Timestamp).toDate();
      final keyStart = DateTime(dtStart.year, dtStart.month, dtStart.day);

      final tsEnd = e['event_date_end'];
      final dtEnd = tsEnd != null
          ? (tsEnd as Timestamp).toDate()
          : DateTime(keyStart.year, keyStart.month, keyStart.day);
      final keyEnd = DateTime(dtEnd.year, dtEnd.month, dtEnd.day);

      DateTime current = keyStart;
      int loop = 0;
      while (!current.isAfter(keyEnd) && loop < 30) {
        final key = DateTime(current.year, current.month, current.day);
        map.putIfAbsent(key, () => []).add(e);
        current = current.add(const Duration(days: 1));
        loop++;
      }
    }
    return map;
  }

  List<Map<String, dynamic>> _eventsForDate(
      Map<DateTime, List<Map<String, dynamic>>> map, DateTime date) =>
      map[DateTime(date.year, date.month, date.day)] ?? [];

  void _prevMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1));

  void _nextMonth() => setState(() =>
  _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1));

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Could not open link'),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ));
    }
  }

  String _formatSelectedDate(DateTime d) =>
      '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';

  // ── Full filter modal ─────────────────────────────────────────────────────
  void _showFilterModal(List<Map<String, dynamic>> enrichedEvents) {
    _CalFilter temp = _filter;

    final locationMap = _buildLocationMapFromEvents(enrichedEvents);

    // Build city list from enriched events
    final cities = <String>{};
    for (final e in enrichedEvents) {
      final c = (e['_resolvedCity'] ?? '').toString().trim();
      if (c.isNotEmpty) cities.add(c);
    }
    final sortedCities = cities.toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {

          // ── Section label ───────────────────────────────────────────────
          Widget sectionLabel(String text) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Container(
                width: 3, height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(text,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800,
                      color: _textMid, letterSpacing: 0.8)),
            ]),
          );

          Widget divider() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: _borderMd),
          );

          // ── Checkbox pill ───────────────────────────────────────────────
          Widget checkPill(String label, bool value, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.primary.withOpacity(0.08) : _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: value
                        ? AppColors.primary.withOpacity(0.5) : _borderMd,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 15, height: 15,
                    decoration: BoxDecoration(
                      color: value ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: value ? AppColors.primary : _borderMd,
                          width: 1.5),
                    ),
                    child: value
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: value ? AppColors.primary : _textMid)),
                ]),
              ),
            );
          }

          // ── Dropdown field ──────────────────────────────────────────────
          Widget dropdownField(
              String label, String value,
              List<String> options, String allLabel,
              ValueChanged<String> onChange) {
            final hasVal = value.isNotEmpty;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 12,
                          fontWeight: FontWeight.w700, color: _textLight)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasVal
                          ? AppColors.primary.withOpacity(0.06) : _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasVal
                            ? AppColors.primary.withOpacity(0.4) : _borderMd,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: value.isEmpty ? '' : value,
                        isExpanded: true,
                        dropdownColor: _surface,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: hasVal ? AppColors.primary : _textLight,
                            size: 20),
                        style: TextStyle(
                            color: hasVal ? AppColors.primary : _textDark,
                            fontSize: 14, fontWeight: FontWeight.w500),
                        items: [
                          DropdownMenuItem(
                              value: '',
                              child: Text(allLabel,
                                  style: const TextStyle(color: _textLight))),
                          ...options.map((o) =>
                              DropdownMenuItem(value: o, child: Text(o))),
                        ],
                        onChanged: (v) => onChange(v ?? ''),
                      ),
                    ),
                  ),
                ]);
          }

          final availablePrefs = temp.country.isNotEmpty
              ? (locationMap[temp.country] ?? [])
              : <Map<String, String>>[];
          final sortedPrefs =
          availablePrefs.map((p) => p['en']!).toList()..sort();

          // ── Modal shell ─────────────────────────────────────────────────
          return Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _borderMd,
                    borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(children: [
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          color: _textDark, letterSpacing: -0.4)),
                  const Spacer(),
                  if (_filter.isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Active',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: _cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: _borderMd),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _textMid, size: 18),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _borderMd),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── LOCATION ─────────────────────────────────────────
                        sectionLabel('LOCATION'),
                        Row(children: [
                          Expanded(child: dropdownField(
                              'Country', temp.country,
                              locationMap.keys.toList(), 'All countries',
                                  (v) => setS(() => temp = temp.copyWith(
                                  country: v, prefecture: '', city: '')))),
                          const SizedBox(width: 12),
                          Expanded(child: dropdownField(
                              'Prefecture', temp.prefecture,
                              sortedPrefs, 'All',
                                  (v) => setS(() =>
                              temp = temp.copyWith(prefecture: v)))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: dropdownField(
                              'City', temp.city,
                              sortedCities, 'All',
                                  (v) => setS(() =>
                              temp = temp.copyWith(city: v)))),
                          const SizedBox(width: 12),
                          Expanded(child: dropdownField(
                              'Event Type', temp.type,
                              _eventTypes, 'All types',
                                  (v) => setS(() =>
                              temp = temp.copyWith(type: v)))),
                        ]),

                        divider(),

                        // ── SKILL LEVELS ──────────────────────────────────────
                        sectionLabel('SKILL LEVELS'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          checkPill('Pro', temp.skillPro, () => setS(() =>
                          temp = temp.copyWith(skillPro: !temp.skillPro))),
                          checkPill('Amateur', temp.skillAmateur, () => setS(() =>
                          temp = temp.copyWith(
                              skillAmateur: !temp.skillAmateur))),
                          checkPill('Beginner', temp.skillBeginner, () => setS(() =>
                          temp = temp.copyWith(
                              skillBeginner: !temp.skillBeginner))),
                        ]),

                        divider(),

                        // ── CATEGORIES ────────────────────────────────────────
                        sectionLabel('CATEGORIES'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          checkPill('Mixed Doubles', temp.catMx,
                                  () => setS(() =>
                              temp = temp.copyWith(catMx: !temp.catMx))),
                          checkPill("Men's Doubles", temp.catMd,
                                  () => setS(() =>
                              temp = temp.copyWith(catMd: !temp.catMd))),
                          checkPill("Women's Doubles", temp.catWd,
                                  () => setS(() =>
                              temp = temp.copyWith(catWd: !temp.catWd))),
                          checkPill("Men's Singles", temp.catMs,
                                  () => setS(() =>
                              temp = temp.copyWith(catMs: !temp.catMs))),
                          checkPill("Women's Singles", temp.catWs,
                                  () => setS(() =>
                              temp = temp.copyWith(catWs: !temp.catWs))),
                          checkPill('Seniors', temp.catSe,
                                  () => setS(() =>
                              temp = temp.copyWith(catSe: !temp.catSe))),
                          checkPill('Juniors', temp.catJu,
                                  () => setS(() =>
                              temp = temp.copyWith(catJu: !temp.catJu))),
                          checkPill('Collegiate', temp.catCo,
                                  () => setS(() =>
                              temp = temp.copyWith(catCo: !temp.catCo))),
                        ]),

                        divider(),

                        // ── OTHER ─────────────────────────────────────────────
                        sectionLabel('OTHER'),
                        checkPill('Tourist Friendly', temp.tourist,
                                () => setS(() =>
                            temp = temp.copyWith(tourist: !temp.tourist))),

                        const SizedBox(height: 28),

                        // ── Action buttons ────────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setS(() =>
                              temp = _CalFilter()),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: _borderMd, width: 1.5),
                                ),
                                child: const Center(
                                  child: Text('Clear All',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _textMid)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: GestureDetector(
                              onTap: () {
                                setState(() => _filter = temp);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary
                                          .withOpacity(0.30),
                                      blurRadius: 14,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('APPLY FILTERS',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.6)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ]),
                ),
              ),
            ]),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(calendarEventsProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: eventsAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (rawEvents) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _enrichEvents(rawEvents),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary));
              }
              final events       = snapshot.data ?? [];
              final eventMap     = _buildEventMap(events);
              final selectedEvts = _eventsForDate(eventMap, _selectedDate);

              return CustomScrollView(
                slivers: [
                  // ── App Bar ───────────────────────────────────────────
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: _surface,
                    elevation: 0,
                    scrolledUnderElevation: 0.5,
                    shadowColor: _border,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: _textDark, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: const Text('Calendar Events',
                        style: TextStyle(
                            color: _textDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3)),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => _showFilterModal(events),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _filter.isActive
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_rounded,
                                          size: 13,
                                          color: _filter.isActive
                                              ? Colors.white
                                              : AppColors.primary),
                                      const SizedBox(width: 4),
                                      Text(_locationLabel,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: _filter.isActive
                                                  ? Colors.white
                                                  : AppColors.primary)),
                                      const SizedBox(width: 2),
                                      Icon(Icons.keyboard_arrow_down_rounded,
                                          size: 14,
                                          color: _filter.isActive
                                              ? Colors.white
                                              : AppColors.primary),
                                    ]),
                              ),
                              // Orange dot when non-location filters active
                              if (_filter.hasNonLocationFilters)
                                Positioned(
                                  top: -3, right: -3,
                                  child: Container(
                                    width: 10, height: 10,
                                    decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle),
                                    child: Center(
                                        child: Container(
                                            width: 7, height: 7,
                                            decoration: const BoxDecoration(
                                                color: Colors.orange,
                                                shape: BoxShape.circle))),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    bottom: PreferredSize(
                      preferredSize: const Size.fromHeight(1),
                      child: Container(height: 1, color: _border),
                    ),
                  ),

                  // ── Body ─────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: SlideTransition(
                        position: _slideAnim,
                        child: Column(children: [

                          // ── Calendar Card ─────────────────────────────
                          Container(
                            margin:
                            const EdgeInsets.fromLTRB(16, 20, 16, 0),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(children: [

                              // Month navigation
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    8, 18, 8, 10),
                                child: Row(
                                  mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                                  children: [
                                    IconButton(
                                      onPressed: _prevMonth,
                                      icon: const Icon(
                                          Icons.chevron_left_rounded,
                                          color: AppColors.primary,
                                          size: 28),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                    Text(
                                      '${_monthNames[_focusedMonth.month - 1]} ${_focusedMonth.year}',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: _textDark,
                                          letterSpacing: -0.3),
                                    ),
                                    IconButton(
                                      onPressed: _nextMonth,
                                      icon: const Icon(
                                          Icons.chevron_right_rounded,
                                          color: AppColors.primary,
                                          size: 28),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                    ),
                                  ],
                                ),
                              ),

                              // Weekday headers
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12),
                                child: Row(
                                  children: _weekdays
                                      .map((d) => Expanded(
                                    child: Center(
                                      child: Text(d,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight:
                                              FontWeight.w700,
                                              color: Colors
                                                  .grey.shade400,
                                              letterSpacing: 0.5)),
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Grid
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 16),
                                child: _buildGrid(eventMap),
                              ),
                            ]),
                          ),

                          const SizedBox(height: 20),

                          // ── Selected date header ──────────────────────
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                16, 0, 16, 12),
                            child: Row(children: [
                              Container(
                                width: 4, height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatSelectedDate(_selectedDate),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: _textDark),
                              ),
                              const Spacer(),
                              if (selectedEvts.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withOpacity(0.1),
                                    borderRadius:
                                    BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    '${selectedEvts.length} event${selectedEvts.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary),
                                  ),
                                ),
                            ]),
                          ),

                          // ── Events or empty state ─────────────────────
                          if (selectedEvts.isEmpty)
                            _buildEmptyState()
                          else
                            ...selectedEvts.map((e) => _EventCard(
                              event: e,
                              onOpenLink: _openLink,
                            )),

                          const SizedBox(height: 40),
                        ]),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Calendar grid ─────────────────────────────────────────────────────────
  Widget _buildGrid(
      Map<DateTime, List<Map<String, dynamic>>> eventMap) {
    final firstDay    = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final daysInMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    final startWeekday = firstDay.weekday % 7;
    final todayNorm    = DateTime.now();
    final todayKey =
    DateTime(todayNorm.year, todayNorm.month, todayNorm.day);

    final cells = <Widget>[];
    for (int i = 0; i < startWeekday; i++) cells.add(const SizedBox());

    for (int day = 1; day <= daysInMonth; day++) {
      final date      = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final dayEvents = _eventsForDate(eventMap, date);
      final hasEvents = dayEvents.isNotEmpty;
      final isToday   = date == todayKey;
      final isSelected = date ==
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final isPast = date.isBefore(todayKey);

      cells.add(GestureDetector(
        onTap: () => setState(() => _selectedDate = date),
        child: hasEvents
            ? _EventThumbCell(
            day: day, events: dayEvents,
            isSelected: isSelected, isToday: isToday)
            : _EmptyDayCell(
            day: day, isSelected: isSelected,
            isToday: isToday, isPast: isPast),
      ));
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: cells,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Icon(Icons.event_available_rounded,
            color: Colors.grey.shade300, size: 32),
        const SizedBox(width: 16),
        Text('No events on this day',
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar cell: day with event thumbnail
// ─────────────────────────────────────────────────────────────────────────────
class _EventThumbCell extends StatelessWidget {
  final int day;
  final List<Map<String, dynamic>> events;
  final bool isSelected;
  final bool isToday;

  const _EventThumbCell({
    required this.day, required this.events,
    required this.isSelected, required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final count    = events.length;
    final imageUrl = (events.first['event_pic'] ??
        events.first['event_pic_thumbnail'] ??
        events.first['event_image'] ?? '')
        .toString();

    return Container(
      margin: const EdgeInsets.all(2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(fit: StackFit.expand, children: [
          imageUrl.isNotEmpty
              ? Image.network(imageUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withOpacity(0.12),
                child: const Icon(Icons.event,
                    size: 16, color: AppColors.primary),
              ))
              : Container(
            color: AppColors.primary.withOpacity(0.12),
            child: const Icon(Icons.event,
                size: 16, color: AppColors.primary),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.06),
                  Colors.black.withOpacity(0.50),
                ],
              ),
            ),
          ),
          if (isSelected)
            Container(color: AppColors.primary.withOpacity(0.52)),
          Positioned(
            left: 5, bottom: 4,
            child: Text('$day',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [
                      Shadow(color: Colors.black54,
                          blurRadius: 4, offset: Offset(0, 1))
                    ])),
          ),
          Positioned(
            top: 4, right: 4,
            child: Container(
              width: 16, height: 16,
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2),
                      blurRadius: 4, offset: const Offset(0, 1)),
                ],
              ),
              child: Center(
                child: Text('$count',
                    style: TextStyle(
                        fontSize: 8, fontWeight: FontWeight.w900,
                        color: isSelected
                            ? AppColors.primary : Colors.white)),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Calendar cell: empty day
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyDayCell extends StatelessWidget {
  final int  day;
  final bool isSelected;
  final bool isToday;
  final bool isPast;

  const _EmptyDayCell({
    required this.day, required this.isSelected,
    required this.isToday, required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : isToday
            ? AppColors.primary.withOpacity(0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isToday && !isSelected
            ? Border.all(
            color: AppColors.primary.withOpacity(0.35), width: 1.5)
            : null,
      ),
      child: Center(
        child: Text('$day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected || isToday
                  ? FontWeight.w800 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isPast
                  ? Colors.grey.shade300
                  : const Color(0xFF1A1A1A),
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event card
// ─────────────────────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final Future<void> Function(String) onOpenLink;

  const _EventCard({required this.event, required this.onOpenLink});

  String get _title =>
      (event['event_title_en'] ?? event['event_title'] ?? 'Untitled Event')
          .toString();
  String get _imageUrl =>
      (event['event_pic'] ?? event['event_pic_thumbnail'] ??
          event['event_image'] ?? '').toString();
  String get _url =>
      (event['event_link'] ?? event['event_url'] ?? '').toString();
  String get _fee {
    final f = event['event_fee'];
    if (f == null || f.toString().isEmpty ||
        f.toString() == '0' || f.toString() == '0.0') return 'Free';
    return '¥${f.toString()}';
  }
  String get _time {
    final raw = event['event_time'] ?? event['event_start_time'];
    if (raw == null) return '';
    if (raw is Timestamp) return DateFormat('h:mm a').format(raw.toDate());
    return raw.toString();
  }
  String get _location =>
      (event['location'] ?? event['event_venue_name'] ?? '').toString();
  String get _address =>
      (event['event_address'] ?? event['event_venue_address'] ?? '')
          .toString();
  String get _googleLink =>
      (event['event_googlelink'] ?? event['event_venue_link'] ?? '').toString();
  String get _orgName =>
      (event['org_name'] ?? event['event_org_name'] ?? '').toString();

  static const Color _surface  = Colors.white;
  static const Color _border   = Color(0xFFEEEFF1);
  static const Color _textDark = Color(0xFF0D0D0D);

  @override
  Widget build(BuildContext context) {
    final isFree     = _fee == 'Free';
    final hasImage   = _imageUrl.isNotEmpty;
    final hasTime    = _time.isNotEmpty;
    final hasLoc     = _location.isNotEmpty || _address.isNotEmpty;
    final hasOrg     = _orgName.isNotEmpty;
    final hasLink    = _url.isNotEmpty;
    final hasGMap    = _googleLink.isNotEmpty;
    final locDisplay = _location.isNotEmpty ? _location : _address;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04),
              blurRadius: 14, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (hasImage)
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 7,
              child: Image.network(_imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary.withOpacity(0.08),
                    child: const Icon(Icons.event,
                        size: 40, color: AppColors.primary),
                  )),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Text(_title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w800,
                            color: _textDark, letterSpacing: -0.2)),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isFree
                          ? Colors.green.shade50
                          : AppColors.primary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(_fee,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: isFree
                                ? Colors.green.shade600
                                : AppColors.primary)),
                  ),
                ]),
                if (hasTime) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Text(_time,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500)),
                  ]),
                ],
                if (hasLoc) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: hasGMap ? () => onOpenLink(_googleLink) : null,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 14,
                              color: hasGMap
                                  ? AppColors.primary : Colors.grey.shade400),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(locDisplay,
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                  color: hasGMap
                                      ? AppColors.primary : Colors.grey.shade500,
                                  decoration: hasGMap
                                      ? TextDecoration.underline
                                      : TextDecoration.none,
                                  decorationColor: AppColors.primary,
                                )),
                          ),
                          if (hasGMap) ...[
                            const SizedBox(width: 4),
                            Icon(Icons.open_in_new_rounded,
                                size: 12, color: AppColors.primary),
                          ],
                        ]),
                  ),
                ],
                if (hasOrg) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(_orgName,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500)),
                    ),
                  ]),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasLink ? () => onOpenLink(_url) : null,
                    icon: const Icon(Icons.open_in_new_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('More Information',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade400,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared location picker sub-widgets
// ─────────────────────────────────────────────────────────────────────────────
class _LocationDropdown extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final bool          hasValue;
  final bool          enabled;
  final VoidCallback? onTap;

  const _LocationDropdown({
    required this.icon, required this.label, required this.hasValue,
    this.enabled = true, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = hasValue && enabled;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary.withOpacity(0.06)
              : const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active
                  ? AppColors.primary.withOpacity(0.5)
                  : const Color(0xFFDDDEE1),
              width: 1.5),
        ),
        child: Row(children: [
          Icon(icon, size: 16,
              color: active ? AppColors.primary
                  : enabled ? const Color(0xFF555760)
                  : const Color(0xFFBBBCC0)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: active ? AppColors.primary
                          : enabled ? const Color(0xFF333438)
                          : const Color(0xFFBBBCC0)))),
          Icon(Icons.keyboard_arrow_down_rounded, size: 18,
              color: active ? AppColors.primary
                  : enabled ? const Color(0xFF888A90)
                  : const Color(0xFFBBBCC0)),
        ]),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isHeader;
  final bool isSelected;
  final VoidCallback onTap;

  const _PickerRow({
    required this.label, this.sublabel,
    required this.isHeader, required this.isSelected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: isSelected ? const Color(0xFFE8E8E2) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Row(children: [
          Expanded(
            child: sublabel != null
                ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: isHeader ? 14 : 16,
                          fontWeight: isHeader
                              ? FontWeight.w500 : FontWeight.w600,
                          color: isHeader
                              ? const Color(0xFF888880)
                              : const Color(0xFF1A1A1A),
                          letterSpacing: -0.2)),
                  Text(sublabel!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF888880),
                          fontWeight: FontWeight.w400)),
                ])
                : Text(label,
                style: TextStyle(
                    fontSize: isHeader ? 14 : 16,
                    fontWeight: isHeader
                        ? FontWeight.w500 : FontWeight.w600,
                    color: isHeader
                        ? const Color(0xFF888880)
                        : const Color(0xFF1A1A1A),
                    letterSpacing: -0.2)),
          ),
          if (isSelected)
            Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
        ]),
      ),
    );
  }
}

class _PickerDivider extends StatelessWidget {
  const _PickerDivider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDD5));
}