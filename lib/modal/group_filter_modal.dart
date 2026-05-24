// lib/modal/group_filter_modal.dart

import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupFilter  —  immutable filter data class
// ─────────────────────────────────────────────────────────────────────────────
class GroupFilter {
  // Location
  final String? orgCountry;
  final String? orgPrefecture;
  final String? orgCity;

  // Skill
  final bool orgSkillBeginner;
  final bool orgSkillIntermediate;
  final bool orgSkillAdvance;

  // Age
  final bool orgAgeJuniors;
  final bool orgAgeStudents;
  final bool orgAgeAdult;
  final bool orgAgeSeniors;

  // Meetup days
  final bool orgMeetupSun;
  final bool orgMeetupMon;
  final bool orgMeetupTues;
  final bool orgMeetupWeds;
  final bool orgMeetupThurs;
  final bool orgMeetupFri;
  final bool orgMeetupSat;

  // Meetup times
  final bool orgMeetupTimeMornings;
  final bool orgMeetupTimeAfternoons;
  final bool orgMeetupTimeEvenings;

  const GroupFilter({
    this.orgCountry,
    this.orgPrefecture,
    this.orgCity,
    this.orgSkillBeginner     = false,
    this.orgSkillIntermediate = false,
    this.orgSkillAdvance      = false,
    this.orgAgeJuniors        = false,
    this.orgAgeStudents       = false,
    this.orgAgeAdult          = false,
    this.orgAgeSeniors        = false,
    this.orgMeetupSun         = false,
    this.orgMeetupMon         = false,
    this.orgMeetupTues        = false,
    this.orgMeetupWeds        = false,
    this.orgMeetupThurs       = false,
    this.orgMeetupFri         = false,
    this.orgMeetupSat         = false,
    this.orgMeetupTimeMornings   = false,
    this.orgMeetupTimeAfternoons = false,
    this.orgMeetupTimeEvenings   = false,
  });

  // ── "No filters active" check ─────────────────────────────────────────────
  bool get isDefault =>
      orgCountry    == null &&
          orgPrefecture == null &&
          orgCity       == null &&
          !orgSkillBeginner    && !orgSkillIntermediate && !orgSkillAdvance &&
          !orgAgeJuniors       && !orgAgeStudents && !orgAgeAdult && !orgAgeSeniors &&
          !orgMeetupSun  && !orgMeetupMon  && !orgMeetupTues && !orgMeetupWeds &&
          !orgMeetupThurs && !orgMeetupFri && !orgMeetupSat &&
          !orgMeetupTimeMornings && !orgMeetupTimeAfternoons && !orgMeetupTimeEvenings;

  // ── copyWith ──────────────────────────────────────────────────────────────
  GroupFilter copyWith({
    Object? orgCountry    = _sentinel,
    Object? orgPrefecture = _sentinel,
    Object? orgCity       = _sentinel,
    bool?   orgSkillBeginner,
    bool?   orgSkillIntermediate,
    bool?   orgSkillAdvance,
    bool?   orgAgeJuniors,
    bool?   orgAgeStudents,
    bool?   orgAgeAdult,
    bool?   orgAgeSeniors,
    bool?   orgMeetupSun,
    bool?   orgMeetupMon,
    bool?   orgMeetupTues,
    bool?   orgMeetupWeds,
    bool?   orgMeetupThurs,
    bool?   orgMeetupFri,
    bool?   orgMeetupSat,
    bool?   orgMeetupTimeMornings,
    bool?   orgMeetupTimeAfternoons,
    bool?   orgMeetupTimeEvenings,
  }) {
    return GroupFilter(
      orgCountry:    orgCountry    == _sentinel ? this.orgCountry    : orgCountry    as String?,
      orgPrefecture: orgPrefecture == _sentinel ? this.orgPrefecture : orgPrefecture as String?,
      orgCity:       orgCity       == _sentinel ? this.orgCity       : orgCity       as String?,
      orgSkillBeginner:     orgSkillBeginner     ?? this.orgSkillBeginner,
      orgSkillIntermediate: orgSkillIntermediate ?? this.orgSkillIntermediate,
      orgSkillAdvance:      orgSkillAdvance      ?? this.orgSkillAdvance,
      orgAgeJuniors:        orgAgeJuniors        ?? this.orgAgeJuniors,
      orgAgeStudents:       orgAgeStudents       ?? this.orgAgeStudents,
      orgAgeAdult:          orgAgeAdult          ?? this.orgAgeAdult,
      orgAgeSeniors:        orgAgeSeniors        ?? this.orgAgeSeniors,
      orgMeetupSun:         orgMeetupSun         ?? this.orgMeetupSun,
      orgMeetupMon:         orgMeetupMon         ?? this.orgMeetupMon,
      orgMeetupTues:        orgMeetupTues        ?? this.orgMeetupTues,
      orgMeetupWeds:        orgMeetupWeds        ?? this.orgMeetupWeds,
      orgMeetupThurs:       orgMeetupThurs       ?? this.orgMeetupThurs,
      orgMeetupFri:         orgMeetupFri         ?? this.orgMeetupFri,
      orgMeetupSat:         orgMeetupSat         ?? this.orgMeetupSat,
      orgMeetupTimeMornings:   orgMeetupTimeMornings   ?? this.orgMeetupTimeMornings,
      orgMeetupTimeAfternoons: orgMeetupTimeAfternoons ?? this.orgMeetupTimeAfternoons,
      orgMeetupTimeEvenings:   orgMeetupTimeEvenings   ?? this.orgMeetupTimeEvenings,
    );
  }

