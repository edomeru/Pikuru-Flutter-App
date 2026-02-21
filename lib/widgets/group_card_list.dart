import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';

class GroupCardList extends ConsumerWidget {
  final Map<String, dynamic> group;

  const GroupCardList({
    super.key,
    required this.group,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgLocId = (group['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // ── Group Image/Logo ─────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              group['org_image'] ?? '',
              width: 90,
              height: 90,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 90,
                height: 90,
                color: AppColors.primary.withOpacity(0.1),
                child: const Icon(
                  Icons.group,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // ── Group Details ────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        group['org_name'] ?? 'Unnamed Group',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.black54,
                      size: 20,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Location
                locationAsync.when(
                  data: (location) => Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          location,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  loading: () => const Text('...'),
                  error: (_, __) => const Text('Unknown location'),
                ),
                const SizedBox(height: 4),

                // Skill levels
                Text(
                  _getSkillLevels(group),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),

                // Schedule
                Text(
                  _getSchedule(group),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),

                // Age groups + JOIN button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getAgeGroups(group),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'JOIN',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getSkillLevels(Map<String, dynamic> group) {
    // Extract from Firestore or use placeholder
    return 'Beginner | Intermediate';
  }

  String _getSchedule(Map<String, dynamic> group) {
    return 'Weekday nights | Weekends';
  }

  String _getAgeGroups(Map<String, dynamic> group) {
    return '20s/30s | 40s';
  }
}