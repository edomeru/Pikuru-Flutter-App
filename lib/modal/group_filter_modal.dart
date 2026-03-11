import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GroupFilter — matches actual Firestore org document field names
//
// Fields used (from Organizations sheet in Pikuru_Data.xlsx):
//
//   LOCATION   : org_loc_id → locations collection → loc_prefecture_en / loc_city_en
//   ORG TYPE   : org_type   = "Professional" | "Gym/Club" | "Organization" | "Local Group"
//   SKILL      : org_skill_beginner (bool) | org_skill_intermediate (bool) | org_skill_advance (bool)
//   MEETING    : org_meetup_time_mornings (bool) | org_meetup_time_afternoons (bool)
//               | org_meetup_time_evenings (bool) | org_meetup_sat (bool) | org_meetup_sun (bool)
//               → mapped to "Mornings" | "Afternoons" | "Evenings" | "Weekends"
//
//   NOTE: org_age_* fields are currently empty in the DB so Age Group filter is omitted.
// ─────────────────────────────────────────────────────────────────────────────

class GroupFilter {
  final String? prefecture;  // English, e.g. "Tokyo" | null = All
  final String? city;        // English, e.g. "Shinjuku" | null = All
  final String? orgType;     // "Professional" | "Gym/Club" | "Organization" | "Local Group" | null
  final String? skillLevel;  // "Beginner" | "Intermediate" | "Advanced" | null
  final String? meetingTime; // "Mornings" | "Afternoons" | "Evenings" | "Weekends" | null

  const GroupFilter({
    this.prefecture,
    this.city,
    this.orgType,
    this.skillLevel,
    this.meetingTime,
  });

  /// Default on first load: Tokyo only.
  static const tokyo = GroupFilter(prefecture: 'Tokyo');

  bool get isDefault =>
      (prefecture == null || prefecture == 'Tokyo') &&
          city == null &&
          orgType == null &&
          skillLevel == null &&
          meetingTime == null;

  GroupFilter copyWith({
    Object? prefecture  = _s,
    Object? city        = _s,
    Object? orgType     = _s,
    Object? skillLevel  = _s,
    Object? meetingTime = _s,
  }) =>
      GroupFilter(
        prefecture:  prefecture  == _s ? this.prefecture  : prefecture  as String?,
        city:        city        == _s ? this.city        : city        as String?,
        orgType:     orgType     == _s ? this.orgType     : orgType     as String?,
        skillLevel:  skillLevel  == _s ? this.skillLevel  : skillLevel  as String?,
        meetingTime: meetingTime == _s ? this.meetingTime : meetingTime as String?,
      );

  // ── Location match (via locMap: org_loc_id → location doc) ───────────────
  bool _matchesLocation(
      Map<String, dynamic> g, Map<String, Map<String, dynamic>> locMap) {
    if (prefecture == null && city == null) return true;
    final locId = (g['org_loc_id'] ?? '').toString().trim();
    if (locId.isEmpty) return prefecture == null;
    final loc = locMap[locId];
    if (loc == null) return prefecture == null;

    if (prefecture != null) {
      final en = (loc['loc_prefecture_en'] ?? '').toString().trim();
      final jp = (loc['loc_prefecture']    ?? '').toString().trim();
      if ((en.isNotEmpty ? en : jp) != prefecture) return false;
    }
    if (city != null) {
      final en = (loc['loc_city_en'] ?? '').toString().trim();
      final jp = (loc['loc_city']    ?? '').toString().trim();
      if ((en.isNotEmpty ? en : jp) != city) return false;
    }
    return true;
  }

  // ── Org type match (org_type field) ───────────────────────────────────────
  bool _matchesOrgType(Map<String, dynamic> g) {
    if (orgType == null) return true;
    return (g['org_type'] ?? '').toString() == orgType;
  }

  // ── Skill match (org_skill_beginner / intermediate / advance) ────────────
  bool _matchesSkill(Map<String, dynamic> g) {
    if (skillLevel == null) return true;
    switch (skillLevel) {
      case 'Beginner':     return _t(g['org_skill_beginner']);
      case 'Intermediate': return _t(g['org_skill_intermediate']);
      case 'Advanced':     return _t(g['org_skill_advance']);
    }
    return true;
  }

