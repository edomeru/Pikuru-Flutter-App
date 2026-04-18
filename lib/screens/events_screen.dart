import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/event_card_full.dart';
import 'package:pikuru/screens/calendar_events_screen.dart';
import 'package:pikuru/screens/add_event_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Language
// ─────────────────────────────────────────────────────────────────────────────
enum AppLang { en, ja }

// ─────────────────────────────────────────────────────────────────────────────
// Strings
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final AppLang lang;
  const _S(this.lang);

  String get events        => lang == AppLang.en ? 'Events'          : 'イベント';
  String get upcoming      => lang == AppLang.en ? 'Upcoming'        : '開催予定';
  String get today         => lang == AppLang.en ? 'Today'           : '今日';
  String get tomorrow      => lang == AppLang.en ? 'Tomorrow'        : '明日';
  String get thisWeek      => lang == AppLang.en ? 'This Week'       : '今週';
  String get weekend       => lang == AppLang.en ? 'Weekend'         : '週末';
  String get search        => lang == AppLang.en ? 'Search events, type…' : 'イベント・種類を検索…';
  String get filters       => lang == AppLang.en ? 'Filters'         : 'フィルター';
  String get filtersActive => lang == AppLang.en ? 'Filters active'  : 'フィルター中';
  String get allCountries  => lang == AppLang.en ? 'All Countries'   : 'すべての国';
  String get clearAll      => lang == AppLang.en ? 'Clear All'       : 'クリア';
  String get applyFilters  => lang == AppLang.en ? 'APPLY FILTERS'   : 'フィルターを適用';

  // Section labels
  String get dateSection      => lang == AppLang.en ? 'DATE'         : '日付';
  String get locationSection  => lang == AppLang.en ? 'LOCATION'     : '場所';
  String get eventTypeSection => lang == AppLang.en ? 'EVENT TYPE'   : 'イベント種類';
  String get skillSection     => lang == AppLang.en ? 'SKILL LEVELS' : 'スキルレベル';
  String get categorySection  => lang == AppLang.en ? 'CATEGORIES'   : 'カテゴリー';
  String get otherSection     => lang == AppLang.en ? 'OTHER'        : 'その他';

  // Date
  String get startDate     => lang == AppLang.en ? 'Start Date' : '開始日';
  String get endDate       => lang == AppLang.en ? 'End Date'   : '終了日';
  String get selectDate    => lang == AppLang.en ? 'Select'     : '選択';

  // Location
  String get country       => lang == AppLang.en ? 'Country'    : '国';
  String get prefecture    => lang == AppLang.en ? 'Prefecture' : '都道府県';
  String get city          => lang == AppLang.en ? 'City'       : '市区町村';
  String get all           => lang == AppLang.en ? 'All'        : 'すべて';
  String get allTypes      => lang == AppLang.en ? 'All types'  : 'すべての種類';

  // Skills
  String get pro           => lang == AppLang.en ? 'Pro'        : '上級';
  String get amateur       => lang == AppLang.en ? 'Amateur'    : '中級';
  String get beginner      => lang == AppLang.en ? 'Beginner'   : '初級';

  // Categories
  String get mixedDoubles  => lang == AppLang.en ? 'Mixed Doubles'   : 'ミックス';
  String get mensDoubles   => lang == AppLang.en ? "Men's Doubles"   : '男子ダブルス';
  String get womensDoubles => lang == AppLang.en ? "Women's Doubles" : '女子ダブルス';
  String get mensSingles   => lang == AppLang.en ? "Men's Singles"   : '男子シングルス';
  String get womensSingles => lang == AppLang.en ? "Women's Singles" : '女子シングルス';
  String get seniors       => lang == AppLang.en ? 'Seniors'         : 'シニア';
  String get juniors       => lang == AppLang.en ? 'Juniors'         : 'ジュニア';
  String get collegiate    => lang == AppLang.en ? 'Collegiate'      : '学生';

  // Other
  String get touristFriendly => lang == AppLang.en ? 'Tourist Friendly' : '観光客歓迎';

  // Empty state
  String noEvents(String loc) => lang == AppLang.en
      ? 'No upcoming events in $loc\nin the next 30 days.'
      : '$loc で今後30日間のイベントはありません。';
  String get clearFilters => lang == AppLang.en ? 'Clear all filters' : 'フィルターをクリア';

  // Event types
  List<String> get eventTypeKeys => [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];

  String localizeEventType(String key) {
    if (lang == AppLang.en) return key;
    const m = {
      'Professional Tournament':      'プロトーナメント',
      'Global Tournament':            'グローバルトーナメント',
      'Japan Tournament':             '日本トーナメント',
      'Open Play':                    'オープンプレイ',
      'Trial Session':                '体験セッション',
      'Local Event':                  'ローカルイベント',
      'Lessons/Clinics':              'レッスン・クリニック',
      'Weekly Play / Recurring Play': '定期プレイ',
    };
    return m[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter state
// ─────────────────────────────────────────────────────────────────────────────
class _AdvFilter {
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

  bool get hasNonLocationFilters =>
      dateStart != null || dateEnd != null ||
          type.isNotEmpty ||
          skillPro || skillAmateur || skillBeginner ||
          catMx || catMd || catMs || catWs || catWd || catSe || catJu || catCo ||
          tourist;

  bool get isActive =>
      hasNonLocationFilters ||
          country.isNotEmpty || prefecture.isNotEmpty || city.isNotEmpty;

  _AdvFilter get cleared => _AdvFilter();
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController      _scrollController = ScrollController();

  String    _selectedFilter = 'Upcoming';
  AppLang   _lang           = AppLang.en;
  _AdvFilter _adv = _AdvFilter(country: 'Japan', prefecture: 'Tokyo');

  _S get s => _S(_lang);

  static const int _defaultDays = 30;

  // ── Original light-mode palette ───────────────────────────────────────────
  static const Color _bg        = Color(0xFFF7F8FA);
  static const Color _surface   = Colors.white;
  static const Color _cardBg    = Color(0xFFF2F3F5);
  static const Color _border    = Color(0xFFDDDEE1);
  static const Color _textDark  = Color(0xFF0D0D0D);
  static const Color _textMid   = Color(0xFF555760);
  static const Color _textLight = Color(0xFF888A90);

  String get _locationLabel {
    if (_adv.prefecture.isNotEmpty) return _adv.prefecture;
    if (_adv.country.isNotEmpty)    return _adv.country;
    return s.allCountries;
  }

  // ─────────────────────────────────────────────────────────────────────────
  bool _matchesLocation(
      Map<String, dynamic> event, List<Map<String, dynamic>> allLocs) {
    if (_adv.country.isEmpty) return true;
    final targetCountry = _adv.country.toLowerCase();
    final targetPref    = _adv.prefecture.isNotEmpty ? _adv.prefecture.toLowerCase() : null;
    final targetCity    = _adv.city.isNotEmpty       ? _adv.city.toLowerCase()       : null;

    final locId = (event['loc_id'] ?? event['event_loc_id'] ?? '').toString().trim();
    Map<String, dynamic> loc = {};
    if (locId.isNotEmpty) {
      loc = allLocs.firstWhere(
            (l) => (l['loc_id'] ?? l['id'] ?? '').toString() == locId,
        orElse: () => {},
      );
    }

    String get(String key) =>
        ((loc.isNotEmpty ? loc[key] : null) ?? event[key] ?? '')
            .toString().trim().toLowerCase();

    final country = get('loc_country');
    if (country.isEmpty ||
        (!country.contains(targetCountry) && !targetCountry.contains(country))) {
      return false;
    }

    if (targetPref != null && targetPref.isNotEmpty) {
      bool prefMatch = false;
      for (final key in ['loc_prefecture_en', 'loc_prefecture_jp', 'loc_prefecture',
        'event_prefecture', 'prefecture']) {
        final v = get(key);
        if (v.isNotEmpty && (v.contains(targetPref) || targetPref.contains(v))) {
          prefMatch = true; break;
        }
      }
      if (!prefMatch) return false;
    }

    if (targetCity != null && targetCity.isNotEmpty) {
      bool cityMatch = false;
      for (final key in ['loc_city_en', 'loc_city', 'event_city', 'city']) {
        final v = get(key);
        if (v.isNotEmpty && (v.contains(targetCity) || targetCity.contains(v))) {
          cityMatch = true; break;
        }
      }
      if (!cityMatch) return false;
    }
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilter(
      List<Map<String, dynamic>> events, List<Map<String, dynamic>> allLocs) {
    final now        = DateTime.now();
    final today      = DateTime(now.year, now.month, now.day);
    final tomorrow   = today.add(const Duration(days: 1));
    final defaultEnd = today.add(const Duration(days: _defaultDays));
    final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday   = today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    final sunday     = saturday.add(const Duration(days: 1));
    final endOfWeek  = today.add(Duration(days: 7 - now.weekday));
    final q = _searchController.text.toLowerCase().trim();

    return events.where((e) {
      if (q.isNotEmpty) {
        final title   = (e['event_title']    ?? '').toString().toLowerCase();
        final type    = (e['event_type']     ?? '').toString().toLowerCase();
        final titleJp = (e['event_title_jp'] ?? '').toString().toLowerCase();
        if (!title.contains(q) && !type.contains(q) && !titleJp.contains(q)) return false;
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

      if (_adv.dateStart != null || _adv.dateEnd != null) {
        if (_adv.dateStart != null && day.isBefore(_adv.dateStart!)) return false;
        if (_adv.dateEnd   != null && day.isAfter(_adv.dateEnd!))    return false;
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
  // FILTER MODAL — original light style, new structure
  // ─────────────────────────────────────────────────────────────────────────
  void _showFilterModal() {
    _AdvFilter temp = _adv;

    final allLocs   = ref.read(locationsProvider).asData?.value ?? [];
    final allEvents = ref.read(eventsProvider).asData?.value   ?? [];

    final countries   = <String>{};
    final prefectures = <String>{};
    final cities      = <String>{};

    for (final event in allEvents) {
      final locId = (event['loc_id'] ?? event['event_loc_id'] ?? '').toString().trim();
      final loc = locId.isNotEmpty
          ? allLocs.firstWhere(
              (l) => (l['loc_id'] ?? l['id'] ?? '').toString() == locId,
          orElse: () => <String, dynamic>{})
          : <String, dynamic>{};

      String field(String key) =>
          ((loc.isNotEmpty ? loc[key] : null) ?? event[key] ?? '').toString().trim();

      final c  = field('loc_country');
      final p  = field('loc_prefecture_en').isNotEmpty
          ? field('loc_prefecture_en') : field('loc_prefecture');
      final ci = field('loc_city_en').isNotEmpty
          ? field('loc_city_en') : field('loc_city');

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
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {

        // ── Section label ─────────────────────────────────────────────
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
            Text(text, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800,
              color: _textMid, letterSpacing: 0.8,
            )),
          ]),
        );

        Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: _border),
        );

        // ── Date picker field ─────────────────────────────────────────
        Widget datePicker(String label, DateTime? value,
            ValueChanged<DateTime?> onPicked) {
          final hasVal = value != null;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _textLight,
            )),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: value ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate:  DateTime.now().add(const Duration(days: 365 * 3)),
                  builder: (c, child) => Theme(
                    data: Theme.of(c).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.primary,
                        onSurface: _textDark,
                      ),
                    ),
                    child: child!,
                  ),
                );
                onPicked(picked);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
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
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14,
                      color: hasVal ? AppColors.primary : _textLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hasVal
                          ? DateFormat('MM/dd/yyyy').format(value!)
                          : s.selectDate,
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: hasVal ? AppColors.primary : _textLight,
                      ),
                    ),
                  ),
                  if (hasVal)
                    GestureDetector(
                      onTap: () => onPicked(null),
                      child: Icon(Icons.close_rounded,
                          size: 14, color: AppColors.primary),
                    ),
                ]),
              ),
            ),
          ]);
        }

        // ── Dropdown field ────────────────────────────────────────────
        Widget dropdownField(
            String label,
            String value,
            List<String> options,
            String allLabel,
            ValueChanged<String> onChange, {
              String Function(String)? displayMapper,
            }) {
          final hasVal = value.isNotEmpty;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (label.isNotEmpty) ...[
              Text(label, style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: _textLight,
              )),
              const SizedBox(height: 6),
            ],
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
                    fontSize: 14, fontWeight: FontWeight.w500,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(allLabel,
                          style: const TextStyle(color: _textLight)),
                    ),
                    ...options.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        displayMapper != null ? displayMapper(o) : o,
                      ),
                    )),
                  ],
                  onChanged: (v) => onChange(v ?? ''),
                ),
              ),
            ),
          ]);
        }

        // ── Checkbox pill ─────────────────────────────────────────────
        Widget checkPill(String label, bool value, VoidCallback onTap) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                      width: 1.5,
                    ),
                  ),
                  child: value
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: value ? AppColors.primary : _textMid,
                )),
              ]),
            ),
          );
        }

        // ── Modal shell ───────────────────────────────────────────────
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
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
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
              child: Row(children: [
                Text(s.filters, style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800,
                  color: _textDark, letterSpacing: -0.4,
                )),
                const Spacer(),
                if (_adv.isActive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Active', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    )),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _cardBg, shape: BoxShape.circle,
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

                    // ── DATE ──────────────────────────────────────────
                    sectionLabel(s.dateSection),
                    Row(children: [
                      Expanded(child: datePicker(
                        s.startDate, temp.dateStart,
                            (d) => setS(() => temp = temp.copyWith(dateStart: d)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: datePicker(
                        s.endDate, temp.dateEnd,
                            (d) => setS(() => temp = temp.copyWith(dateEnd: d)),
                      )),
                    ]),

                    divider(),

                    // ── LOCATION ──────────────────────────────────────
                    sectionLabel(s.locationSection),
                    Row(children: [
                      Expanded(child: dropdownField(
                        s.country, temp.country,
                        sortedCountries, s.allCountries,
                            (v) => setS(() => temp = temp.copyWith(country: v)),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: dropdownField(
                        s.prefecture, temp.prefecture,
                        sortedPrefectures, s.all,
                            (v) => setS(() => temp = temp.copyWith(prefecture: v)),
                      )),
                    ]),
                    const SizedBox(height: 12),
                    dropdownField(
                      s.city, temp.city,
                      sortedCities, s.all,
                          (v) => setS(() => temp = temp.copyWith(city: v)),
                    ),

                    divider(),

                    // ── EVENT TYPE ────────────────────────────────────
                    sectionLabel(s.eventTypeSection),
                    dropdownField(
                      '', temp.type,
                      s.eventTypeKeys, s.allTypes,
                          (v) => setS(() => temp = temp.copyWith(type: v)),
                      displayMapper: s.localizeEventType,
                    ),

                    divider(),

                    // ── SKILL LEVELS ──────────────────────────────────
                    sectionLabel(s.skillSection),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      checkPill(s.pro,      temp.skillPro,
                              () => setS(() => temp = temp.copyWith(skillPro: !temp.skillPro))),
                      checkPill(s.amateur,  temp.skillAmateur,
                              () => setS(() => temp = temp.copyWith(skillAmateur: !temp.skillAmateur))),
                      checkPill(s.beginner, temp.skillBeginner,
                              () => setS(() => temp = temp.copyWith(skillBeginner: !temp.skillBeginner))),
                    ]),

                    divider(),

                    // ── CATEGORIES ────────────────────────────────────
                    sectionLabel(s.categorySection),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      checkPill(s.mixedDoubles,  temp.catMx,
                              () => setS(() => temp = temp.copyWith(catMx: !temp.catMx))),
                      checkPill(s.mensDoubles,   temp.catMd,
                              () => setS(() => temp = temp.copyWith(catMd: !temp.catMd))),
                      checkPill(s.womensDoubles, temp.catWd,
                              () => setS(() => temp = temp.copyWith(catWd: !temp.catWd))),
                      checkPill(s.mensSingles,   temp.catMs,
                              () => setS(() => temp = temp.copyWith(catMs: !temp.catMs))),
                      checkPill(s.womensSingles, temp.catWs,
                              () => setS(() => temp = temp.copyWith(catWs: !temp.catWs))),
                      checkPill(s.seniors,       temp.catSe,
                              () => setS(() => temp = temp.copyWith(catSe: !temp.catSe))),
                      checkPill(s.juniors,       temp.catJu,
                              () => setS(() => temp = temp.copyWith(catJu: !temp.catJu))),
                      checkPill(s.collegiate,    temp.catCo,
                              () => setS(() => temp = temp.copyWith(catCo: !temp.catCo))),
                    ]),

                    divider(),

                    // ── OTHER ─────────────────────────────────────────
                    sectionLabel(s.otherSection),
                    checkPill(s.touristFriendly, temp.tourist,
                            () => setS(() => temp = temp.copyWith(tourist: !temp.tourist))),

                    const SizedBox(height: 28),

                    // ── Action buttons ────────────────────────────────
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
                            child: Center(child: Text(s.clearAll,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: _textMid))),
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
                            child: Center(child: Text(s.applyFilters,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w800,
                                    color: Colors.white, letterSpacing: 0.6))),
                          ),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ]),
        );
      }),
    );
  }

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
              bottom: 24, left: 0, right: 0,
              child: Center(child: _buildAddEventButton()),
            ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final fmt = DateFormat('MMM d');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.events, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: Color(0xFF0D0D0D), letterSpacing: -0.5,
              )),
              const SizedBox(height: 4),
              Wrap(spacing: 6, runSpacing: 4, children: [
                _activeBadge(
                  icon: Icons.location_on_rounded,
                  label: _locationLabel,
                  onTap: _showFilterModal,
                ),
                if (_adv.dateStart != null)
                  _activeBadge(
                    icon: Icons.calendar_today_rounded,
                    label: _adv.dateEnd != null &&
                        !_isSameDay(_adv.dateStart!, _adv.dateEnd!)
                        ? '${fmt.format(_adv.dateStart!)} – ${fmt.format(_adv.dateEnd!)}'
                        : fmt.format(_adv.dateStart!),
                    onTap: () => setState(() => _adv = _adv.copyWith(clearDates: true)),
                    showClose: true,
                    onClose: () => setState(() => _adv = _adv.copyWith(clearDates: true)),
                  ),
                if (_adv.hasNonLocationFilters && _adv.dateStart == null)
                  _activeBadge(
                    icon: Icons.filter_alt_rounded,
                    label: s.filtersActive,
                    onTap: _showFilterModal,
                    showClose: true,
                    onClose: () => setState(() {
                      _adv = _AdvFilter(
                        country:    _adv.country,
                        prefecture: _adv.prefecture,
                        city:       _adv.city,
                      );
                    }),
                  ),
              ]),
            ]),
          ),
          Row(children: [
            // ── Language switcher ────────────────────────────────────
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _langBtn('EN',    AppLang.en),
                _langBtn('日本語', AppLang.ja),
              ]),
            ),
            const SizedBox(width: 10),
            // ── Filter icon ──────────────────────────────────────────
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
                      color: _adv.isActive ? Colors.white : AppColors.primary,
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
                              color: Colors.orange, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 10),
            // ── Calendar icon ────────────────────────────────────────
            GestureDetector(
              onTap: () => Navigator.push(context,
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
        ]),
        const SizedBox(height: 14),

        // Search bar
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
              hintText: s.search,
              hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w400),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.black.withOpacity(0.35), size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                  onTap: () => setState(() => _searchController.clear()),
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

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: [
            _filterChip('Upcoming',  s.upcoming,  Icons.bolt_rounded),
            _filterChip('Today',     s.today,     Icons.wb_sunny_rounded),
            _filterChip('Tomorrow',  s.tomorrow,  Icons.arrow_forward_rounded),
            _filterChip('This Week', s.thisWeek,  Icons.date_range_rounded),
            _filterChip('Weekend',   s.weekend,   Icons.weekend_rounded),
          ]),
        ),
        const SizedBox(height: 4),
        Container(height: 1, color: const Color(0xFFEEEFF1)),
      ]),
    );
  }

  Widget _langBtn(String label, AppLang l) {
    final active = _lang == l;
    return GestureDetector(
      onTap: () => setState(() => _lang = l),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800,
          color: active ? Colors.white : _textLight,
        )),
      ),
    );
  }

  Widget _activeBadge({
    required IconData     icon,
    required String       label,
    required VoidCallback onTap,
    bool showClose        = false,
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
          Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: AppColors.primary)),
          if (showClose) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose ?? onTap,
              child: Icon(Icons.close_rounded,
                  size: 11, color: AppColors.primary),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _filterChip(String key, String label, IconData icon) {
    final isSelected = _adv.dateStart == null && _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedFilter = key;
        _adv = _adv.copyWith(clearDates: true);
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8, bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFDDDEE1),
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15,
              color: isSelected ? Colors.white : const Color(0xFF888A90)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF555760),
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          )),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventsList() {
    final eventsAsync = ref.watch(eventsProvider);
    final allLocs     = ref.watch(locationsProvider).asData?.value ?? [];
    return eventsAsync.when(
      data: (events) {
        final filtered = _applyFilter(events, allLocs);
        if (filtered.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.event_busy_rounded, size: 56,
                  color: Colors.black.withOpacity(0.12)),
              const SizedBox(height: 14),
              Text(
                s.noEvents(_locationLabel),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.black.withOpacity(0.35),
                    fontWeight: FontWeight.w500),
              ),
              if (_adv.isActive) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => setState(() => _adv = _AdvFilter()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(s.clearFilters,
                        style: const TextStyle(
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
              style: const TextStyle(color: Colors.black45, fontSize: 14)),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _lang == AppLang.en ? 'Add an Event' : 'イベント追加',
              style: const TextStyle(
                  color: Colors.white, fontSize: 15,
                  fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
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