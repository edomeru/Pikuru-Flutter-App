import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/screens/group_detail_screen.dart';

class GroupCardList extends ConsumerWidget {
  final Map<String, dynamic> group;

  const GroupCardList({
    super.key,
    required this.group,
  });

  // ── Real data resolvers ───────────────────────────────────────────────────

  bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num)  return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes';
  }

  String _getSkillLevels(Map<String, dynamic> g) {
    // Use pre-composed field if present
    final existing = (g['org_skill_level'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') return existing;

    // Build from individual boolean flags (org_skill_beginner etc.)
    final levels = <String>[];
    if (_isTruthy(g['org_skill_beginner']))     levels.add('Beginner');
    if (_isTruthy(g['org_skill_intermediate'])) levels.add('Intermediate');
    if (_isTruthy(g['org_skill_advance']))      levels.add('Advanced');
    if (levels.isNotEmpty) return levels.join(' | ');

    // Type-based fallback
    final type = (g['org_type'] ?? '').toString();
    return type == 'Professional' ? 'Pro | Amateur' : 'All levels';
  }

  String _getSchedule(Map<String, dynamic> g) {
    // Use pre-composed field if present
    final existing = (g['org_schedule'] ?? g['org_meetup_time'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') return existing;

    // Build from boolean day flags
    final dayMap = {
      'org_meetup_sun':   'Sun',
      'org_meetup_mon':   'Mon',
      'org_meetup_tues':  'Tue',
      'org_meetup_weds':  'Wed',
      'org_meetup_thurs': 'Thu',
      'org_meetup_fri':   'Fri',
      'org_meetup_sat':   'Sat',
    };
    final days = dayMap.entries
        .where((e) => _isTruthy(g[e.key]))
        .map((e) => e.value)
        .toList();

    final times = <String>[
      if (_isTruthy(g['org_meetup_time_mornings']))   'Mornings',
      if (_isTruthy(g['org_meetup_time_afternoons'])) 'Afternoons',
      if (_isTruthy(g['org_meetup_time_evenings']))   'Evenings',
    ];

    if (days.isNotEmpty && times.isNotEmpty) {
      return '${days.join(' | ')}  ·  ${times.join(' | ')}';
    }
    if (days.isNotEmpty)  return days.join(' | ');
    if (times.isNotEmpty) return times.join(' | ');
    return 'Flexible schedule';
  }

  String _getAgeGroups(Map<String, dynamic> g) {
    // Use pre-composed field if present
    final existing = (g['org_age_groups'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') return existing;

    // Build from boolean age flags
    final ages = <String>[];
    if (_isTruthy(g['org_age_juniors']))  ages.add('Juniors');
    if (_isTruthy(g['org_age_students'])) ages.add('Students');
    if (_isTruthy(g['org_age_adult']))    ages.add('Adults');
    if (_isTruthy(g['org_age_seniors']))  ages.add('Seniors');
    return ages.isEmpty ? 'All ages' : ages.join(' | ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgLocId      = (group['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));
    final imageUrl      = (group['org_image'] ?? group['org_pic'] ?? '').toString();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailScreen(group: group),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Group Image/Logo ───────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                imageUrl,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(),
              )
                  : _placeholder(),
            ),

            const SizedBox(width: 16),

            // ── Group Details ──────────────────────────────────────────
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

                  // Location — resolved via locationResolverProvider (loc_id FK)
                  // Falls back to org_country when loc_id is absent
                  locationAsync.when(
                    data: (location) {
                      final label = location.isNotEmpty
                          ? location
                          : (group['org_country'] ?? '').toString();
                      return label.isNotEmpty
                          ? _infoRow(Icons.location_on, label)
                          : const SizedBox.shrink();
                    },
                    loading: () => _infoRow(Icons.location_on, '...'),
                    error: (_, __) {
                      final country = (group['org_country'] ?? '').toString();
                      return country.isNotEmpty
                          ? _infoRow(Icons.location_on, country)
                          : const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 4),

                  // Skill levels — from org_skill_* boolean fields
                  _infoRow(Icons.sports_tennis_rounded, _getSkillLevels(group)),
                  const SizedBox(height: 4),

                  // Schedule — from org_meetup_* fields + org_meetup_time
                  _infoRow(Icons.calendar_today_rounded, _getSchedule(group)),
                  const SizedBox(height: 4),

                  // Age groups + JOIN button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: _infoRow(
                            Icons.people_alt_rounded, _getAgeGroups(group)),
                      ),
                      const SizedBox(width: 8),
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
      ),
    );
  }

  // ── Small helper: icon + text row ─────────────────────────────────────────
  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.group,
          size: 40, color: AppColors.primary.withOpacity(0.4)),
    );
  }
}