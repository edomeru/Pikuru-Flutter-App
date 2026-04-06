import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/event_card_full.dart';
import 'package:pikuru/screens/calendar_events_screen.dart';
import 'package:pikuru/screens/choose_date_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pikuru/screens/add_event_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Advanced filter state
// ─────────────────────────────────────────────────────────────────────────────
class _AdvFilter {
  String    datePreset;
  DateTime? dateStart;
  DateTime? dateEnd;
  String    country;
  String    prefecture;
  String    city;
  String    type;
  bool skillPro;
  bool skillAmateur;
  bool skillBeginner;
  bool catMx, catMd, catMs, catWs, catWd, catSe, catJu, catCo;
  bool tourist;

  _AdvFilter({
    this.datePreset    = '',
    this.dateStart,
    this.dateEnd,
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

  _AdvFilter copyWith({
    String?   datePreset,
    DateTime? dateStart,
    DateTime? dateEnd,
    bool      clearDates = false,
    String?   country,
    String?   prefecture,
    String?   city,
    String?   type,
    bool? skillPro, bool? skillAmateur, bool? skillBeginner,
    bool? catMx, bool? catMd, bool? catMs, bool? catWs,
    bool? catWd, bool? catSe, bool? catJu, bool? catCo,
    bool? tourist,
  }) => _AdvFilter(
    datePreset:    datePreset    ?? this.datePreset,
    dateStart:     clearDates ? null : (dateStart ?? this.dateStart),
    dateEnd:       clearDates ? null : (dateEnd   ?? this.dateEnd),
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

  bool get isActive =>
      datePreset.isNotEmpty || country.isNotEmpty || prefecture.isNotEmpty ||
          city.isNotEmpty || type.isNotEmpty ||
          skillPro || skillAmateur || skillBeginner ||
          catMx || catMd || catMs || catWs || catWd || catSe || catJu || catCo ||
          tourist;

  _AdvFilter get cleared => _AdvFilter();
}

// ─────────────────────────────────────────────────────────────────────────────
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();

  String    _selectedFilter    = 'Upcoming';
  DateTime? _customStart;
  DateTime? _customEnd;
  String?   _selectedCountry    = 'Japan';
  String?   _selectedPrefecture = 'Tokyo';
  _AdvFilter _adv = _AdvFilter();

  bool get _hasCustomRange  => _customStart != null;
  bool get _isDefaultState  =>
      _selectedFilter == 'Upcoming' && !_hasCustomRange &&
          _selectedCountry == 'Japan'   && _selectedPrefecture == 'Tokyo' &&
          !_adv.isActive;

  static const int _defaultDays = 30;
  static const _filterOptions = [
    ('Upcoming',  Icons.bolt_rounded),
    ('Today',     Icons.wb_sunny_rounded),
    ('Tomorrow',  Icons.arrow_forward_rounded),
    ('This Week', Icons.date_range_rounded),
    ('Weekend',   Icons.weekend_rounded),
  ];

  static const List<String> _eventTypes = [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];

  // ── shared colours (light mode) ───────────────────────────────────────────
  static const Color _bg        = Color(0xFFF7F8FA);
  static const Color _surface   = Colors.white;
  static const Color _cardBg    = Color(0xFFF2F3F5);
  static const Color _border    = Color(0xFFDDDEE1);
  static const Color _textDark  = Color(0xFF0D0D0D);
  static const Color _textMid   = Color(0xFF555760);
  static const Color _textLight = Color(0xFF888A90);

  // ─────────────────────────────────────────────────────────────────────────
  Map<String, List<Map<String, String>>> _buildLocationMap(
      List<Map<String, dynamic>> locs) {
    final map = <String, List<Map<String, String>>>{};
    for (final loc in locs) {
      final country = (loc['loc_country'] ?? '').toString().trim();
      if (country.isEmpty) continue;
      final prefEn = ((loc['loc_prefecture_en'] ?? '').toString().trim().isNotEmpty
          ? loc['loc_prefecture_en']
          : loc['loc_prefecture'] ?? '')
          .toString()
          .trim();
      final prefJp = (loc['loc_prefecture_jp'] ?? '').toString().trim();
      if (prefEn.isEmpty) continue;
      map.putIfAbsent(country, () => []);
      if (!map[country]!.any((p) => p['en'] == prefEn)) {
        map[country]!.add({'en': prefEn, 'jp': prefJp});
      }
    }
    final sorted = Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
    for (final prefs in sorted.values) {
      prefs.sort((a, b) => a['en']!.compareTo(b['en']!));
    }
    return sorted;
  }

  String get _locationLabel {
    if (_selectedPrefecture != null) return _selectedPrefecture!;
    if (_selectedCountry != null) return _selectedCountry!;
    return 'All Countries';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Location matching
  // ─────────────────────────────────────────────────────────────────────────
  bool _matchesLocation(
      Map<String, dynamic> event, List<Map<String, dynamic>> allLocs) {
    if (_selectedCountry == null && _adv.country.isEmpty) return true;
    final targetCountry =
    (_adv.country.isNotEmpty ? _adv.country : _selectedCountry ?? '')
        .toLowerCase();
    final targetPref = (_adv.prefecture.isNotEmpty
        ? _adv.prefecture
        : _selectedPrefecture)
        ?.toLowerCase();

    final locId =
    (event['loc_id'] ?? event['event_loc_id'] ?? '').toString().trim();
    Map<String, dynamic> loc = {};
    if (locId.isNotEmpty) {
      loc = allLocs.firstWhere(
              (l) => (l['loc_id'] ?? l['id'] ?? '').toString() == locId,
          orElse: () => {});
    }

    String get(String key) =>
        ((loc.isNotEmpty ? loc[key] : null) ?? event[key] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final country = get('loc_country');
    if (country.isEmpty ||
        (!country.contains(targetCountry) &&
            !targetCountry.contains(country))) return false;
    if (targetPref == null || targetPref.isEmpty) return true;

    for (final key in [
      'loc_prefecture_en', 'loc_prefecture_jp', 'loc_prefecture',
      'event_prefecture', 'prefecture',
    ]) {
      final v = get(key);
      if (v.isNotEmpty && (v.contains(targetPref) || targetPref.contains(v))) {
        return true;
      }
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Filter logic
  // ─────────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> events, List<Map<String, dynamic>> allLocs) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final tomorrow  = today.add(const Duration(days: 1));
    final defaultEnd = today.add(const Duration(days: _defaultDays));
    final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday  = today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    final sunday    = saturday.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - now.weekday));
    final q = _searchController.text.toLowerCase().trim();

    return events.where((e) {
      if (q.isNotEmpty) {
        final title = (e['event_title'] ?? '').toString().toLowerCase();
        final type  = (e['event_type']  ?? '').toString().toLowerCase();
        if (!title.contains(q) && !type.contains(q)) return false;
      }
      if (!_matchesLocation(e, allLocs)) return false;

      final raw = e['event_date'];
      DateTime? d;
      if (raw is Timestamp) d = raw.toDate();
      else if (raw is String && raw.isNotEmpty) {
        try { d = DateTime.parse(raw); } catch (_) {}
      }
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);

      final preset = _adv.datePreset;
      if (preset.isNotEmpty) {
        switch (preset) {
          case 'today':
            if (!_isSameDay(day, today)) return false;
          case 'tomorrow':
            if (!_isSameDay(day, tomorrow)) return false;
          case 'this_week':
            if (day.isBefore(today) || day.isAfter(endOfWeek)) return false;
          case 'weekend':
            if (!_isSameDay(day, saturday) && !_isSameDay(day, sunday)) return false;
          case 'custom':
            if (_adv.dateStart != null && day.isBefore(_adv.dateStart!)) return false;
            if (_adv.dateEnd   != null && day.isAfter(_adv.dateEnd!))    return false;
        }
      } else if (_hasCustomRange) {
        final end = _customEnd ?? _customStart!;
        if (day.isBefore(_customStart!) || day.isAfter(end)) return false;
      } else {
        switch (_selectedFilter) {
          case 'Today':    if (!_isSameDay(day, today))    return false;
          case 'Tomorrow': if (!_isSameDay(day, tomorrow)) return false;
          case 'This Week':
            if (day.isBefore(today) || day.isAfter(endOfWeek)) return false;
          case 'Weekend':
            if (!_isSameDay(day, saturday) && !_isSameDay(day, sunday)) return false;
          default:
            if (day.isBefore(today) || day.isAfter(defaultEnd)) return false;
        }
      }

      if (_adv.type.isNotEmpty &&
          (e['event_type'] ?? '').toString() != _adv.type) return false;

      if (_adv.skillPro || _adv.skillAmateur || _adv.skillBeginner) {
        final match =
            (_adv.skillPro      && e['event_skill_level_pro']      == true) ||
                (_adv.skillAmateur  && e['event_skill_level_amateur']   == true) ||
                (_adv.skillBeginner && e['event_skill_level_beginner']  == true);
        if (!match) return false;
      }

      if (_adv.catMx || _adv.catMd || _adv.catMs || _adv.catWs ||
          _adv.catWd || _adv.catSe || _adv.catJu || _adv.catCo) {
        final match =
            (_adv.catMx && e['event_category_mixeddoubles']  == true) ||
                (_adv.catMd && e['event_category_mensdoubles']   == true) ||
                (_adv.catMs && e['event_category_menssingle']    == true) ||
                (_adv.catWs && e['event_category_womenssingle']  == true) ||
                (_adv.catWd && e['event_category_womensdoubles'] == true) ||
                (_adv.catSe && e['event_category_seniors']       == true) ||
                (_adv.catJu && e['event_category_juniors']       == true) ||
                (_adv.catCo && e['event_category_collegiate']    == true);
        if (!match) return false;
      }

      if (_adv.tourist && e['event_touristfriendly'] != true) return false;
      return true;
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ─────────────────────────────────────────────────────────────────────────
  // ADVANCED FILTER MODAL — light mode, consistent with app design
  // ─────────────────────────────────────────────────────────────────────────
  void _showFilterModal() {
    _AdvFilter temp = _adv.copyWith();

    final allLocs     = ref.read(locationsProvider).asData?.value ?? [];
    final countries   = <String>{};
    final prefectures = <String>{};
    final cities      = <String>{};
    for (final loc in allLocs) {
      final c  = (loc['loc_country']      ?? '').toString().trim();
      final p  = (loc['loc_prefecture_en'] ?? loc['loc_prefecture'] ?? '').toString().trim();
      final ci = (loc['loc_city_en']       ?? loc['loc_city'] ?? '').toString().trim();
      if (c.isNotEmpty)  countries.add(c);
      if (p.isNotEmpty)  prefectures.add(p);
      if (ci.isNotEmpty) cities.add(ci);
    }
    final sortedCountries   = countries.toList()  ..sort();
    final sortedPrefectures = prefectures.toList()..sort();
    final sortedCities      = cities.toList()     ..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setS) {

          // ── Section label ─────────────────────────────────────────────────
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
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _textMid,
                      letterSpacing: 0.8)),
            ]),
          );

          // ── Divider ───────────────────────────────────────────────────────
          Widget divider() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: _border),
          );

          // ── Date preset row ───────────────────────────────────────────────
          Widget dateRow(String id, String label, IconData icon) {
            final sel = temp.datePreset == id;
            return GestureDetector(
              onTap: () => setS(() => temp = temp.copyWith(datePreset: id)),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary.withOpacity(0.07)
                      : _cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary.withOpacity(0.4)
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.primary.withOpacity(0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16,
                        color: sel ? AppColors.primary : _textLight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? AppColors.primary : _textDark)),
                  ),
                  // Radio dot
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: sel ? AppColors.primary : _border, width: 2),
                    ),
                    child: sel
                        ? Center(
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle),
                      ),
                    )
                        : null,
                  ),
                ]),
              ),
            );
          }

          // ── Checkbox pill ─────────────────────────────────────────────────
          Widget checkPill(String label, bool value, VoidCallback onTap) {
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: value
                      ? AppColors.primary.withOpacity(0.08)
                      : _cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: value
                        ? AppColors.primary.withOpacity(0.5)
                        : _border,
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
                          color: value ? AppColors.primary : _border,
                          width: 1.5),
                    ),
                    child: value
                        ? const Icon(Icons.check, size: 10, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: value ? AppColors.primary : _textMid)),
                ]),
              ),
            );
          }

          // ── Dropdown field ────────────────────────────────────────────────
          Widget dropdownField(
              String label,
              String value,
              List<String> options,
              String allLabel,
              ValueChanged<String> onChange) {
            final hasVal = value.isNotEmpty;
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _textLight)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: hasVal
                          ? AppColors.primary.withOpacity(0.06)
                          : _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasVal
                            ? AppColors.primary.withOpacity(0.4)
                            : _border,
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
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
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

          // ── Modal shell ───────────────────────────────────────────────────
          return Container(
            constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2)),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                child: Row(children: [
                  const Text('Filters',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textDark,
                          letterSpacing: -0.4)),
                  const Spacer(),
                  // Active filter count badge
                  if (_adv.isActive) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Active',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _textMid, size: 18),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _border),

              // Scrollable body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── DATE ─────────────────────────────────────────────────
                        sectionLabel('DATE'),
                        dateRow('',          'Any time',           Icons.access_time_rounded),
                        dateRow('today',     'Today',              Icons.wb_sunny_rounded),
                        dateRow('tomorrow',  'Tomorrow',           Icons.arrow_forward_rounded),
                        dateRow('this_week', 'This Week',          Icons.date_range_rounded),
                        dateRow('weekend',   'Weekend',            Icons.weekend_rounded),
                        dateRow('custom',    'Custom Date Range',  Icons.calendar_month_rounded),

                        if (temp.datePreset == 'custom') ...[
                          const SizedBox(height: 12),
                          Row(children: [
                            Expanded(child: _LightDatePickerField(
                              label: 'Start Date',
                              value: temp.dateStart,
                              onPicked: (d) =>
                                  setS(() => temp = temp.copyWith(dateStart: d)),
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _LightDatePickerField(
                              label: 'End Date',
                              value: temp.dateEnd,
                              onPicked: (d) =>
                                  setS(() => temp = temp.copyWith(dateEnd: d)),
                            )),
                          ]),
                        ],

                        divider(),

                        // ── LOCATION ──────────────────────────────────────────────
                        sectionLabel('LOCATION'),
                        Row(children: [
                          Expanded(child: dropdownField(
                              'Country', temp.country, sortedCountries, 'All countries',
                                  (v) => setS(() => temp = temp.copyWith(country: v)))),
                          const SizedBox(width: 12),
                          Expanded(child: dropdownField(
                              'Prefecture', temp.prefecture, sortedPrefectures, 'All',
                                  (v) => setS(() => temp = temp.copyWith(prefecture: v)))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(child: dropdownField(
                              'City', temp.city, sortedCities, 'All',
                                  (v) => setS(() => temp = temp.copyWith(city: v)))),
                          const SizedBox(width: 12),
                          Expanded(child: dropdownField(
                              'Event Type', temp.type, _eventTypes, 'All types',
                                  (v) => setS(() => temp = temp.copyWith(type: v)))),
                        ]),

                        divider(),

                        // ── SKILL LEVELS ──────────────────────────────────────────
                        sectionLabel('SKILL LEVELS'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          checkPill('Pro',      temp.skillPro,
                                  () => setS(() => temp = temp.copyWith(skillPro:      !temp.skillPro))),
                          checkPill('Amateur',  temp.skillAmateur,
                                  () => setS(() => temp = temp.copyWith(skillAmateur:  !temp.skillAmateur))),
                          checkPill('Beginner', temp.skillBeginner,
                                  () => setS(() => temp = temp.copyWith(skillBeginner: !temp.skillBeginner))),
                        ]),

                        divider(),

                        // ── CATEGORIES ────────────────────────────────────────────
                        sectionLabel('CATEGORIES'),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          checkPill('Mixed Doubles',   temp.catMx,
                                  () => setS(() => temp = temp.copyWith(catMx: !temp.catMx))),
                          checkPill("Men's Doubles",   temp.catMd,
                                  () => setS(() => temp = temp.copyWith(catMd: !temp.catMd))),
                          checkPill("Women's Doubles", temp.catWd,
                                  () => setS(() => temp = temp.copyWith(catWd: !temp.catWd))),
                          checkPill("Men's Singles",   temp.catMs,
                                  () => setS(() => temp = temp.copyWith(catMs: !temp.catMs))),
                          checkPill("Women's Singles", temp.catWs,
                                  () => setS(() => temp = temp.copyWith(catWs: !temp.catWs))),
                          checkPill('Seniors',         temp.catSe,
                                  () => setS(() => temp = temp.copyWith(catSe: !temp.catSe))),
                          checkPill('Juniors',         temp.catJu,
                                  () => setS(() => temp = temp.copyWith(catJu: !temp.catJu))),
                          checkPill('Collegiate',      temp.catCo,
                                  () => setS(() => temp = temp.copyWith(catCo: !temp.catCo))),
                        ]),

                        divider(),

                        // ── OTHER ─────────────────────────────────────────────────
                        sectionLabel('OTHER'),
                        checkPill('Tourist Friendly', temp.tourist,
                                () => setS(() =>
                            temp = temp.copyWith(tourist: !temp.tourist))),

                        const SizedBox(height: 28),

                        // ── Action buttons ────────────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setS(() => temp = _AdvFilter()),
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _border, width: 1.5),
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
                                setState(() => _adv = temp);
                                Navigator.pop(ctx);
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.30),
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
  // Legacy location-picker modal (kept unchanged)
  // ─────────────────────────────────────────────────────────────────────────
  void _showLegacyFilterModal() {
    String    tempFilter     = _selectedFilter;
    DateTime? tempStart      = _customStart;
    DateTime? tempEnd        = _customEnd;
    String?   tempCountry    = _selectedCountry;
    String?   tempPrefecture = _selectedPrefecture;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          final hasRange    = tempStart != null;
          final fmt         = DateFormat('MM/dd/yyyy');
          final allLocs     = ref.watch(locationsProvider).asData?.value ?? [];
          final locationMap = _buildLocationMap(allLocs);
          final availablePrefs = tempCountry != null
              ? (locationMap[tempCountry] ?? [])
              : <Map<String, String>>[];

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800,
                              color: Color(0xFF0D0D0D), letterSpacing: -0.4)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              shape: BoxShape.circle),
                          child: Icon(Icons.close_rounded,
                              color: AppColors.primary, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Icon(Icons.location_on_rounded,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    const Text('Location',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: Color(0xFF0D0D0D))),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _LocationDropdown(
                      icon: Icons.public_rounded,
                      label: tempCountry ?? 'Country',
                      hasValue: tempCountry != null,
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.25),
                          builder: (_) => _CountryPickerDialog(
                            countries: locationMap.keys.toList(),
                            currentCountry: tempCountry,
                            onSelected: (c) => setModalState(() {
                              tempCountry = c;
                              if (c == null) {
                                tempPrefecture = null;
                              } else if (!(locationMap[c] ?? [])
                                  .any((p) => p['en'] == tempPrefecture)) {
                                tempPrefecture = null;
                              }
                            }),
                          ),
                        );
                      },
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _LocationDropdown(
                      icon: Icons.location_on_rounded,
                      label: tempPrefecture ?? 'Area',
                      hasValue: tempPrefecture != null,
                      enabled: tempCountry != null,
                      onTap: tempCountry == null ? null : () {
                        showDialog(
                          context: context,
                          barrierColor: Colors.black.withOpacity(0.25),
                          builder: (_) => _PrefecturePickerDialog(
                            country: tempCountry!,
                            prefectures: availablePrefs,
                            currentPrefecture: tempPrefecture,
                            onSelected: (p) =>
                                setModalState(() => tempPrefecture = p),
                          ),
                        );
                      },
                    )),
                  ]),
                  const SizedBox(height: 24),
                  const Text('DATE',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFF888A90), letterSpacing: 1.0)),
                  const SizedBox(height: 12),
                  ..._filterOptions.map((opt) {
                    final label    = opt.$1;
                    final icon     = opt.$2;
                    final isSel    = !hasRange && tempFilter == label;
                    final subtitle = label == 'Upcoming'
                        ? 'Today → next $_defaultDays days'
                        : null;
                    return GestureDetector(
                      onTap: () => setModalState(() {
                        tempFilter = label;
                        tempStart  = null;
                        tempEnd    = null;
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary.withOpacity(0.07)
                              : const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: isSel
                                  ? AppColors.primary.withOpacity(0.4)
                                  : Colors.transparent,
                              width: 1.5),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(9)),
                            child: Icon(icon,
                                size: 16,
                                color: isSel
                                    ? AppColors.primary
                                    : const Color(0xFF888A90)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: subtitle != null
                                ? Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSel
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSel
                                              ? AppColors.primary
                                              : const Color(0xFF0D0D0D))),
                                  Text(subtitle,
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isSel
                                              ? AppColors.primary
                                              .withOpacity(0.6)
                                              : const Color(0xFF999BA0))),
                                ])
                                : Text(label,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? AppColors.primary
                                        : const Color(0xFF0D0D0D))),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: isSel
                                        ? AppColors.primary
                                        : const Color(0xFFCCCDD0),
                                    width: 2)),
                            child: isSel
                                ? Center(
                                child: Container(
                                    width: 9, height: 9,
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary)))
                                : null,
                          ),
                        ]),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final result =
                      await Navigator.push<Map<String, DateTime?>>(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => ChooseDateScreen(
                                initialStart: tempStart,
                                initialEnd: tempEnd)),
                      );
                      if (result != null) {
                        setModalState(() {
                          tempStart  = result['start'];
                          tempEnd    = result['end'];
                          tempFilter = 'Upcoming';
                        });
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: hasRange
                            ? AppColors.primary.withOpacity(0.07)
                            : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: hasRange
                                ? AppColors.primary.withOpacity(0.4)
                                : Colors.transparent,
                            width: 1.5),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              color: hasRange
                                  ? AppColors.primary.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(Icons.calendar_month_rounded,
                              size: 16,
                              color: hasRange
                                  ? AppColors.primary
                                  : const Color(0xFF888A90)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: hasRange
                              ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Custom date range',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary)),
                                const SizedBox(height: 2),
                                Text(
                                    tempEnd != null &&
                                        !_isSameDay(
                                            tempStart!, tempEnd!)
                                        ? '${fmt.format(tempStart!)}  →  ${fmt.format(tempEnd!)}'
                                        : fmt.format(tempStart!),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary
                                            .withOpacity(0.7))),
                              ])
                              : const Text('Choose a date',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0D0D0D))),
                        ),
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: hasRange
                                      ? AppColors.primary
                                      : const Color(0xFFCCCDD0),
                                  width: 1.5)),
                          child: Icon(
                              hasRange
                                  ? Icons.edit_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 14,
                              color: hasRange
                                  ? AppColors.primary
                                  : const Color(0xFF888A90)),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() {
                          tempFilter     = 'Upcoming';
                          tempStart      = null;
                          tempEnd        = null;
                          tempCountry    = 'Japan';
                          tempPrefecture = 'Tokyo';
                        }),
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                              child: Text('Reset',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedFilter     = tempFilter;
                            _customStart        = tempStart;
                            _customEnd          = tempEnd;
                            _selectedCountry    = tempCountry;
                            _selectedPrefecture = tempPrefecture;
                          });
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4))
                            ],
                          ),
                          child: const Center(
                              child: Text('APPLY',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.8))),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showAddButton = ref.watch(showAddEventButtonProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Stack(children: [
          Column(children: [
            _buildHeader(),
            Expanded(child: _buildEventsList()),
          ]),
          if (showAddButton)
            Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _buildAddEventButton())),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    final fmt = DateFormat('MMM d');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Events',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D),
                            letterSpacing: -0.5)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _activeBadge(
                          icon: Icons.location_on_rounded,
                          label: _locationLabel,
                          onTap: _showLegacyFilterModal),
                      if (_hasCustomRange)
                        _activeBadge(
                          icon: Icons.calendar_today_rounded,
                          label: _customEnd != null &&
                              !_isSameDay(_customStart!, _customEnd!)
                              ? '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}'
                              : fmt.format(_customStart!),
                          onTap: () => setState(() {
                            _customStart    = null;
                            _customEnd      = null;
                            _selectedFilter = 'Upcoming';
                          }),
                          showClose: true,
                        ),
                      if (_adv.isActive)
                        _activeBadge(
                          icon: Icons.filter_alt_rounded,
                          label: 'Filters active',
                          onTap: _showFilterModal,
                          showClose: true,
                          onClose: () => setState(() => _adv = _AdvFilter()),
                        ),
                    ]),
                  ]),
            ),
            Row(children: [
              GestureDetector(
                onTap: _showFilterModal,
                child: Stack(clipBehavior: Clip.none, children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: _adv.isActive
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.tune_rounded,
                        color: _adv.isActive
                            ? Colors.white
                            : AppColors.primary,
                        size: 20),
                  ),
                  if (_adv.isActive)
                    Positioned(
                      top: -3, right: -3,
                      child: Container(
                        width: 10, height: 10,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Center(
                            child: Container(
                                width: 7, height: 7,
                                decoration: const BoxDecoration(
                                    color: Colors.orange,
                                    shape: BoxShape.circle))),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const CalendarEventsScreen())),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 22),
                ),
              ),
            ]),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 48,
          decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14)),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
            decoration: InputDecoration(
              hintText: 'Search events, type...',
              hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.black.withOpacity(0.35), size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                  onTap: () =>
                      setState(() => _searchController.clear()),
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.35), size: 20))
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            _filterChip('Upcoming',  icon: Icons.bolt_rounded),
            _filterChip('Today',     icon: Icons.wb_sunny_rounded),
            _filterChip('Tomorrow',  icon: Icons.arrow_forward_rounded),
            _filterChip('This Week', icon: Icons.date_range_rounded),
            _filterChip('Weekend',   icon: Icons.weekend_rounded),
          ]),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: const Color(0xFFEEEFF1)),
      ]),
    );
  }

  Widget _activeBadge({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showClose = false,
    VoidCallback? onClose,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
          if (showClose) ...[
            const SizedBox(width: 4),
            GestureDetector(
                onTap: onClose ?? onTap,
                child:
                Icon(Icons.close_rounded, size: 11, color: AppColors.primary)),
          ],
        ]),
      ),
    );
  }

  Widget _filterChip(String label, {required IconData icon}) {
    final isSelected = !_hasCustomRange && _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = label;
        _customStart    = null;
        _customEnd      = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color:
              isSelected ? AppColors.primary : const Color(0xFFDDDEE1),
              width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF888A90)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : const Color(0xFF555760),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5)),
        ]),
      ),
    );
  }

  Widget _buildEventsList() {
    final eventsAsync = ref.watch(eventsProvider);
    final allLocs     = ref.watch(locationsProvider).asData?.value ?? [];
    return eventsAsync.when(
      data: (events) {
        final filtered = _applyFilter(events, allLocs);
        if (filtered.isEmpty) {
          final loc =
              _selectedPrefecture ?? _selectedCountry ?? 'everywhere';
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_busy_rounded,
                  size: 56, color: Colors.black.withOpacity(0.12)),
              const SizedBox(height: 14),
              Text(
                _hasCustomRange
                    ? 'No events in $loc for this date range.'
                    : {
                  'Today':     'No events in $loc today.',
                  'Tomorrow':  'No events in $loc tomorrow.',
                  'This Week': 'No events in $loc this week.',
                  'Weekend':   'No events in $loc this weekend.',
                  'Upcoming':  'No upcoming events in $loc\nin the next $_defaultDays days.',
                }[_selectedFilter] ??
                    'No events found in $loc.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.35),
                    fontWeight: FontWeight.w500),
              ),
              if (_selectedCountry != null || _adv.isActive) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() {
                    _selectedCountry    = null;
                    _selectedPrefecture = null;
                    _adv = _AdvFilter();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: const Text('Clear all filters',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                  ),
                ),
              ],
            ]),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          itemCount: filtered.length,
          itemBuilder: (context, index) =>
              EventCardFull(event: filtered[index]),
        );
      },
      loading: () => Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2.5)),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.black45, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildAddEventButton() {
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEventScreen())),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8))
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Add an Event',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2)),
          ]),
        ),
      ),
      Positioned(
        top: -8, right: -8,
        child: GestureDetector(
          onTap: () =>
          ref.read(showAddEventButtonProvider.notifier).state = false,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: const Color(0xFF0D0D0D), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.close_rounded,
                size: 16, color: Color(0xFF0D0D0D)),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light-mode Date Picker Field (for advanced filter modal)
// ─────────────────────────────────────────────────────────────────────────────
class _LightDatePickerField extends StatelessWidget {
  final String    label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPicked;

  const _LightDatePickerField({
    required this.label,
    required this.value,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    const border    = Color(0xFFDDDEE1);
    const cardBg    = Color(0xFFF2F3F5);
    const textLight = Color(0xFF888A90);
    const textDark  = Color(0xFF0D0D0D);

    final hasVal = value != null;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: textLight)),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime.now().subtract(const Duration(days: 1)),
            lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
            builder: (ctx, child) => Theme(
              data: Theme.of(ctx).copyWith(
                colorScheme: const ColorScheme.light(
                    primary: AppColors.primary, onSurface: textDark),
              ),
              child: child!,
            ),
          );
          onPicked(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: hasVal
                ? AppColors.primary.withOpacity(0.06)
                : cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: hasVal
                    ? AppColors.primary.withOpacity(0.4)
                    : border),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_rounded,
                size: 14,
                color: hasVal ? AppColors.primary : textLight),
            const SizedBox(width: 8),
            Text(
              hasVal
                  ? DateFormat('MM/dd/yyyy').format(value!)
                  : 'Select',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: hasVal ? AppColors.primary : textLight),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared sub-widgets (location pickers — unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _LocationDropdown extends StatelessWidget {
  final IconData   icon;
  final String     label;
  final bool       hasValue;
  final bool       enabled;
  final VoidCallback? onTap;

  const _LocationDropdown({
    required this.icon,
    required this.label,
    required this.hasValue,
    this.enabled = true,
    this.onTap,
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
          Icon(icon,
              size: 16,
              color: active
                  ? AppColors.primary
                  : enabled
                  ? const Color(0xFF555760)
                  : const Color(0xFFBBBCC0)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppColors.primary
                          : enabled
                          ? const Color(0xFF333438)
                          : const Color(0xFFBBBCC0)))),
          Icon(Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: active
                  ? AppColors.primary
                  : enabled
                  ? const Color(0xFF888A90)
                  : const Color(0xFFBBBCC0)),
        ]),
      ),
    );
  }
}