  // ── Meeting time match ────────────────────────────────────────────────────
  // Org fields: org_meetup_time_mornings | org_meetup_time_afternoons
  //             | org_meetup_time_evenings | org_meetup_sat | org_meetup_sun
  bool _matchesMeeting(Map<String, dynamic> g) {
    if (meetingTime == null) return true;
    switch (meetingTime) {
      case 'Mornings':   return _t(g['org_meetup_time_mornings']);
      case 'Afternoons': return _t(g['org_meetup_time_afternoons']);
      case 'Evenings':   return _t(g['org_meetup_time_evenings']);
      case 'Weekends':   return _t(g['org_meetup_sat']) || _t(g['org_meetup_sun']);
      case 'Weekdays':
        return _t(g['org_meetup_mon'])  || _t(g['org_meetup_tues']) ||
            _t(g['org_meetup_weds']) || _t(g['org_meetup_thurs']) ||
            _t(g['org_meetup_fri']);
    }
    return true;
  }

  bool matches(Map<String, dynamic> g, Map<String, Map<String, dynamic>> locMap) =>
      _matchesLocation(g, locMap) &&
          _matchesOrgType(g) &&
          _matchesSkill(g) &&
          _matchesMeeting(g);

  static bool _t(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num)  return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes';
  }
}

const _s = Object(); // sentinel

// ── Location map helper ───────────────────────────────────────────────────────
Map<String, Map<String, dynamic>> buildLocMap(
    List<Map<String, dynamic>> locations) {
  final map = <String, Map<String, dynamic>>{};
  for (final loc in locations) {
    final id    = (loc['loc_id']  ?? '').toString().trim();
    final docId = (loc['_doc_id'] ?? '').toString().trim();
    if (id.isNotEmpty)    map[id]    = loc;
    if (docId.isNotEmpty) map[docId] = loc;
  }
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// Modal
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

  static Future<GroupFilter?> show(
      BuildContext context, {
        required GroupFilter currentFilter,
        required List<Map<String, dynamic>> allGroups,
        required Map<String, Map<String, dynamic>> locMap,
      }) =>
      showModalBottomSheet<GroupFilter>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => GroupFilterModal(
          currentFilter: currentFilter,
          allGroups: allGroups,
          locMap: locMap,
        ),
      );

  @override
  State<GroupFilterModal> createState() => _GroupFilterModalState();
}

class _GroupFilterModalState extends State<GroupFilterModal> {
  late GroupFilter _draft;
  late final List<String> _prefectures;
  late final Map<String, List<String>> _citiesByPrefecture;

  // ── Fixed option lists (matching actual Firestore field values) ────────────

  // org_type values actually in DB
  static const _typeOptions = [
    'Local Group',
    'Gym/Club',
    'Organization',
    'Professional',
  ];

  // org_skill_* boolean fields
  static const _skillOptions = ['Beginner', 'Intermediate', 'Advanced'];

  // org_meetup_time_* and org_meetup_sat/sun boolean fields
  static const _meetingOptions = [
    'Weekdays',
    'Weekends',
    'Mornings',
    'Afternoons',
    'Evenings',
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter;
    _buildLocationData();
  }

