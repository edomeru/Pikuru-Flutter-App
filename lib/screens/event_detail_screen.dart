import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/screens/share_modal.dart';


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

  String _formatPrice(dynamic fee) {
    if (fee == null) return 'Free';
    final feeStr = fee.toString();
    if (feeStr.isEmpty || feeStr == '0') return 'Free';
    return '¥$feeStr';
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
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

  // ── Share Modal ───────────────────────────────────────────────────────
  void _showShareModal() {
    final title = widget.event['event_title'] ?? 'Check out this event!';
    final eventId = widget.event['event_id']?.toString() ?? '';
    final eventUrl = eventId.isNotEmpty
        ? 'https://pikuru.app/events/$eventId'
        : 'https://pikuru.app/events';

    ShareModal.show(
      context,
      eventTitle: title,
      eventUrl: eventUrl,
    );
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
                child: const Icon(Icons.arrow_back, color: Colors.white),
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
                  child: const Icon(Icons.share, color: Colors.white),
                ),
                // ✅ Now opens the share modal
                onPressed: _showShareModal,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.event['event_image'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.event,
                      size: 80, color: AppColors.primary),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
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
                        child: const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormatter.formatDateTime(date, time)
                                  .split(' ')
                                  .take(4)
                                  .join(' '),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${time.hour}:${time.minute.toString().padLeft(2, '0')} — 9:00 AM',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: locationAsync.when(
                    data: (locationName) =>
                        _buildLocationSection(locationName),
                    loading: () => _buildLocationSection('Loading...'),
                    error: (_, __) =>
                        _buildLocationSection('Unknown location'),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Details',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary)),
                      const SizedBox(height: 16),
                      Text(
                        widget.event['event_description'] ?? '',
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                const SizedBox(height: 24),
                _buildMapSection(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                const SizedBox(height: 24),
                _buildOrganizerSection(),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                const SizedBox(height: 24),
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
                            color: Colors.black),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('More Information',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
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

  Widget _buildLocationSection(String locationName) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('locations')
          .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
          .limit(1)
          .get()
          .then((snap) => snap.docs.first),
      builder: (context, snapshot) {
        final locationData =
        snapshot.data?.data() as Map<String, dynamic>?;
        final fullAddress = locationData?['loc_address'] ?? '';

        return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.location_on,
                  color: AppColors.primary, size: 28),
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
                        color: Colors.black),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fullAddress.isNotEmpty ? fullAddress : locationName,
                    style: const TextStyle(
                        fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () async {
                final snap = await FirebaseFirestore.instance
                    .collection('locations')
                    .where('loc_org_id',
                    isEqualTo: widget.event['event_loc_id'])
                    .limit(1)
                    .get();
                if (snap.docs.isNotEmpty) {
                  final data = snap.docs.first.data();
                  final lat = _parseCoordinate(data['loc_latitude']);
                  final lng = _parseCoordinate(data['loc_longitude']);
                  if (lat != null && lng != null) _openGoogleMaps(lat, lng);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_forward,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapSection() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('locations')
          .where('loc_org_id', isEqualTo: widget.event['event_loc_id'])
          .limit(1)
          .get()
          .then((snap) => snap.docs.first),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 200);
        final locationData =
        snapshot.data!.data() as Map<String, dynamic>;
        final lat = _parseCoordinate(locationData['loc_latitude']);
        final lng = _parseCoordinate(locationData['loc_longitude']);
        if (lat == null || lng == null) return const SizedBox(height: 200);
        final position = LatLng(lat, lng);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Map',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              const SizedBox(height: 8),
              Text(locationData['loc_name'] ?? '',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black)),
              const SizedBox(height: 4),
              Text(locationData['loc_address'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _openGoogleMaps(lat, lng),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 200,
                    child: AbsorbPointer(
                      child: GoogleMap(
                        initialCameraPosition:
                        CameraPosition(target: position, zoom: 15),
                        markers: {
                          Marker(
                              markerId: const MarkerId('event_location'),
                              position: position)
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                        onMapCreated: (c) => _mapController = c,
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

  Widget _buildOrganizerSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organized by',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
          const SizedBox(height: 16),
          Text(
            widget.event['event_organizer'] ??
                'Osaka Pickleball Association',
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black),
          ),
          const SizedBox(height: 8),
          FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('locations')
                .where('loc_org_id',
                isEqualTo: widget.event['event_loc_id'])
                .limit(1)
                .get()
                .then((snap) => snap.docs.first),
            builder: (context, snapshot) {
              final locationData =
              snapshot.data?.data() as Map<String, dynamic>?;
              return Text(locationData?['loc_address'] ?? '',
                  style: const TextStyle(
                      fontSize: 14, color: Colors.black87));
            },
          ),
        ],
      ),
    );
  }
}