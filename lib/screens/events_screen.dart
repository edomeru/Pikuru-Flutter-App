import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/widgets/event_card_full.dart';
import 'package:pikuru/screens/calendar_events_screen.dart';
import 'package:pikuru/screens/add_event_screen.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localized location dictionary (parity with web app locDic in page.tsx)
// ─────────────────────────────────────────────────────────────────────────────
const Map<String, String> _locDic = {
  // Countries
  'Japan': '日本', 'Australia': 'オーストラリア', 'Philippines': 'フィリピン',
  'United States': 'アメリカ', 'USA': 'アメリカ',
  'Canada': 'カナダ', 'China': '中国', 'India': 'インド',
  'Malaysia': 'マレーシア', 'Singapore': 'シンガポール',
  'Slovenia': 'スロベニア', 'Sovenia': 'スロベニア',
  'Turkey': 'トルコ', 'United Kingdom': 'イギリス', 'United Kingdon': 'イギリス',
  'Vietnam': 'ベトナム',
  // Prefectures / cities
  'Hokkaido': '北海道', 'Aomori': '青森', 'Iwate': '岩手', 'Miyagi': '宮城', 'Akita': '秋田', 'Yamagata': '山形', 'Fukushima': '福島',
  'Ibaraki': '茨城', 'Tochigi': '栃木', 'Gunma': '群馬', 'Saitama': '埼玉', 'Chiba': '千葉', 'Tokyo': '東京', 'Kanagawa': '神奈川',
  'Niigata': '新潟', 'Toyama': '富山', 'Ishikawa': '石川', 'Fukui': '福井', 'Yamanashi': '山梨', 'Nagano': '長野', 'Gifu': '岐阜',
  'Shizuoka': '静岡', 'Aichi': '愛知', 'Mie': '三重', 'Shiga': '滋賀', 'Kyoto': '京都', 'Osaka': '大阪', 'Hyogo': '兵庫',
  'Nara': '奈良', 'Wakayama': '和歌山', 'Tottori': '鳥取', 'Shimane': '島根', 'Okayama': '岡山', 'Hiroshima': '広島', 'Yamaguchi': '山口',
  'Tokushima': '徳島', 'Kagawa': '香川', 'Ehime': '愛媛', 'Kochi': '高知', 'Fukuoka': '福岡', 'Saga': '佐賀', 'Nagasaki': '長崎',
  'Kumamoto': '熊本', 'Oita': '大分', 'Miyazaki': '宮崎', 'Kagoshima': '鹿児島', 'Okinawa': '沖縄',
  'Shibuya': '渋谷区', 'Shinjuku': '新宿区', 'Minato': '港区', 'Chuo': '中央区', 'Yokohama': '横浜市',
  'Melbourne': 'メルボルン', 'Victoria': 'ビクトリア州', 'Queensland': 'クイーンズランド州',
  'New South Wales': 'ニューサウスウェールズ州', 'California': 'カリフォルニア州',
};

/// Returns a JA label for [en]. Prefers the matching JA field on any doc in
/// [locs] whose [enField] equals [en]; falls back to [_locDic] then [en].
String _localizeLoc(String en, List<Map<String, dynamic>> locs,
    List<String> enFields, String jaField) {
  if (en.isEmpty) return en;
  for (final loc in locs) {
    for (final f in enFields) {
      final v = (loc[f] ?? '').toString().trim();
      if (v.isNotEmpty && v == en) {
        final ja = (loc[jaField] ?? '').toString().trim();
        if (ja.isNotEmpty && ja != en) return ja;
      }
    }
  }
  return _locDic[en] ?? en;
}

