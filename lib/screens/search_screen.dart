import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/user_profile_screen.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'searchTitle':        'Search',
    'placeholder':        'Search courts, events, groups, users…',
    'all':                'All',
    'courts':             'Courts',
    'events':             'Events',
    'groups':             'Groups',
    'users':              'Users',
    'noResults':          'No results found',
    'noResultsSub':       'Try a different search term',
    'recentSearches':     'RECENT SEARCHES',
    'popularSearches':    'POPULAR SEARCHES',
    'clearRecent':        'Clear',
    'viewAll':            'View all',
    'court':              'Court',
    'event':              'Event',
    'group':              'Group',
    'user':               'User',
    'dateTbd':            'Date TBD',
    'startSearching':     'Start searching',
    'startSearchingSub':  'Find courts, events, groups, and users',
    'loading':            'Searching…',
  },
  kLangJa: {
    'searchTitle':        '検索',
    'placeholder':        'コート、イベント、グループ、ユーザーを検索…',
    'all':                'すべて',
    'courts':             'コート',
    'events':             'イベント',
    'groups':             'グループ',
    'users':              'ユーザー',
    'noResults':          '結果が見つかりません',
    'noResultsSub':       '別の検索語をお試しください',
    'recentSearches':     '最近の検索',
    'popularSearches':    'おすすめの検索',
    'clearRecent':        'クリア',
    'viewAll':            'すべて見る',
    'court':              'コート',
    'event':              'イベント',
    'group':              'グループ',
    'user':               'ユーザー',
    'dateTbd':            '日時未定',
    'startSearching':     '検索を始めましょう',
    'startSearchingSub':  '全国のコート・イベント・グループ・ユーザーを検索',
    'loading':            '検索中…',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

const _popularEn = [
  'Tokyo courts', 'Pickleball events', 'Saitama',
  'Kanagawa', 'Indoor courts', 'Beginner groups',
];
const _popularJa = [
  '東京 コート', 'ピックルボール イベント', '埼玉',
  '神奈川', '室内コート', '初心者グループ',
];

// ─────────────────────────────────────────────────────────────────────────────
// Tab enum
// ─────────────────────────────────────────────────────────────────────────────
enum _Tab { all, courts, events, groups, users }

// ─────────────────────────────────────────────────────────────────────────────
// Result models
// ─────────────────────────────────────────────────────────────────────────────
class _CourtResult {
  final String docId, name, nameJp, image, cityEn, cityJp, prefEn, prefJp, country, type;
  final bool indoor, outdoor;
  const _CourtResult({
    required this.docId, required this.name, required this.nameJp,
    required this.image, required this.cityEn, required this.cityJp,
    required this.prefEn, required this.prefJp, required this.country,
    required this.type, required this.indoor, required this.outdoor,
  });
  factory _CourtResult.from(Map<String, dynamic> d, String id) => _CourtResult(
    docId: id,
    name:    (d['loc_name']            ?? '').toString(),
    nameJp:  (d['loc_name_jp']         ?? '').toString(),
    image:   (d['loc_image']           ?? '').toString(),
    cityEn:  (d['loc_city_en']         ?? d['loc_city']         ?? '').toString(),
    cityJp:  (d['loc_city_jp']         ?? d['loc_city']         ?? '').toString(),
    prefEn:  (d['loc_prefecture_en']   ?? d['loc_prefecture']   ?? '').toString(),
    prefJp:  (d['loc_prefecture_jp']   ?? d['loc_prefecture']   ?? '').toString(),
    country: (d['loc_country']         ?? '').toString(),
    type:    (d['loc_type']            ?? '').toString(),
    indoor:  d['loc_court_type_indoor']  == true,
    outdoor: d['loc_court_type_outdoor'] == true,
  );
  String location(String lang) {
    final c = lang == kLangJa ? cityJp : cityEn;
    final p = lang == kLangJa ? prefJp : prefEn;
    if (c.isNotEmpty && p.isNotEmpty) return '$c, $p';
    if (c.isNotEmpty) return c;
    if (p.isNotEmpty) return p;
    return country;
  }
  String displayName(String lang) =>
      lang == kLangJa && nameJp.isNotEmpty ? nameJp : name;
}

// ── _EventResult now stores the FULL raw Firestore document ──────────────────
// This ensures EventDetailScreen receives every field it needs (location,
// capacity, categories, organizer, end date, contact, etc.) — exactly
// matching what the web app does by fetching the full event doc.
class _EventResult {
  final String docId;
  final String title;
  final String titleJp;
  final String image;
  final String cityEn;
  final String cityJp;
  final String prefEn;
  final String prefJp;
  final Timestamp? eventDate;
  final dynamic eventTime;
  // Full raw Firestore data — passed to EventDetailScreen unchanged
  final Map<String, dynamic> _rawData;

  const _EventResult({
    required this.docId,
    required this.title,
    required this.titleJp,
    required this.image,
    required this.cityEn,
    required this.cityJp,
    required this.prefEn,
    required this.prefJp,
    required this.eventDate,
    required this.eventTime,
    required Map<String, dynamic> rawData,
  }) : _rawData = rawData;

  factory _EventResult.from(Map<String, dynamic> d, String id) => _EventResult(
    docId:    id,
    title:    (d['event_title']          ?? '').toString(),
    titleJp:  (d['event_title_jp']       ?? '').toString(),
    image:    (d['event_pic']            ?? d['event_pic_thumbnail'] ?? '').toString(),
    cityEn:   (d['event_city_en']        ?? '').toString(),
    cityJp:   (d['event_city_jp']        ?? '').toString(),
    prefEn:   (d['event_prefecture_en']  ?? '').toString(),
    prefJp:   (d['event_prefecture_jp']  ?? '').toString(),
    eventDate: d['event_date'] as Timestamp?,
    eventTime: d['event_time'],
    rawData:  Map<String, dynamic>.from(d),
  );

  String location(String lang) {
    final c = lang == kLangJa ? cityJp : cityEn;
    final p = lang == kLangJa ? prefJp : prefEn;
    if (c.isNotEmpty && p.isNotEmpty) return '$c, $p';
    return c.isNotEmpty ? c : p;
  }

  String displayName(String lang) =>
      lang == kLangJa && titleJp.isNotEmpty ? titleJp : title;

  String formattedDate(String lang) {
    if (eventDate == null) return _t(lang, 'dateTbd');
    final d = eventDate!.toDate();
    String dateStr;
    if (lang == kLangJa) {
      const wd = ['日', '月', '火', '水', '木', '金', '土'];
      dateStr = '${d.month}月${d.day}日(${wd[d.weekday % 7]})';
    } else {
      dateStr = DateFormat('EEE, MMM d').format(d);
    }
    if (eventTime is Timestamp) {
      final t = (eventTime as Timestamp).toDate();
      final tStr = lang == kLangJa
          ? '${t.hour}:${t.minute.toString().padLeft(2, '0')}'
          : DateFormat('h:mm a').format(t);
      return '$dateStr · $tStr';
    }
    if (eventTime is String && (eventTime as String).isNotEmpty) {
      return '$dateStr · $eventTime';
    }
    return dateStr;
  }

  /// Returns the FULL event map so EventDetailScreen has all fields.
  Map<String, dynamic> toEventMap() {
    final map = Map<String, dynamic>.from(_rawData);
    // Ensure _doc_id is always present
    map['_doc_id'] = docId;
    return map;
  }
}

class _GroupResult {
  final String docId, name, nameJp, image, city, cityJp, pref, prefJp, country, type;
  const _GroupResult({
    required this.docId, required this.name, required this.nameJp,
    required this.image, required this.city, required this.cityJp,
    required this.pref, required this.prefJp, required this.country,
    required this.type,
  });
  factory _GroupResult.from(Map<String, dynamic> d, String id) => _GroupResult(
    docId:  id,
    name:   (d['org_name']          ?? '').toString(),
    nameJp: (d['org_name_jp']       ?? '').toString(),
    image:  (d['org_image']         ?? '').toString(),
    city:   (d['org_city']          ?? '').toString(),
    cityJp: (d['org_city_jp']       ?? d['org_city'] ?? '').toString(),
    pref:   (d['org_prefecture']    ?? '').toString(),
    prefJp: (d['org_prefecture_jp'] ?? d['org_prefecture'] ?? '').toString(),
    country:(d['org_country']       ?? '').toString(),
    type:   (d['org_type']          ?? '').toString(),
  );
  String location(String lang) {
    final c = lang == kLangJa ? cityJp : city;
    final p = lang == kLangJa ? prefJp : pref;
    if (c.isNotEmpty && p.isNotEmpty) return '$c, $p';
    return c.isNotEmpty ? c : (p.isNotEmpty ? p : country);
  }
  String displayName(String lang) =>
      lang == kLangJa && nameJp.isNotEmpty ? nameJp : name;
  Map<String, dynamic> toGroupMap() => {
    '_doc_id': docId, 'org_name': name, 'org_name_jp': nameJp,
    'org_image': image, 'org_city': city, 'org_type': type,
  };
}

class _UserResult {
  final String docId, nickname, firstName, lastName, address, photoUrl, profileImg;
  const _UserResult({
    required this.docId, required this.nickname, required this.firstName,
    required this.lastName, required this.address, required this.photoUrl,
    required this.profileImg,
  });
  factory _UserResult.from(Map<String, dynamic> d, String id) => _UserResult(
    docId:      id,
    nickname:   (d['nickname']    ?? '').toString(),
    firstName:  (d['firstName']   ?? '').toString(),
    lastName:   (d['lastName']    ?? '').toString(),
    address:    (d['address']     ?? '').toString(),
    photoUrl:   (d['photoURL']    ?? '').toString(),
    profileImg: (d['profile_img'] ?? '').toString(),
  );
  String displayName(String lang) {
    if (nickname.isNotEmpty) return nickname;
    if (firstName.isNotEmpty && lastName.isNotEmpty) return '$firstName $lastName';
    if (firstName.isNotEmpty) return firstName;
    return lang == kLangJa ? '不明なユーザー' : 'Unknown User';
  }
  String get avatarUrl {
    if (photoUrl.isNotEmpty) return photoUrl;
    return '';
  }
  String get initials {
    final n = displayName(kLangEn);
    final parts = n.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (n.isNotEmpty) return n[0].toUpperCase();
    return '?';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SearchScreen
// ─────────────────────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  final String lang;
  const SearchScreen({super.key, required this.lang});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _focusNode         = FocusNode();
  late TabController _tabController;

  _Tab   _activeTab    = _Tab.all;
  bool   _loading      = false;
  bool   _hasSearched  = false;
  String _query        = '';
  Timer? _debounce;

  List<_CourtResult> _courts = [];
  List<_EventResult> _events = [];
  List<_GroupResult> _groups = [];
  List<_UserResult>  _users  = [];

  List<String> _recentSearches = [];

  // ── colours ──────────────────────────────────────────────────────────────
  static const _bg        = Color(0xFFF8FAF8);
  static const _card      = Colors.white;
  static const _border    = Color(0xFFE8EFE8);
  static const _muted     = Color(0xFF8A9E8A);
  static const _textDark  = Color(0xFF0D1F0D);
  static const _textMid   = Color(0xFF3D533D);
  static const _chipBg    = Color(0xFFEDF5ED);

  String get _lang => widget.lang;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _activeTab = _Tab.values[_tabController.index]);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── search ────────────────────────────────────────────────────────────────
  Future<void> _doSearch(String term) async {
    final q = term.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() { _hasSearched = false; _courts = []; _events = []; _groups = []; _users = []; });
      return;
    }
    setState(() { _loading = true; _hasSearched = true; });
    _saveRecent(term.trim());

    try {
      // Courts
      final cSnap = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_checked',        isEqualTo: true)
          .where('loc_active',         isEqualTo: true)
          .where('loc_pending_review', isEqualTo: false)
          .limit(200)
          .get();
      final courts = cSnap.docs
          .map((d) => _CourtResult.from(d.data(), d.id))
          .where((c) => _matchesCourt(c, q))
          .toList();

      // Events — fetch full documents so EventDetailScreen has all fields
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final eSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('event_active',         isEqualTo: true)
          .where('event_checked',        isEqualTo: true)
          .where('event_pending_review', isEqualTo: false)
          .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('event_date')
          .limit(200)
          .get();
      final events = eSnap.docs
          .map((d) => _EventResult.from(d.data(), d.id))
          .where((e) => _matchesEvent(e, q))
          .toList();

      // Groups
      final gSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .where('org_active', isEqualTo: true)
          .limit(200)
          .get();
      final groups = gSnap.docs
          .map((d) => _GroupResult.from(d.data(), d.id))
          .where((g) => _matchesGroup(g, q))
          .toList();

      // Users — collection: registration
      final uSnap = await FirebaseFirestore.instance
          .collection('registration')
          .limit(200)
          .get();
      final users = uSnap.docs
          .map((d) => _UserResult.from(d.data(), d.id))
          .where((u) => _matchesUser(u, q))
          .toList();

      if (mounted) {
        setState(() {
          _courts = courts;
          _events = events;
          _groups = groups;
          _users  = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[SearchScreen] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _matchesCourt(_CourtResult c, String q) {
    return [c.name, c.nameJp, c.cityEn, c.cityJp, c.prefEn, c.prefJp, c.country, c.type]
        .any((f) => f.toLowerCase().contains(q));
  }
  bool _matchesEvent(_EventResult e, String q) {
    return [e.title, e.titleJp, e.cityEn, e.cityJp, e.prefEn, e.prefJp]
        .any((f) => f.toLowerCase().contains(q));
  }
  bool _matchesGroup(_GroupResult g, String q) {
    return [g.name, g.nameJp, g.city, g.cityJp, g.pref, g.prefJp, g.country, g.type]
        .any((f) => f.toLowerCase().contains(q));
  }
  bool _matchesUser(_UserResult u, String q) {
    return [u.nickname, u.firstName, u.lastName, u.address]
        .any((f) => f.toLowerCase().contains(q));
  }

  void _saveRecent(String term) {
    if (term.isEmpty) return;
    setState(() {
      _recentSearches = [
        term,
        ..._recentSearches.where((s) => s.toLowerCase() != term.toLowerCase()),
      ].take(8).toList();
    });
  }

  void _onChanged(String val) {
    setState(() => _query = val);
    _debounce?.cancel();
    if (val.trim().isEmpty) {
      setState(() { _hasSearched = false; _courts = []; _events = []; _groups = []; _users = []; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(val));
  }

  void _quickSearch(String term) {
    _searchController.text = term;
    setState(() => _query = term);
    _doSearch(term);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() { _query = ''; _hasSearched = false; _courts = []; _events = []; _groups = []; _users = []; });
    _focusNode.requestFocus();
  }

  // ── helpers ───────────────────────────────────────────────────────────────
  int get _total => _courts.length + _events.length + _groups.length + _users.length;

  String _tabLabel(_Tab tab) {
    switch (tab) {
      case _Tab.all:    return _t(_lang, 'all');
      case _Tab.courts: return _t(_lang, 'courts');
      case _Tab.events: return _t(_lang, 'events');
      case _Tab.groups: return _t(_lang, 'groups');
      case _Tab.users:  return _t(_lang, 'users');
    }
  }

  int _tabCount(_Tab tab) {
    switch (tab) {
      case _Tab.all:    return _total;
      case _Tab.courts: return _courts.length;
      case _Tab.events: return _events.length;
      case _Tab.groups: return _groups.length;
      case _Tab.users:  return _users.length;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          if (_hasSearched) _buildTabBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _textDark),
      ),
      title: Text(
        _t(_lang, 'searchTitle'),
        style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w800,
          color: _textDark, letterSpacing: -0.4,
        ),
      ),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _border),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _focusNode.hasFocus ? AppColors.primary : _border,
            width: _focusNode.hasFocus ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.search_rounded, size: 20, color: _muted),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: _onChanged,
                onSubmitted: _doSearch,
                style: const TextStyle(fontSize: 15, color: _textDark, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: _t(_lang, 'placeholder'),
                  hintStyle: TextStyle(fontSize: 15, color: _muted.withOpacity(0.7), fontWeight: FontWeight.w400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: _clearSearch,
                child: Container(
                  margin: const EdgeInsets.only(right: 10),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: _muted.withOpacity(0.15), shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 14, color: _muted),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: _Tab.values.map((tab) {
                final selected = _activeTab == tab;
                final count    = _tabCount(tab);
                return GestureDetector(
                  onTap: () {
                    setState(() => _activeTab = tab);
                    _tabController.animateTo(tab.index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 6, bottom: 10, top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? AppColors.primary : _border,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        _tabLabel(tab),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? AppColors.primary : _muted,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.primary : _muted.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: selected ? Colors.white : _muted,
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(height: 1, color: _border),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (!_hasSearched) return _buildEmptyState();
    if (_total == 0) return _buildNoResults();
    return _buildResults();
  }

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: 5,
      itemBuilder: (_, __) => _SkeletonRow(),
    );
  }

  Widget _buildEmptyState() {
    final popular = _lang == kLangJa ? _popularJa : _popularEn;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Recent
        if (_recentSearches.isNotEmpty) ...[
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_t(_lang, 'recentSearches'),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                    color: _muted, letterSpacing: 0.8)),
            GestureDetector(
              onTap: () => setState(() => _recentSearches = []),
              child: Text(_t(_lang, 'clearRecent'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: AppColors.primary)),
            ),
          ]),
          const SizedBox(height: 10),
          ...(_recentSearches.map((s) => GestureDetector(
            onTap: () => _quickSearch(s),
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.access_time_rounded, size: 15, color: _muted),
                const SizedBox(width: 12),
                Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _textMid)),
              ]),
            ),
          ))),
          const SizedBox(height: 24),
        ],

        // Popular
        Text(_t(_lang, 'popularSearches'),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                color: _muted, letterSpacing: 0.8)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: popular.map((s) =>
            GestureDetector(
              onTap: () => _quickSearch(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _chipBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text(s, style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
              ),
            ),
        ).toList()),

        const SizedBox(height: 40),
        Center(child: Column(children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _chipBg,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.search_rounded, size: 30, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Text(_t(_lang, 'startSearching'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
          const SizedBox(height: 4),
          Text(_t(_lang, 'startSearchingSub'),
              style: TextStyle(fontSize: 12, color: _muted)),
        ])),
      ]),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: _chipBg, shape: BoxShape.circle),
          child: Icon(Icons.search_off_rounded, size: 28, color: _muted),
        ),
        const SizedBox(height: 16),
        Text(_t(_lang, 'noResults'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
        const SizedBox(height: 4),
        Text(_t(_lang, 'noResultsSub'),
            style: TextStyle(fontSize: 13, color: _muted)),
      ]),
    );
  }

  Widget _buildResults() {
    final showCourts = (_activeTab == _Tab.all || _activeTab == _Tab.courts) && _courts.isNotEmpty;
    final showEvents = (_activeTab == _Tab.all || _activeTab == _Tab.events) && _events.isNotEmpty;
    final showGroups = (_activeTab == _Tab.all || _activeTab == _Tab.groups) && _groups.isNotEmpty;
    final showUsers  = (_activeTab == _Tab.all || _activeTab == _Tab.users)  && _users.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (showCourts) ...[
          if (_activeTab == _Tab.all)
            _sectionHeader(_t(_lang, 'courts'), _courts.length,
                _courts.length > 3 ? () => setState(() { _activeTab = _Tab.courts; _tabController.animateTo(1); }) : null),
          ...(_activeTab == _Tab.all ? _courts.take(3) : _courts)
              .map((c) => _CourtTile(result: c, lang: _lang,
              onTap: () {
                Navigator.pop(context, {'type': 'court', 'docId': c.docId});
              })),
          const SizedBox(height: 16),
        ],
        if (showEvents) ...[
          if (_activeTab == _Tab.all)
            _sectionHeader(_t(_lang, 'events'), _events.length,
                _events.length > 3 ? () => setState(() { _activeTab = _Tab.events; _tabController.animateTo(2); }) : null),
          // Pass the FULL event map so EventDetailScreen has all fields
          ...(_activeTab == _Tab.all ? _events.take(3) : _events)
              .map((e) => _EventTile(result: e, lang: _lang,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => EventDetailScreen(event: e.toEventMap()))))),
          const SizedBox(height: 16),
        ],
        if (showGroups) ...[
          if (_activeTab == _Tab.all)
            _sectionHeader(_t(_lang, 'groups'), _groups.length,
                _groups.length > 3 ? () => setState(() { _activeTab = _Tab.groups; _tabController.animateTo(3); }) : null),
          ...(_activeTab == _Tab.all ? _groups.take(3) : _groups)
              .map((g) => _GroupTile(result: g, lang: _lang,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: g.toGroupMap()))))),
          const SizedBox(height: 16),
        ],
        if (showUsers) ...[
          if (_activeTab == _Tab.all)
            _sectionHeader(_t(_lang, 'users'), _users.length,
                _users.length > 3 ? () => setState(() { _activeTab = _Tab.users; _tabController.animateTo(4); }) : null),
          // ── CHANGED: pass onTap to navigate to UserProfileScreen ──────────
          ...(_activeTab == _Tab.all ? _users.take(3) : _users)
              .map((u) => _UserTile(
            result: u,
            lang: _lang,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserProfileScreen(
                  userId:        u.docId,
                  initialName:   u.displayName(_lang),
                  initialAvatar: u.avatarUrl,
                ),
              ),
            ),
          )),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, int count, VoidCallback? onViewAll) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Text(title, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: _textDark)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
          ),
        ]),
        if (onViewAll != null)
          GestureDetector(
            onTap: onViewAll,
            child: Text(_t(_lang, 'viewAll'), style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result tiles
// ─────────────────────────────────────────────────────────────────────────────

class _ResultTileShell extends StatelessWidget {
  final Widget leading;
  final Widget content;
  final VoidCallback? onTap;

  const _ResultTileShell({required this.leading, required this.content, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EFE8)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: content),
          const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFFCCDEC5)),
        ]),
      ),
    );
  }
}

