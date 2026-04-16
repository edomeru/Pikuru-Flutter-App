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

      String field(String locKey, String orgKey) =>
          (loc[locKey] ?? g[orgKey] ?? '').toString().toLowerCase().trim();

      final country = field('loc_country', 'org_country');
      final prefEn  = field('loc_prefecture_en', 'org_prefecture');
      final pref    = field('loc_prefecture', 'org_prefecture');
      final cityEn  = field('loc_city_en', 'org_city');
      final city    = field('loc_city', 'org_city');

      if (orgCountry != null) {
        final target = orgCountry!.toLowerCase();
        if (!country.contains(target) && !target.contains(country)) return false;
      }

      if (orgPrefecture != null) {
        final target = orgPrefecture!.toLowerCase();
        final matched = prefEn.contains(target) || target.contains(prefEn) ||
            pref.contains(target) || target.contains(pref);
        if (!matched) return false;
      }

      if (orgCity != null) {
        final target = orgCity!.toLowerCase();
        final matched = cityEn.contains(target) || target.contains(cityEn) ||
            city.contains(target) || target.contains(city);
        if (!matched) return false;
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
// GroupFilterModal  —  bottom-sheet widget
// Returns a GroupFilter via Navigator.pop when the user taps Apply.
// ─────────────────────────────────────────────────────────────────────────────
class GroupFilterModal extends StatefulWidget {
  final GroupFilter currentFilter;
  final List<Map<String, dynamic>> allGroups;
  final Map<String, Map<String, dynamic>> locMap;

  const GroupFilterModal({
    super.key,
    required this.currentFilter,
    required this.allGroups,
    required this.locMap,
  });

  @override
  State<GroupFilterModal> createState() => _GroupFilterModalState();
}

class _GroupFilterModalState extends State<GroupFilterModal> {
  late GroupFilter _draft;

  late final List<String> _prefectures;
  late final Map<String, List<String>> _prefCityMap;

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter.copyWith(orgCountry: 'Japan');

    final prefectures = <String>{};
    final prefCityMap = <String, Set<String>>{};

    for (final g in widget.allGroups) {
      // ── Only include Japan groups ──────────────────────────────────────────
      final locId = (g['org_loc_id'] ?? '').toString();
      final loc = widget.locMap[locId] ?? {};

      final country = (loc['loc_country'] ?? g['org_country'] ?? '')
          .toString().trim().toLowerCase();
      if (country != 'japan') continue; // ← skip non-Japan

      final pe = (loc['loc_prefecture_en'] ?? loc['loc_prefecture'] ?? g['org_prefecture'] ?? '')
          .toString().trim();
      if (pe.isEmpty) continue;         // ← skip if no prefecture resolved

      final city = (g['org_city'] ?? '').toString().trim();

      prefectures.add(pe);
      prefCityMap.putIfAbsent(pe, () => <String>{});
      if (city.isNotEmpty) prefCityMap[pe]!.add(city);
    }

    _prefectures = prefectures.toList()..sort();
    _prefCityMap = prefCityMap.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

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
    final currentCities = _draft.orgPrefecture != null
        ? (_prefCityMap[_draft.orgPrefecture] ?? <String>[])
        : <String>[];

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────────
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
                child: Row(children: [
                  const Text(
                    'Filter Groups',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        letterSpacing: -0.4),
                  ),
                  const Spacer(),
                  if (!_draft.isDefault)
                    TextButton(
                      onPressed: _clear,
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 34,
                      height: 34,
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

              // ── Scrollable filter sections ───────────────────────────────
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [

                    // ── LOCATION ───────────────────────────────────────────
                    _sectionLabel('LOCATION'),
                    _dropdown(
                      label: 'Prefecture',
                      value: _draft.orgPrefecture ?? '',
                      options: _prefectures,
                      allLabel: 'All prefectures',
                      onChange: (v) => setState(() => _draft = _draft.copyWith(
                          orgPrefecture: v.isEmpty ? null : v,
                          orgCity: null)),
                    ),
                    const SizedBox(height: 12),
                    _dropdown(
                      label: 'City',
                      value: _draft.orgCity ?? '',
                      options: currentCities,
                      allLabel: _draft.orgPrefecture == null
                          ? 'Select a prefecture first'
                          : 'All cities',
                      onChange: (v) => setState(() => _draft =
                          _draft.copyWith(orgCity: v.isEmpty ? null : v)),
                    ),

                    _divider(),

                    // ── SKILL LEVELS ───────────────────────────────────────
                    _sectionLabel('SKILL LEVELS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(
                          'Beginner',
                          _draft.orgSkillBeginner,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillBeginner: !_draft.orgSkillBeginner))),
                      _pill(
                          'Intermediate',
                          _draft.orgSkillIntermediate,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillIntermediate:
                              !_draft.orgSkillIntermediate))),
                      _pill(
                          'Advanced',
                          _draft.orgSkillAdvance,
                              () => setState(() => _draft = _draft.copyWith(
                              orgSkillAdvance: !_draft.orgSkillAdvance))),
                    ]),

                    _divider(),

                    // ── AGE GROUPS ─────────────────────────────────────────
                    _sectionLabel('AGE GROUPS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(
                          'Juniors',
                          _draft.orgAgeJuniors,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeJuniors: !_draft.orgAgeJuniors))),
                      _pill(
                          'Students',
                          _draft.orgAgeStudents,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeStudents: !_draft.orgAgeStudents))),
                      _pill(
                          'Adults',
                          _draft.orgAgeAdult,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeAdult: !_draft.orgAgeAdult))),
                      _pill(
                          'Seniors',
                          _draft.orgAgeSeniors,
                              () => setState(() => _draft = _draft.copyWith(
                              orgAgeSeniors: !_draft.orgAgeSeniors))),
                    ]),

                    _divider(),

                    // ── MEETUP DAYS ────────────────────────────────────────
                    _sectionLabel('MEETUP DAYS'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill('Sun', _draft.orgMeetupSun,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupSun: !_draft.orgMeetupSun))),
                      _pill('Mon', _draft.orgMeetupMon,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupMon: !_draft.orgMeetupMon))),
                      _pill('Tue', _draft.orgMeetupTues,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupTues: !_draft.orgMeetupTues))),
                      _pill('Wed', _draft.orgMeetupWeds,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupWeds: !_draft.orgMeetupWeds))),
                      _pill('Thu', _draft.orgMeetupThurs,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupThurs: !_draft.orgMeetupThurs))),
                      _pill('Fri', _draft.orgMeetupFri,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupFri: !_draft.orgMeetupFri))),
                      _pill('Sat', _draft.orgMeetupSat,
                              () => setState(() => _draft = _draft.copyWith(orgMeetupSat: !_draft.orgMeetupSat))),
                    ]),

                    _divider(),

                    // ── MEETUP TIMES ───────────────────────────────────────
                    _sectionLabel('MEETUP TIMES'),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _pill(
                          'Mornings',
                          _draft.orgMeetupTimeMornings,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeMornings:
                              !_draft.orgMeetupTimeMornings))),
                      _pill(
                          'Afternoons',
                          _draft.orgMeetupTimeAfternoons,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeAfternoons:
                              !_draft.orgMeetupTimeAfternoons))),
                      _pill(
                          'Evenings',
                          _draft.orgMeetupTimeEvenings,
                              () => setState(() => _draft = _draft.copyWith(
                              orgMeetupTimeEvenings:
                              !_draft.orgMeetupTimeEvenings))),
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
                      child: const Text(
                        'APPLY FILTERS',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.6),
                      ),
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
        width: 3,
        height: 14,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2)),
      ),
      Text(text,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _textSub,
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
            width: 15,
            height: 15,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
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
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : _textMid)),
        ]),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required String allLabel,
    required ValueChanged<String> onChange,
  }) {
    final hasVal = value.isNotEmpty;
    final isDisabled = options.isEmpty && label == 'City';

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
            color: hasVal ? AppColors.primary.withOpacity(0.4) : _border,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value.isEmpty ? '' : value,
            isExpanded: true,
            dropdownColor: Colors.white,
            onChanged: isDisabled ? null : (v) => onChange(v ?? ''),
            icon: Icon(Icons.keyboard_arrow_down_rounded,
                color: isDisabled
                    ? _textSub.withOpacity(0.4)
                    : hasVal
                    ? AppColors.primary
                    : _textSub,
                size: 20),
            style: TextStyle(
                color: hasVal ? AppColors.primary : _textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500),
            items: [
              DropdownMenuItem(
                  value: '',
                  child: Text(allLabel,
                      style: TextStyle(
                          color: isDisabled
                              ? _textSub.withOpacity(0.4)
                              : _textSub))),
              ...options.map((o) =>
                  DropdownMenuItem(value: o, child: Text(o))),
            ],
          ),
        ),
      ),
    ]);
  }
}