  // ── matches — returns true if the group passes all active filters ──────────
  bool matches(
      Map<String, dynamic> g,
      Map<String, Map<String, dynamic>> locMap,
      ) {
    // ── Location ─────────────────────────────────────────────────────────────
    if (orgCountry != null || orgPrefecture != null || orgCity != null) {
      final locId = (g['org_loc_id'] ?? '').toString();
      final Map<String, dynamic> loc = locMap[locId] ?? {};

      // Helper: get a trimmed lowercase string, checking loc doc first then
      // the org doc fallback field.
      String f(String locKey, String orgKey) =>
          (loc[locKey] ?? g[orgKey] ?? '').toString().toLowerCase().trim();

      final country = f('loc_country', 'org_country');

      // Collect all prefecture variants for this group
      final prefVariants = <String>{
        f('loc_prefecture_en', 'org_prefecture'),
        f('loc_prefecture',    'org_prefecture'),
        f('loc_prefecture',    'org_prefecture_jp'),
      }..removeWhere((s) => s.isEmpty);

      // Collect all city variants for this group
      final cityVariants = <String>{
        f('loc_city_en', 'org_city'),
        f('loc_city',    'org_city'),
        f('loc_city',    'org_city_jp'),
      }..removeWhere((s) => s.isEmpty);

      // ── Country check (loose — "japan" == "japan") ──────────────────────
      if (orgCountry != null) {
        final target = orgCountry!.toLowerCase().trim();
        if (country != target) return false;
      }

      // ── Prefecture check — EXACT match only ────────────────────────────
      // The filter stores the EN key (e.g. "Tokyo"). We compare it against
      // every variant of the group's prefecture (EN + JP). This prevents
      // "Tokyo" accidentally matching "Tokushima" via .contains().
      if (orgPrefecture != null) {
        final target = orgPrefecture!.toLowerCase().trim();
        if (!prefVariants.contains(target)) return false;
      }

      // ── City check — EXACT match only ──────────────────────────────────
      if (orgCity != null) {
        final target = orgCity!.toLowerCase().trim();
        if (!cityVariants.contains(target)) return false;
      }
    }

    // ── Skill ─────────────────────────────────────────────────────────────────
    if (orgSkillBeginner || orgSkillIntermediate || orgSkillAdvance) {
      final ok =
          (orgSkillBeginner    && g['org_skill_beginner']     == true) ||
              (orgSkillIntermediate && g['org_skill_intermediate'] == true) ||
              (orgSkillAdvance     && g['org_skill_advance']      == true);
      if (!ok) return false;
    }

    // ── Age ───────────────────────────────────────────────────────────────────
    if (orgAgeJuniors || orgAgeStudents || orgAgeAdult || orgAgeSeniors) {
      final ok =
          (orgAgeJuniors  && g['org_age_juniors']  == true) ||
              (orgAgeStudents && g['org_age_students'] == true) ||
              (orgAgeAdult    && g['org_age_adult']    == true) ||
              (orgAgeSeniors  && g['org_age_seniors']  == true);
      if (!ok) return false;
    }

    // ── Meetup days ───────────────────────────────────────────────────────────
    if (orgMeetupSun || orgMeetupMon || orgMeetupTues || orgMeetupWeds ||
        orgMeetupThurs || orgMeetupFri || orgMeetupSat) {
      final ok =
          (orgMeetupSun   && g['org_meetup_sun']   == true) ||
              (orgMeetupMon   && g['org_meetup_mon']   == true) ||
              (orgMeetupTues  && g['org_meetup_tues']  == true) ||
              (orgMeetupWeds  && g['org_meetup_weds']  == true) ||
              (orgMeetupThurs && g['org_meetup_thurs'] == true) ||
              (orgMeetupFri   && g['org_meetup_fri']   == true) ||
              (orgMeetupSat   && g['org_meetup_sat']   == true);
      if (!ok) return false;
    }

    // ── Meetup times ──────────────────────────────────────────────────────────
    if (orgMeetupTimeMornings || orgMeetupTimeAfternoons || orgMeetupTimeEvenings) {
      final ok =
          (orgMeetupTimeMornings   && g['org_meetup_time_mornings']   == true) ||
              (orgMeetupTimeAfternoons && g['org_meetup_time_afternoons'] == true) ||
              (orgMeetupTimeEvenings   && g['org_meetup_time_evenings']   == true);
      if (!ok) return false;
    }

    return true;
  }
}