class _ResultAvatar extends StatelessWidget {
  final String imageUrl;
  final String fallbackEmoji;

  const _ResultAvatar({required this.imageUrl, required this.fallbackEmoji});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 52, height: 52,
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF2D6A3F), Color(0xFF4A9C5E)],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
    ),
    child: Center(child: Text(fallbackEmoji, style: const TextStyle(fontSize: 22))),
  );
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
    );
  }
}

// ── Court tile ────────────────────────────────────────────────────────────────
class _CourtTile extends StatelessWidget {
  final _CourtResult result;
  final String lang;
  final VoidCallback onTap;
  const _CourtTile({required this.result, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTileShell(
      onTap: onTap,
      leading: _ResultAvatar(imageUrl: result.image, fallbackEmoji: '🏟️'),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _TypeBadge(label: _t(lang, 'court'), color: AppColors.primary),
          if (result.indoor || result.outdoor) ...[
            const SizedBox(width: 5),
            Text(
              result.indoor && result.outdoor ? '🏠 / 🌳'
                  : result.indoor
                  ? (lang == kLangJa ? '🏠 室内' : '🏠 Indoor')
                  : (lang == kLangJa ? '🌳 屋外' : '🌳 Outdoor'),
              style: const TextStyle(fontSize: 9, color: Color(0xFF8A9E8A)),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Text(result.displayName(lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D1F0D)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (result.location(lang).isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 10, color: AppColors.primary),
            const SizedBox(width: 3),
            Expanded(child: Text(result.location(lang),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E8A)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }
}

// ── Event tile ────────────────────────────────────────────────────────────────
class _EventTile extends StatelessWidget {
  final _EventResult result;
  final String lang;
  final VoidCallback onTap;
  const _EventTile({required this.result, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTileShell(
      onTap: onTap,
      leading: _ResultAvatar(imageUrl: result.image, fallbackEmoji: '🎾'),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TypeBadge(label: _t(lang, 'event'), color: const Color(0xFF3B8650)),
        const SizedBox(height: 4),
        Text(result.displayName(lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D1F0D)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(result.formattedDate(lang),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
        if (result.location(lang).isNotEmpty) ...[
          const SizedBox(height: 1),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 10, color: Color(0xFF8A9E8A)),
            const SizedBox(width: 3),
            Expanded(child: Text(result.location(lang),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E8A)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }
}

// ── Group tile ────────────────────────────────────────────────────────────────
class _GroupTile extends StatelessWidget {
  final _GroupResult result;
  final String lang;
  final VoidCallback onTap;
  const _GroupTile({required this.result, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTileShell(
      onTap: onTap,
      leading: _ResultAvatar(imageUrl: result.image, fallbackEmoji: '👥'),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _TypeBadge(label: _t(lang, 'group'), color: AppColors.primary),
          if (result.type.isNotEmpty) ...[
            const SizedBox(width: 5),
            Text(result.type, style: const TextStyle(fontSize: 9, color: Color(0xFF8A9E8A))),
          ],
        ]),
        const SizedBox(height: 4),
        Text(result.displayName(lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D1F0D)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (result.location(lang).isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 10, color: AppColors.primary),
            const SizedBox(width: 3),
            Expanded(child: Text(result.location(lang),
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E8A)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────
// ── CHANGED: added required onTap parameter — routes to UserProfileScreen ───
class _UserTile extends StatelessWidget {
  final _UserResult result;
  final String lang;
  final VoidCallback onTap;
  const _UserTile(
      {required this.result, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ResultTileShell(
      onTap: onTap,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 52, height: 52,
          child: result.avatarUrl.isNotEmpty
              ? Image.network(result.avatarUrl, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initialsAvatar())
              : _initialsAvatar(),
        ),
      ),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _TypeBadge(label: _t(lang, 'user'), color: AppColors.primary),
        const SizedBox(height: 4),
        Text(result.displayName(lang),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0D1F0D)),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (result.address.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(children: [
            const Icon(Icons.location_on_rounded, size: 10, color: Color(0xFF8A9E8A)),
            const SizedBox(width: 3),
            Expanded(child: Text(result.address,
                style: const TextStyle(fontSize: 11, color: Color(0xFF8A9E8A)),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ],
      ]),
    );
  }

  Widget _initialsAvatar() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D6A3F), Color(0xFF4A9C5E)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(result.initials,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loading row
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonRow extends StatefulWidget {
  @override
  State<_SkeletonRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonRow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8EFE8)),
        ),
        child: Row(children: [
          Container(width: 52, height: 52,
              decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(_anim.value),
                  borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(height: 10, width: 60,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(_anim.value),
                    borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 6),
            Container(height: 14, width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(_anim.value + 0.1),
                    borderRadius: BorderRadius.circular(5))),
            const SizedBox(height: 4),
            Container(height: 10, width: 120,
                decoration: BoxDecoration(color: Colors.grey.withOpacity(_anim.value),
                    borderRadius: BorderRadius.circular(5))),
          ])),
        ]),
      ),
    );
  }
}