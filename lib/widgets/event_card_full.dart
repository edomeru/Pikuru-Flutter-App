import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class EventCardFull extends ConsumerWidget {
  final Map<String, dynamic> event;

  const EventCardFull({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Date ─────────────────────────────────────────────────────────────────
    final rawDate = event['event_date'];
    String dateStr = '';
    if (rawDate is Timestamp) {
      final dt = rawDate.toDate();
      dateStr = DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
    } else if (rawDate is String && rawDate.isNotEmpty) {
      try {
        final dt = DateTime.parse(rawDate);
        dateStr = DateFormat('EEE, MMM d, yyyy').format(dt).toUpperCase();
      } catch (_) {
        dateStr = rawDate.toUpperCase();
      }
    }

    // ── Time ─────────────────────────────────────────────────────────────────
    final rawTime = event['event_time'];
    String timeStr = '';
    if (rawTime is Timestamp) {
      timeStr = DateFormat('h:mm a').format(rawTime.toDate());
    } else if (rawTime is String && rawTime.isNotEmpty) {
      timeStr = rawTime;
    }

    final tags = _buildTagStrings();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ───────────────────────────────────────────────────────
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Image.network(
                    (event['event_pic'] ?? event['event_pic_thumbnail'] ?? '').toString(),
                    height: 190,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 190,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        color: AppColors.primary.withOpacity(0.07),
                      ),
                      child: Center(
                        child: Icon(Icons.event_rounded, size: 56, color: AppColors.primary.withOpacity(0.3)),
                      ),
                    ),
                  ),
                ),
                // Event type badge top-left
                if ((event['event_type'] ?? '').toString().isNotEmpty)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        (event['event_type'] ?? '').toString().toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // ── Content ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    (event['event_title'] ?? 'Untitled Event').toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0D0D0D),
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Date & Location row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date/time column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (dateStr.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text(
                                    dateStr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            if (timeStr.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 13, color: Colors.black38),
                                  const SizedBox(width: 5),
                                  Text(
                                    timeStr,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Location
                  _buildLocation(ref),

                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    // Tags
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tags.map((tag) => _buildTag(tag)).toList(),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom row: arrow
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: AppColors.primary,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocation(WidgetRef ref) {
    final eventLocId = (event['event_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(eventLocId));

    return locationAsync.when(
      data: (location) => Row(
        children: [
          Icon(Icons.location_on_rounded, size: 13, color: Colors.black38),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              location,
              style: const TextStyle(fontSize: 12, color: Colors.black45, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      loading: () => const Text('...', style: TextStyle(fontSize: 12, color: Colors.black38)),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  List<String> _buildTagStrings() {
    final tags = <String>[];
    if (event['event_skill_level_pro'] == true) tags.add('PRO');
    if (event['event_skill_level_amateur'] == true) tags.add('AMATEUR');
    if (event['event_skill_level_beginner'] == true) tags.add('BEGINNER');
    if (event['event_category_juniors'] == true) tags.add('JUNIORS');
    if (event['event_category_seniors'] == true) tags.add('SENIORS');
    if (event['event_category_collegiate'] == true) tags.add('COLLEGIATE');
    if (event['event_category_mixeddoubles'] == true) tags.add('MIXED DOUBLES');
    if (tags.isEmpty) {
      final oldSkill = (event['event_skill_level'] ?? '').toString();
      if (oldSkill.isNotEmpty) tags.add(oldSkill.toUpperCase());
    }
    return tags;
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}