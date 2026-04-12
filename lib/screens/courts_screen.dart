import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/screens/add_court_screen.dart';

// ── Filter State ──────────────────────────────────────────────────────────────
//
// Mirrors web app's CourtFilter exactly:
//   country    → loc_country
//   prefecture → loc_prefecture_en || loc_prefecture
//   city       → loc_city_en || loc_city          ← added to match web
//   setupType  → loc_setup_type                   ← added to match web
//   amenities  → loc_amenities_<key> (true | 'T' | 'Yes')
//
// Web amenity keys: openplay, reservation, membership, lessons, dedicated,
//                   paddlerentals                  ← paddlerentals added
//
// Web DEFAULT_FILTER: { country:'Japan', prefecture:'Tokyo',
//                       city:null, setupType:null, amenities:{} }
//
class CourtFilter {
  final String? country;
  final String? prefecture;
  final String? city;       // ← web: filter.city
  final String? setupType;  // ← web: filter.setupType
  final Set<String> amenities;

  const CourtFilter({
    this.country,
    this.prefecture,
    this.city,
    this.setupType,
    this.amenities = const {},
  });

  CourtFilter copyWith({
    Object? country    = _sentinel,
    Object? prefecture = _sentinel,
    Object? city       = _sentinel,
    Object? setupType  = _sentinel,
    Set<String>? amenities,
  }) {
    return CourtFilter(
      country:    country    == _sentinel ? this.country    : country    as String?,
      prefecture: prefecture == _sentinel ? this.prefecture : prefecture as String?,
      city:       city       == _sentinel ? this.city       : city       as String?,
      setupType:  setupType  == _sentinel ? this.setupType  : setupType  as String?,
      amenities:  amenities  ?? this.amenities,
    );
  }

  // Mirrors web DEFAULT_FILTER exactly
  static const CourtFilter defaultFilter = CourtFilter(
    country:    'Japan',
    prefecture: 'Tokyo',
  );

  // ── Helpers ────────────────────────────────────────────────────────────────

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

  // ── matchesFilter — mirrors web matchesFilter() ────────────────────────────
  // When search is active: skip geo filter, apply only matchesNonGeo.
  // When no search:        apply geo filter (country + prefecture) then non-geo.
  bool matchesLocation(Map<String, dynamic> loc) {
    if (country != null) {
      if ((loc['loc_country'] ?? '').toString() != country) return false;
    }
    if (prefecture != null) {
      if (_prefValue(loc) != prefecture) return false;
    }
    return _matchesNonGeo(loc);
  }

  bool matchesNonGeo(Map<String, dynamic> loc) => _matchesNonGeo(loc);