class _CountryPickerDialog extends StatelessWidget {
  final List<String>        countries;
  final String?             currentCountry;
  final void Function(String?) onSelected;
  const _CountryPickerDialog(
      {required this.countries,
        required this.currentCountry,
        required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand()),
      Positioned(
        left: 24, right: 24,
        top: MediaQuery.of(context).size.height * 0.26,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5EF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 10))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _PickerRow(
                      label: 'All Countries',
                      isHeader: true,
                      isSelected: currentCountry == null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(null);
                      }),
                  const _Divider(),
                  ...countries.asMap().entries.map((e) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PickerRow(
                          label: e.value,
                          isHeader: false,
                          isSelected: currentCountry == e.value,
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(e.value);
                          }),
                      if (e.key < countries.length - 1) const _Divider(),
                    ],
                  )),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _PrefecturePickerDialog extends StatelessWidget {
  final String                   country;
  final List<Map<String, String>> prefectures;
  final String?                  currentPrefecture;
  final void Function(String?)   onSelected;
  const _PrefecturePickerDialog(
      {required this.country,
        required this.prefectures,
        required this.currentPrefecture,
        required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand()),
      Positioned(
        left: 24, right: 24,
        top: MediaQuery.of(context).size.height * 0.26,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.52),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5EF),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 10))
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  _PickerRow(
                      label: 'All $country',
                      isHeader: true,
                      isSelected: currentPrefecture == null,
                      onTap: () {
                        Navigator.pop(context);
                        onSelected(null);
                      }),
                  const _Divider(),
                  ...prefectures.asMap().entries.map((e) {
                    final en = e.value['en']!;
                    final jp = e.value['jp'] ?? '';
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      _PickerRow(
                          label: en,
                          sublabel: jp.isNotEmpty ? jp : null,
                          isHeader: false,
                          isSelected: currentPrefecture == en,
                          onTap: () {
                            Navigator.pop(context);
                            onSelected(en);
                          }),
                      if (e.key < prefectures.length - 1) const _Divider(),
                    ]);
                  }),
                ]),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

class _PickerRow extends StatelessWidget {
  final String    label;
  final String?   sublabel;
  final bool      isHeader;
  final bool      isSelected;
  final VoidCallback onTap;
  const _PickerRow(
      {required this.label,
        this.sublabel,
        required this.isHeader,
        required this.isSelected,
        required this.onTap});

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
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: isHeader
                              ? const Color(0xFF888880)
                              : const Color(0xFF1A1A1A),
                          letterSpacing: -0.2)),
                  Text(sublabel!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888880),
                          fontWeight: FontWeight.w400)),
                ])
                : Text(label,
                style: TextStyle(
                    fontSize: isHeader ? 14 : 16,
                    fontWeight:
                    isHeader ? FontWeight.w500 : FontWeight.w600,
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

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: Color(0xFFDDDDD5));
}