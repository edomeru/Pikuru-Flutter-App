import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';

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
  bool _hasMovedCamera = false;

  // Default location (Tokyo, Japan) - will be updated when markers load
  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.6762, 139.6503),
    zoom: 12,
  );

  @override
  bool get wantKeepAlive => false;

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

  // Move camera to show all markers
  void _moveCameraToMarkers() {
    if (_mapController == null || _markers.isEmpty || _hasMovedCamera) return;

    // Calculate bounds that include all markers
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
      final bounds = LatLngBounds(
        southwest: LatLng(minLat, minLng),
        northeast: LatLng(maxLat, maxLng),
      );

      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 50), // 50 = padding
      );
      _hasMovedCamera = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final showAddButton = ref.watch(showAddCourtButtonProvider);
    final locationsAsync = ref.watch(locationsProvider);

    // Build markers from locations
    locationsAsync.whenData((locations) {
      final newMarkers = <Marker>{};

      print('🗺️ Loading ${locations.length} locations from Firestore...');

      for (int i = 0; i < locations.length; i++) {
        final location = locations[i];
        final lat = _parseCoordinate(location['loc_latitude']);
        final lng = _parseCoordinate(location['loc_longitude']);

        print('📍 Location $i:');
        print('   Name: ${location['loc_name']}');
        print('   City: ${location['loc_city']}');
        print('   Raw lat: ${location['loc_latitude']} (${location['loc_latitude'].runtimeType})');
        print('   Raw lng: ${location['loc_longitude']} (${location['loc_longitude'].runtimeType})');
        print('   Parsed lat: $lat');
        print('   Parsed lng: $lng');

        if (lat != null && lng != null) {
          newMarkers.add(
            Marker(
              markerId: MarkerId('court_$i'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: location['loc_name'] ?? 'Court',
                snippet: location['loc_city'] ?? '',
              ),
            ),
          );
          print('   ✅ Marker added!');
        } else {
          print('   ❌ Skipped - invalid coordinates');
        }
      }

      print('🎯 Total markers created: ${newMarkers.length}');

      if (newMarkers.isNotEmpty && newMarkers.length != _markers.length) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _markers = newMarkers;
            });
            // Move camera to show all markers
            Future.delayed(const Duration(milliseconds: 500), () {
              _moveCameraToMarkers();
            });
          }
        });
      }
    });

    return Scaffold(
      body: Stack(
        children: [
          // ── Google Map ───────────────────────────────────────
          GoogleMap(
            initialCameraPosition: _initialPosition,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
              print('🗺️ Map controller created');
            },
          ),

          // ── Search Bar ───────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: const InputDecoration(
                          hintText: 'Search Pickleball Courts...',
                          hintStyle: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.primary,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Floating Add Court Button ───────────────────────
          if (showAddButton)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: _buildAddCourtButton(),
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
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Add a Court',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: GestureDetector(
            onTap: () {
              ref.read(showAddCourtButtonProvider.notifier).state = false;
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: Colors.black,
              ),
            ),
          ),
        ),
      ],
    );
  }
}