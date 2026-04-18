import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/screens/add_court_screen.dart';

// ── i18n ─────────────────────────────────────────────────────────────────────
class _T {
  final String courts;
  final String tokyo;
  final String search;
  final String filterTitle;
  final String courtSetting;
  final String all;
  final String indoor;
  final String outdoor;
  final String prefecture;
  final String allPrefectures;
  final String city;
  final String allCities;
  final String setupType;
  final String amenities;
  final String resetFilters;
  final String applyFilters;
  final String courtsFound;
  final String moreInfo;
  final String disclaimer;
  final String addCourt;
  final String loadingMap;
  // Setup type labels
  final String setupPublic;
  final String setupPrivate;
  // Amenity labels
  final String amenityOpenPlay;
  final String amenityReservation;
  final String amenityMembership;
  final String amenityLessons;
  final String amenityDedicated;
  final String amenityPaddleRentals;
  // Detail sheet
  final String indoor2;
  final String outdoor2;

  const _T({
    required this.courts,
    required this.tokyo,
    required this.search,
    required this.filterTitle,
    required this.courtSetting,
    required this.all,
    required this.indoor,
    required this.outdoor,
    required this.prefecture,
    required this.allPrefectures,
    required this.city,
    required this.allCities,
    required this.setupType,
    required this.amenities,
    required this.resetFilters,
    required this.applyFilters,
    required this.courtsFound,
    required this.moreInfo,
    required this.disclaimer,
    required this.addCourt,
    required this.loadingMap,
    required this.setupPublic,
    required this.setupPrivate,
    required this.amenityOpenPlay,
    required this.amenityReservation,
    required this.amenityMembership,
    required this.amenityLessons,
    required this.amenityDedicated,
    required this.amenityPaddleRentals,
    required this.indoor2,
    required this.outdoor2,
  });

  static const en = _T(
    courts:               'Courts',
    tokyo:                'Tokyo',
    search:               'Search pickleball courts...',
    filterTitle:          'Filter Courts',
    courtSetting:         'Court Setting',
    all:                  'All',
    indoor:               'Indoor',
    outdoor:              'Outdoor',
    prefecture:           'Prefecture',
    allPrefectures:       'All prefectures',
    city:                 'City',
    allCities:            'All cities',
    setupType:            'Setup Type',
    amenities:            'Amenities',
    resetFilters:         'Reset Filters',
    applyFilters:         'Apply Filters',
    courtsFound:          'courts found',
    moreInfo:             'More Information',
    disclaimer:           'Court hours and amenities may change. Please confirm details directly with the facility or court operator.',
    addCourt:             'Add a Court',
    loadingMap:           'Loading map...',
    setupPublic:          'Public Access Courts',
    setupPrivate:         'Private / Coordinated Courts',
    amenityOpenPlay:      'Open Play',
    amenityReservation:   'Reservation',
    amenityMembership:    'Membership',
    amenityLessons:       'Lessons',
    amenityDedicated:     'Dedicated',
    amenityPaddleRentals: 'Paddle Rentals',
    indoor2:              'Indoor',
    outdoor2:             'Outdoor',
  );

  static const ja = _T(
    courts:               'コート',
    tokyo:                '東京',
    search:               'ピックルボールコートを検索...',
    filterTitle:          'コートを絞り込む',
    courtSetting:         'コート環境',
    all:                  'すべて',
    indoor:               '室内',
    outdoor:              '屋外',
    prefecture:           '都道府県',
    allPrefectures:       '全ての都道府県',
    city:                 '市区町村',
    allCities:            '全ての市区町村',
    setupType:            'セットアップタイプ',
    amenities:            'アメニティ',
    resetFilters:         'リセット',
    applyFilters:         'フィルターを適用',
    courtsFound:          '件のコートが見つかりました',
    moreInfo:             '詳細を見る',
    disclaimer:           'コートの営業時間や設備は変更される場合があります。詳細は施設またはコート運営者に直接ご確認ください。',
    addCourt:             'コート追加',
    loadingMap:           'マップを読み込み中...',
    setupPublic:          '一般開放コート',
    setupPrivate:         '事前調整・予約制コート',
    amenityOpenPlay:      'オープンプレイ',
    amenityReservation:   '予約制',
    amenityMembership:    '会員制',
    amenityLessons:       'レッスンあり',
    amenityDedicated:     '専用コート',
    amenityPaddleRentals: 'パドルレンタル',
    indoor2:              '室内',
    outdoor2:             '屋外',
  );
}

