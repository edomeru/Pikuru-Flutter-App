import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/widgets/group_card_list.dart';
import 'package:pikuru/modal/group_filter_modal.dart';
import 'package:pikuru/screens/add_group_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Lang type
// ─────────────────────────────────────────────────────────────────────────────
typedef Lang = String; // 'en' | 'ja'

// ─────────────────────────────────────────────────────────────────────────────
// buildLocMap
// ─────────────────────────────────────────────────────────────────────────────
Map<String, Map<String, dynamic>> buildLocMap(
    List<Map<String, dynamic>> locations,
    ) {
  final map = <String, Map<String, dynamic>>{};
  for (final d in locations) {
    final docId = (d['_doc_id'] ?? '').toString();
    final locId = (d['loc_id'] ?? '').toString();
    if (docId.isNotEmpty) map[docId] = d;
    if (locId.isNotEmpty) map[locId] = d;
  }
  return map;
}

// ─────────────────────────────────────────────────────────────────────────────
// resolveLocation
// ─────────────────────────────────────────────────────────────────────────────
String resolveLocation(
    Map<String, dynamic> g,
    Map<String, Map<String, dynamic>> locMap,
    Lang lang,
    ) {
  String cityEn = '', city = '', prefEn = '', pref = '', country = '';
  final locId = (g['org_loc_id'] ?? '').toString();
  if (locId.isNotEmpty && locMap.containsKey(locId)) {
    final d = locMap[locId]!;
    cityEn = (d['loc_city_en'] ?? '').toString().trim();
    city = (d['loc_city'] ?? '').toString().trim();
    prefEn = (d['loc_prefecture_en'] ?? '').toString().trim();
    pref = (d['loc_prefecture'] ?? '').toString().trim();
    country = (d['loc_country'] ?? '').toString().trim();
  }
  if (lang == 'ja') {
    if (prefEn.isEmpty && pref.isEmpty)
      pref = (g['org_prefecture_jp'] ?? g['org_prefecture'] ?? '')
          .toString()
          .trim();
    if (cityEn.isEmpty && city.isEmpty)
      city = (g['org_city_jp'] ?? g['org_city'] ?? '').toString().trim();
  } else {
    if (prefEn.isEmpty) prefEn = (g['org_prefecture'] ?? '').toString().trim();
    if (cityEn.isEmpty) cityEn = (g['org_city'] ?? '').toString().trim();
  }
  if (country.isEmpty) country = (g['org_country'] ?? '').toString().trim();

  final c = lang == 'ja'
      ? (city.isNotEmpty ? city : cityEn)
      : (cityEn.isNotEmpty ? cityEn : city);
  final p = lang == 'ja'
      ? (pref.isNotEmpty ? pref : prefEn)
      : (prefEn.isNotEmpty ? prefEn : pref);

  String loc;
  if (c.isNotEmpty && p.isNotEmpty)
    loc = '$c, $p';
  else if (c.isNotEmpty && country.isNotEmpty)
    loc = '$c, $country';
  else
    loc = c.isNotEmpty ? c : (p.isNotEmpty ? p : country);

  final venue = (g['org_venue_loc_name'] ?? '').toString().trim();
  if (venue.isNotEmpty && loc.isNotEmpty) return '$venue - $loc';
  if (venue.isNotEmpty) return venue;
  return loc;
}

