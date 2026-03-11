import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/modal/share_event_modal.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Event save status
// ─────────────────────────────────────────────────────────────────────────────
enum _SaveStatus { none, myEvents, interested }

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

  // Save state
  _SaveStatus _saveStatus = _SaveStatus.none;
  bool _saveLoading = true;

  String get locId => (widget.event['event_loc_id'] ?? '').toString();
  String get eventId => (widget.event['event_id'] ?? widget.event['_doc_id'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _loadSaveStatus();
  }

  // ── Firestore save helpers ────────────────────────────────────────────────

  Future<void> _loadSaveStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) {
      setState(() => _saveLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_events')
          .doc('${uid}_$eventId')
          .get();
      if (doc.exists) {
        final status = (doc.data()?['status'] ?? '').toString();
        setState(() {
          _saveStatus = status == 'my_events'
              ? _SaveStatus.myEvents
              : status == 'interested'
              ? _SaveStatus.interested
              : _SaveStatus.none;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _saveLoading = false);
  }

  Future<void> _setSaveStatus(_SaveStatus newStatus) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || eventId.isEmpty) return;
    HapticFeedback.lightImpact();

    setState(() => _saveStatus = newStatus);

    final docRef = FirebaseFirestore.instance
        .collection('user_events')
        .doc('${uid}_$eventId');

    if (newStatus == _SaveStatus.none) {
      await docRef.delete();
    } else {
      await docRef.set({
        'user_id': uid,
        'event_id': eventId,
        'status': newStatus == _SaveStatus.myEvents ? 'my_events' : 'interested',
        'event_title': widget.event['event_title'] ?? '',
        'event_pic': widget.event['event_pic'] ?? '',
        'saved_at': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Shows the bottom sheet for saving ────────────────────────────────────

  void _showSaveSheet() {
    final eventLink = (widget.event['event_link'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SaveBottomSheet(
        currentStatus: _saveStatus,
        eventLink: eventLink,
        onSelect: (status) async {
          Navigator.pop(context);
          await _setSaveStatus(status);
          // Always open event link after saving (My Events or Interested)
          if (eventLink.isNotEmpty) {
            await Future.delayed(const Duration(milliseconds: 200));
            _openEventLink(eventLink);
          }
        },
        onRemove: () async {
          Navigator.pop(context);
          await _setSaveStatus(_SaveStatus.none);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Utilities
  // ─────────────────────────────────────────────────────────────────────────

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

  Future<void> _openEventLink(String link) async {
    if (link.isEmpty) return;
    try {
      // Ensure URL has a scheme
      final raw = link.startsWith('http') ? link : 'https://$link';
      final url = Uri.parse(raw);
      // Use externalApplication to open in the device browser directly.
      // Skip canLaunchUrl — it silently fails on Android without intent queries.
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        // Fallback: platform default (in-app browser / system chooser)
        await launchUrl(Uri.parse(link), mode: LaunchMode.platformDefault);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $link')),
          );
        }
      }
    }
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

  void _showShareModal() {
    ShareEventModal.show(context, event: widget.event);
  }

  Future<Map<String, dynamic>?> _fetchLocation() async {
    if (locId.isEmpty) return null;
    try {
      final q1 = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_id', isEqualTo: locId)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) return q1.docs.first.data();

      final q2 = await FirebaseFirestore.instance
          .collection('locations')
          .where('loc_ID', isEqualTo: locId)
          .limit(1)
          .get();
      if (q2.docs.isNotEmpty) return q2.docs.first.data();

      final doc = await FirebaseFirestore.instance
          .collection('locations')
          .doc(locId)
          .get();
      if (doc.exists) return doc.data();

      final all = await FirebaseFirestore.instance.collection('locations').get();
      for (final d in all.docs) {
        final data = d.data();
        if (d.id == locId ||
            data['loc_ID']?.toString() == locId ||
            data['loc_id']?.toString() == locId) return data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> _fetchOrganizer() async {
    final orgId = (widget.event['event_org_id'] ?? '').toString();
    if (orgId.isEmpty) return null;
    try {
      Map<String, dynamic>? raw;
      final q1 = await FirebaseFirestore.instance
          .collection('organizations')
          .where('org_id', isEqualTo: orgId)
          .limit(1)
          .get();
      if (q1.docs.isNotEmpty) { raw = q1.docs.first.data(); }

      if (raw == null) {
        final q2 = await FirebaseFirestore.instance
            .collection('organizations')
            .where('org_ID', isEqualTo: orgId)
            .limit(1)
            .get();
        if (q2.docs.isNotEmpty) raw = q2.docs.first.data();
      }
      if (raw == null) {
        final doc = await FirebaseFirestore.instance
            .collection('organizations').doc(orgId).get();
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

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title    = (widget.event['event_title'] ?? 'Untitled Event').toString();
    final dateStr  = _formatDate(widget.event['event_date']);
    final timeStr  = _formatTime(widget.event['event_time']);
    final feeStr   = _formatFee(widget.event['event_fee']);
    final desc     = (widget.event['event_description'] ?? '').toString();
    final imageUrl = (widget.event['event_pic'] ?? widget.event['event_pic_thumbnail'] ?? '').toString();
    final eventLink = (widget.event['event_link'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        slivers: [

          // ── Hero AppBar ──────────────────────────────────────────────────
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

                // ── Title Card ─────────────────────────────────────────────
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
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
                                  Text(dateStr,
                                    style: const TextStyle(fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D0D0D)),
                                  ),
                                  if (timeStr.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(timeStr,
                                      style: const TextStyle(fontSize: 15,
                                          color: Colors.black54,
                                          fontWeight: FontWeight.w500),
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

                // ── Location + Map Card ────────────────────────────────────
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
                                    if (locName.isEmpty && locAddress.isEmpty)
                                      Text(
                                        isLoading ? 'Loading...'
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

                // ── Description Card ───────────────────────────────────────
                if (desc.isNotEmpty)
                  _card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionLabel('About this Event'),
                        const SizedBox(height: 12),
                        Text(desc,
                          style: const TextStyle(
                            fontSize: 15, color: Color(0xFF444444), height: 1.7,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Organizer Card ─────────────────────────────────────────
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: orgLogo.isNotEmpty
                                    ? Image.network(orgLogo, width: 52, height: 52,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _orgPlaceholder())
                                    : _orgPlaceholder(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(orgName,
                                  style: const TextStyle(fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0D0D0D)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // ── Fee + CTA Card ─────────────────────────────────────────
                _card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fee row
                      Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Entry Fee',
                                style: TextStyle(fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black.withOpacity(0.4),
                                    letterSpacing: 0.5),
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
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Save / Status Widget ─────────────────────────────
                      _saveLoading
                          ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                          : _buildSaveWidget(eventLink),
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

  // ── Save Widget — shows different UI based on current status ──────────────
  Widget _buildSaveWidget(String eventLink) {
    switch (_saveStatus) {
      case _SaveStatus.none:
        return _SaveNoneWidget(
          hasLink: eventLink.isNotEmpty,
          onTap: _showSaveSheet,
        );

      case _SaveStatus.myEvents:
        return _SavedWidget(
          label: 'Saved to My Events',
          icon: Icons.bookmark_rounded,
          color: AppColors.primary,
          onTap: _showSaveSheet,
        );

      case _SaveStatus.interested:
        return _SavedWidget(
          label: 'Marked as Interested',
          icon: Icons.star_rounded,
          color: const Color(0xFFE6A817),
          onTap: _showSaveSheet,
        );
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
    return Text(text,
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

// ═════════════════════════════════════════════════════════════════════════════
// Save None Widget — shown when not yet saved
// ═════════════════════════════════════════════════════════════════════════════
class _SaveNoneWidget extends StatelessWidget {
  final bool hasLink;
  final VoidCallback onTap;

  const _SaveNoneWidget({required this.hasLink, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
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
            Icon(Icons.bookmark_add_outlined,
                color: hasLink ? Colors.white : Colors.grey, size: 19),
            const SizedBox(width: 8),
            Text('Save & More Information',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: hasLink ? Colors.white : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Saved Widget — shown when already saved (either status)
// ═════════════════════════════════════════════════════════════════════════════
class _SavedWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SavedWidget({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: color),
            ),
            const SizedBox(width: 8),
            Icon(Icons.edit_rounded, color: color.withOpacity(0.55), size: 15),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Save Bottom Sheet
// ═════════════════════════════════════════════════════════════════════════════
class _SaveBottomSheet extends StatelessWidget {
  final _SaveStatus currentStatus;
  final String eventLink;
  final void Function(_SaveStatus) onSelect;
  final VoidCallback onRemove;

  const _SaveBottomSheet({
    required this.currentStatus,
    required this.eventLink,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isAlreadySaved = currentStatus != _SaveStatus.none;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            isAlreadySaved ? 'Update Event Status' : 'Save this Event',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                color: Color(0xFF0D0D0D), letterSpacing: -0.4),
          ),
          const SizedBox(height: 6),
          Text(
            isAlreadySaved
                ? 'Change how this event is saved, or remove it.'
                : "Choose a category — you'll be taken to the event page right after.",
            style: TextStyle(fontSize: 14, color: Colors.black.withOpacity(0.45)),
          ),
          const SizedBox(height: 24),

          // ── My Events option ────────────────────────────────────────────
          _OptionTile(
            icon: Icons.bookmark_rounded,
            iconColor: AppColors.primary,
            title: "My Events",
            subtitle: "Events you're planning to join",
            isSelected: currentStatus == _SaveStatus.myEvents,
            onTap: () => onSelect(_SaveStatus.myEvents),
          ),
          const SizedBox(height: 10),

          // ── Interested option ────────────────────────────────────────────
          _OptionTile(
            icon: Icons.star_rounded,
            iconColor: const Color(0xFFE6A817),
            title: "Interested",
            subtitle: "Events you'd like to keep an eye on",
            isSelected: currentStatus == _SaveStatus.interested,
            onTap: () => onSelect(_SaveStatus.interested),
          ),



          // ── Remove ──────────────────────────────────────────────────────
          if (isAlreadySaved) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: onRemove,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.delete_outline_rounded,
                        color: Colors.red, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text('Remove from saved events',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                        color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Option Tile ───────────────────────────────────────────────────────────────
class _OptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool muted;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? iconColor.withOpacity(0.07)
              : muted
              ? const Color(0xFFF7F7F9)
              : const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? iconColor.withOpacity(0.45)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(isSelected ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: muted
                          ? Colors.black54
                          : const Color(0xFF0D0D0D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                    style: TextStyle(fontSize: 12.5,
                        color: Colors.black.withOpacity(0.4)),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: iconColor, size: 22)
            else
              Icon(Icons.chevron_right_rounded,
                  color: Colors.black.withOpacity(0.18), size: 22),
          ],
        ),
      ),
    );
  }
}