// ── Filter State ──────────────────────────────────────────────────────────────
class CourtFilter {
  final String? prefecture;
  final String? city;
  final String? setupType;
  final Set<String> amenities;
  final String setting;

  const CourtFilter({
    this.prefecture,
    this.city,
    this.setupType,
    this.amenities = const {},
    this.setting = 'all',
  });

  CourtFilter copyWith({
    Object? prefecture = _sentinel,
    Object? city       = _sentinel,
    Object? setupType  = _sentinel,
    Set<String>? amenities,
    String? setting,
  }) {
    return CourtFilter(
      prefecture: prefecture == _sentinel ? this.prefecture : prefecture as String?,
      city:       city       == _sentinel ? this.city       : city       as String?,
      setupType:  setupType  == _sentinel ? this.setupType  : setupType  as String?,
      amenities:  amenities  ?? this.amenities,
      setting:    setting    ?? this.setting,
    );
  }

  static const String _country = 'Japan';

  static const CourtFilter defaultFilter = CourtFilter(
    prefecture: 'Tokyo',
    setting: 'all',
  );

  static String _prefValue(Map<String, dynamic> loc) {
    final en = (loc['loc_prefecture_en'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    return (loc['loc_prefecture'] ?? '').toString().trim();
  }

  static String _cityValue(Map<String, dynamic> loc) {
    final en = (loc['loc_city_en'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    return (loc['loc_city'] ?? '').toString().trim();
  }

  bool matchesLocation(Map<String, dynamic> loc) {
    if ((loc['loc_country'] ?? '').toString() != _country) return false;
    if (prefecture != null && _prefValue(loc) != prefecture) return false;
    return _matchesNonGeo(loc);
  }

  bool matchesNonGeo(Map<String, dynamic> loc) => _matchesNonGeo(loc);

  bool _matchesNonGeo(Map<String, dynamic> loc) {
    if (city != null && _cityValue(loc) != city) return false;
    if (setupType != null &&
        (loc['loc_setup_type'] ?? '').toString() != setupType) return false;
    if (setting == 'indoor'  && loc['loc_court_type_indoor']  != true) return false;
    if (setting == 'outdoor' && loc['loc_court_type_outdoor'] != true) return false;
    for (final a in amenities) {
      final val = loc['loc_amenities_$a'];
      if (val != true && val?.toString() != 'T' && val?.toString() != 'Yes') {
        return false;
      }
    }
    return true;
  }
}

const _sentinel = Object();

bool _hasActiveFilter(CourtFilter f) =>
    (f.prefecture != null && f.prefecture != 'Tokyo') ||
        f.city != null ||
        f.setupType != null ||
        f.amenities.isNotEmpty ||
        f.setting != 'all';

// ─────────────────────────────────────────────────────────────────────────────
// CourtsScreen
// ─────────────────────────────────────────────────────────────────────────────
class CourtsScreen extends ConsumerStatefulWidget {
  const CourtsScreen({super.key});

  @override
  ConsumerState<CourtsScreen> createState() => _CourtsScreenState();
}

class _CourtsScreenState extends ConsumerState<CourtsScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _mapReady = false;

  CourtFilter _filter = CourtFilter.defaultFilter;
  bool _isJa = false; // ← language toggle
  _T get _t => _isJa ? _T.ja : _T.en;

  List<Map<String, dynamic>> _lastLocations = [];
  Timer? _searchDebounce;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6762, 139.6503),
    zoom: 10,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(showAddCourtButtonProvider.notifier).state = true;
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null)   return null;
    if (value is double) return value;
    if (value is int)    return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _moveCameraToMarkers() {
    if (_mapController == null) return;
    if (_markers.isEmpty) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(const LatLng(35.6762, 139.6503), 10));
      return;
    }
    if (_markers.length == 1) {
      _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(_markers.first.position, 14));
      return;
    }
    double? minLat, maxLat, minLng, maxLng;
    for (final m in _markers) {
      final lat = m.position.latitude;
      final lng = m.position.longitude;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }
    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if (minLat == maxLat && minLng == maxLng) {
        _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14));
      } else {
        _mapController!.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng)),
            80));
      }
    }
  }

  void _updateMarkers(List<Map<String, dynamic>> filtered) {
    final newMarkers = <Marker>{};
    for (int i = 0; i < filtered.length; i++) {
      final loc = filtered[i];
      final lat = _parseCoordinate(loc['loc_latitude']);
      final lng = _parseCoordinate(loc['loc_longitude']);
      if (lat != null && lng != null) {
        newMarkers.add(Marker(
          markerId: MarkerId(loc['_doc_id'] ?? 'court_$i'),
          position: LatLng(lat, lng),
          onTap: () => _showCourtSheet(loc),
        ));
      }
    }
    setState(() => _markers = newMarkers);
    Future.delayed(const Duration(milliseconds: 800), _moveCameraToMarkers);
  }

  void _applySearchAndFilter() {
    final search = _searchController.text.trim().toLowerCase();
    final filtered = _lastLocations.where((loc) {
      if (search.isNotEmpty) {
        final name   = (loc['loc_name']         ?? '').toString().toLowerCase();
        final nameJp = (loc['loc_name_jp']       ?? '').toString().toLowerCase();
        final city   = (loc['loc_city']          ?? '').toString().toLowerCase();
        final cityEn = (loc['loc_city_en']       ?? '').toString().toLowerCase();
        final pref   = (loc['loc_prefecture']    ?? '').toString().toLowerCase();
        final prefEn = (loc['loc_prefecture_en'] ?? '').toString().toLowerCase();
        final addr   = (loc['loc_address']       ?? '').toString().toLowerCase();
        final addrJp = (loc['loc_address_jp']    ?? '').toString().toLowerCase();
        if (!name.contains(search)   && !nameJp.contains(search) &&
            !city.contains(search)   && !cityEn.contains(search) &&
            !pref.contains(search)   && !prefEn.contains(search) &&
            !addr.contains(search)   && !addrJp.contains(search)) return false;
        return _filter.matchesNonGeo(loc);
      }
      return _filter.matchesLocation(loc);
    }).toList();
    _updateMarkers(filtered);
  }

  void _showCourtSheet(Map<String, dynamic> loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourtDetailSheet(loc: loc, isJa: _isJa, t: _t),
    );
  }

  void _openFilterModal(List<Map<String, dynamic>> allLocations) async {
    final result = await showModalBottomSheet<CourtFilter>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CourtFilterModal(
        currentFilter: _filter,
        allLocations: allLocations,
        isJa: _isJa,
        t: _t,
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      _applySearchAndFilter();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showAddButton  = ref.watch(showAddCourtButtonProvider);
    final locationsAsync = ref.watch(locationsProvider);
    final allLocations   = locationsAsync.asData?.value ?? [];

    if (locationsAsync.hasValue && allLocations.isNotEmpty) {
      final newIds = allLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      final oldIds = _lastLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      if (!newIds.containsAll(oldIds) || !oldIds.containsAll(newIds)) {
        _lastLocations = allLocations;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applySearchAndFilter();
        });
      }
    }

    final searchQuery = _searchController.text.trim().toLowerCase();
    final filteredLocations = allLocations.where((loc) {
      if (searchQuery.isNotEmpty) {
        final name   = (loc['loc_name']         ?? '').toString().toLowerCase();
        final nameJp = (loc['loc_name_jp']       ?? '').toString().toLowerCase();
        final city   = (loc['loc_city']          ?? '').toString().toLowerCase();
        final cityEn = (loc['loc_city_en']       ?? '').toString().toLowerCase();
        final pref   = (loc['loc_prefecture']    ?? '').toString().toLowerCase();
        final prefEn = (loc['loc_prefecture_en'] ?? '').toString().toLowerCase();
        final addr   = (loc['loc_address']       ?? '').toString().toLowerCase();
        final addrJp = (loc['loc_address_jp']    ?? '').toString().toLowerCase();
        if (!name.contains(searchQuery) && !nameJp.contains(searchQuery) &&
            !city.contains(searchQuery) && !cityEn.contains(searchQuery) &&
            !pref.contains(searchQuery) && !prefEn.contains(searchQuery) &&
            !addr.contains(searchQuery) && !addrJp.contains(searchQuery)) return false;
        return _filter.matchesNonGeo(loc);
      }
      return _filter.matchesLocation(loc);
    }).toList();

    final hasActiveFilter = _hasActiveFilter(_filter);

    return Scaffold(
      body: Stack(
        children: [
          RepaintBoundary(
            child: GoogleMap(
              key: const ValueKey('google_map'),
              initialCameraPosition: _initialPosition,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              mapType: MapType.normal,
              compassEnabled: false,
              onMapCreated: (controller) {
                _mapController = controller;
                setState(() => _mapReady = true);
                Future.delayed(const Duration(milliseconds: 600), () {
                  if (mounted && _markers.isNotEmpty) _moveCameraToMarkers();
                });
              },
            ),
          ),

          if (!_mapReady && Platform.isIOS)
            Container(
              color: const Color(0xFFE8F0E9),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 12),
                  Text(_t.loadingMap,
                      style: TextStyle(
                          color: AppColors.primary, fontWeight: FontWeight.w600)),
                ]),
              ),
            ),

          SafeArea(
            child: Column(children: [
              _buildHeader(allLocations, hasActiveFilter),
            ]),
          ),

          if (_lastLocations.isNotEmpty && (searchQuery.isNotEmpty || hasActiveFilter))
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    _isJa
                        ? '${filteredLocations.length}${_t.courtsFound}'
                        : '${filteredLocations.length} ${_t.courtsFound}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),

          if (showAddButton)
            Positioned(
              bottom: 24, left: 0, right: 0,
              child: Center(child: _buildAddCourtButton()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(List<Map<String, dynamic>> allLocations, bool hasActiveFilter) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Text(_t.courts,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800,
                        color: Color(0xFF0D0D0D), letterSpacing: -0.5)),
                const SizedBox(width: 8),
                if (!hasActiveFilter)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(_t.tokyo,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 8),

          // ── Language toggle ─────────────────────────────────────────────
          _LangToggle(
            isJa: _isJa,
            onToggle: (ja) => setState(() {
              _isJa = ja;
              // Rebuild filter modal with new lang next open
            }),
          ),
          const SizedBox(width: 8),

          // ── Filter button ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => _openFilterModal(allLocations),
            child: Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: hasActiveFilter ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: hasActiveFilter
                            ? AppColors.primary.withOpacity(0.4)
                            : Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: Icon(Icons.tune_rounded,
                    color: hasActiveFilter ? Colors.white : AppColors.primary,
                    size: 22),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 14, height: 14,
                    decoration: const BoxDecoration(
                        color: Colors.orangeAccent, shape: BoxShape.circle),
                  ),
                ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {});
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 300), () {
                if (!mounted) return;
                _applySearchAndFilter();
              });
            },
            style: const TextStyle(fontSize: 15, color: Color(0xFF0D0D0D)),
            decoration: InputDecoration(
              hintText: _t.search,
              hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15, fontWeight: FontWeight.w400),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.black.withOpacity(0.35), size: 22),
              suffixIcon: _searchController.text.isNotEmpty
                  ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() {});
                    _applySearchAndFilter();
                  },
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.35), size: 20))
                  : null,
              border: InputBorder.none,
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildAddCourtButton() {
    return Stack(clipBehavior: Clip.none, children: [
      GestureDetector(
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddCourtScreen())),
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
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(_t.addCourt,
                style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ]),
        ),
      ),
      Positioned(
        top: -8, right: -8,
        child: GestureDetector(
          onTap: () =>
          ref.read(showAddCourtButtonProvider.notifier).state = false,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: Colors.white, shape: BoxShape.circle,
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
    ]);
  }
}