  bool _matchesNonGeo(Map<String, dynamic> loc) {
    // city — mirrors web: (loc_city_en || loc_city).trim() !== filter.city
    if (city != null) {
      if (_cityValue(loc) != city) return false;
    }
    // setupType — mirrors web: loc_setup_type !== filter.setupType
    if (setupType != null) {
      if ((loc['loc_setup_type'] ?? '').toString() != setupType) return false;
    }
    // amenities — mirrors web: val !== true && val !== 'T' && val !== 'Yes'
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

// ── hasActiveFilter — mirrors web exactly ─────────────────────────────────────
// Web: country !== 'Japan' || prefecture !== 'Tokyo' ||
//      city !== null || setupType !== null || amenities.size > 0
bool _hasActiveFilter(CourtFilter f) {
  if (f.country    != null && f.country    != 'Japan') return true;
  if (f.prefecture != null && f.prefecture != 'Tokyo') return true;
  if (f.city       != null) return true;
  if (f.setupType  != null) return true;
  if (f.amenities.isNotEmpty) return true;
  return false;
}

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
          onTap:    () => _showCourtSheet(loc),
        ));
      }
    }
    setState(() => _markers = newMarkers);
    Future.delayed(const Duration(milliseconds: 800), _moveCameraToMarkers);
  }

  void _applySearchAndFilter() {
    final search   = _searchController.text.trim().toLowerCase();
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
        if (!name.contains(search)   &&
            !nameJp.contains(search) &&
            !city.contains(search)   &&
            !cityEn.contains(search) &&
            !pref.contains(search)   &&
            !prefEn.contains(search) &&
            !addr.contains(search)   &&
            !addrJp.contains(search)) return false;
        return _filter.matchesNonGeo(loc);
      }
      return _filter.matchesLocation(loc);
    }).toList();
    _updateMarkers(filtered);
  }

  void _showCourtSheet(Map<String, dynamic> loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor:    Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourtDetailSheet(loc: loc),
    );
  }

  void _openFilterModal(List<Map<String, dynamic>> allLocations) async {
    final result = await showModalBottomSheet<CourtFilter>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    Colors.transparent,
      builder: (_) => _CourtFilterModal(
        currentFilter: _filter,
        allLocations:  allLocations,
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
              key:                     const ValueKey('google_map'),
              initialCameraPosition:   _initialPosition,
              markers:                 _markers,
              myLocationEnabled:       true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled:     false,
              mapToolbarEnabled:       false,
              mapType:                 MapType.normal,
              compassEnabled:          false,
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
                  Text('Loading map...',
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
              top:   MediaQuery.of(context).padding.top + 130,
              left:  0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                          color:      AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset:     const Offset(0, 4)),
                    ],
                  ),
                  child: Text(
                    '${filteredLocations.length} '
                        'court${filteredLocations.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   13,
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
                      color:      Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset:     const Offset(0, 4)),
                ],
              ),
              child: Row(children: [
                Container(
                  width:  34, height: 34,
                  decoration: BoxDecoration(
                      color:        AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.location_on_rounded,
                      color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Courts',
                    style: TextStyle(
                        fontSize:   20, fontWeight: FontWeight.w800,
                        color:      Color(0xFF0D0D0D), letterSpacing: -0.5)),
                const SizedBox(width: 8),
                if (!hasActiveFilter)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color:        AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('Tokyo',
                        style: TextStyle(
                            fontSize:   10,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.primary)),
                  ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
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
                        offset:     const Offset(0, 4)),
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
                  color:      Colors.black.withOpacity(0.07),
                  blurRadius: 16,
                  offset:     const Offset(0, 4)),
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
              hintText: 'Search pickleball courts...',
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
              border:         InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
                  color:      Colors.black.withOpacity(0.22),
                  blurRadius: 20,
                  offset:     const Offset(0, 8)),
            ],
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text('Add a Court',
                style: TextStyle(
                    color:      Colors.white, fontSize: 15,
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
                    color:      Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset:     const Offset(0, 2)),
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
// Court Detail Bottom Sheet  (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _CourtDetailSheet extends StatelessWidget {
  final Map<String, dynamic> loc;
  const _CourtDetailSheet({required this.loc});

  String get _name    => (loc['loc_name']    ?? 'Court').toString();
  String get _address => (loc['loc_address'] ?? '').toString();
  String get _city {
    final en = (loc['loc_city_en'] ?? '').toString().trim();
    return en.isNotEmpty ? en : (loc['loc_city'] ?? '').toString();
  }
  String get _prefecture {
    final en = (loc['loc_prefecture_en'] ?? '').toString().trim();
    if (en.isNotEmpty) return en;
    return (loc['loc_prefecture'] ?? '').toString();
  }
  String get _country    => (loc['loc_country']      ?? '').toString();
  String get _type       => (loc['loc_type']          ?? '').toString();
  String get _price      => (loc['loc_price']         ?? '').toString();
  String get _phone      => (loc['loc_contact_email'] ?? '').toString();
  String get _googleLink => (loc['loc_googlelink']    ?? '').toString();
  String get _website    => (loc['loc_website']       ?? '').toString();
  String get _image      => (loc['loc_image']         ?? '').toString();

  String get _primaryLink => _website.isNotEmpty ? _website : _googleLink;

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
    String startDay  = filled[0].$1;
    String prevDay   = filled[0].$1;
    String curHours  = filled[0].$2;
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color:      Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset:     const Offset(0, -8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color:        Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),
          if (_image.isNotEmpty)
            SizedBox(
              height: 160, width: double.infinity,
              child: Image.network(_image,
                  fit: BoxFit.cover,
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
                        color:        AppColors.primary.withOpacity(0.1),
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
              if (_isIndoor || _isOutdoor || _courtCount > 0) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  if (_isIndoor)
                    _tag('Indoor',  Icons.roofing_rounded),
                  if (_isOutdoor)
                    _tag('Outdoor', Icons.park_rounded),
                  if (_courtCount > 0)
                    _tag('$_courtCount court${_courtCount == 1 ? '' : 's'}',
                        Icons.grid_view_rounded),
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
                  label: const Text('More Information',
                      style: TextStyle(
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
                  color:  Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Court hours and amenities may change. '
                          'Please confirm details directly with the '
                          'facility or court operator.',
                      style: TextStyle(fontSize: 11, color: Colors.black38, height: 1.5),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color:    Colors.black.withOpacity(0.65),
                  height:   1.4)),
        ),
      ]),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color:        AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.primary)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Modal — mirrors web FilterModal exactly
//
// Sections (in order, same as web):
//   1. Country       dropdown
//   2. Prefecture    dropdown  (when country selected)
//   3. City          dropdown  (when prefecture selected) ← NEW matches web
//   4. Setup Type    chips     (when loc_setup_type data exists) ← NEW matches web
//   5. Amenities     chips     (dedicated, membership, openplay,
//                               reservation, lessons, paddlerentals) ← paddlerentals added
//
// Reset → CourtFilter.defaultFilter (Japan / Tokyo)
// ─────────────────────────────────────────────────────────────────────────────
class _CourtFilterModal extends StatefulWidget {
  final CourtFilter                currentFilter;
  final List<Map<String, dynamic>> allLocations;