// Sentinel object used for nullable copyWith overrides
const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────
// _FilterStrings — localised labels for the modal
// ─────────────────────────────────────────────────────────────────────────────
class _FilterStrings {
  final String title;
  final String clearAll;
  final String applyFilters;

  // Section headers
  final String secLocation;
  final String secSkill;
  final String secAge;
  final String secDays;
  final String secTimes;

  // Location dropdowns
  final String labelPrefecture;
  final String labelCity;
  final String allPrefectures;
  final String allCities;
  final String selectPrefFirst;

  // Skill pills
  final String skillBeginner;
  final String skillIntermediate;
  final String skillAdvanced;

  // Age pills
  final String ageJuniors;
  final String ageStudents;
  final String ageAdults;
  final String ageSeniors;

  // Day pills
  final String daySun;
  final String dayMon;
  final String dayTue;
  final String dayWed;
  final String dayThu;
  final String dayFri;
  final String daySat;

  // Time pills
  final String timeMornings;
  final String timeAfternoons;
  final String timeEvenings;

  const _FilterStrings({
    required this.title,
    required this.clearAll,
    required this.applyFilters,
    required this.secLocation,
    required this.secSkill,
    required this.secAge,
    required this.secDays,
    required this.secTimes,
    required this.labelPrefecture,
    required this.labelCity,
    required this.allPrefectures,
    required this.allCities,
    required this.selectPrefFirst,
    required this.skillBeginner,
    required this.skillIntermediate,
    required this.skillAdvanced,
    required this.ageJuniors,
    required this.ageStudents,
    required this.ageAdults,
    required this.ageSeniors,
    required this.daySun,
    required this.dayMon,
    required this.dayTue,
    required this.dayWed,
    required this.dayThu,
    required this.dayFri,
    required this.daySat,
    required this.timeMornings,
    required this.timeAfternoons,
    required this.timeEvenings,
  });

  static const en = _FilterStrings(
    title:            'Filter Groups',
    clearAll:         'Clear all',
    applyFilters:     'APPLY FILTERS',
    secLocation:      'LOCATION',
    secSkill:         'SKILL LEVELS',
    secAge:           'AGE GROUPS',
    secDays:          'MEETUP DAYS',
    secTimes:         'MEETUP TIMES',
    labelPrefecture:  'Prefecture',
    labelCity:        'City',
    allPrefectures:   'All prefectures',
    allCities:        'All cities',
    selectPrefFirst:  'Select a prefecture first',
    skillBeginner:    'Beginner',
    skillIntermediate:'Intermediate',
    skillAdvanced:    'Advanced',
    ageJuniors:       'Juniors',
    ageStudents:      'Students',
    ageAdults:        'Adults',
    ageSeniors:       'Seniors',
    daySun: 'Sun', dayMon: 'Mon', dayTue: 'Tue', dayWed: 'Wed',
    dayThu: 'Thu', dayFri: 'Fri', daySat: 'Sat',
    timeMornings:     'Mornings',
    timeAfternoons:   'Afternoons',
    timeEvenings:     'Evenings',
  );

