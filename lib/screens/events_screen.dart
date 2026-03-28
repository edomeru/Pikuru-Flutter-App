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

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // ── Filter state ───────────────────────────────────────────────────────────
  String _selectedFilter = 'Upcoming';
  DateTime? _customStart;
  DateTime? _customEnd;

  // Default: Japan / Tokyo prefecture
  String? _selectedCountry    = 'Japan';
  String? _selectedPrefecture = 'Tokyo'; // stores the English prefecture name

  bool get _hasCustomRange => _customStart != null;

  bool get _isDefaultState =>
      _selectedFilter      == 'Upcoming' &&
          !_hasCustomRange     &&
          _selectedCountry     == 'Japan'    &&
          _selectedPrefecture  == 'Tokyo';

  static const int _defaultDays = 30;

  static const _filterOptions = [
    ('Upcoming',  Icons.bolt_rounded),
    ('Today',     Icons.wb_sunny_rounded),
    ('Tomorrow',  Icons.arrow_forward_rounded),
    ('This Week', Icons.date_range_rounded),
    ('Weekend',   Icons.weekend_rounded),
  ];

  // ── Build { country → [{en, jp}] } from loc_prefecture_en / loc_prefecture_jp
  Map<String, List<Map<String, String>>> _buildLocationMap(
      List<Map<String, dynamic>> locs) {
    final map = <String, List<Map<String, String>>>{};
    for (final loc in locs) {
      final country = (loc['loc_country'] ?? '').toString().trim();
      if (country.isEmpty) continue;

      // Prefecture English: prefer loc_prefecture_en, fall back to loc_prefecture
      final prefEn = ((loc['loc_prefecture_en'] ?? '').toString().trim().isNotEmpty
          ? loc['loc_prefecture_en']
          : loc['loc_prefecture'] ?? '')
          .toString()
          .trim();

      // Prefecture Japanese
      final prefJp = (loc['loc_prefecture_jp'] ?? '').toString().trim();

      if (prefEn.isEmpty) continue;

      map.putIfAbsent(country, () => []);
      final already = map[country]!.any((p) => p['en'] == prefEn);
      if (!already) map[country]!.add({'en': prefEn, 'jp': prefJp});
    }

    // Sort countries & prefectures alphabetically
    final sorted = Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    for (final prefs in sorted.values) {
      prefs.sort((a, b) => a['en']!.compareTo(b['en']!));
    }
    return sorted;
  }

  // ── Header badge label ─────────────────────────────────────────────────────
  String get _locationLabel {
    if (_selectedPrefecture != null) return _selectedPrefecture!;
    if (_selectedCountry    != null) return _selectedCountry!;
    return 'All Countries';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Location matching ──────────────────────────────────────────────────────
  bool _matchesLocation(
      Map<String, dynamic> event, List<Map<String, dynamic>> allLocs) {
    if (_selectedCountry == null) return true;

    final targetCountry = _selectedCountry!.toLowerCase();
    final targetPref    = _selectedPrefecture?.toLowerCase();

    // Resolve loc document via loc_id
    final locId =
    (event['loc_id'] ?? event['event_loc_id'] ?? '').toString().trim();
    Map<String, dynamic> loc = {};
    if (locId.isNotEmpty) {
      loc = allLocs.firstWhere(
            (l) => (l['loc_id'] ?? l['id'] ?? '').toString() == locId,
        orElse: () => {},
      );
    }

    String get(String key) =>
        ((loc.isNotEmpty ? loc[key] : null) ?? event[key] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    // Country check
    final country = get('loc_country');
    if (country.isEmpty ||
        (!country.contains(targetCountry) &&
            !targetCountry.contains(country))) {
      return false;
    }
    if (targetPref == null) return true;

    // Prefecture check — try all prefecture fields
    for (final key in [
      'loc_prefecture_en',
      'loc_prefecture_jp',
      'loc_prefecture',
      'event_prefecture',
      'prefecture',
    ]) {
      final v = get(key);
      if (v.isNotEmpty &&
          (v.contains(targetPref) || targetPref.contains(v))) {
        return true;
      }
    }
    return false;
  }

  // ── Filter logic ───────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> events,
      List<Map<String, dynamic>> allLocs) {
    final now          = DateTime.now();
    final today        = DateTime(now.year, now.month, now.day);
    final tomorrow     = today.add(const Duration(days: 1));
    final defaultEnd   = today.add(const Duration(days: _defaultDays));
    final daysUntilSat = (DateTime.saturday - now.weekday + 7) % 7;
    final saturday =
    today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    final sunday    = saturday.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: 7 - now.weekday));
    final q         = _searchController.text.toLowerCase().trim();

    return events.where((e) {
      if (q.isNotEmpty) {
        final title = (e['event_title'] ?? '').toString().toLowerCase();
        final type  = (e['event_type']  ?? '').toString().toLowerCase();
        if (!title.contains(q) && !type.contains(q)) return false;
      }
      if (!_matchesLocation(e, allLocs)) return false;

      final raw = e['event_date'];
      DateTime? d;
      if (raw is Timestamp)
        d = raw.toDate();
      else if (raw is String && raw.isNotEmpty) {
        try { d = DateTime.parse(raw); } catch (_) {}
      }
      if (d == null) return false;
      final day = DateTime(d.year, d.month, d.day);

      if (_hasCustomRange) {
        final end = _customEnd ?? _customStart!;
        return !day.isBefore(_customStart!) && !day.isAfter(end);
      }
      switch (_selectedFilter) {
        case 'Today':     return _isSameDay(day, today);
        case 'Tomorrow':  return _isSameDay(day, tomorrow);
        case 'This Week': return !day.isBefore(today) && !day.isAfter(endOfWeek);
        case 'Weekend':
          return _isSameDay(day, saturday) || _isSameDay(day, sunday);
        default:
          return !day.isBefore(today) && !day.isAfter(defaultEnd);
      }
    }).toList();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Filter modal ───────────────────────────────────────────────────────────
  void _showFilterModal() {
    String    tempFilter = _selectedFilter;
    DateTime? tempStart  = _customStart;
    DateTime? tempEnd    = _customEnd;
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
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 12, bottom: 20),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0D0D0D),
                              letterSpacing: -0.4)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded,
                              color: AppColors.primary, size: 18),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── LOCATION section header ───────────────────────────────
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text('Location',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D0D0D))),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // ── Two dropdowns: Country  |  Prefecture ─────────────────
                  Row(
                    children: [
                      // Country dropdown
                      Expanded(
                        child: _LocationDropdown(
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
                                onSelected: (country) =>
                                    setModalState(() {
                                      tempCountry = country;
                                      // Reset prefecture if it doesn't belong to
                                      // the new country (or country cleared)
                                      if (country == null) {
                                        tempPrefecture = null;
                                      } else if (!(locationMap[country] ?? [])
                                          .any((p) => p['en'] == tempPrefecture)) {
                                        tempPrefecture = null;
                                      }
                                    }),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Prefecture / Area dropdown
                      Expanded(
                        child: _LocationDropdown(
                          icon: Icons.location_on_rounded,
                          label: tempPrefecture ?? 'Area',
                          hasValue: tempPrefecture != null,
                          enabled: tempCountry != null,
                          onTap: tempCountry == null
                              ? null
                              : () {
                            showDialog(
                              context: context,
                              barrierColor:
                              Colors.black.withOpacity(0.25),
                              builder: (_) => _PrefecturePickerDialog(
                                country: tempCountry!,
                                prefectures: availablePrefs,
                                currentPrefecture: tempPrefecture,
                                onSelected: (pref) => setModalState(
                                        () => tempPrefecture = pref),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── DATE ─────────────────────────────────────────────────
                  const Text('DATE',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF888A90),
                          letterSpacing: 1.0)),
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
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32, height: 32,
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primary.withOpacity(0.12)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(9),
                              ),
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
                                            : const Color(0xFF0D0D0D),
                                      )),
                                  Text(subtitle,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSel
                                            ? AppColors.primary
                                            .withOpacity(0.6)
                                            : const Color(0xFF999BA0),
                                      )),
                                ],
                              )
                                  : Text(label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSel
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSel
                                        ? AppColors.primary
                                        : const Color(0xFF0D0D0D),
                                  )),
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
                                  width: 2,
                                ),
                              ),
                              child: isSel
                                  ? Center(
                                child: Container(
                                  width: 9, height: 9,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Custom date row
                  GestureDetector(
                    onTap: () async {
                      final result =
                      await Navigator.push<Map<String, DateTime?>>(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => ChooseDateScreen(
                            initialStart: tempStart,
                            initialEnd: tempEnd,
                          ),
                        ),
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
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: hasRange
                                  ? AppColors.primary.withOpacity(0.12)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(9),
                            ),
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
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
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
                                          .withOpacity(0.7)),
                                ),
                              ],
                            )
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
                                  width: 1.5),
                            ),
                            child: Icon(
                              hasRange
                                  ? Icons.edit_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 14,
                              color: hasRange
                                  ? AppColors.primary
                                  : const Color(0xFF888A90),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Action buttons ────────────────────────────────────────
                  Row(
                    children: [
                      // Reset → Japan / Tokyo
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() {
                            tempFilter      = 'Upcoming';
                            tempStart       = null;
                            tempEnd         = null;
                            tempCountry     = 'Japan';
                            tempPrefecture  = 'Tokyo';
                          }),
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: AppColors.primary, width: 1.5),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('Reset',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFilter      = tempFilter;
                              _customStart         = tempStart;
                              _customEnd           = tempEnd;
                              _selectedCountry     = tempCountry;
                              _selectedPrefecture  = tempPrefecture;
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
                                  offset: const Offset(0, 4),
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
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final showAddButton = ref.watch(showAddEventButtonProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(child: _buildEventsList()),
              ],
            ),
            if (showAddButton)
              Positioned(
                bottom: 24, left: 0, right: 0,
                child: Center(child: _buildAddEventButton()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isFiltered = !_isDefaultState;
    final fmt = DateFormat('MMM d');

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    Wrap(
                      spacing: 6, runSpacing: 4,
                      children: [
                        _activeBadge(
                          icon: Icons.location_on_rounded,
                          label: _locationLabel,
                          onTap: _showFilterModal,
                        ),
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
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: _showFilterModal,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isFiltered
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: isFiltered
                                  ? Colors.white
                                  : AppColors.primary,
                              size: 20),
                        ),
                        if (isFiltered)
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
                                      shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
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
                      color: Colors.black.withOpacity(0.35), size: 20),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Date filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _filterChip('Upcoming',  icon: Icons.bolt_rounded),
                _filterChip('Today',     icon: Icons.wb_sunny_rounded),
                _filterChip('Tomorrow',  icon: Icons.arrow_forward_rounded),
                _filterChip('This Week', icon: Icons.date_range_rounded),
                _filterChip('Weekend',   icon: Icons.weekend_rounded),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(height: 1, color: const Color(0xFFEEEFF1)),
        ],
      ),
    );
  }

  Widget _activeBadge({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool showClose = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
            if (showClose) ...[
              const SizedBox(width: 4),
              Icon(Icons.close_rounded, size: 11, color: AppColors.primary),
            ],
          ],
        ),
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
            color: isSelected ? AppColors.primary : const Color(0xFFDDDEE1),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 15,
                color: isSelected ? Colors.white : const Color(0xFF888A90)),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF555760),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                )),
          ],
        ),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                if (_selectedCountry != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedCountry    = null;
                      _selectedPrefecture = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Show all countries',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                    ),
                  ),
                ],
              ],
            ),
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
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Something went wrong.\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black45, fontSize: 14)),
        ),
      ),
    );
  }

  Widget _buildAddEventButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [

        // ── Pill → opens AddEventScreen ────────────────────────────────────
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEventScreen()),
          ),
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
                    offset: const Offset(0, 8)),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add an Event',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── ✕ dismiss button (hides the pill without navigating) ───────────
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
                border: Border.all(color: const Color(0xFF0D0D0D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: Color(0xFF0D0D0D)),
            ),
          ),
        ),
      ],
    );
  }

}

