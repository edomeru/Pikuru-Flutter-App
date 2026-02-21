import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> event;

  const EventDetailScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  GoogleMapController? _mapController;

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // ── Format Price ─────────────────────────────────────────────────────
  String _formatPrice(dynamic fee) {
    if (fee == null) return 'Free';
    final feeStr = fee.toString();
    if (feeStr.isEmpty || feeStr == '0') return 'Free';
    return '¥$feeStr';
  }

  // ── Open Google Maps ─────────────────────────────────────────────────
  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open Google Maps')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Timestamp startDate = widget.event['event_start_date'];
    final Timestamp startTime = widget.event['event_start_time'];
    final DateTime date = startDate.toDate();
    final DateTime time = startTime.toDate();

    final eventLocId = (widget.event['event_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(eventLocId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Image ───────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.share,
                    color: Colors.white,
                  ),
                ),
                onPressed: () {
                  // Share functionality
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.event['event_image'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.event,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // ── Event Title ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.event['event_title'] ?? 'Untitled Event',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Date & Time ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.calendar_today,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormatter.formatDateTime(date, time).split(' ').take(4).join(' '), // Just the date part
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${time.hour}:${time.minute.toString().padLeft(2, '0')} — 9:00 AM', // Time range
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Location with Arrow ──────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: locationAsync.when(
                    data: (locationName) => _buildLocationSection(locationName),
                    loading: () => _buildLocationSection('Loading...'),
                    error: (_, __) => _buildLocationSection('Unknown location'),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Divider ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Details Section ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.event['event_description'] ??
                            'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.\n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Divider ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Map Section ──────────────────────────────────
                _buildMapSection(),

                const SizedBox(height: 32),

                // ── Divider ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Organized By Section ─────────────────────────
                _buildOrganizerSection(),

                const SizedBox(height: 32),

                // ── Divider ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Price + More Info Button ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatPrice(widget.event['event_fee']),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // More information action
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'More Information',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Location Section with Arrow ──────────────────────────────────────
  Widget _buildLocationSection(String locationName) {
    // Get full location details from Firestore
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('locations')
          .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
          .limit(1)
          .get()
          .then((snap) => snap.docs.first),
      builder: (context, snapshot) {
        final locationData = snapshot.data?.data() as Map<String, dynamic>?;
        final fullAddress = locationData?['loc_address'] ?? '';

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationData?['loc_name'] ?? locationName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fullAddress.isNotEmpty ? fullAddress : locationName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                // Get coordinates and open Google Maps
                final snapshot = await FirebaseFirestore.instance
                    .collection('locations')
                    .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
                    .limit(1)
                    .get();

                if (snapshot.docs.isNotEmpty) {
                  final data = snapshot.docs.first.data();
                  final lat = _parseCoordinate(data['loc_latitude']);
                  final lng = _parseCoordinate(data['loc_longitude']);

                  if (lat != null && lng != null) {
                    _openGoogleMaps(lat, lng);
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Map Section ──────────────────────────────────────────────────────
  Widget _buildMapSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('locations')
          .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
          .limit(1)
          .get()
          .then((snap) => snap.docs.first),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 200);
        }

        final locationData = snapshot.data!.data() as Map<String, dynamic>;
        final lat = _parseCoordinate(locationData['loc_latitude']);
        final lng = _parseCoordinate(locationData['loc_longitude']);

        if (lat == null || lng == null) {
          return const SizedBox(height: 200);
        }

        final position = LatLng(lat, lng);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Map',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                locationData['loc_name'] ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                locationData['loc_address'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openGoogleMaps(lat, lng),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    child: AbsorbPointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: position,
                          zoom: 15,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('event_location'),
                            position: position,
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                        },
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

  // ── Organizer Section ────────────────────────────────────────────────
  Widget _buildOrganizerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Organized by',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.event['event_organizer'] ?? 'Osaka Pickleball Association',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('locations')
                .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
                .limit(1)
                .get()
                .then((snap) => snap.docs.first),
            builder: (context, snapshot) {
              final locationData =
              snapshot.data?.data() as Map<String, dynamic>?;
              return Text(
                locationData?['loc_address'] ?? '',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}