  static const ja = _FilterStrings(
    title:            'グループを絞り込む',
    clearAll:         'クリア',
    applyFilters:     '適用する',
    secLocation:      '場所',
    secSkill:         'スキルレベル',
    secAge:           '年齢層',
    secDays:          '活動日',
    secTimes:         '活動時間',
    labelPrefecture:  '都道府県',
    labelCity:        '市区町村',
    allPrefectures:   'すべての都道府県',
    allCities:        'すべての市区町村',
    selectPrefFirst:  '先に都道府県を選択',
    skillBeginner:    '初級',
    skillIntermediate:'中級',
    skillAdvanced:    '上級',
    ageJuniors:       'ジュニア（子供）',
    ageStudents:      '学生',
    ageAdults:        '大人一般',
    ageSeniors:       'シニア',
    daySun: '日', dayMon: '月', dayTue: '火', dayWed: '水',
    dayThu: '木', dayFri: '金', daySat: '土',
    timeMornings:     '午前',
    timeAfternoons:   '午後',
    timeEvenings:     '夜間',
  );

  static _FilterStrings of(String lang) => lang == 'ja' ? ja : en;
}

// ─────────────────────────────────────────────────────────────────────────────
// GroupFilterModal  —  bottom-sheet widget
// ─────────────────────────────────────────────────────────────────────────────
class GroupFilterModal extends StatefulWidget {
  final GroupFilter currentFilter;
  final List<Map<String, dynamic>> allGroups;
  final Map<String, Map<String, dynamic>> locMap;
  final String lang;

  const GroupFilterModal({
    super.key,
    required this.currentFilter,
    required this.allGroups,
    required this.locMap,
    this.lang = 'en',
  });

  @override
  State<GroupFilterModal> createState() => _GroupFilterModalState();
}

class _GroupFilterModalState extends State<GroupFilterModal> {
  late GroupFilter _draft;

  // Prefecture list keyed by English name (canonical key used for filtering)
  late final List<String> _prefecturesEn;

  // EN prefecture → list of EN cities
  late final Map<String, List<String>> _prefCityMapEn;

  // EN prefecture → JP display label
  late final Map<String, String> _prefEnToJp;

