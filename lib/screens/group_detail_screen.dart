import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/modal/join_group_modal.dart';
import 'package:pikuru/modal/mark_interested_modal.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  bool? _isJoined; // null = loading, true/false = resolved

  @override
  void initState() {
    super.initState();
    _checkJoinStatus();
  }

  // ── Check join status once on load ────────────────────────────────────
  Future<void> _checkJoinStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isJoined = false);
      return;
    }
    // ✅ Uses the same _resolveGroupId logic as JoinGroupModal
    final joined =
    await JoinGroupModal.isAlreadyJoined(user.uid, widget.group);
    if (mounted) setState(() => _isJoined = joined);
  }

  @override
  Widget build(BuildContext context) {
    final orgLocId = (widget.group['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));

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
                onPressed: () {},
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(
                widget.group['org_image'] ?? '',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primary.withOpacity(0.1),
                  child: const Icon(Icons.group,
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

                // ── Group Title ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.group['org_name'] ?? 'Unnamed Group',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Description ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    widget.group['org_description'] ??
                        'Join our friendly pickleball group!',
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.black87,
                      height: 1.6,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Info Grid ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              Icons.location_on,
                              locationAsync.when(
                                data: (l) => l,
                                loading: () => 'Loading...',
                                error: (_, __) => 'Unknown',
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              Icons.people,
                              widget.group['org_age_groups'] ??
                                  'Teens, 20s to 30s',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoItem(
                              Icons.calendar_month,
                              widget.group['org_schedule'] ??
                                  'Weekends | Weekday Nights',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildInfoItem(
                              Icons.sports,
                              widget.group['org_skill_level'] ??
                                  'Beginner | Intermediate',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Join & Interested Buttons ────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isJoined == true
                                  ? null // disabled if already joined
                                  : () async {
                                await JoinGroupModal.show(
                                    context, widget.group);
                                // Re-check status after modal closes
                                _checkJoinStatus();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isJoined == true
                                    ? Colors.grey.shade300
                                    : AppColors.primary,
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isJoined == true ? 'Joined ✓' : 'Join',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isJoined == true
                                      ? Colors.grey.shade600
                                      : Colors.white,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  MarkInterestedModal.show(context, widget.group),
                              style: OutlinedButton.styleFrom(
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                side: const BorderSide(
                                    color: AppColors.primary, width: 2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Interested',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // ── Already joined banner ────────────────
                      if (_isJoined == true) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 10),
                              Text(
                                'You have already joined this group',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Upcoming Events ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Upcoming Events',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildUpcomingEventsList(),
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

  Widget _buildInfoItem(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 14, color: Colors.black87, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .orderBy('event_start_date')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()));
        }

        final events = snapshot.data!.docs;

        if (events.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No upcoming events yet',
                  style: TextStyle(fontSize: 14, color: Colors.black54)),
            ),
          );
        }

        return Column(
          children: events.take(3).map((doc) {
            final event = doc.data() as Map<String, dynamic>;
            return _buildEventItem(event);
          }).toList(),
        );
      },
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final Timestamp startDate = event['event_start_date'];
    final Timestamp startTime = event['event_start_time'];
    final date = startDate.toDate();
    final time = startTime.toDate();
    final eventLocId = (event['event_loc_id'] ?? '').toString();

    final eventWithGroup = {
      ...event,
      'group_id': widget.group['_doc_id'] ??
          widget.group['org_id'] ??
          widget.group['group_id'] ??
          '',
      'group_image':
      widget.group['group_image'] ?? widget.group['org_image'] ?? '',
      'group_name':
      widget.group['group_name'] ?? widget.group['org_name'] ?? '',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              event['event_image'] ?? '',
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 60,
                height: 60,
                color: AppColors.primary.withOpacity(0.1),
                child: const Icon(Icons.event, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['event_title'] ?? 'Untitled Event',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormatter.month(date.month)} ${date.day}, ${date.year} | ${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                  style:
                  const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final locationAsync = ref.watch(
                              locationResolverProvider(eventLocId));
                          return locationAsync.when(
                            data: (location) => Text(location,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.black54),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            loading: () => const Text('...'),
                            error: (_, __) =>
                            const Text('Unknown location'),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          MarkInterestedModal.show(context, eventWithGroup),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('JOIN',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.arrow_forward_ios, color: Colors.black54, size: 18),
        ],
      ),
    );
  }
}