// ─────────────────────────────────────────────────────────────────────────────
// Strings
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final String lang;
  const _S(this.lang);

  bool get isJa => lang == kLangJa;

  String get events        => isJa ? 'イベント'           : 'Events';
  String get upcoming      => isJa ? '開催予定'           : 'Upcoming';
  String get today         => isJa ? '今日'               : 'Today';
  String get tomorrow      => isJa ? '明日'               : 'Tomorrow';
  String get thisWeek      => isJa ? '今週'               : 'This Week';
  String get weekend       => isJa ? '週末'               : 'Weekend';
  String get search        => isJa ? 'イベント・種類を検索…' : 'Search events, type…';
  String get filters       => isJa ? 'フィルター'          : 'Filters';
  String get filtersActive => isJa ? 'フィルター中'        : 'Filters active';
  String get allCountries  => isJa ? 'すべての国'          : 'All Countries';
  String get clearAll      => isJa ? 'クリア'             : 'Clear All';
  String get applyFilters  => isJa ? 'フィルターを適用'    : 'APPLY FILTERS';

  String get defaultLocation => isJa ? '東京' : 'Tokyo';

  String get dateSection      => isJa ? '日付'          : 'DATE';
  String get locationSection  => isJa ? '場所'          : 'LOCATION';
  String get eventTypeSection => isJa ? 'イベント種類'   : 'EVENT TYPE';
  String get skillSection     => isJa ? 'スキルレベル'   : 'SKILL LEVELS';
  String get categorySection  => isJa ? 'カテゴリー'    : 'CATEGORIES';
  String get categoryNote     => isJa ? 'M=男子、W=女子、Mixed=混合' : "M=Men's, W=Women's, Mixed";
  String get otherSection     => isJa ? 'その他'        : 'OTHER';

  String get startDate  => isJa ? '開始日' : 'Start Date';
  String get endDate    => isJa ? '終了日' : 'End Date';
  String get selectDate => isJa ? '選択'  : 'Select';

  String get country    => isJa ? '国'       : 'Country';
  String get prefecture => isJa ? '都道府県'  : 'Prefecture';
  String get city       => isJa ? '市区町村'  : 'City';
  String get all        => isJa ? 'すべて'   : 'All';
  String get allTypes   => isJa ? 'すべての種類' : 'All types';

  String get pro      => isJa ? '上級' : 'Pro';
  String get amateur  => isJa ? '中級' : 'Amateur';
  String get beginner => isJa ? '初級' : 'Beginner';

  String get mensDoubles   => isJa ? '男子ダブルス'   : 'M Doubles';
  String get mensSingles   => isJa ? '男子シングルズ'  : 'M Singles';
  String get womensDoubles => isJa ? '女子ダブルス'   : 'W Doubles';
  String get womensSingles => isJa ? '女子シングルズ'  : 'W Singles';
  String get mixedDoubles  => isJa ? 'ミックスダブルス' : 'Mixed Doubles';
  String get seniors       => isJa ? 'シニア'         : 'Seniors';
  String get juniors       => isJa ? 'ジュニア'       : 'Juniors';
  String get collegiate    => isJa ? '学生'           : 'Collegiate';

  String get touristFriendly => isJa ? '観光客歓迎' : 'Tourist Friendly';

  String noEvents(String loc) => isJa
      ? '$loc で今後30日間のイベントはありません。'
      : 'No upcoming events in $loc\nin the next 30 days.';
  String get clearFilters => isJa ? 'フィルターをクリア' : 'Clear all filters';

  List<String> get eventTypeKeys => [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];

  String localizeEventType(String key) {
    if (!isJa) return key;
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
  bool defaultLocationActive;

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
    this.defaultLocationActive = true,
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
    bool? defaultLocationActive,
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
    defaultLocationActive: defaultLocationActive ?? this.defaultLocationActive,
  );

  bool get hasNonLocationFilters =>
      dateStart != null || dateEnd != null ||
          type.isNotEmpty ||
          skillPro || skillAmateur || skillBeginner ||
          catMx || catMd || catMs || catWs || catWd || catSe || catJu || catCo ||
          tourist;

  bool get isActive =>
      hasNonLocationFilters ||
          country.isNotEmpty || prefecture.isNotEmpty || city.isNotEmpty ||
          !defaultLocationActive;

  _AdvFilter get cleared => _AdvFilter(defaultLocationActive: true);
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

  String     _selectedFilter = 'Upcoming';
  _AdvFilter _adv = _AdvFilter();

  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _locations = [];
  bool _loadingEvents = true;
  String? _loadError;

  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  static const Color _bg         = Color(0xFFF7F8FA);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _cardBg     = Color(0xFFF0F4F1);
  static const Color _border     = Color(0xFFE2EAE4);
  static const Color _green      = Color(0xFF3A7D44);
  static const Color _greenLight = Color(0xFFE8F4EB);
  static const Color _textDark   = Color(0xFF1A1D1B);
  static const Color _textMid    = Color(0xFF5C6B61);
  static const Color _textLight  = Color(0xFF9EB3A3);

  _S get s => _S(ref.watch(appLangProvider));

  static const int _defaultDays = 30;

  @override
  void initState() {
    super.initState();
    _loadEventsDirectly();
  }

  Future<void> _loadEventsDirectly() async {
    if (!mounted) return;
    setState(() {
      _loadingEvents = true;
      _loadError = null;
    });

    try {
      final now   = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final in30  = today.add(const Duration(days: 30));

      final futures = await Future.wait([
        FirebaseFirestore.instance
            .collection('events')
            .where('event_active',         isEqualTo: true)
            .where('event_checked',        isEqualTo: true)
            .where('event_pending_review', isEqualTo: false)
            .where('event_date', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
            .where('event_date', isLessThanOrEqualTo:    Timestamp.fromDate(in30))
            .orderBy('event_date')
            .limit(100)
            .get(),
        FirebaseFirestore.instance.collection('locations').get(),
        FirebaseFirestore.instance.collection('organizations').get(),
      ]);

      final snap = futures[0] as QuerySnapshot<Map<String, dynamic>>;
      final locsSnap = futures[1] as QuerySnapshot<Map<String, dynamic>>;
      final orgsSnap = futures[2] as QuerySnapshot<Map<String, dynamic>>;

      if (!mounted) return;

      final locList = locsSnap.docs
          .map((d) => d.data())
          .toList();

      final locCache = {
        for (var loc in locList)
          (loc['loc_id'] ?? '').toString().trim(): loc
      };

      final orgList = orgsSnap.docs
          .map((d) => d.data())
          .toList();

      final orgCache = {
        for (var org in orgList)
          (org['org_id'] ?? '').toString().trim(): org
      };

      final raw = snap.docs
          .map((d) => <String, dynamic>{...d.data(), '_doc_id': d.id})
          .toList();

      debugPrint('[EventsScreen] Raw events fetched: ${raw.length}');

      final enriched = raw
          .map((e) => _enrichEvent(e, locCache, orgCache))
          .toList();

      if (!mounted) return;
      setState(() {
        _locations = locList;
        _events = enriched;
        _loadingEvents = false;
      });

      debugPrint('[EventsScreen] Enriched events: ${_events.length}');
    } catch (e) {
      debugPrint('[EventsScreen] Load error: $e');
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loadingEvents = false;
      });
    }
  }

  Map<String, dynamic> _enrichEvent(
      Map<String, dynamic> event,
      Map<String, Map<String, dynamic>> locCache,
      Map<String, Map<String, dynamic>> orgCache) {
    final locId = (event['event_loc_id'] ?? event['loc_id'] ?? '').toString().trim();
    final locDoc = locId.isNotEmpty ? (locCache[locId] ?? <String, dynamic>{}) : <String, dynamic>{};

    String getField(String key) =>
        ((locDoc[key] ?? event[key] ?? '')).toString().trim();

    final pref = [
      getField('loc_prefecture_en'),
      getField('loc_prefecture'),
      getField('loc_prefecture_jp'),
      getField('event_prefecture'),
      getField('prefecture'),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final prefJp = [
      getField('loc_prefecture_jp'),
      getField('event_prefecture_jp'),
      pref,
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final country = [
      getField('loc_country'),
      getField('event_country'),
      getField('country'),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final countryJp = [
      getField('loc_country_jp'),
      getField('event_country_jp'),
      country,
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final city = [
      getField('loc_city_en'),
      getField('loc_city'),
      getField('event_city'),
      getField('city'),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final cityJp = [
      getField('loc_city_jp'),
      getField('event_city_jp'),
      city,
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final addr = [
      getField('loc_address'),
      getField('event_venue_address'),
      (event['event_address'] ?? '').toString().trim(),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final addrJp = [
      getField('loc_address_jp'),
      getField('event_venue_address_jp'),
      (event['event_address_jp'] ?? '').toString().trim(),
      addr,
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final googleLink = [
      getField('loc_googlelink'),
      getField('event_googlelink'),
      getField('event_venue_link'),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    String orgNameEn = [
      getField('org_name'),
      (event['event_org_name'] ?? '').toString().trim(),
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    String orgNameJp = [
      getField('org_name_jp'),
      orgNameEn,
    ].firstWhere((v) => v.isNotEmpty, orElse: () => '');

    final orgId = (event['event_org_id'] ?? '').toString().trim();
    if (orgId.isNotEmpty && orgCache.containsKey(orgId)) {
      final org = orgCache[orgId]!;
      final resolvedEn = (org['org_name'] ?? '').toString().trim();
      final resolvedJp = (org['org_name_jp'] ?? resolvedEn).toString().trim();
      if (resolvedEn.isNotEmpty) orgNameEn = resolvedEn;
      if (resolvedJp.isNotEmpty) orgNameJp = resolvedJp;
    }

    String label = city.isNotEmpty && pref.isNotEmpty
        ? '$city, $pref'
        : city.isNotEmpty
        ? city
        : pref.isNotEmpty
        ? pref
        : country;

    String labelJp = cityJp.isNotEmpty && prefJp.isNotEmpty
        ? '$prefJp$cityJp'
        : cityJp.isNotEmpty
        ? cityJp
        : prefJp.isNotEmpty
        ? prefJp
        : countryJp;

    final venueName = getField('event_venue_name');

    return {
      ...event,
      'location':         label.isNotEmpty ? label : venueName,
      'location_jp':      labelJp.isNotEmpty ? labelJp : venueName,
      'event_address':    addr,
      'event_address_jp': addrJp,
      'event_googlelink': googleLink,
      'org_name':         orgNameEn,
      'org_name_jp':      orgNameJp,
      '_prefecture':      pref,
      '_prefecture_jp':   prefJp,
      '_country':         country,
      '_country_jp':      countryJp,
      '_city':            city,
      '_city_jp':         cityJp,
    };
  }

  String get _locationLabel {
    if (_adv.defaultLocationActive) return s.defaultLocation;
    if (_adv.city.isNotEmpty) {
      return s.isJa
          ? _localizeLoc(_adv.city, _locations, const ['loc_city_en', 'loc_city'], 'loc_city_jp')
          : _adv.city;
    }
    if (_adv.prefecture.isNotEmpty) {
      return s.isJa
          ? _localizeLoc(_adv.prefecture, _locations, const ['loc_prefecture_en', 'loc_prefecture'], 'loc_prefecture_jp')
          : _adv.prefecture;
    }
    if (_adv.country.isNotEmpty) {
      return s.isJa
          ? _localizeLoc(_adv.country, _locations, const ['loc_country'], 'loc_country_jp')
          : _adv.country;
    }
    return s.allCountries;
  }

  bool _matchesLocation(Map<String, dynamic> event) {
    if (_adv.defaultLocationActive) {
      final pref = (event['_prefecture'] ?? '').toString().toLowerCase();
      return pref.contains('tokyo') || pref.contains('東京');
    }

    if (_adv.country.isEmpty && _adv.prefecture.isEmpty && _adv.city.isEmpty) {
      return true;
    }

    if (_adv.country.isNotEmpty) {
      final country = (event['_country'] ?? '').toString().toLowerCase();
      final target  = _adv.country.toLowerCase();
      if (country.isNotEmpty &&
          !country.contains(target) && !target.contains(country)) {
        return false;
      }
    }

    if (_adv.prefecture.isNotEmpty) {
      final pref   = (event['_prefecture'] ?? '').toString().toLowerCase();
      final target = _adv.prefecture.toLowerCase();
      if (pref.isNotEmpty &&
          !pref.contains(target) && !target.contains(pref)) {
        return false;
      }
    }

    if (_adv.city.isNotEmpty) {
      final city   = (event['_city'] ?? '').toString().toLowerCase();
      final target = _adv.city.toLowerCase();
      if (city.isNotEmpty &&
          !city.contains(target) && !target.contains(city)) {
        return false;
      }
    }

    return true;
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> events) {
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
      final locId = (e['event_loc_id'] ?? '').toString().trim();
      if (locId.isEmpty) return false;

      if (q.isNotEmpty) {
        final title   = (e['event_title']    ?? '').toString().toLowerCase();
        final titleJp = (e['event_title_jp'] ?? '').toString().toLowerCase();
        final type    = (e['event_type']     ?? '').toString().toLowerCase();
        if (!title.contains(q) && !titleJp.contains(q) && !type.contains(q)) return false;
      }

      if (!_matchesLocation(e)) return false;

      final raw = e['event_date'];
      DateTime? d;
      if (raw is Timestamp)            d = raw.toDate();
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
  // FILTER MODAL
  // ─────────────────────────────────────────────────────────────────────────
  void _showFilterModal() {
    _AdvFilter temp = _adv;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {

        Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Container(
              width: 3, height: 14,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(text, style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: _green,
              letterSpacing: 1.0,
            )),
          ]),
        );

        Widget sectionLabelWithNote(String text, String note) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 3, height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(text, style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _green,
                letterSpacing: 1.0,
              )),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  note,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: _textLight,
                    letterSpacing: 0.1,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

        Widget divider() => const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1, color: _border),
        );

        Widget datePicker(String label, DateTime? value, ValueChanged<DateTime?> onPicked) {
          final hasVal = value != null;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: _textMid,
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
                        primary: _green,
                        surface: _surface,
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: hasVal ? _greenLight : _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasVal ? _green.withOpacity(0.5) : _border,
                    width: 1.5,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 14, color: hasVal ? _green : _textLight),
                  const SizedBox(width: 8),
                  Text(
                    hasVal
                        ? DateFormat('MM/dd/yyyy').format(value!)
                        : s.selectDate,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: hasVal ? _green : _textLight,
                    ),
                  ),
                  if (hasVal) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => onPicked(null),
                      child: const Icon(Icons.close_rounded, size: 14, color: _green),
                    ),
                  ],
                ]),
              ),
            ),
          ]);
        }

        Widget dropdownField(
            String label,
            String value,
            List<String> options,
            String allLabel,
            ValueChanged<String> onChange, {
              String Function(String)? displayMapper,
            }) {
          final hasVal = value.isNotEmpty;

          final seen = <String>{};
          final dedupedOptions = <String>[];
          for (final o in options) {
            if (o.isNotEmpty && seen.add(o)) dedupedOptions.add(o);
          }
          if (hasVal && !dedupedOptions.contains(value)) {
            dedupedOptions.add(value);
          }

          final dropdownValue = (hasVal && dedupedOptions.contains(value)) ? value : '';

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (label.isNotEmpty)
              Text(label, style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textMid,
              )),
            if (label.isNotEmpty) const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: hasVal ? _greenLight : _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasVal ? _green.withOpacity(0.5) : _border,
                  width: 1.5,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: dropdownValue,
                  isExpanded: true,
                  dropdownColor: _surface,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: hasVal ? _green : _textLight, size: 20),
                  style: TextStyle(
                    color: hasVal ? _green : _textDark,
                    fontSize: 14, fontWeight: FontWeight.w500,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: '',
                      child: Text(allLabel, style: const TextStyle(color: _textLight)),
                    ),
                    ...dedupedOptions.map((o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        displayMapper != null ? displayMapper(o) : o,
                        style: const TextStyle(color: _textDark),
                      ),
                    )),
                  ],
                  onChanged: (v) => onChange(v ?? ''),
                ),
              ),
            ),
          ]);
        }

        Widget checkPill(String label, bool value, VoidCallback onTap) {
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: value ? _greenLight : _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: value ? _green.withOpacity(0.6) : _border,
                  width: 1.5,
                ),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 15, height: 15,
                  decoration: BoxDecoration(
                    color: value ? _green : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: value ? _green : _border,
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
                  color: value ? _green : _textMid,
                )),
              ]),
            ),
          );
        }

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.92,
          ),
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

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
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Active', style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _green,
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
                    child: const Icon(Icons.close_rounded, color: _textMid, size: 18),
                  ),
                ),
              ]),
            ),
            const Divider(height: 1, color: _border),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

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

                    sectionLabel(s.locationSection),
                    Row(children: [
                      Expanded(child: dropdownField(
                        s.country,
                        temp.defaultLocationActive ? 'Japan' : temp.country,
                        _locations
                            .map((loc) => (loc['loc_country'] ?? '').toString().trim())
                            .where((c) => c.isNotEmpty)
                            .toSet()
                            .toList()..sort(),
                        s.allCountries,
                            (v) => setS(() {
                          if (v == 'Japan' && temp.defaultLocationActive) {
                            temp = temp.copyWith(country: 'Japan', prefecture: 'Tokyo', city: '', defaultLocationActive: true);
                          } else if (v.isEmpty) {
                            temp = temp.copyWith(country: '', prefecture: '', city: '', defaultLocationActive: false);
                          } else {
                            temp = temp.copyWith(country: v, prefecture: '', city: '', defaultLocationActive: false);
                          }
                        }),
                        displayMapper: (v) => s.isJa
                            ? _localizeLoc(v, _locations, const ['loc_country'], 'loc_country_jp')
                            : v,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: dropdownField(
                        s.prefecture,
                        temp.defaultLocationActive ? 'Tokyo' : temp.prefecture,
                            () {
                          final activeCountry = temp.defaultLocationActive ? 'Japan' : temp.country;
                          return _locations
                              .where((loc) {
                            final c = (loc['loc_country'] ?? '').toString().trim();
                            return activeCountry.isEmpty || c.toLowerCase() == activeCountry.toLowerCase();
                          })
                              .map((loc) => (loc['loc_prefecture_en'] ?? loc['loc_prefecture'] ?? '').toString().trim())
                              .where((p) => p.isNotEmpty)
                              .toSet()
                              .toList()..sort();
                        }(),
                        s.all,
                            (v) => setS(() {
                          if (v.isEmpty) {
                            final currentCountry = temp.defaultLocationActive ? 'Japan' : temp.country;
                            temp = temp.copyWith(country: currentCountry, prefecture: '', city: '', defaultLocationActive: false);
                          } else {
                            var currentCountry = temp.defaultLocationActive ? 'Japan' : temp.country;
                            // Auto-select country based on the chosen prefecture (parity with web app)
                            final foundLoc = _locations.firstWhere(
                                  (loc) {
                                final c = (loc['loc_country'] ?? '').toString().trim();
                                final pEn = (loc['loc_prefecture_en'] ?? '').toString().trim();
                                final pJa = (loc['loc_prefecture'] ?? '').toString().trim();
                                return c.isNotEmpty && (pEn == v || pJa == v);
                              },
                              orElse: () => <String, dynamic>{},
                            );
                            final foundCountry = (foundLoc['loc_country'] ?? '').toString().trim();
                            if (foundCountry.isNotEmpty) {
                              currentCountry = foundCountry;
                            }
                            temp = temp.copyWith(country: currentCountry, prefecture: v, city: '', defaultLocationActive: false);
                          }
                        }),
                        displayMapper: (v) => s.isJa
                            ? _localizeLoc(v, _locations,
                            const ['loc_prefecture_en', 'loc_prefecture'], 'loc_prefecture_jp')
                            : v,
                      )),
                    ]),
                    const SizedBox(height: 12),
                    dropdownField(
                      s.city,
                      temp.city,
                          () {
                        final activeCountry = temp.defaultLocationActive ? 'Japan' : temp.country;
                        final activePref = temp.defaultLocationActive ? 'Tokyo' : temp.prefecture;
                        return _locations
                            .where((loc) {
                          final c = (loc['loc_country'] ?? '').toString().trim();
                          final p = (loc['loc_prefecture_en'] ?? loc['loc_prefecture'] ?? '').toString().trim();
                          final matchCountry = activeCountry.isEmpty || c.toLowerCase() == activeCountry.toLowerCase();
                          final matchPref = activePref.isEmpty || p.toLowerCase() == activePref.toLowerCase();
                          return matchCountry && matchPref;
                        })
                            .map((loc) => (loc['loc_city_en'] ?? loc['loc_city'] ?? '').toString().trim())
                            .where((ci) => ci.isNotEmpty)
                            .toSet()
                            .toList()..sort();
                      }(),
                      s.all,
                          (v) => setS(() => temp = temp.copyWith(city: v, defaultLocationActive: false)),
                      displayMapper: (v) => s.isJa
                          ? _localizeLoc(v, _locations,
                          const ['loc_city_en', 'loc_city'], 'loc_city_jp')
                          : v,
                    ),


                    divider(),

                    sectionLabel(s.eventTypeSection),
                    dropdownField(
                      '', temp.type,
                      s.eventTypeKeys, s.allTypes,
                          (v) => setS(() => temp = temp.copyWith(type: v)),
                      displayMapper: s.localizeEventType,
                    ),

                    divider(),

                    sectionLabel(s.skillSection),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      checkPill(s.pro,      temp.skillPro,
                              () => setS(() => temp = temp.copyWith(skillPro:      !temp.skillPro))),
                      checkPill(s.amateur,  temp.skillAmateur,
                              () => setS(() => temp = temp.copyWith(skillAmateur:  !temp.skillAmateur))),
                      checkPill(s.beginner, temp.skillBeginner,
                              () => setS(() => temp = temp.copyWith(skillBeginner: !temp.skillBeginner))),
                    ]),

                    divider(),

                    sectionLabelWithNote(s.categorySection, s.categoryNote),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      checkPill(s.mensDoubles,   temp.catMd,
                              () => setS(() => temp = temp.copyWith(catMd: !temp.catMd))),
                      checkPill(s.mensSingles,   temp.catMs,
                              () => setS(() => temp = temp.copyWith(catMs: !temp.catMs))),
                      checkPill(s.womensDoubles, temp.catWd,
                              () => setS(() => temp = temp.copyWith(catWd: !temp.catWd))),
                      checkPill(s.womensSingles, temp.catWs,
                              () => setS(() => temp = temp.copyWith(catWs: !temp.catWs))),
                      checkPill(s.mixedDoubles,  temp.catMx,
                              () => setS(() => temp = temp.copyWith(catMx: !temp.catMx))),
                      checkPill(s.seniors,       temp.catSe,
                              () => setS(() => temp = temp.copyWith(catSe: !temp.catSe))),
                      checkPill(s.juniors,       temp.catJu,
                              () => setS(() => temp = temp.copyWith(catJu: !temp.catJu))),
                      checkPill(s.collegiate,    temp.catCo,
                              () => setS(() => temp = temp.copyWith(catCo: !temp.catCo))),
                    ]),

                    divider(),

                    sectionLabel(s.otherSection),
                    checkPill(s.touristFriendly, temp.tourist,
                            () => setS(() => temp = temp.copyWith(tourist: !temp.tourist))),

                    const SizedBox(height: 28),

                    Row(children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setS(() => temp = _AdvFilter(defaultLocationActive: true)),
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
                              color: _green,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: _green.withOpacity(0.3),
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
    ref.watch(appLangProvider);
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

  Widget _buildHeader() {
    final fmt  = DateFormat('MMM d');
    final lang = ref.watch(appLangProvider);

    return Container(
      color: _surface,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.events, style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: _textDark, letterSpacing: -0.5,
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
                    label: _adv.dateEnd != null && !_isSameDay(_adv.dateStart!, _adv.dateEnd!)
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
            Container(
              height: 34,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _langBtn('EN',   kLangEn, lang),
                _langBtn('日本語', kLangJa, lang),
              ]),
            ),
            const SizedBox(width: 10),

            GestureDetector(
              onTap: _showFilterModal,
              child: Stack(clipBehavior: Clip.none, children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: _adv.isActive ? _green : _greenLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.tune_rounded,
                      color: _adv.isActive ? Colors.white : _green, size: 20),
                ),
                if (_adv.isActive)
                  Positioned(
                    top: -3, right: -3,
                    child: Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(
                        color: _surface, shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 7, height: 7,
                          decoration: const BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
            const SizedBox(width: 10),

            GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const CalendarEventsScreen())),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: _green, size: 22),
              ),
            ),
          ]),
        ]),
        const SizedBox(height: 14),

        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 15, color: _textDark),
            decoration: InputDecoration(
              hintText: s.search,
              hintStyle: const TextStyle(color: _textLight, fontSize: 15, fontWeight: FontWeight.w400),
              prefixIcon: const Icon(Icons.search_rounded, color: _textLight, size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                onTap: () => setState(() => _searchController.clear()),
                child: const Icon(Icons.close_rounded, color: _textLight, size: 20),
              )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 14),

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
        Container(height: 1, color: _border),
      ]),
    );
  }

  Widget _langBtn(String label, String code, String currentLang) {
    final active = currentLang == code;
    return GestureDetector(
      onTap: () => ref.read(appLangProvider.notifier).setLang(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
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
          color: _greenLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _green.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: _green),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700, color: _green,
          )),
          if (showClose) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClose ?? onTap,
              child: const Icon(Icons.close_rounded, size: 11, color: _green),
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
          color: isSelected ? _green : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? _green : _border,
            width: 1.5,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: isSelected ? Colors.white : _textMid),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: isSelected ? Colors.white : _textMid,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          )),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EVENTS LIST
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEventsList() {
    final isJa = ref.watch(appLangProvider) == kLangJa;

    if (_loadingEvents) {
      return const Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2.5),
      );
    }

    if (_loadError != null) {
      return RefreshIndicator(
        onRefresh: _loadEventsDirectly,
        color: _green,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Something went wrong.\n$_loadError',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _textLight, fontSize: 14)),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _loadEventsDirectly,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _greenLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Retry',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _green)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final filtered = _applyFilter(_events);

    debugPrint('[EventsScreen] Filtered events: ${filtered.length} / total: ${_events.length}');

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadEventsDirectly,
        color: _green,
        backgroundColor: Colors.white,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: 400,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.event_busy_rounded, size: 56, color: _textLight),
                const SizedBox(height: 14),
                Text(
                  s.noEvents(_locationLabel),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: _textLight,
                      fontWeight: FontWeight.w500),
                ),
                if (_adv.isActive) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => setState(() => _adv = _AdvFilter()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _greenLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s.clearFilters, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _green,
                      )),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      );
    }

    final totalPages = (filtered.length / _itemsPerPage).ceil();
    if (_currentPage > totalPages) {
      _currentPage = totalPages > 0 ? 1 : 0;
    }
    if (_currentPage < 1 && totalPages > 0) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final pageItems = totalPages > 0
        ? filtered.sublist(
      startIndex,
      endIndex > filtered.length ? filtered.length : endIndex,
    )
        : <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _loadEventsDirectly,
      color: _green,
      backgroundColor: Colors.white,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        itemCount: pageItems.length + (totalPages > 1 ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == pageItems.length) {
            return _buildPaginationRow(totalPages);
          }
          final event = pageItems[index];
          return EventCardFull(
            event: event,
            lang: isJa ? 'ja' : 'en',
          );
        },
      ),
    );
  }

  Widget _buildAddEventButton() {
    final isJa = ref.watch(appLangProvider) == kLangJa;
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AddEventScreen())),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 36),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: _green.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              isJa ? 'イベント追加' : 'Add an Event',
              style: const TextStyle(
                color: Colors.white, fontSize: 15,
                fontWeight: FontWeight.w700, letterSpacing: 0.2,
              ),
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
              color: _surface,
              shape: BoxShape.circle,
              border: Border.all(color: _green.withOpacity(0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.close_rounded, size: 16, color: _textMid),
          ),
        ),
      ),
    ]);
  }

  Widget _buildPaginationRow(int totalPages) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          GestureDetector(
            onTap: _currentPage <= 1
                ? null
                : () {
              setState(() => _currentPage--);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: Opacity(
              opacity: _currentPage <= 1 ? 0.35 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _green.withOpacity(0.15)),
                ),
                child: Text(
                  s.isJa ? '前へ' : 'Prev',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _green,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Page indicators / bubbles
          ...List.generate(totalPages, (index) {
            final page = index + 1;
            final isCurrent = page == _currentPage;
            return GestureDetector(
              onTap: () {
                setState(() => _currentPage = page);
                _scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCurrent ? _green : _greenLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCurrent ? _green : _green.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: isCurrent
                      ? [
                    BoxShadow(
                      color: _green.withOpacity(0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$page',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : _green,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 8),

          // Next button
          GestureDetector(
            onTap: _currentPage >= totalPages
                ? null
                : () {
              setState(() => _currentPage++);
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            },
            child: Opacity(
              opacity: _currentPage >= totalPages ? 0.35 : 1.0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _green.withOpacity(0.15)),
                ),
                child: Text(
                  s.isJa ? '次へ' : 'Next',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _green,
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