// ── Language Toggle widget ────────────────────────────────────────────────────
class _LangToggle extends StatelessWidget {
  final bool isJa;
  final ValueChanged<bool> onToggle;
  const _LangToggle({required this.isJa, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _tab('EN',   !isJa, () => onToggle(false)),
        _tab('日本語', isJa,  () => onToggle(true)),
      ]),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : Colors.black.withOpacity(0.4))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Court Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CourtDetailSheet extends StatelessWidget {
  final Map<String, dynamic> loc;
  final bool isJa;
  final _T t;
  const _CourtDetailSheet({required this.loc, required this.isJa, required this.t});

  String get _name {
    if (isJa) {
      final jp = (loc['loc_name_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (loc['loc_name'] ?? 'Court').toString();
  }

  String get _address {
    if (isJa) {
      final jp = (loc['loc_address_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    return (loc['loc_address'] ?? '').toString();
  }

  String get _city {
    if (isJa) {
      final jp = (loc['loc_city_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    final en = (loc['loc_city_en'] ?? '').toString().trim();
    return en.isNotEmpty ? en : (loc['loc_city'] ?? '').toString();
  }

  String get _prefecture {
    if (isJa) {
      final jp = (loc['loc_prefecture_jp'] ?? '').toString().trim();
      if (jp.isNotEmpty) return jp;
    }
    final en = (loc['loc_prefecture_en'] ?? '').toString().trim();
    return en.isNotEmpty ? en : (loc['loc_prefecture'] ?? '').toString();
  }

  String get _country    => (loc['loc_country']      ?? '').toString();
  String get _type       => (loc['loc_type']          ?? '').toString();
  String get _price      => (loc['loc_price']         ?? '').toString();
  String get _phone      => (loc['loc_contact_email'] ?? '').toString();
  String get _googleLink => (loc['loc_googlelink']    ?? '').toString();
  String get _website    => (loc['loc_website']       ?? '').toString();
  String get _image      => (loc['loc_image']         ?? '').toString();
  String get _primaryLink => _website.isNotEmpty ? _website : _googleLink;

  // Setup type — show JP label when in JP mode
  String get _setupTypeLabel {
    final raw = (loc['loc_setup_type'] ?? '').toString().trim();
    if (!isJa || raw.isEmpty) return raw;
    if (raw == 'Public Access Courts')         return '一般開放コート';
    if (raw == 'Private / Coordinated Courts') return '事前調整・予約制コート';
    return raw;
  }

  int get _courtCount {
    final v = loc['loc_court_count'];
    if (v is int)    return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  bool get _isIndoor  => loc['loc_court_type_indoor']  == true;
  bool get _isOutdoor => loc['loc_court_type_outdoor'] == true;

  String get _hoursFormatted {
    const days = [
      ('Mon', 'loc_hours_mon'),   ('Tue', 'loc_hours_tues'),
      ('Wed', 'loc_hours_weds'),  ('Thu', 'loc_hours_thurs'),
      ('Fri', 'loc_hours_fri'),   ('Sat', 'loc_hours_sat'),
      ('Sun', 'loc_hours_sun'),
    ];
    final filled = <(String, String)>[];
    for (final (label, field) in days) {
      final v = (loc[field] ?? '').toString().trim();
      if (v.isNotEmpty) filled.add((label, v));
    }
    if (filled.isEmpty) return '';
    final groups = <({String range, String hours})>[];
    String startDay = filled[0].$1, prevDay = filled[0].$1, curHours = filled[0].$2;
    for (int i = 1; i < filled.length; i++) {
      final (day, hours) = filled[i];
      if (hours == curHours) {
        prevDay = day;
      } else {
        groups.add((
        range: startDay == prevDay ? startDay : '$startDay–$prevDay',
        hours: curHours,
        ));
        startDay = prevDay = day;
        curHours = hours;
      }
    }
    groups.add((
    range: startDay == prevDay ? startDay : '$startDay–$prevDay',
    hours: curHours,
    ));
    return groups.map((g) => '${g.range}: ${g.hours}').join('  •  ');
  }

  String get _locationLine =>
      [_city, _prefecture, _country].where((s) => s.isNotEmpty).join(', ');

  Future<void> _openLink(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isTruthy(dynamic v) =>
      v == true || v?.toString() == 'T' || v?.toString() == 'Yes';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),
          if (_image.isNotEmpty)
            SizedBox(
              height: 160, width: double.infinity,
              child: Image.network(_image, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.primary.withOpacity(0.08),
                    child: Icon(Icons.sports_tennis_rounded,
                        size: 48, color: AppColors.primary.withOpacity(0.3)),
                  )),
            )
          else
            Container(
              height: 100, width: double.infinity,
              color: AppColors.primary.withOpacity(0.08),
              child: Icon(Icons.sports_tennis_rounded,
                  size: 48, color: AppColors.primary.withOpacity(0.3)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Text(_name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D), letterSpacing: -0.3)),
                ),
                if (_type.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(_type,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
              ]),
              const SizedBox(height: 14),
              if (_locationLine.isNotEmpty)
                _infoRow(Icons.location_on_rounded,  _locationLine),
              if (_address.isNotEmpty)
                _infoRow(Icons.home_rounded,          _address),
              if (_price.isNotEmpty)
                _infoRow(Icons.payments_outlined,     _price),
              if (_hoursFormatted.isNotEmpty)
                _infoRow(Icons.access_time_rounded,   _hoursFormatted),
              if (_phone.isNotEmpty)
                _infoRow(Icons.phone_outlined,        _phone),
              if (_setupTypeLabel.isNotEmpty)
                _infoRow(Icons.construction_rounded,  _setupTypeLabel),

              // Tags
              if (_isIndoor || _isOutdoor || _courtCount > 0 ||
                  _isTruthy(loc['loc_amenities_dedicated'])    ||
                  _isTruthy(loc['loc_amenities_membership'])   ||
                  _isTruthy(loc['loc_amenities_openplay'])     ||
                  _isTruthy(loc['loc_amenities_reservation'])  ||
                  _isTruthy(loc['loc_amenities_lessons'])      ||
                  _isTruthy(loc['loc_amenities_paddlerentals'])) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (_isIndoor)
                    _tag(t.indoor2,  Icons.roofing_rounded),
                  if (_isOutdoor)
                    _tag(t.outdoor2, Icons.park_rounded),
                  if (_courtCount > 0)
                    _tag(
                      isJa
                          ? '$_courtCount コート'
                          : '$_courtCount court${_courtCount == 1 ? '' : 's'}',
                      Icons.grid_view_rounded,
                    ),
                  if (_isTruthy(loc['loc_amenities_dedicated']))
                    _tag(t.amenityDedicated,     Icons.sports_tennis_rounded),
                  if (_isTruthy(loc['loc_amenities_membership']))
                    _tag(t.amenityMembership,    Icons.card_membership_rounded),
                  if (_isTruthy(loc['loc_amenities_openplay']))
                    _tag(t.amenityOpenPlay,      Icons.people_rounded),
                  if (_isTruthy(loc['loc_amenities_reservation']))
                    _tag(t.amenityReservation,   Icons.calendar_today_rounded),
                  if (_isTruthy(loc['loc_amenities_lessons']))
                    _tag(t.amenityLessons,       Icons.school_rounded),
                  if (_isTruthy(loc['loc_amenities_paddlerentals']))
                    _tag(t.amenityPaddleRentals, Icons.sports_rounded),
                ]),
              ],

              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: _primaryLink.isNotEmpty
                      ? () => _openLink(context, _primaryLink)
                      : null,
                  icon: const Icon(Icons.open_in_browser_rounded,
                      size: 18, color: Colors.white),
                  label: Text(t.moreInfo,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: Colors.white, letterSpacing: 0.1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryLink.isNotEmpty
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(t.disclaimer,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38, height: 1.5)),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(text,
            style: TextStyle(
                fontSize: 13, color: Colors.black.withOpacity(0.65), height: 1.4)),
      ),
    ]),
  );

  Widget _tag(String label, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: AppColors.primary),
      const SizedBox(width: 4),
      Text(label,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Modal
// ─────────────────────────────────────────────────────────────────────────────
class _CourtFilterModal extends StatefulWidget {
  final CourtFilter currentFilter;
  final List<Map<String, dynamic>> allLocations;
  final bool isJa;
  final _T t;

  const _CourtFilterModal({
    required this.currentFilter,
    required this.allLocations,
    required this.isJa,
    required this.t,
  });

  @override
  State<_CourtFilterModal> createState() => _CourtFilterModalState();
}

class _CourtFilterModalState extends State<_CourtFilterModal> {
  late CourtFilter _draft;
  late final List<String> _prefectures;
  late final Map<String, List<String>> _citiesByPref;

  // Fixed setup type options: (EN Firestore value, EN label, JP label)
  static const _setupTypes = [
    ('Public Access Courts',         'Public Access Courts',         '一般開放コート'),
    ('Private / Coordinated Courts', 'Private / Coordinated Courts', '事前調整・予約制コート'),
  ];

  // (EN label, JP label, Firestore key)
  static const _amenities = [
    ('Open Play',      'オープンプレイ',   'openplay'),
    ('Reservation',    '予約制',          'reservation'),
    ('Membership',     '会員制',          'membership'),
    ('Lessons',        'レッスンあり',     'lessons'),
    ('Dedicated',      '専用コート',       'dedicated'),
    ('Paddle Rentals', 'パドルレンタル',   'paddlerentals'),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter;
    _buildLookups();
  }

  void _buildLookups() {
    final prefectures  = <String>{};
    final citiesByPref = <String, Set<String>>{};

    for (final loc in widget.allLocations) {
      final country = (loc['loc_country'] ?? '').toString().trim();
      if (country != 'Japan') continue;

      final prefEn  = (loc['loc_prefecture_en'] ?? '').toString().trim();
      final pref    = (loc['loc_prefecture']    ?? '').toString().trim();
      final prefVal = prefEn.isNotEmpty ? prefEn : pref;

      final cityEn  = (loc['loc_city_en'] ?? '').toString().trim();
      final city    = (loc['loc_city']    ?? '').toString().trim();
      final cityVal = cityEn.isNotEmpty ? cityEn : city;

      if (prefVal.isNotEmpty) {
        prefectures.add(prefVal);
        if (cityVal.isNotEmpty) {
          citiesByPref.putIfAbsent(prefVal, () => <String>{}).add(cityVal);
        }
      }
    }

    _prefectures  = prefectures.toList()..sort();
    _citiesByPref = citiesByPref.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  List<String> get _currentCities =>
      _draft.prefecture != null ? (_citiesByPref[_draft.prefecture] ?? []) : [];

  String? get _safeCity =>
      (_draft.city != null && _currentCities.contains(_draft.city))
          ? _draft.city
          : null;

  String? get _safePref =>
      (_draft.prefecture != null && _prefectures.contains(_draft.prefecture))
          ? _draft.prefecture
          : null;

  _T get _t => widget.t;
  bool get _isJa => widget.isJa;

  void _resetAndClose() =>
      Navigator.of(context, rootNavigator: false).pop(CourtFilter.defaultFilter);

  void _applyAndClose() =>
      Navigator.of(context, rootNavigator: false).pop(_draft);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 40,
                    offset: const Offset(0, -8)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [

                // Drag handle
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.tune_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(_t.filterTitle,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0D0D), letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: false).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(34, 34),
                        padding: EdgeInsets.zero,
                      ),
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: Colors.black.withOpacity(0.5)),
                    ),
                  ]),
                ),
                const SizedBox(height: 4),
                Divider(height: 20, thickness: 1,
                    color: Colors.black.withOpacity(0.06)),

                // Scrollable body
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                        20, 4, 20,
                        MediaQuery.of(context).padding.bottom + 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── 1. Court Setting ──────────────────────────────
                        _sectionLabel(_t.courtSetting, Icons.roofing_rounded),
                        const SizedBox(height: 10),
                        Row(children: [
                          _settingChip(_t.all,     'all'),
                          const SizedBox(width: 8),
                          _settingChip(_t.indoor,  'indoor'),
                          const SizedBox(width: 8),
                          _settingChip(_t.outdoor, 'outdoor'),
                        ]),
                        const SizedBox(height: 20),

                        // ── 2. Prefecture ─────────────────────────────────
                        _sectionLabel(_t.prefecture, Icons.map_outlined),
                        const SizedBox(height: 10),
                        _buildDropdown(
                          value:     _safePref,
                          hint:      _t.allPrefectures,
                          items:     _prefectures,
                          onChanged: (v) => setState(() => _draft =
                              _draft.copyWith(prefecture: v, city: null)),
                        ),
                        const SizedBox(height: 20),

                        // ── 3. City ───────────────────────────────────────
                        if (_currentCities.isNotEmpty) ...[
                          _sectionLabel(_t.city, Icons.location_city_rounded),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value:     _safeCity,
                            hint:      _t.allCities,
                            items:     _currentCities,
                            onChanged: (v) => setState(
                                    () => _draft = _draft.copyWith(city: v)),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── 4. Setup Type ─────────────────────────────────
                        _sectionLabel(_t.setupType, Icons.construction_rounded),
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _setupChip(
                              _isJa ? 'すべて' : 'All',
                              null),
                          ..._setupTypes.map((tp) {
                            final (value, enLabel, jpLabel) = tp;
                            return _setupChip(
                                _isJa ? jpLabel : enLabel,
                                value);
                          }),
                        ]),
                        const SizedBox(height: 20),

                        // ── 5. Amenities ──────────────────────────────────
                        _sectionLabel(_t.amenities, Icons.star_outline_rounded),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _amenities.map((a) {
                            final (enLabel, jpLabel, key) = a;
                            final label  = _isJa ? jpLabel : enLabel;
                            final active = _draft.amenities.contains(key);
                            return GestureDetector(
                              onTap: () {
                                final next = Set<String>.from(_draft.amenities);
                                if (active) next.remove(key); else next.add(key);
                                setState(() =>
                                _draft = _draft.copyWith(amenities: next));
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 9),
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.black.withOpacity(0.04),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: active
                                        ? AppColors.primary
                                        : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  if (active) ...[
                                    Icon(Icons.check_rounded,
                                        size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(label,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: active
                                              ? AppColors.primary
                                              : Colors.black.withOpacity(0.55))),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),

                        // ── Action buttons ────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _resetAndClose,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(_t.resetFilters,
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
                              onTap: _applyAndClose,
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
                                child: Center(
                                  child: Text(_t.applyFilters,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2)),
                                ),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) => Row(children: [
    Icon(icon, size: 15, color: AppColors.primary),
    const SizedBox(width: 6),
    Text(label,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800,
            color: Color(0xFF0D0D0D), letterSpacing: 0.2)),
  ]);

  Widget _settingChip(String label, String value) {
    final selected = _draft.setting == value;
    return GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(setting: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black.withOpacity(0.55))),
      ),
    );
  }

  Widget _setupChip(String label, String? value) {
    final selected = _draft.setupType == value;
    return GestureDetector(
      onTap: () => setState(() => _draft = _draft.copyWith(setupType: value)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black.withOpacity(0.55))),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    final uniqueItems = items.toSet().toList()..sort();
    final safeValue =
    (value != null && uniqueItems.contains(value)) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: safeValue != null
              ? AppColors.primary.withOpacity(0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: safeValue,
          hint: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(hint,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.black.withOpacity(0.38),
                    fontWeight: FontWeight.w500)),
          ),
          isExpanded: true,
          padding: const EdgeInsets.only(left: 14, right: 8),
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary, size: 22),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint,
                  style: TextStyle(
                      fontSize: 14, color: Colors.black.withOpacity(0.4))),
            ),
            ...uniqueItems.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0D0D0D))),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}