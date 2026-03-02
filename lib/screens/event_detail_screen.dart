import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/screens/share_modal.dart';
import 'package:intl/intl.dart';

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

  // ✅ THE FIX: locId is a getter on the state class, accessible anywhere inside it
  String get locId => (widget.event['event_loc_id'] ?? '').toString();

  double? _parseCoordinate(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _formatDate(dynamic raw) {
    if (raw is Timestamp) {
      return DateFormat('EEE, MMM d, yyyy').format(raw.toDate());
    } else if (raw is String && raw.isNotEmpty) {
      try { return DateFormat('EEE, MMM d, yyyy').format(DateTime.parse(raw)); }
      catch (_) { return raw; }
    }
    return '';
  }

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) return DateFormat('h:mm a').format(raw.toDate());
    if (raw is String && raw.isNotEmpty) return raw;
    return '';
  }

  String _formatFee(dynamic fee) {
    if (fee == null) return 'Free';
    final s = fee.toString();
    if (s.isEmpty || s == '0' || s == '0.0') return 'Free';
    return '¥$s';
  }

  Future<void> _openGoogleMaps(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  Future<void> _openEventLink() async {
    final link = (widget.event['event_link'] ?? '').toString();
    if (link.isEmpty) return;
    final url = Uri.parse(link);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showShareModal() {
    final title = widget.event['event_title'] ?? 'Check out this event!';
    final eventId = widget.event['event_id']?.toString() ?? '';
    final eventUrl = eventId.isNotEmpty
        ? 'https://pikuru.app/events/$eventId'
        : 'https://pikuru.app/events';
    ShareModal.show(context, eventTitle: title, eventUrl: eventUrl);
  }

  // Tries loc_id field first (the field you just added), then fallbacks
  Future<Map<String, dynamic>?> _fetchLocation() async {
    if (locId.isEmpty) return null;
    try {
      // 1. loc_id field (lowercase — the new field you added to Firestore)
      final q1 = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_id', isEqualTo: locId)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) return q1.docs.first.data();

      // 2. loc_ID field (uppercase variant)
      final q2 = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_ID', isEqualTo: locId)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) return q2.docs.first.data();

      // 3. Direct Firestore document ID
      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locId)
          .get();
      if (doc.exists) return doc.data();

      // 4. Full scan fallback
      final all = await FirebaseFirestore.instance
          .collection('locations')
          .get();
      for (final d in all.docs) {
        final data = d.data();
        if (d.id == locId ||
            data['loc_ID']?.toString() == locId ||
            data['loc_id']?.toString() == locId) {
          return data;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOrganizer() async {
    final orgId = (widget.event['event_org_id'] ?? '').toString();
    if (orgId.isEmpty) return null;
    try {
      Map<String, dynamic>? raw;

      // 1. org_id field (lowercase — the field you just added)
      final q1 = await FirebaseFirestore.instance
          .collection('organizations')
          .where('org_id', isEqualTo: orgId)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) {
        raw = q1.docs.first.data();
      }

      // 2. org_ID field (uppercase variant)
      if (raw == null) {
        final q2 = await FirebaseFirestore.instance
            .collection('organizations')
            .where('org_ID', isEqualTo: orgId)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) raw = q2.docs.first.data();
      }

      // 3. Direct Firestore document ID fallback
      if (raw == null) {
        final doc = await FirebaseFirestore.instance
            .collection('organizations')
            .doc(orgId)
            .get();
        if (doc.exists) raw = doc.data();
      }

      if (raw == null) return null;
      return {
        'org_name': (raw['org_name'] ?? '').toString().trim(),
        'org_logo': (raw['org_logo'] ?? '').toString().trim(),
      };
    } catch (_) {}
    return null;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title     = (widget.event['event_title'] ?? 'Untitled Event').toString();
    final dateStr   = _formatDate(widget.event['event_date']);
    final timeStr   = _formatTime(widget.event['event_time']);
    final feeStr    = _formatFee(widget.event['event_fee']);
    final desc      = (widget.event['event_description'] ?? '').toString();
    final imageUrl  = (widget.event['event_pic'] ?? widget.event['event_pic_thumbnail'] ?? '').toString();
    final eventLink = (widget.event['event_link'] ?? '').toString();
    final hasLink   = eventLink.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [

          // ── Hero AppBar ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: _showShareModal,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Icon(Icons.event_rounded, size: 80,
                          color: AppColors.primary.withOpacity(0.3)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                  if ((widget.event['event_type'] ?? '').toString().isNotEmpty)
                    Positioned(
                      bottom: 16, left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          (widget.event['event_type'] ?? '').toString().toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.w700, letterSpacing: 0.8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Title Card ───────────────────────────────────────────────
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800,
                          color: Color(0xFF0D0D0D), height: 1.2, letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (dateStr.isNotEmpty)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.calendar_today_rounded,
                                  color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Text(
                                    dateStr,
                                    style: const TextStyle(
                                      fontSize: 17, fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D0D0D),
                                    ),
                                  ),
                                  if (timeStr.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 15, color: Colors.black54,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                      const SizedBox(height: 20),
                      _buildAllTags(),
                    ],
                  ),
                ),

                // ── Location + Map Card ──────────────────────────────────────
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchLocation(),
                  builder: (context, snap) {
                    final loc        = snap.data;
                    final locName    = (loc?['loc_name'] ?? '').toString();
                    final locAddress = (loc?['loc_address'] ?? '').toString();
                    final lat        = _parseCoordinate(loc?['loc_latitude']);
                    final lng        = _parseCoordinate(loc?['loc_longitude']);
                    final isLoading  = snap.connectionState == ConnectionState.waiting;

                    return _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Location'),
                          const SizedBox(height: 16),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.location_on_rounded,
                                    color: AppColors.primary, size: 26),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    if (locName.isNotEmpty)
                                      Text(locName,
                                        style: const TextStyle(fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF0D0D0D)),
                                      ),
                                    if (locAddress.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(locAddress,
                                        style: const TextStyle(
                                            fontSize: 14, color: Colors.black54),
                                      ),
                                    ],
                                    // ✅ locId getter is now accessible here
                                    if (locName.isEmpty && locAddress.isEmpty)
                                      Text(
                                        isLoading
                                            ? 'Loading...'
                                            : locId.isNotEmpty
                                            ? 'No location found (ID: $locId)'
                                            : 'No location set',
                                        style: const TextStyle(
                                            fontSize: 15, color: Colors.black45),
                                      ),
                                  ],
                                ),
                              ),
                              if (lat != null && lng != null) ...[
                                const SizedBox(width: 12),
                                GestureDetector(
                                  onTap: () => _openGoogleMaps(lat, lng),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.arrow_forward,
                                        color: Colors.white, size: 22),
                                  ),
                                ),
                              ],
                            ],
                          ),

                          if (lat != null && lng != null) ...[
                            const SizedBox(height: 20),
                            _sectionLabel('Map'),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () => _openGoogleMaps(lat, lng),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  height: 200,
                                  child: AbsorbPointer(
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: LatLng(lat, lng),
                                        zoom: 15,
                                      ),
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('event_loc'),
                                          position: LatLng(lat, lng),
                                        ),
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
                        ],
                      ),
                    );
                  },
                ),

                // ── Description Card ─────────────────────────────────────────
                if (desc.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('About this Event'),
                        const SizedBox(height: 12),
                        Text(
                          desc,
                          style: const TextStyle(
                            fontSize: 15, color: Color(0xFF444444), height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Organizer Card ───────────────────────────────────────────
                FutureBuilder<Map<String, dynamic>?>(
                  future: _fetchOrganizer(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    final org = snap.data;
                    if (org == null) return const SizedBox.shrink();
                    final orgName = (org['org_name'] ?? '').toString();
                    final orgLogo = (org['org_logo'] ?? '').toString();
                    if (orgName.isEmpty) return const SizedBox.shrink();

                    return _card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Organized by'),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Logo
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: orgLogo.isNotEmpty
                                    ? Image.network(
                                  orgLogo,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _orgPlaceholder(),
                                )
                                    : _orgPlaceholder(),
                              ),
                              const SizedBox(width: 14),
                              // Name only — no address
                              Expanded(
                                child: Text(
                                  orgName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0D0D0D),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Fee + CTA ────────────────────────────────────────────────
                _card(
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entry Fee',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.black.withOpacity(0.4), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(feeStr,
                            style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w800,
                              color: feeStr == 'Free'
                                  ? Colors.green.shade600
                                  : const Color(0xFF0D0D0D),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: hasLink ? _openEventLink : null,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: hasLink ? AppColors.primary : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: hasLink
                                  ? [BoxShadow(color: AppColors.primary.withOpacity(0.3),
                                  blurRadius: 12, offset: const Offset(0, 4))]
                                  : [],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    color: hasLink ? Colors.white : Colors.grey, size: 17),
                                const SizedBox(width: 8),
                                Text('More Information',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                      color: hasLink ? Colors.white : Colors.grey),
                                ),
                              ],
                            ),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
      child: child,
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
          color: AppColors.primary),
    );
  }

  Widget _orgPlaceholder() {
    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.groups_rounded, color: AppColors.primary, size: 28),
    );
  }

  Widget _buildAllTags() {
    final tags = <String>[];

    if (widget.event['event_skill_level_pro'] == true)      tags.add('PRO');
    if (widget.event['event_skill_level_amateur'] == true)  tags.add('AMATEUR');
    if (widget.event['event_skill_level_beginner'] == true) tags.add('BEGINNER');

    if (widget.event['event_category_menssingle'] == true)    tags.add("MEN'S SINGLES");
    if (widget.event['event_category_womenssingle'] == true)  tags.add("WOMEN'S SINGLES");
    if (widget.event['event_category_mixeddoubles'] == true)  tags.add('MIXED DOUBLES');
    if (widget.event['event_category_mensdoubles'] == true)   tags.add("MEN'S DOUBLES");
    if (widget.event['event_category_womensdoubles'] == true) tags.add("WOMEN'S DOUBLES");
    if (widget.event['event_category_juniors'] == true)       tags.add('JUNIORS');
    if (widget.event['event_category_collegiate'] == true)    tags.add('COLLEGIATE');
    if (widget.event['event_category_seniors'] == true)       tags.add('SENIORS');

    if (tags.isEmpty) {
      final old = (widget.event['event_skill_level'] ?? '').toString();
      if (old.isNotEmpty) tags.add(old.toUpperCase());
    }

    if (tags.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 7, runSpacing: 7,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.09),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(tag,
          style: TextStyle(color: AppColors.primary, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.4),
        ),
      )).toList(),
    );
  }
}