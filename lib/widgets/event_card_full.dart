import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/screens/event_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EventCardFull extends ConsumerWidget {
  final Map<String, dynamic> event;

  const EventCardFull({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Timestamp startDate = event['event_start_date'];
    final Timestamp startTime = event['event_start_time'];
    final DateTime date = startDate.toDate();
    final DateTime time = startTime.toDate();

    // Format date and time using DateFormatter.formatDateTime
    final dateTimeStr = DateFormatter.formatDateTime(date, time);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Event Image ────────────────────────────────────────
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              child: Image.network(
                event['event_image'] ?? '',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.primary.withOpacity(0.1),
                  child: const Icon(
                    Icons.event,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),

            // ── Event Details ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    event['event_title'] ?? 'Untitled Event',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Date & Time combined
                  Text(
                    dateTimeStr.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Location with resolver
                  _buildLocation(ref),

                  const SizedBox(height: 12),

                  // Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _buildTags(),
                  ),

                  const SizedBox(height: 12),

                  // Arrow icon
                  const Icon(
                    Icons.arrow_forward,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Location with Riverpod resolver ───────────────────────────────
  Widget _buildLocation(WidgetRef ref) {
    final eventLocId = (event['event_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(eventLocId));

    return locationAsync.when(
      data: (location) => Text(
        location,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.black54,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      loading: () => const Text(
        '...',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
      error: (_, __) => const Text(
        'Unknown location',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      ),
    );
  }

  // ── Build Tags ─────────────────────────────────────────────────────
  List<Widget> _buildTags() {
    final tags = <String>[];

    final skillLevel = event['event_skill_level']?.toString() ?? '';
    if (skillLevel.isNotEmpty) tags.add(skillLevel.toUpperCase());

    final category = event['event_category']?.toString() ?? '';
    if (category.isNotEmpty) tags.add(category.toUpperCase());

    if (tags.isEmpty) {
      tags.addAll(['BEGINNER', 'INDOOR', 'COACH']);
    }

    return tags.map((tag) => _buildTag(tag)).toList();
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}