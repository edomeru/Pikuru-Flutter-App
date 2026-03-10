import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';

// ── Filter State ──────────────────────────────────────────────────────────────
class CourtFilter {
  final String? country;
  final String? prefecture;
  final String? locType;
  final String? priceRange;
  final String? courtCount;
  final bool? indoorOnly;
  final Set<String> amenities;

  const CourtFilter({
    this.country,
    this.prefecture,
    this.locType,
    this.priceRange,
    this.courtCount,
    this.indoorOnly,
    this.amenities = const {},
  });

  CourtFilter copyWith({
    Object? country = _sentinel,
    Object? prefecture = _sentinel,
    Object? locType = _sentinel,
    Object? priceRange = _sentinel,
    Object? courtCount = _sentinel,
    Object? indoorOnly = _sentinel,
    Set<String>? amenities,
  }) {
    return CourtFilter(
      country:     country     == _sentinel ? this.country     : country as String?,
      prefecture:  prefecture  == _sentinel ? this.prefecture  : prefecture as String?,
      locType:     locType     == _sentinel ? this.locType     : locType as String?,
      priceRange:  priceRange  == _sentinel ? this.priceRange  : priceRange as String?,
      courtCount:  courtCount  == _sentinel ? this.courtCount  : courtCount as String?,
      indoorOnly:  indoorOnly  == _sentinel ? this.indoorOnly  : indoorOnly as bool?,
      amenities:   amenities   ?? this.amenities,
    );
  }

  // isEmpty = no filters beyond the Tokyo default
  bool get isEmpty =>
      (country == null || country == 'Japan') &&
          (prefecture == null || prefecture == '東京都') &&
          locType == null &&
          priceRange == null &&
          courtCount == null &&
          indoorOnly == null &&
          amenities.isEmpty;

  bool matchesLocation(Map<String, dynamic> loc) {
    if (country != null) {
      final c = (loc['loc_country'] ?? '').toString();
      if (c != country) return false;
    }
    if (prefecture != null) {
      final p = (loc['loc_prefecture'] ?? '').toString();
      if (p != prefecture) return false;
    }
    if (locType != null) {
      final t = (loc['loc_type'] ?? '').toString();
      if (t != locType) return false;
    }
    if (priceRange != null) {
      final price = (loc['loc_price'] ?? '').toString().toLowerCase();
      final isFree = loc['loc_price_free'] == true || price.contains('free');
      switch (priceRange) {
        case 'free':
          if (!isFree) return false;
          break;
        case '~1000':
          if (isFree) break;
          final num = _extractYen(price);
          if (num == null || num > 1000) return false;
          break;
        case '~3000':
          if (isFree) break;
          final num = _extractYen(price);
          if (num == null || num > 3000) return false;
          break;
        case '~5000':
          if (isFree) break;
          final num = _extractYen(price);
          if (num == null || num > 5000) return false;
          break;
      }
    }
    if (courtCount != null) {
      final count = _toDouble(loc['loc_court_count']);
      if (count == null) return false;
      switch (courtCount) {
        case '1-3':
          if (count < 1 || count > 3) return false;
          break;
        case '4-6':
          if (count < 4 || count > 6) return false;
          break;
        case '7+':
          if (count < 7) return false;
          break;
      }
    }
    if (indoorOnly == true) {
      if (loc['loc_court_type_indoor'] != true) return false;
    } else if (indoorOnly == false) {
      if (loc['loc_court_type_outdoor'] != true) return false;
    }
    for (final a in amenities) {
      if (loc['loc_amenities_$a'] != true) return false;
    }
    return true;
  }