// ══════════════════════════════════════════════════════════════════════════════
// Dropdown button pill — Groups screen style
// ══════════════════════════════════════════════════════════════════════════════
class _LocationDropdown extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool hasValue;
  final bool enabled;
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
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16,
                color: active
                    ? AppColors.primary
                    : enabled
                    ? const Color(0xFF555760)
                    : const Color(0xFFBBBCC0)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? AppColors.primary
                      : enabled
                      ? const Color(0xFF333438)
                      : const Color(0xFFBBBCC0),
                ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: active
                    ? AppColors.primary
                    : enabled
                    ? const Color(0xFF888A90)
                    : const Color(0xFFBBBCC0)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Country picker dialog
// ══════════════════════════════════════════════════════════════════════════════
class _CountryPickerDialog extends StatelessWidget {
  final List<String> countries;
  final String? currentCountry;
  final void Function(String? country) onSelected;

  const _CountryPickerDialog({
    required this.countries,
    required this.currentCountry,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
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
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PickerRow(
                        label: 'All Countries',
                        isHeader: true,
                        isSelected: currentCountry == null,
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(null);
                        },
                      ),
                      const _Divider(),
                      ...countries.asMap().entries.map((e) {
                        final country = e.value;
                        final isLast  = e.key == countries.length - 1;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PickerRow(
                              label: country,
                              isHeader: false,
                              isSelected: currentCountry == country,
                              onTap: () {
                                Navigator.pop(context);
                                onSelected(country);
                              },
                            ),
                            if (!isLast) const _Divider(),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Prefecture / Area picker dialog
// ══════════════════════════════════════════════════════════════════════════════
class _PrefecturePickerDialog extends StatelessWidget {
  final String country;
  final List<Map<String, String>> prefectures; // [{en, jp}]
  final String? currentPrefecture;
  final void Function(String? prefecture) onSelected;

  const _PrefecturePickerDialog({
    required this.country,
    required this.prefectures,
    required this.currentPrefecture,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          behavior: HitTestBehavior.opaque,
          child: const SizedBox.expand(),
        ),
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
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // "All [Country]" — clears prefecture filter
                      _PickerRow(
                        label: 'All $country',
                        isHeader: true,
                        isSelected: currentPrefecture == null,
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(null);
                        },
                      ),
                      const _Divider(),
                      ...prefectures.asMap().entries.map((e) {
                        final pref   = e.value;
                        final en     = pref['en']!;
                        final jp     = pref['jp'] ?? '';
                        final isLast = e.key == prefectures.length - 1;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PickerRow(
                              label: en,
                              // show JP name as subtitle when available
                              sublabel: jp.isNotEmpty ? jp : null,
                              isHeader: false,
                              isSelected: currentPrefecture == en,
                              onTap: () {
                                Navigator.pop(context);
                                onSelected(en);
                              },
                            ),
                            if (!isLast) const _Divider(),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared picker row
// ══════════════════════════════════════════════════════════════════════════════
class _PickerRow extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isHeader;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget? leading;
  final Widget? trailing;

  const _PickerRow({
    required this.label,
    this.sublabel,
    required this.isHeader,
    required this.isSelected,
    required this.onTap,
    this.leading,
    this.trailing,
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
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
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
                        letterSpacing: -0.2,
                      )),
                  Text(sublabel!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF888880),
                          fontWeight: FontWeight.w400)),
                ],
              )
                  : Text(label,
                  style: TextStyle(
                    fontSize: isHeader ? 14 : 16,
                    fontWeight:
                    isHeader ? FontWeight.w500 : FontWeight.w600,
                    color: isHeader
                        ? const Color(0xFF888880)
                        : const Color(0xFF1A1A1A),
                    letterSpacing: -0.2,
                  )),
            ),
            if (trailing != null) trailing!,
            if (isSelected)
              Icon(Icons.check_rounded, size: 18, color: AppColors.primary),
          ],
        ),
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