  // EN city → JP display label
  late final Map<String, String> _cityEnToJp;

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter.copyWith(orgCountry: 'Japan');
    _buildLocationData();
  }

  /// Builds prefecture/city lookup tables from allGroups + locMap.
  /// Always keyed on English values so filter logic is language-agnostic.
  void _buildLocationData() {
    final prefecturesEn = <String>{};
    final prefCityMapEn = <String, Set<String>>{};
    final prefEnToJp    = <String, String>{};
    final cityEnToJp    = <String, String>{};

    for (final g in widget.allGroups) {
      final locId = (g['org_loc_id'] ?? '').toString();
      final loc   = widget.locMap[locId] ?? {};

      final country = (loc['loc_country'] ?? g['org_country'] ?? '')
          .toString().trim().toLowerCase();
      if (country != 'japan') continue;

      // EN prefecture — canonical key. Prefer loc_prefecture_en, fall back
      // to loc_prefecture (which may be Japanese), then org_prefecture.
      final prefEn = (loc['loc_prefecture_en'] ??
          loc['loc_prefecture'] ??
          g['org_prefecture'] ??
          '')
          .toString()
          .trim();
      if (prefEn.isEmpty) continue;

      // JP display label
      final prefJp =
      (loc['loc_prefecture'] ?? g['org_prefecture_jp'] ?? prefEn)
          .toString()
          .trim();

      // EN city — canonical key
      final cityEn =
      (loc['loc_city_en'] ?? g['org_city'] ?? '').toString().trim();

      // JP city display label
      final cityJp =
      (loc['loc_city'] ?? g['org_city_jp'] ?? cityEn).toString().trim();

      prefecturesEn.add(prefEn);
      prefEnToJp.putIfAbsent(prefEn, () => prefJp);

      prefCityMapEn.putIfAbsent(prefEn, () => <String>{});
      if (cityEn.isNotEmpty) {
        prefCityMapEn[prefEn]!.add(cityEn);
        cityEnToJp.putIfAbsent(cityEn, () => cityJp);
      }
    }

    _prefecturesEn =
    prefecturesEn.toList()..sort();
    _prefCityMapEn =
        prefCityMapEn.map((k, v) => MapEntry(k, v.toList()..sort()));
    _prefEnToJp = prefEnToJp;
    _cityEnToJp = cityEnToJp;
  }

  String _prefDisplay(String prefEn) =>
      widget.lang == 'ja' ? (_prefEnToJp[prefEn] ?? prefEn) : prefEn;

  String _cityDisplay(String cityEn) =>
      widget.lang == 'ja' ? (_cityEnToJp[cityEn] ?? cityEn) : cityEn;

  void _apply() => Navigator.of(context).pop(_draft);
  void _clear() =>
      setState(() => _draft = const GroupFilter(orgCountry: 'Japan'));

  // ── Palette ────────────────────────────────────────────────────────────────
  static const Color _bg       = Colors.white;
  static const Color _cardBg   = Color(0xFFF2F3F5);
  static const Color _border   = Color(0xFFDDDEE1);
  static const Color _textDark = Color(0xFF0D0D0D);
  static const Color _textMid  = Color(0xFF555760);
  static const Color _textSub  = Color(0xFF888A90);

  @override
  Widget build(BuildContext context) {
    final s = _FilterStrings.of(widget.lang);

    final currentCitiesEn = _draft.orgPrefecture != null
        ? (_prefCityMapEn[_draft.orgPrefecture] ?? <String>[])
        : <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand:           false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color:        _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                child: Row(children: [
                  Text(s.title,
                      style: const TextStyle(
                          fontSize:      20,
                          fontWeight:    FontWeight.w800,
                          color:         _textDark,
                          letterSpacing: -0.4)),
                  const Spacer(),
                  if (!_draft.isDefault)
                    TextButton(
                      onPressed: _clear,
                      child: Text(s.clearAll,
                          style: const TextStyle(
                              color:      AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color:  _cardBg,
                        shape:  BoxShape.circle,
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.close_rounded,
                          color: _textMid, size: 18),
                    ),
                  ),
                ]),
              ),
              const Divider(height: 1, color: _border),

              // ── Scrollable filter sections ───────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [

                    // ── LOCATION ──────────────────────────────────────────
                    _sectionLabel(s.secLocation),

                    _dropdown(
                      label:     s.labelPrefecture,
                      value:     _draft.orgPrefecture ?? '',
                      options:   _prefecturesEn,
                      allLabel:  s.allPrefectures,
                      displayFn: _prefDisplay,
                      onChange:  (v) => setState(() => _draft = _draft.copyWith(
                          orgPrefecture: v.isEmpty ? null : v,
                          orgCity: null)),
                    ),
                    const SizedBox(height: 12),

                    _dropdown(
                      label:     s.labelCity,
                      value:     _draft.orgCity ?? '',
                      options:   currentCitiesEn,
                      allLabel:  _draft.orgPrefecture == null
                          ? s.selectPrefFirst
                          : s.allCities,
                      displayFn: _cityDisplay,
                      onChange:  (v) => setState(() => _draft =
                          _draft.copyWith(orgCity: v.isEmpty ? null : v)),
                    ),

                    _divider(),

                    // ── SKILL LEVELS ──────────────────────────────────────
                    _sectionLabel(s.secSkill),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(s.skillBeginner,    _draft.orgSkillBeginner,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillBeginner: !_draft.orgSkillBeginner))),
                      _pill(s.skillIntermediate, _draft.orgSkillIntermediate,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillIntermediate: !_draft.orgSkillIntermediate))),
                      _pill(s.skillAdvanced,    _draft.orgSkillAdvance,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillAdvance: !_draft.orgSkillAdvance))),
                    ]),

                    _divider(),

                    // ── AGE GROUPS ────────────────────────────────────────
                    _sectionLabel(s.secAge),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(s.ageJuniors,  _draft.orgAgeJuniors,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeJuniors: !_draft.orgAgeJuniors))),
                      _pill(s.ageStudents, _draft.orgAgeStudents,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeStudents: !_draft.orgAgeStudents))),
                      _pill(s.ageAdults,   _draft.orgAgeAdult,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeAdult: !_draft.orgAgeAdult))),
                      _pill(s.ageSeniors,  _draft.orgAgeSeniors,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeSeniors: !_draft.orgAgeSeniors))),
                    ]),

                    _divider(),

                    // ── MEETUP DAYS ───────────────────────────────────────
                    _sectionLabel(s.secDays),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(s.daySun, _draft.orgMeetupSun,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupSun: !_draft.orgMeetupSun))),
                      _pill(s.dayMon, _draft.orgMeetupMon,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupMon: !_draft.orgMeetupMon))),
                      _pill(s.dayTue, _draft.orgMeetupTues,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTues: !_draft.orgMeetupTues))),
                      _pill(s.dayWed, _draft.orgMeetupWeds,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupWeds: !_draft.orgMeetupWeds))),
                      _pill(s.dayThu, _draft.orgMeetupThurs,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupThurs: !_draft.orgMeetupThurs))),
                      _pill(s.dayFri, _draft.orgMeetupFri,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupFri: !_draft.orgMeetupFri))),
                      _pill(s.daySat, _draft.orgMeetupSat,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupSat: !_draft.orgMeetupSat))),
                    ]),

                    _divider(),

                    // ── MEETUP TIMES ──────────────────────────────────────
                    _sectionLabel(s.secTimes),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(s.timeMornings,   _draft.orgMeetupTimeMornings,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeMornings: !_draft.orgMeetupTimeMornings))),
                      _pill(s.timeAfternoons, _draft.orgMeetupTimeAfternoons,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeAfternoons: !_draft.orgMeetupTimeAfternoons))),
                      _pill(s.timeEvenings,   _draft.orgMeetupTimeEvenings,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeEvenings: !_draft.orgMeetupTimeEvenings))),
                    ]),

                    const SizedBox(height: 24),
                  ],
                ),
              ),

              // ── Apply button ─────────────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(s.applyFilters,
                          style: const TextStyle(
                              fontSize:      15,
                              fontWeight:    FontWeight.w800,
                              color:         Colors.white,
                              letterSpacing: 0.6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Shared UI helpers ──────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
      Container(
        width: 3, height: 14,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2)),
      ),
      Text(text,
          style: const TextStyle(
              fontSize:      11,
              fontWeight:    FontWeight.w800,
              color:         _textSub,
              letterSpacing: 0.8)),
    ]),
  );

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 20),
    child: Divider(height: 1, color: _border),
  );

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
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
              color:        selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: selected ? AppColors.primary : _border,
                  width: 1.5),
            ),
            child: selected
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                  color:      selected ? AppColors.primary : _textMid)),
        ]),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required String allLabel,
    required String Function(String) displayFn,
    required ValueChanged<String> onChange,
  }) {
    final hasVal     = value.isNotEmpty;
    final isDisabled = options.isEmpty &&
        label != _FilterStrings.en.labelPrefecture &&
        label != _FilterStrings.ja.labelPrefecture;

    final safeValue =
    (value.isNotEmpty && options.contains(value)) ? value : '';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _textSub)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDisabled
              ? _cardBg.withOpacity(0.5)
              : hasVal
              ? AppColors.primary.withOpacity(0.06)
              : _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: hasVal
                  ? AppColors.primary.withOpacity(0.4)
                  : _border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value:        safeValue.isEmpty ? '' : safeValue,
            isExpanded:   true,
            dropdownColor: Colors.white,
            onChanged:    isDisabled ? null : (v) => onChange(v ?? ''),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDisabled
                  ? _textSub.withOpacity(0.4)
                  : hasVal
                  ? AppColors.primary
                  : _textSub,
              size: 20,
            ),
            style: TextStyle(
                color:      hasVal ? AppColors.primary : _textDark,
                fontSize:   14,
                fontWeight: FontWeight.w500),
            items: [
              DropdownMenuItem(
                value: '',
                child: Text(allLabel,
                    style: TextStyle(
                        color: isDisabled
                            ? _textSub.withOpacity(0.4)
                            : _textSub)),
              ),
              ...options.map((enKey) => DropdownMenuItem(
                value: enKey,
                child: Text(
                  displayFn(enKey),
                  style: TextStyle(
                      color: enKey == safeValue
                          ? AppColors.primary
                          : _textDark,
                      fontWeight: enKey == safeValue
                          ? FontWeight.w700
                          : FontWeight.w500),
                ),
              )),
            ],
          ),
        ),
      ),
    ]);
  }
}