  const _CourtFilterModal({
    required this.currentFilter,
    required this.allLocations,
  });

  @override
  State<_CourtFilterModal> createState() => _CourtFilterModalState();
}

class _CourtFilterModalState extends State<_CourtFilterModal> {
  late CourtFilter _draft;

  // Derived lookup tables built from allLocations
  late final List<String>              _countries;
  late final Map<String, List<String>> _prefsByCountry;
  late final Map<String, List<String>> _citiesByPref;
  late final List<String>              _setupTypes;

  // ── Web amenity list (label, Firestore key suffix) ─────────────────────────
  // Mirrors web AMENITIES array exactly, including paddlerentals
  static const _amenities = [
    ('Open Play',      'openplay'),
    ('Reservation',    'reservation'),
    ('Membership',     'membership'),
    ('Lessons',        'lessons'),
    ('Dedicated',      'dedicated'),
    ('Paddle Rentals', 'paddlerentals'), // ← added to match web
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter;
    _buildLookups();
  }

  void _buildLookups() {
    final countries    = <String>{};
    final prefsByC     = <String, Set<String>>{};
    final citiesByPref = <String, Set<String>>{};
    final setupTypes   = <String>{};

    for (final loc in widget.allLocations) {
      final country  = (loc['loc_country'] ?? '').toString().trim();
      final prefEn   = (loc['loc_prefecture_en'] ?? '').toString().trim();
      final pref     = (loc['loc_prefecture']    ?? '').toString().trim();
      final prefVal  = prefEn.isNotEmpty ? prefEn : pref;
      final cityEn   = (loc['loc_city_en'] ?? '').toString().trim();
      final city     = (loc['loc_city']    ?? '').toString().trim();
      final cityVal  = cityEn.isNotEmpty ? cityEn : city;
      final setup    = (loc['loc_setup_type'] ?? '').toString().trim();

      if (country.isNotEmpty) {
        countries.add(country);
        if (prefVal.isNotEmpty) {
          prefsByC.putIfAbsent(country, () => <String>{}).add(prefVal);
          if (cityVal.isNotEmpty) {
            citiesByPref.putIfAbsent(prefVal, () => <String>{}).add(cityVal);
          }
        }
      }
      if (setup.isNotEmpty) setupTypes.add(setup);
    }

    _countries      = countries.toList()..sort();
    _prefsByCountry = prefsByC.map((k, v) => MapEntry(k, v.toList()..sort()));
    _citiesByPref   = citiesByPref.map((k, v) => MapEntry(k, v.toList()..sort()));
    _setupTypes     = setupTypes.toList()..sort();
  }

  // Available prefectures for currently selected country
  List<String> get _currentPrefs =>
      _draft.country != null ? (_prefsByCountry[_draft.country] ?? []) : [];

  // Safe prefecture value (reset if not in list)
  String? get _safePref {
    if (_draft.prefecture == null) return null;
    return _currentPrefs.contains(_draft.prefecture) ? _draft.prefecture : null;
  }

  // Available cities for currently selected prefecture
  List<String> get _currentCities =>
      _safePref != null ? (_citiesByPref[_safePref] ?? []) : [];

  // Safe city value (reset if not in list)
  String? get _safeCity {
    if (_draft.city == null) return null;
    return _currentCities.contains(_draft.city) ? _draft.city : null;
  }