// ─────────────────────────────────────────────────────────────────────────────
// resolveCity — always EN, used only for sorting
// ─────────────────────────────────────────────────────────────────────────────
String resolveCity(
    Map<String, dynamic> g,
    Map<String, Map<String, dynamic>> locMap,
    ) {
  final locId = (g['org_loc_id'] ?? '').toString();
  if (locId.isNotEmpty && locMap.containsKey(locId)) {
    final d = locMap[locId]!;
    final en = (d['loc_city_en'] ?? '').toString().trim();
    final ja = (d['loc_city'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    if (ja.isNotEmpty) return ja;
  }
  return (g['org_city'] ?? '').toString().trim();
}

// ─────────────────────────────────────────────────────────────────────────────
// resolveGroupName
// ─────────────────────────────────────────────────────────────────────────────
String resolveGroupName(Map<String, dynamic> g, Lang lang) {
  if (lang == 'ja') {
    final jp = (g['org_name_jp'] ?? '').toString().trim();
    if (jp.isNotEmpty) return jp;
  }
  return (g['org_name'] ?? '').toString().trim();
}

String resolveGroupDescription(Map<String, dynamic> g, Lang lang) {
  if (lang == 'ja') {
    final jp = (g['org_description_jp'] ?? '').toString().trim();
    if (jp.isNotEmpty && jp != 'null') return jp;
  }
  final en = (g['org_description'] ?? '').toString().trim();
  return en == 'null' ? '' : en;
}

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings
// ─────────────────────────────────────────────────────────────────────────────
class _T {
  final String searchHint,
      title,
      noResults,
      noMatch,
      noMatchSub,
      addGroup,
      langEn,
      langJa;
  final bool isJa;
  const _T({
    required this.searchHint,
    required this.title,
    required this.noResults,
    required this.noMatch,
    required this.noMatchSub,
    required this.addGroup,
    required this.langEn,
    required this.langJa,
    required this.isJa,
  });

  static const en = _T(
    searchHint: 'Search local groups...',
    title: 'Groups',
    noResults: 'No groups found.',
    noMatch: 'No groups match your search or filters.',
    noMatchSub: 'Try adjusting your filters.',
    addGroup: 'Add a Group',
    langEn: 'EN',
    langJa: '日本語',
    isJa: false,
  );
  static const ja = _T(
    searchHint: '地元のグループを検索...',
    title: 'グループ',
    noResults: 'グループが見つかりませんでした。',
    noMatch: '検索やフィルターに一致するグループがありません。',
    noMatchSub: 'フィルターを調整してみてください。',
    addGroup: 'グループ作成',
    langEn: 'EN',
    langJa: '日本語',
    isJa: true,
  );
  static _T of(Lang lang) => lang == 'ja' ? ja : en;

  String get chipBeginner => isJa ? '初級' : 'Beginner';
  String get chipIntermediate => isJa ? '中級' : 'Intermediate';
  String get chipAdvanced => isJa ? '上級' : 'Advanced';
  String get chipJuniors => isJa ? 'ジュニア' : 'Juniors';
  String get chipStudents => isJa ? '学生' : 'Students';
  String get chipAdults => isJa ? '大人' : 'Adults';
  String get chipSeniors => isJa ? 'シニア' : 'Seniors';
  String get chipMornings => isJa ? '午前' : 'Mornings';
  String get chipAfternoons => isJa ? '午後' : 'Afternoons';
  String get chipEvenings => isJa ? '夜間' : 'Evenings';
  // My Activity strings (parity with web app)
  String get myActivity   => isJa ? 'マイアクティビティ' : 'My Activity';
  String get groupsJoined => isJa ? '参加グループ'      : 'Groups Joined';
  String get groupsSaved  => isJa ? 'お気に入りグループ' : 'Favorite Groups';
  String get explore      => isJa ? '見る'              : 'Explore';

  List<String> get chipDays => isJa
      ? ['日', '月', '火', '水', '木', '金', '土']
      : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom pull-to-refresh widget
// Indicator styled to match EventsScreen's RefreshIndicator:
// white circular card background + AppColors.primary spinner
// ─────────────────────────────────────────────────────────────────────────────
class _PickleballRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const _PickleballRefresh({required this.child, required this.onRefresh});

  @override
  State<_PickleballRefresh> createState() => _PickleballRefreshState();
}

class _PickleballRefreshState extends State<_PickleballRefresh>
    with SingleTickerProviderStateMixin {
  static const double _triggerDistance = 80.0;
  // spinner size inside the white circle (matches Material RefreshIndicator)
  static const double _spinnerSize = 22.0;
  // white circle diameter (matches Material RefreshIndicator pill size)
  static const double _circleSize = 40.0;

  late AnimationController _spinController;

  double _dragOffset = 0.0;
  bool _isRefreshing = false;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is OverscrollNotification && notification.overscroll < 0) {
      setState(() {
        _dragOffset = (_dragOffset - notification.overscroll).clamp(
          0.0,
          _triggerDistance * 1.4,
        );
        _triggered = _dragOffset >= _triggerDistance;
      });
      if (_triggered && !_spinController.isAnimating) {
        _spinController.repeat();
      }
    }

    if (notification is ScrollEndNotification) {
      if (_triggered && !_isRefreshing) {
        _startRefresh();
      } else {
        _resetDrag();
      }
    }

    return false;
  }

  Future<void> _startRefresh() async {
    setState(() {
      _isRefreshing = true;
      _dragOffset = _triggerDistance;
    });
    if (!_spinController.isAnimating) _spinController.repeat();
    await widget.onRefresh();
    if (mounted) _resetDrag();
  }

  void _resetDrag() {
    _spinController.stop();
    setState(() {
      _dragOffset = 0.0;
      _isRefreshing = false;
      _triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset / _triggerDistance).clamp(0.0, 1.0);
    final indicatorVisible = _dragOffset > 4.0;

    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          AnimatedPadding(
            duration: _isRefreshing
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            padding: EdgeInsets.only(
              top: _dragOffset.clamp(0.0, _triggerDistance),
            ),
            child: widget.child,
          ),
          if (indicatorVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: _dragOffset.clamp(0.0, _triggerDistance),
                child: Center(
                  child: Opacity(
                    opacity: progress.clamp(0.2, 1.0),
                    // ── White circle card — identical to RefreshIndicator's pill ──
                    child: Container(
                      width: _circleSize,
                      height: _circleSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SizedBox(
                          width: _spinnerSize,
                          height: _spinnerSize,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                            value: _isRefreshing || _triggered
                                ? null
                                : progress,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GroupsScreen
// ─────────────────────────────────────────────────────────────────────────────
class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});
  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  GroupFilter _filter = const GroupFilter(
    orgCountry: 'Japan',
    orgPrefecture: 'Tokyo',
  );
  int _currentPage = 1;
  static const int _pageSize = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showAddGroupButtonProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Refresh: invalidate both providers so Riverpod re-fetches ────────────
  Future<void> _refresh() async {
    ref.invalidate(organizationsProvider);
    ref.invalidate(locationsProvider);
    // Wait until both providers have completed loading
    await Future.wait([
      ref.read(organizationsProvider.future),
      ref.read(locationsProvider.future),
    ]);
  }

  bool get _hasActiveFilter => !_filter.isDefault;

  Future<void> _openFilter({
    required List<Map<String, dynamic>> allGroups,
    required Map<String, Map<String, dynamic>> locMap,
    required String lang,
  }) async {
    final result = await showModalBottomSheet<GroupFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupFilterModal(
        currentFilter: _filter,
        allGroups: allGroups,
        locMap: locMap,
        lang: lang,
      ),
    );
    if (result != null && mounted) setState(() => _filter = result);
  }

  List<_Chip> _activeChips(_T t) {
    final chips = <_Chip>[];
    void add(String label, VoidCallback remove) =>
        chips.add(_Chip(label: label, onRemove: remove));

    if (_filter.orgPrefecture != null)
      add(
        _filter.orgPrefecture!,
            () => setState(
              () => _filter = _filter.copyWith(orgPrefecture: null, orgCity: null),
        ),
      );
    if (_filter.orgCity != null)
      add(
        _filter.orgCity!,
            () => setState(() => _filter = _filter.copyWith(orgCity: null)),
      );
    if (_filter.orgSkillBeginner)
      add(
        t.chipBeginner,
            () =>
            setState(() => _filter = _filter.copyWith(orgSkillBeginner: false)),
      );
    if (_filter.orgSkillIntermediate)
      add(
        t.chipIntermediate,
            () => setState(
              () => _filter = _filter.copyWith(orgSkillIntermediate: false),
        ),
      );
    if (_filter.orgSkillAdvance)
      add(
        t.chipAdvanced,
            () =>
            setState(() => _filter = _filter.copyWith(orgSkillAdvance: false)),
      );
    if (_filter.orgAgeJuniors)
      add(
        t.chipJuniors,
            () => setState(() => _filter = _filter.copyWith(orgAgeJuniors: false)),
      );
    if (_filter.orgAgeStudents)
      add(
        t.chipStudents,
            () => setState(() => _filter = _filter.copyWith(orgAgeStudents: false)),
      );
    if (_filter.orgAgeAdult)
      add(
        t.chipAdults,
            () => setState(() => _filter = _filter.copyWith(orgAgeAdult: false)),
      );
    if (_filter.orgAgeSeniors)
      add(
        t.chipSeniors,
            () => setState(() => _filter = _filter.copyWith(orgAgeSeniors: false)),
      );

    final days = t.chipDays;
    final getters = [
      _filter.orgMeetupSun,
      _filter.orgMeetupMon,
      _filter.orgMeetupTues,
      _filter.orgMeetupWeds,
      _filter.orgMeetupThurs,
      _filter.orgMeetupFri,
      _filter.orgMeetupSat,
    ];
    final setters = <VoidCallback>[
          () => setState(() => _filter = _filter.copyWith(orgMeetupSun: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupMon: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupTues: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupWeds: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupThurs: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupFri: false)),
          () => setState(() => _filter = _filter.copyWith(orgMeetupSat: false)),
    ];
    for (var i = 0; i < 7; i++) {
      if (getters[i]) add(days[i], setters[i]);
    }
    if (_filter.orgMeetupTimeMornings)
      add(
        t.chipMornings,
            () => setState(
              () => _filter = _filter.copyWith(orgMeetupTimeMornings: false),
        ),
      );
    if (_filter.orgMeetupTimeAfternoons)
      add(
        t.chipAfternoons,
            () => setState(
              () => _filter = _filter.copyWith(orgMeetupTimeAfternoons: false),
        ),
      );
    if (_filter.orgMeetupTimeEvenings)
      add(
        t.chipEvenings,
            () => setState(
              () => _filter = _filter.copyWith(orgMeetupTimeEvenings: false),
        ),
      );
    return chips;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final lang = ref.watch(appLangProvider);
    final t = _T.of(lang);
    final showAddButton = ref.watch(showAddGroupButtonProvider);
    final groupsAsync = ref.watch(organizationsProvider);
    final locMap = buildLocMap(
      ref.watch(locationsProvider).asData?.value ?? [],
    );
    final allGroups = groupsAsync.asData?.value ?? [];

    final validGroups =
    allGroups.where((g) {
      if (g['org_type'] != 'Local Group') return false;
      if (g['org_public'] != true) return false;
      if (g['org_pending_review'] == true) return false;
      return true;
    }).toList()..sort((a, b) {
      final ca = resolveCity(a, locMap).toLowerCase();
      final cb = resolveCity(b, locMap).toLowerCase();
      return ca.compareTo(cb);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(
                  t: t,
                  lang: lang,
                  allGroups: validGroups,
                  locMap: locMap,
                ),
                Expanded(
                  child: _buildGroupsList(
                    t,
                    groupsAsync,
                    validGroups,
                    locMap,
                    lang,
                  ),
                ),
              ],
            ),
            if (showAddButton)
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(child: _buildAddGroupButton(t)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({
    required _T t,
    required String lang,
    required List<Map<String, dynamic>> allGroups,
    required Map<String, Map<String, dynamic>> locMap,
  }) {
    final chips = _activeChips(t);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (_filter.orgPrefecture != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              [
                                _filter.orgPrefecture,
                                if (_filter.orgCity != null) _filter.orgCity,
                              ].whereType<String>().join(', '),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => _openFilter(
                      allGroups: allGroups,
                      locMap: locMap,
                      lang: lang,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _hasActiveFilter
                                ? AppColors.primary
                                : AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: _hasActiveFilter
                                ? Colors.white
                                : AppColors.primary,
                            size: 20,
                          ),
                        ),
                        if (_hasActiveFilter)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LangButton(
                          label: t.langEn,
                          selected: lang == 'en',
                          onTap: () =>
                              ref.read(appLangProvider.notifier).setLang('en'),
                        ),
                        _LangButton(
                          label: t.langJa,
                          selected: lang == 'ja',
                          onTap: () =>
                              ref.read(appLangProvider.notifier).setLang('ja'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                hintText: t.searchHint,
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.black.withOpacity(0.35),
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                  onTap: () => setState(() => _searchController.clear()),
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.black.withOpacity(0.35),
                    size: 20,
                  ),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (chips.isNotEmpty) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...chips.map((c) => _buildFilterChip(c)),
                  const SizedBox(width: 4),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          Container(height: 1, color: const Color(0xFFEEEFF1)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(_Chip chip) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            chip.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: chip.onRemove,
            child: Icon(
              Icons.close_rounded,
              size: 13,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUPS LIST — wrapped in _PickleballRefresh for all states
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGroupsList(
      _T t,
      AsyncValue<List<Map<String, dynamic>>> groupsAsync,
      List<Map<String, dynamic>> validGroups,
      Map<String, Map<String, dynamic>> locMap,
      Lang lang,
      ) {
    return groupsAsync.when(
      data: (_) {
        if (validGroups.isEmpty) {
          return _PickleballRefresh(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 400,
                child: _empty(Icons.group_off_rounded, t.noResults),
              ),
            ),
          );
        }

        final query = _searchController.text.toLowerCase().trim();
        var filtered = query.isEmpty
            ? validGroups
            : validGroups.where((g) {
          final nameEn = (g['org_name'] ?? '').toString().toLowerCase();
          final nameJp = (g['org_name_jp'] ?? '')
              .toString()
              .toLowerCase();
          final descEn = (g['org_description'] ?? '')
              .toString()
              .toLowerCase();
          final descJp = (g['org_description_jp'] ?? '')
              .toString()
              .toLowerCase();
          return nameEn.contains(query) ||
              nameJp.contains(query) ||
              descEn.contains(query) ||
              descJp.contains(query);
        }).toList();
        filtered = filtered.where((g) => _filter.matches(g, locMap)).toList();

        if (filtered.isEmpty) {
          return _PickleballRefresh(
            onRefresh: _refresh,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 400,
                child: _empty(
                  Icons.search_off_rounded,
                  query.isNotEmpty
                      ? (t.isJa
                          ? '「$query」に一致するグループはありません。'
                          : 'No groups match "$query".')
                      : t.noMatch,
                  sub: t.noMatchSub,
                ),
              ),
            ),
          );
        }

        final enriched = filtered
            .map(
              (g) => {
            ...g,
            '_resolved_name': resolveGroupName(g, lang),
            '_resolved_description': resolveGroupDescription(g, lang),
            '_resolved_location': resolveLocation(g, locMap, lang),
            '_lang': lang,
          },
        )
            .toList();

        // ── Pagination ────────────────────────────────────────────────
        final totalPages = (enriched.length / _pageSize).ceil().clamp(1, 9999);
        final safePage = _currentPage.clamp(1, totalPages);
        final startIdx = (safePage - 1) * _pageSize;
        final pageItems = enriched.skip(startIdx).take(_pageSize).toList();

        return _PickleballRefresh(
          onRefresh: _refresh,
          child: ListView.builder(
            key: ValueKey('$lang-$safePage'),
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
            itemCount: 1 + pageItems.length + (totalPages > 1 ? 1 : 0),
            itemBuilder: (context, rawI) {
              // ── My Activity block (parity with web app) ──
              if (rawI == 0) {
                return _MyActivityGroupsBlock(t: t);
              }
              final i = rawI - 1;
              if (i < pageItems.length) {
                return _PressScaleGroup(
                  child: GroupCardList(group: pageItems[i]),
                );
              }
              // ── Page Bubble Controls ──────────────────────────────
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Prev arrow
                    _PageArrowBtn(
                      enabled: safePage > 1,
                      forward: false,
                      onTap: () => _goToPage(safePage - 1),
                    ),
                    const SizedBox(width: 6),
                    // Page number bubbles
                    ...List.generate(totalPages, (idx) {
                      final p = idx + 1;
                      final isActive = p == safePage;
                      final show =
                          p == 1 ||
                              p == totalPages ||
                              (p - safePage).abs() <= 1;
                      if (!show) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: GestureDetector(
                          onTap: () => _goToPage(p),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.primary.withOpacity(0.08),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : AppColors.primary.withOpacity(0.2),
                              ),
                              boxShadow: isActive
                                  ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(
                                    0.35,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                                  : [],
                            ),
                            child: Center(
                              child: Text(
                                '$p',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.primary.withOpacity(0.6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(width: 6),
                    // Next arrow
                    _PageArrowBtn(
                      enabled: safePage < totalPages,
                      forward: true,
                      onTap: () => _goToPage(safePage + 1),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
      loading: () => Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      ),
      error: (e, _) => _PickleballRefresh(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.isJa
                      ? 'エラーが発生しました。\n$e'
                      : 'Something went wrong.\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black45, fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty(IconData icon, String msg, {String? sub}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: Colors.black.withOpacity(0.1)),
          const SizedBox(height: 14),
          Text(
            msg,
            style: TextStyle(
              fontSize: 16,
              color: Colors.black.withOpacity(0.35),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(
              sub,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black.withOpacity(0.25),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddGroupButton(_T t) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddGroupScreen()),
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
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.addGroup,
                  style: const TextStyle(
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
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () =>
            ref.read(showAddGroupButtonProvider.notifier).state = false,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D0D0D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: Color(0xFF0D0D0D),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Pagination helper ───────────────────────────────────────
  void _goToPage(int page) {
    setState(() => _currentPage = page);
    // Scroll back to top of the list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
}

// ── _LangButton ───────────────────────────────────────────────────────────────
class _LangButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.primary.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

// ── _Chip ─────────────────────────────────────────────────────────────────────────────
class _Chip {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});
}

// ── _PressScaleGroup: tactile press-scale wrapper for group cards ──────────────
class _PressScaleGroup extends StatefulWidget {
  final Widget child;
  const _PressScaleGroup({required this.child});
  @override
  State<_PressScaleGroup> createState() => _PressScaleGroupState();
}

class _PressScaleGroupState extends State<_PressScaleGroup> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      behavior: HitTestBehavior.translucent,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── _PageArrowBtn: prev/next arrow button for pagination ────────────────────
class _PageArrowBtn extends StatelessWidget {
  final bool enabled;
  final bool forward;
  final VoidCallback onTap;
  const _PageArrowBtn({
    required this.enabled,
    required this.forward,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.25,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.08),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Icon(
            forward ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
            size: 20,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// My Activity block (Groups) — parity with web app /groups sidebar
// Live counts from Firestore user_groups where user_id == uid:
//   • joined status ∈ {active, pending, approved, rejected, removed} → Groups Joined
//   • status == 'interested' OR is_favorite == true                  → Favorite Groups
// Shown only when a user is signed in.
// ─────────────────────────────────────────────────────────────────────────────
class _MyActivityGroupsBlock extends StatefulWidget {
  final _T t;
  const _MyActivityGroupsBlock({required this.t});

  @override
  State<_MyActivityGroupsBlock> createState() => _MyActivityGroupsBlockState();
}

class _MyActivityGroupsBlockState extends State<_MyActivityGroupsBlock> {
  static const Color _green      = Color(0xFF3A7D44);
  static const Color _greenLight = Color(0xFFE8F4EB);
  static const Color _border     = Color(0xFFE2EAE4);
  static const Color _textMid    = Color(0xFF5C6B61);
  static const Color _muted      = Color(0xFFC7D3CB);

  int _joined = 0;
  int _saved  = 0;
  String? _uid;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;
  StreamSubscription<User?>? _subAuth;

  static const _joinedStatuses = {
    'active', 'pending', 'approved', 'rejected', 'removed',
  };

  @override
  void initState() {
    super.initState();
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _subAuth = FirebaseAuth.instance.authStateChanges().listen((u) {
      final newUid = u?.uid;
      if (newUid == _uid) return;
      setState(() {
        _uid = newUid;
        _joined = 0;
        _saved = 0;
      });
      _resubscribe();
    });
    _resubscribe();
  }

  void _resubscribe() {
    _sub?.cancel();
    _sub = null;
    final uid = _uid;
    if (uid == null) return;

    _sub = FirebaseFirestore.instance
        .collection('user_groups')
        .where('user_id', isEqualTo: uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      var joined = 0;
      var saved  = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final status = (data['status'] ?? '').toString();
        final isFav  = data['is_favorite'] == true;
        if (_joinedStatuses.contains(status)) joined++;
        if (status == 'interested' || isFav)  saved++;
      }
      setState(() {
        _joined = joined;
        _saved  = saved;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subAuth?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.t.myActivity.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: _green,
              ),
            ),
            const SizedBox(height: 12),
            _GroupsActivityStatCard(
              count: _joined,
              label: widget.t.groupsJoined,
              buttonLabel: widget.t.explore,
              icon: Icons.groups_rounded,
            ),
            const SizedBox(height: 10),
            _GroupsActivityStatCard(
              count: _saved,
              label: widget.t.groupsSaved,
              buttonLabel: widget.t.explore,
              icon: Icons.favorite_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupsActivityStatCard extends StatelessWidget {
  final int count;
  final String label;
  final String buttonLabel;
  final IconData icon;

  const _GroupsActivityStatCard({
    required this.count,
    required this.label,
    required this.buttonLabel,
    required this.icon,
  });

  static const Color _green      = Color(0xFF3A7D44);
  static const Color _greenLight = Color(0xFFE8F4EB);
  static const Color _border     = Color(0xFFE2EAE4);
  static const Color _textMid    = Color(0xFF5C6B61);
  static const Color _muted      = Color(0xFFC7D3CB);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textMid,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _greenLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward_rounded,
                          size: 11, color: _green),
                      const SizedBox(width: 4),
                      Text(
                        buttonLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              height: 1,
              color: count == 0 ? _muted : _green,
            ),
          ),
        ],
      ),
    );
  }
}