  double? _extractYen(String price) {
    final match = RegExp(r'[¥¥](\d[\d,]*)').firstMatch(price);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}

const _sentinel = Object();

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
  // ✅ Default filter: Tokyo only. User can change via filter modal.
  CourtFilter _filter = const CourtFilter(prefecture: '東京都', country: 'Japan');
  List<Map<String, dynamic>> _lastLocations = [];
  Map<String, dynamic>? _selectedCourt; // court shown in bottom sheet

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
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _moveCameraToMarkers() {
    if (_mapController == null) return;

    // ✅ No markers yet — stay on default Tokyo position, don't zoom out
    if (_markers.isEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
            const LatLng(35.6762, 139.6503), 10),
      );
      return;
    }

    if (_markers.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_markers.first.position, 14),
      );
      return;
    }

    double? minLat, maxLat, minLng, maxLng;
    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = minLat == null ? lat : (lat < minLat ? lat : minLat);
      maxLat = maxLat == null ? lat : (lat > maxLat ? lat : maxLat);
      minLng = minLng == null ? lng : (lng < minLng ? lng : minLng);
      maxLng = maxLng == null ? lng : (lng > maxLng ? lng : maxLng);
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if (minLat == maxLat && minLng == maxLng) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 14),
        );
      } else {
        final bounds = LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        );
        _mapController!.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 80),
        );
      }
    }
  }

  void _updateMarkers(List<Map<String, dynamic>> filteredLocations) {
    final newMarkers = <Marker>{};
    for (int i = 0; i < filteredLocations.length; i++) {
      final loc = filteredLocations[i];
      final lat = _parseCoordinate(loc['loc_latitude']);
      final lng = _parseCoordinate(loc['loc_longitude']);
      if (lat != null && lng != null) {
        newMarkers.add(Marker(
          markerId: MarkerId(loc['_doc_id'] ?? 'court_$i'),
          position: LatLng(lat, lng),
          // ✅ No InfoWindow — we show a custom bottom sheet on tap
          onTap: () => _showCourtSheet(loc),
        ));
      }
    }
    setState(() => _markers = newMarkers);
    Future.delayed(const Duration(milliseconds: 800), _moveCameraToMarkers);
  }

  // ── Court detail bottom sheet ──────────────────────────────────────
  void _showCourtSheet(Map<String, dynamic> loc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CourtDetailSheet(loc: loc),
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
      ),
    );
    if (result != null && mounted) {
      setState(() => _filter = result);
      final filtered = _lastLocations.where((loc) {
        return _filter.matchesLocation(loc);
      }).toList();
      _updateMarkers(filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showAddButton = ref.watch(showAddCourtButtonProvider);
    final locationsAsync = ref.watch(locationsProvider);

    final allLocations = locationsAsync.asData?.value ?? [];

    if (locationsAsync.hasValue && allLocations.isNotEmpty) {
      final newIds = allLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      final oldIds = _lastLocations.map((l) => l['_doc_id']?.toString() ?? '').toSet();
      if (!newIds.containsAll(oldIds) || !oldIds.containsAll(newIds)) {
        _lastLocations = allLocations;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final filtered = _lastLocations.where((loc) {
            final search = _searchController.text.trim().toLowerCase();
            if (search.isNotEmpty) {
              final name = (loc['loc_name'] ?? '').toString().toLowerCase();
              final city = (loc['loc_city'] ?? '').toString().toLowerCase();
              final pref = (loc['loc_prefecture'] ?? '').toString().toLowerCase();
              if (!name.contains(search) && !city.contains(search) && !pref.contains(search)) return false;
            }
            return _filter.matchesLocation(loc);
          }).toList();
          _updateMarkers(filtered);
        });
      }
    }

    final filteredLocations = allLocations.where((loc) {
      final search = _searchController.text.trim().toLowerCase();
      if (search.isNotEmpty) {
        final name = (loc['loc_name'] ?? '').toString().toLowerCase();
        final city = (loc['loc_city'] ?? '').toString().toLowerCase();
        final pref = (loc['loc_prefecture'] ?? '').toString().toLowerCase();
        if (!name.contains(search) &&
            !city.contains(search) &&
            !pref.contains(search)) return false;
      }
      return _filter.matchesLocation(loc);
    }).toList();

    // Active filter = anything beyond the Tokyo default
    final _tokyoDefault = const CourtFilter(prefecture: '東京都', country: 'Japan');
    final hasActiveFilter = _filter.country != _tokyoDefault.country ||
        _filter.prefecture != _tokyoDefault.prefecture ||
        _filter.locType != null ||
        _filter.priceRange != null ||
        _filter.courtCount != null ||
        _filter.indoorOnly != null ||
        _filter.amenities.isNotEmpty;

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
                // ✅ Only move camera if markers are already loaded.
                // If not, the initialCameraPosition (Tokyo zoom 10) holds.
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    const SizedBox(height: 12),
                    Text('Loading map...',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(allLocations, hasActiveFilter),
              ],
            ),
          ),

          if (hasActiveFilter || _searchController.text.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 130,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Text(
                    '${filteredLocations.length} court${filteredLocations.length == 1 ? '' : 's'} found',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

          if (showAddButton)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(child: _buildAddCourtButton()),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(
      List<Map<String, dynamic>> allLocations, bool hasActiveFilter) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.location_on_rounded,
                            color: AppColors.primary, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Courts',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _openFilterModal(allLocations),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: hasActiveFilter
                            ? AppColors.primary
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: hasActiveFilter
                                ? AppColors.primary.withOpacity(0.4)
                                : Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: hasActiveFilter
                              ? Colors.white
                              : AppColors.primary,
                          size: 22),
                    ),
                    if (hasActiveFilter)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            color: Colors.orangeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
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
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) {
                setState(() {});
                final filtered = _lastLocations.where((loc) {
                  final search = _searchController.text.trim().toLowerCase();
                  if (search.isNotEmpty) {
                    final name = (loc['loc_name'] ?? '').toString().toLowerCase();
                    final city = (loc['loc_city'] ?? '').toString().toLowerCase();
                    final pref = (loc['loc_prefecture'] ?? '').toString().toLowerCase();
                    if (!name.contains(search) && !city.contains(search) && !pref.contains(search)) return false;
                  }
                  return _filter.matchesLocation(loc);
                }).toList();
                _updateMarkers(filtered);
              },
              style: const TextStyle(
                  fontSize: 15, color: Color(0xFF0D0D0D)),
              decoration: InputDecoration(
                hintText: 'Search pickleball courts...',
                hintStyle: TextStyle(
                  color: Colors.black.withOpacity(0.35),
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.black.withOpacity(0.35), size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? GestureDetector(
                  onTap: () =>
                      setState(() => _searchController.clear()),
                  child: Icon(Icons.close_rounded,
                      color: Colors.black.withOpacity(0.35),
                      size: 20),
                )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddCourtButton() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Add a Court',
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
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () =>
            ref.read(showAddCourtButtonProvider.notifier).state = false,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF0D0D0D), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
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


// ─────────────────────────────────────────────────────────────────────────────
// Court Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CourtDetailSheet extends StatelessWidget {
  final Map<String, dynamic> loc;
  const _CourtDetailSheet({required this.loc});

  String get _name => (loc['loc_name'] ?? 'Court').toString();
  String get _nameJp => (loc['loc_name_jp'] ?? '').toString();
  String get _address => (loc['loc_address'] ?? '').toString();
  String get _addressJp => (loc['loc_address_jp'] ?? '').toString();
  String get _city => (loc['loc_city'] ?? '').toString();
  String get _prefecture => (loc['loc_prefecture'] ?? '').toString();
  String get _country => (loc['loc_country'] ?? '').toString();
  String get _type => (loc['loc_type'] ?? '').toString();
  String get _price => (loc['loc_price'] ?? '').toString();
  String get _hours => (loc['loc_hours'] ?? '').toString();
  String get _phone => (loc['loc_contact_email'] ?? '').toString();
  String get _googleLink => (loc['loc_googlelink'] ?? '').toString();
  String get _image => (loc['loc_image'] ?? '').toString();
  int get _courtCount {
    final v = loc['loc_court_count'];
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  bool get _isIndoor => loc['loc_court_type_indoor'] == true;
  bool get _isOutdoor => loc['loc_court_type_outdoor'] == true;

  String get _locationLine {
    final parts = [_city, _prefecture, _country]
        .where((s) => s.isNotEmpty).toList();
    return parts.join(', ');
  }

  Future<void> _openLink(BuildContext context, String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
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
            color: Colors.black.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ───────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),

            // ── Hero image ────────────────────────────────────────────
            if (_image.isNotEmpty)
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  _image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 160,
                    color: AppColors.primary.withOpacity(0.08),
                    child: Icon(Icons.sports_tennis_rounded,
                        size: 48, color: AppColors.primary.withOpacity(0.3)),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: AppColors.primary.withOpacity(0.08),
                child: Icon(Icons.sports_tennis_rounded,
                    size: 48, color: AppColors.primary.withOpacity(0.3)),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Name + type badge ─────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_name,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0D0D0D),
                                    letterSpacing: -0.3)),
                            if (_nameJp.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(_nameJp,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.black.withOpacity(0.45))),
                            ],
                          ],
                        ),
                      ),
                      if (_type.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_type,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── Info rows ─────────────────────────────────────
                  if (_locationLine.isNotEmpty)
                    _infoRow(Icons.location_on_rounded, _locationLine),
                  if (_address.isNotEmpty)
                    _infoRow(Icons.home_rounded, _address),
                  if (_addressJp.isNotEmpty && _addressJp != _address)
                    _infoRow(Icons.home_outlined, _addressJp),
                  if (_price.isNotEmpty)
                    _infoRow(Icons.payments_outlined, _price),
                  if (_hours.isNotEmpty)
                    _infoRow(Icons.access_time_rounded, _hours),
                  if (_phone.isNotEmpty)
                    _infoRow(Icons.phone_outlined, _phone),

                  // ── Court setting chips ───────────────────────────
                  if (_isIndoor || _isOutdoor || _courtCount > 0) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8, runSpacing: 6,
                      children: [
                        if (_isIndoor)   _tag('Indoor',   Icons.roofing_rounded),
                        if (_isOutdoor)  _tag('Outdoor',  Icons.park_rounded),
                        if (_courtCount > 0)
                          _tag('$_courtCount court${_courtCount == 1 ? '' : 's'}',
                              Icons.grid_view_rounded),
                      ],
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── More Information button ───────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _googleLink.isNotEmpty
                          ? () => _openLink(context, _googleLink)
                          : null,
                      icon: const Icon(Icons.open_in_browser_rounded,
                          size: 18, color: Colors.white),
                      label: const Text('More Information',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _googleLink.isNotEmpty
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        shadowColor: AppColors.primary.withOpacity(0.3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.65),
                    height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter Modal
// ─────────────────────────────────────────────────────────────────────────────
class _CourtFilterModal extends StatefulWidget {
  final CourtFilter currentFilter;
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

  late final List<String> _countries;
  late final List<String> _locTypes;
  late final Map<String, List<String>> _prefecturesByCountry;

  static const _priceOptions = ['All', 'Free', '~¥1,000', '~¥3,000', '~¥5,000'];
  static const _priceValues  = [null,  'free', '~1000',   '~3000',   '~5000'];

  static const _countOptions = ['Any', '1–3', '4–6', '7+'];
  static const _countValues  = [null,  '1-3', '4-6', '7+'];

  static const _amenityOptions = [
    ('Open Play',   'openplay'),
    ('Reservation', 'reservation'),
    ('Membership',  'membership'),
    ('Lessons',     'lessons'),
    ('Dedicated',   'dedicated'),
  ];

  @override
  void initState() {
    super.initState();
    _draft = widget.currentFilter;

    final countries = <String>{};
    final types = <String>{};
    final prefMap = <String, Set<String>>{};

    for (final loc in widget.allLocations) {
      final c = (loc['loc_country']    ?? '').toString().trim();
      final t = (loc['loc_type']       ?? '').toString().trim();
      final p = (loc['loc_prefecture'] ?? '').toString().trim();
      if (c.isNotEmpty) {
        countries.add(c);
        if (p.isNotEmpty) prefMap.putIfAbsent(c, () => <String>{}).add(p);
      }
      if (t.isNotEmpty) types.add(t);
    }
    _countries = countries.toList()..sort();
    _locTypes  = types.toList()..sort();
    _prefecturesByCountry =
        prefMap.map((k, v) => MapEntry(k, v.toList()..sort()));
  }

  List<String> get _currentPrefectures =>
      _draft.country != null
          ? (_prefecturesByCountry[_draft.country] ?? [])
          : [];

  void _applyAndClose() => Navigator.of(context, rootNavigator: false).pop(_draft);
  // ✅ Reset goes back to Tokyo default, not truly empty
  void _resetAndClose() => Navigator.of(context, rootNavigator: false).pop(const CourtFilter(prefecture: '東京都', country: 'Japan'));

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.88),
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 40,
                  offset: const Offset(0, -8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.tune_rounded,
                              color: AppColors.primary, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text('Filter Courts',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0D0D0D),
                                letterSpacing: -0.5)),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(context, rootNavigator: false).pop(),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Divider(height: 20, thickness: 1,
                      color: Colors.black.withOpacity(0.06)),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(20, 4, 20,
                          MediaQuery.of(context).padding.bottom + 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Country', Icons.public_rounded),
                          const SizedBox(height: 10),
                          _buildDropdown(
                            value: _draft.country,
                            hint: 'All countries',
                            items: _countries,
                            onChanged: (v) => setState(
                                    () => _draft = _draft.copyWith(country: v, prefecture: null)),
                          ),
                          const SizedBox(height: 20),
                          if (_currentPrefectures.isNotEmpty) ...[
                            _sectionLabel('Prefecture / State', Icons.map_outlined),
                            const SizedBox(height: 10),
                            _buildDropdown(
                              value: _draft.prefecture,
                              hint: 'All prefectures',
                              items: _currentPrefectures,
                              onChanged: (v) => setState(
                                      () => _draft = _draft.copyWith(prefecture: v)),
                            ),
                            const SizedBox(height: 20),
                          ],
                          _sectionLabel('Court Type', Icons.sports_tennis_rounded),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: [
                              _chip('All', _draft.locType == null,
                                      () => setState(() => _draft = _draft.copyWith(locType: null))),
                              ..._locTypes.map((t) => _chip(t, _draft.locType == t,
                                      () => setState(() => _draft = _draft.copyWith(locType: t)))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Price per Hour', Icons.payments_outlined),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: List.generate(_priceOptions.length, (i) {
                              final val = _priceValues[i];
                              return _chip(_priceOptions[i], _draft.priceRange == val,
                                      () => setState(() => _draft = _draft.copyWith(priceRange: val)));
                            }),
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Number of Courts', Icons.grid_view_rounded),
                          const SizedBox(height: 10),
                          Row(
                            children: List.generate(_countOptions.length, (i) {
                              final val = _countValues[i];
                              final selected = _draft.courtCount == val;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(
                                          () => _draft = _draft.copyWith(courtCount: val)),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    margin: EdgeInsets.only(
                                        right: i < _countOptions.length - 1 ? 8 : 0),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? AppColors.primary
                                          : Colors.black.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected ? AppColors.primary : Colors.transparent,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(_countOptions[i],
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: selected
                                                ? Colors.white
                                                : Colors.black.withOpacity(0.55))),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Court Setting', Icons.wb_sunny_outlined),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _settingTile(label: 'All', icon: Icons.all_inclusive_rounded,
                                  selected: _draft.indoorOnly == null,
                                  onTap: () => setState(() => _draft = _draft.copyWith(indoorOnly: null))),
                              const SizedBox(width: 10),
                              _settingTile(label: 'Indoor', icon: Icons.roofing_rounded,
                                  selected: _draft.indoorOnly == true,
                                  onTap: () => setState(() => _draft = _draft.copyWith(indoorOnly: true))),
                              const SizedBox(width: 10),
                              _settingTile(label: 'Outdoor', icon: Icons.park_rounded,
                                  selected: _draft.indoorOnly == false,
                                  onTap: () => setState(() => _draft = _draft.copyWith(indoorOnly: false))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _sectionLabel('Amenities', Icons.star_outline_rounded),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _amenityOptions.map((a) {
                              final (label, key) = a;
                              final active = _draft.amenities.contains(key);
                              return GestureDetector(
                                onTap: () {
                                  final next = Set<String>.from(_draft.amenities);
                                  if (active) next.remove(key); else next.add(key);
                                  setState(() => _draft = _draft.copyWith(amenities: next));
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.primary.withOpacity(0.1)
                                        : Colors.black.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: active ? AppColors.primary : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (active) ...[
                                        Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(label,
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: active
                                                  ? AppColors.primary
                                                  : Colors.black.withOpacity(0.55))),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            children: [
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
                                      child: Text('Reset to Tokyo',
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
                                    child: const Center(
                                      child: Text('Apply Filters',
                                          style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.2)),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0D0D0D),
                letterSpacing: 0.2)),
      ],
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : Colors.black.withOpacity(0.55))),
      ),
    );
  }

  Widget _settingTile({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.black.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20,
                  color: selected ? Colors.white : Colors.black.withOpacity(0.4)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : Colors.black.withOpacity(0.5))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value != null ? AppColors.primary.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
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
                  style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.4))),
            ),
            ...items.map((item) => DropdownMenuItem<String>(
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