  // Reset → web DEFAULT_FILTER
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
              color:        Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color:      Colors.black.withOpacity(0.18),
                    blurRadius: 40,
                    offset:     const Offset(0, -8)),
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
                      color:        Colors.black.withOpacity(0.12),
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
                          color:        AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.tune_rounded,
                          color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text('Filter Courts',
                        style: TextStyle(
                            fontSize:   20, fontWeight: FontWeight.w800,
                            color:      Color(0xFF0D0D0D), letterSpacing: -0.5)),
                    const Spacer(),
                    IconButton(
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: false).pop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        minimumSize: const Size(34, 34),
                        padding:     EdgeInsets.zero,
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

                        // ── 1. COUNTRY ─────────────────────────────────────
                        _sectionLabel('Country', Icons.public_rounded),
                        const SizedBox(height: 10),
                        _buildDropdown(
                          value:     _draft.country,
                          hint:      'All countries',
                          items:     _countries,
                          onChanged: (v) => setState(() => _draft =
                              _draft.copyWith(
                                  country:    v,
                                  prefecture: null,
                                  city:       null)),
                        ),
                        const SizedBox(height: 20),

                        // ── 2. PREFECTURE (when country selected) ──────────
                        if (_currentPrefs.isNotEmpty) ...[
                          _sectionLabel(
                              'Prefecture / State', Icons.map_outlined),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value:     _safePref,
                            hint:      'All prefectures',
                            items:     _currentPrefs,
                            onChanged: (v) => setState(() => _draft =
                                _draft.copyWith(prefecture: v, city: null)),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── 3. CITY (when prefecture selected) ─────────────
                        // Mirrors web: citiesByPrefecture[safePref]
                        if (_currentCities.isNotEmpty) ...[
                          _sectionLabel('City', Icons.location_city_rounded),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value:     _safeCity,
                            hint:      'All cities',
                            items:     _currentCities,
                            onChanged: (v) => setState(
                                    () => _draft = _draft.copyWith(city: v)),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // ── 4. SETUP TYPE chips ─────────────────────────────
                        // Mirrors web setupTypes section (loc_setup_type)
                        if (_setupTypes.isNotEmpty) ...[
                          _sectionLabel(
                              'Setup Type', Icons.construction_rounded),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            _chip('All', _draft.setupType == null,
                                    () => setState(() => _draft =
                                    _draft.copyWith(setupType: null))),
                            ..._setupTypes.map((t) => _chip(
                                t,
                                _draft.setupType == t,
                                    () => setState(() =>
                                _draft = _draft.copyWith(setupType: t)))),
                          ]),
                          const SizedBox(height: 20),
                        ],

                        // ── 5. AMENITIES ────────────────────────────────────
                        // Mirrors web AMENITIES array (including paddlerentals)
                        _sectionLabel(
                            'Amenities', Icons.star_outline_rounded),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: _amenities.map((a) {
                            final (label, key) = a;
                            final active = _draft.amenities.contains(key);
                            return GestureDetector(
                              onTap: () {
                                final next =
                                Set<String>.from(_draft.amenities);
                                if (active)
                                  next.remove(key);
                                else
                                  next.add(key);
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
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (active) ...[
                                      Icon(Icons.check_rounded,
                                          size:  14,
                                          color: AppColors.primary),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(label,
                                        style: TextStyle(
                                            fontSize:   13,
                                            fontWeight: FontWeight.w600,
                                            color: active
                                                ? AppColors.primary
                                                : Colors.black
                                                .withOpacity(0.55))),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),

                        // ── Action buttons ─────────────────────────────────
                        Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: _resetAndClose,
                              child: Container(
                                height: 54,
                                decoration: BoxDecoration(
                                  color:        Colors.black.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text('Reset Filters',
                                      style: TextStyle(
                                          fontSize:   15,
                                          fontWeight: FontWeight.w700,
                                          color:      Colors.black
                                              .withOpacity(0.55))),
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
                                  color:        AppColors.primary,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.35),
                                      blurRadius: 16,
                                      offset:     const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text('Apply Filters',
                                      style: TextStyle(
                                          fontSize:      15,
                                          fontWeight:    FontWeight.w800,
                                          color:         Colors.white,
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

  // ── Shared sub-widgets ──────────────────────────────────────────────────────

  Widget _sectionLabel(String label, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: AppColors.primary),
      const SizedBox(width: 6),
      Text(label,
          style: const TextStyle(
              fontSize:   13, fontWeight: FontWeight.w800,
              color:      Color(0xFF0D0D0D), letterSpacing: 0.2)),
    ]);
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize:   13,
                fontWeight: FontWeight.w700,
                color:      selected
                    ? Colors.white
                    : Colors.black.withOpacity(0.55))),
      ),
    );
  }

  Widget _buildDropdown({
    required String?          value,
    required String           hint,
    required List<String>     items,
    required void Function(String?) onChanged,
  }) {
    final uniqueItems = items.toSet().toList()..sort();
    final safeValue =
    (value != null && uniqueItems.contains(value)) ? value : null;
    return Container(
      decoration: BoxDecoration(
        color:        Colors.black.withOpacity(0.04),
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
          value:   safeValue,
          hint:    Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(hint,
                style: TextStyle(
                    fontSize:   14,
                    color:      Colors.black.withOpacity(0.38),
                    fontWeight: FontWeight.w500)),
          ),
          isExpanded:   true,
          padding:      const EdgeInsets.only(left: 14, right: 8),
          borderRadius: BorderRadius.circular(16),
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.primary, size: 22),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(hint,
                  style: TextStyle(
                      fontSize: 14,
                      color:    Colors.black.withOpacity(0.4))),
            ),
            ...uniqueItems.map((item) => DropdownMenuItem<String>(
              value: item,
              child: Text(item,
                  style: const TextStyle(
                      fontSize:   14,
                      fontWeight: FontWeight.w500,
                      color:      Color(0xFF0D0D0D))),
            )),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}