  void _buildLocationData() {
    final prefSet = <String>{};
    final cityMap = <String, Set<String>>{};

    for (final g in widget.allGroups) {
      final locId = (g['org_loc_id'] ?? '').toString().trim();
      if (locId.isEmpty) continue;
      final loc = widget.locMap[locId];
      if (loc == null) continue;

      final prefEn = (loc['loc_prefecture_en'] ?? '').toString().trim();
      final pref   = (loc['loc_prefecture']    ?? '').toString().trim();
      final cityEn = (loc['loc_city_en']       ?? '').toString().trim();
      final city   = (loc['loc_city']          ?? '').toString().trim();

      final prefLabel = prefEn.isNotEmpty ? prefEn : pref;
      final cityLabel = cityEn.isNotEmpty ? cityEn : city;

      if (prefLabel.isNotEmpty) {
        prefSet.add(prefLabel);
        if (cityLabel.isNotEmpty) {
          cityMap.putIfAbsent(prefLabel, () => {}).add(cityLabel);
        }
      }
    }

    _prefectures        = prefSet.toList()..sort();
    _citiesByPrefecture = cityMap.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  List<String> get _currentCities =>
      _draft.prefecture != null
          ? (_citiesByPrefecture[_draft.prefecture] ?? [])
          : [];

  String? get _safeCity =>
      (_draft.city != null && _currentCities.contains(_draft.city))
          ? _draft.city
          : null;

  void _apply() => Navigator.of(context).pop(_draft);
  void _clear() => Navigator.of(context).pop(GroupFilter.tokyo);

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 60, 12, 0),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title + close
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Text(
                  'Filter Groups',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0D0D0D),
                    letterSpacing: -0.4,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 18, color: Colors.black.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),
          Divider(
              height: 24,
              thickness: 1,
              color: Colors.black.withOpacity(0.06)),

          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Location ─────────────────────────────────────
                  _label('Location', Icons.location_on_rounded),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _Dropdown(
                          value: _draft.prefecture,
                          hint: 'Prefecture',
                          icon: Icons.location_on_rounded,
                          items: _prefectures,
                          onChanged: (v) => setState(() {
                            _draft = _draft.copyWith(prefecture: v, city: null);
                          }),
                        ),
                      ),
                      if (_currentCities.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Dropdown(
                            value: _safeCity,
                            hint: 'Area',
                            icon: Icons.place_rounded,
                            items: _currentCities,
                            onChanged: (v) => setState(() {
                              _draft = _draft.copyWith(city: v);
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── Group type (org_type) ──────────────────────────
                  _label('Group type', Icons.groups_rounded),
                  const SizedBox(height: 12),
                  _Chips(
                    options: _typeOptions,
                    selected: _draft.orgType,
                    onTap: (v) => setState(() => _draft = _draft.copyWith(
                        orgType: _draft.orgType == v ? null : v)),
                  ),

                  const SizedBox(height: 24),

                  // ── Skill level ───────────────────────────────────
                  // Fields: org_skill_beginner | org_skill_intermediate | org_skill_advance
                  _label('Skill level', Icons.sports_tennis_rounded),
                  const SizedBox(height: 12),
                  _Chips(
                    options: _skillOptions,
                    selected: _draft.skillLevel,
                    onTap: (v) => setState(() => _draft = _draft.copyWith(
                        skillLevel: _draft.skillLevel == v ? null : v)),
                  ),

                  const SizedBox(height: 24),

                  // ── Meeting times ─────────────────────────────────
                  // Fields: org_meetup_time_mornings | org_meetup_time_afternoons
                  //         org_meetup_time_evenings | org_meetup_sat | org_meetup_sun
                  //         + org_meetup_mon..fri (for Weekdays)
                  _label('Meeting times', Icons.calendar_today_rounded),
                  const SizedBox(height: 12),
                  _Chips(
                    options: _meetingOptions,
                    selected: _draft.meetingTime,
                    onTap: (v) => setState(() => _draft = _draft.copyWith(
                        meetingTime: _draft.meetingTime == v ? null : v)),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Buttons
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad + 24),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _clear,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.15), width: 1.5),
                      ),
                      child: Center(
                        child: Text('Clear',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black.withOpacity(0.55))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: _apply,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('APPLY',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D0D0D),
                letterSpacing: 0.1)),
      ],
    );
  }
}

// ── Reusable dropdown ─────────────────────────────────────────────────────────

class _Dropdown extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final void Function(String?) onChanged;

  const _Dropdown({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final unique   = items.toSet().toList()..sort();
    final safeVal  = (value != null && unique.contains(value)) ? value : null;
    final isActive = safeVal != null;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withOpacity(0.06)
            : const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withOpacity(0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeVal,
          isExpanded: true,
          isDense: true,
          borderRadius: BorderRadius.circular(14),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isActive
                  ? AppColors.primary
                  : Colors.black.withOpacity(0.4)),
          hint: Row(children: [
            Icon(icon, size: 14, color: Colors.black.withOpacity(0.35)),
            const SizedBox(width: 6),
            Text(hint,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black.withOpacity(0.38))),
          ]),
          selectedItemBuilder: (ctx) => [
            _selectedRow(icon, hint),
            ...unique.map((i) => _selectedRow(icon, i)),
          ],
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text('All $hint',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.black.withOpacity(0.45))),
            ),
            ...unique.map((i) => DropdownMenuItem<String>(
              value: i,
              child: Text(i,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D0D0D))),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _selectedRow(IconData ico, String label) => Row(children: [
    Icon(ico, size: 14, color: AppColors.primary),
    const SizedBox(width: 6),
    Expanded(
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary),
          overflow: TextOverflow.ellipsis),
    ),
  ]);
}

// ── Reusable chip row ─────────────────────────────────────────────────────────

class _Chips extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final void Function(String) onTap;

  const _Chips({
    required this.options,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('All', selected == null),
        ...options.map((o) => _chip(o, selected == o)),
      ],
    );
  }

  Widget _chip(String label, bool active) {
    return GestureDetector(
      onTap: () => onTap(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? AppColors.primary : Colors.black.withOpacity(0.15),
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : Colors.black.withOpacity(0.55),
                letterSpacing: 0.1)),
      ),
    );
  }
}