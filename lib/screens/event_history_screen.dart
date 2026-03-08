import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:intl/intl.dart';

class EventHistoryScreen extends StatefulWidget {
  const EventHistoryScreen({super.key});

  @override
  State<EventHistoryScreen> createState() => _EventHistoryScreenState();
}

class _EventHistoryScreenState extends State<EventHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
            title: const Text(
              'Events History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  tabs: const [
                    Tab(text: 'My Events'),
                    Tab(text: 'Interested Events'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: const [
            _EventList(status: 'my_events'),
            _EventList(status: 'interested'),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Event List — streams user_events filtered by status,
// then fetches full event details from `events` collection
// ═══════════════════════════════════════════════════════════════════
class _EventList extends StatelessWidget {
  final String status; // 'my_events' | 'interested'
  const _EventList({required this.status});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Not signed in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_events')
          .where('user_id', isEqualTo: uid)
          .where('status', isEqualTo: status)
          .orderBy('saved_at', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2,
            ),
          );
        }

        if (snap.hasError) {
          return _EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Something went wrong',
            subtitle: snap.error.toString(),
          );
        }

        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return _EmptyState(
            icon: status == 'my_events'
                ? Icons.bookmark_outline_rounded
                : Icons.star_outline_rounded,
            title: status == 'my_events'
                ? 'No saved events yet'
                : 'No interested events yet',
            subtitle: status == 'my_events'
                ? 'Events you plan to join will appear here'
                : 'Events you want to keep an eye on will appear here',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _EventCard(
              userEventDoc: docs[i],
              savedData: data,
              otherStatus: status == 'my_events' ? 'interested' : 'my_events',
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Event Card — fetches full event data then renders
// ═══════════════════════════════════════════════════════════════════
class _EventCard extends StatelessWidget {
  final QueryDocumentSnapshot userEventDoc;
  final Map<String, dynamic> savedData;
  final String otherStatus;

  const _EventCard({
    required this.userEventDoc,
    required this.savedData,
    required this.otherStatus,
  });

  Future<Map<String, dynamic>?> _fetchEvent() async {
    final eventId = (savedData['event_id'] ?? '').toString();
    if (eventId.isEmpty) return null;
    try {
      // Try by doc ID first
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        d['_doc_id'] = doc.id;
        return d;
      }
      // Fallback: query by event_id field
      final q = await FirebaseFirestore.instance
          .collection('events')
          .where('event_id', isEqualTo: eventId)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final d = q.docs.first.data();
        d['_doc_id'] = q.docs.first.id;
        return d;
      }
    } catch (_) {}
    return null;
  }

  String _formatDate(dynamic raw) {
    if (raw is Timestamp) {
      return DateFormat('MMM d, yyyy').format(raw.toDate());
    } else if (raw is String && raw.isNotEmpty) {
      try {
        return DateFormat('MMM d, yyyy').format(DateTime.parse(raw));
      } catch (_) {
        return raw;
      }
    }
    return '';
  }

  String _formatTime(dynamic raw) {
    if (raw is Timestamp) return DateFormat('h:mm a').format(raw.toDate());
    if (raw is String && raw.isNotEmpty) return raw;
    return '';
  }

  Future<void> _switchStatus(BuildContext context) async {
    HapticFeedback.lightImpact();
    final newStatus = otherStatus;
    final label = newStatus == 'my_events' ? 'My Events' : 'Interested';
    try {
      await userEventDoc.reference.update({'status': newStatus});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Moved to $label'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _removeEvent(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: const Text('Remove Event?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        content: const Text(
          'This event will be removed from your saved list.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actionsPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: const Text('Cancel',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Remove',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await userEventDoc.reference.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchEvent(),
      builder: (context, snap) {
        // Use cached data from user_events while loading full event
        final title = (snap.data?['event_title'] ??
            savedData['event_title'] ??
            'Loading...')
            .toString();
        final imageUrl =
        (snap.data?['event_pic'] ?? savedData['event_pic'] ?? '')
            .toString();
        final dateStr = snap.data != null
            ? _formatDate(snap.data!['event_date'])
            : '';
        final timeStr = snap.data != null
            ? _formatTime(snap.data!['event_time'])
            : '';
        final locCity = snap.data != null
            ? (snap.data!['_loc_city'] ?? '').toString()
            : '';

        final switchLabel = otherStatus == 'my_events'
            ? 'Mark as My Event'
            : 'Mark as Interested';
        final switchIcon = otherStatus == 'my_events'
            ? Icons.bookmark_rounded
            : Icons.star_rounded;
        final switchColor = otherStatus == 'my_events'
            ? AppColors.primary
            : const Color(0xFFE6A817);

        return GestureDetector(
          onTap: snap.data != null
              ? () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EventDetailScreen(event: snap.data!),
            ),
          )
              : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.10)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Main row ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                          imageUrl,
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _placeholder(),
                        )
                            : _placeholder(),
                      ),
                      const SizedBox(width: 14),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0D0D0D),
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (dateStr.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 12,
                                      color: AppColors.primary
                                          .withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr.isNotEmpty
                                        ? '$dateStr · $timeStr'
                                        : dateStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                      Colors.black.withOpacity(0.5),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (locCity.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 12,
                                      color: AppColors.primary
                                          .withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    locCity,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                      Colors.black.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Chevron
                      Icon(Icons.chevron_right_rounded,
                          color:
                          AppColors.primary.withOpacity(0.3),
                          size: 20),
                    ],
                  ),
                ),

                // ── Action row ────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9F7),
                    borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      // Switch status button
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _switchStatus(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 11, horizontal: 14),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(switchIcon,
                                    color: switchColor, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  switchLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: switchColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Divider
                      Container(
                          width: 1,
                          height: 20,
                          color: AppColors.primary.withOpacity(0.12)),

                      // Delete button
                      GestureDetector(
                        onTap: () => _removeEvent(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 11, horizontal: 16),
                          child: Icon(Icons.delete_outline_rounded,
                              color: Colors.red.shade400, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.event_rounded,
          color: AppColors.primary.withOpacity(0.3), size: 32),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Empty State
// ═══════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  color: AppColors.primary.withOpacity(0.4), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D0D0D),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black.withOpacity(0.4),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}