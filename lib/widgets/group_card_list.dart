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

  // ── Helpers ───────────────────────────────────────────────────────────────

  bool _isTruthy(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num)  return v != 0;
    final s = v.toString().toLowerCase().trim();
    return s == 'true' || s == '1' || s == 't' || s == 'yes';
  }

  // Whether the parent screen enriched this card with a lang key
  bool get _isJa => (group['_lang'] ?? 'en').toString() == 'ja';

  String _t(String en, String ja) => _isJa ? ja : en;

  // ── Skill levels ──────────────────────────────────────────────────────────
  String _getSkillLevels(Map<String, dynamic> g) {
    final existing = (g['org_skill_level'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') {
      // existing is always EN — re-label when in JP mode
      if (_isJa) {
        return existing
            .replaceAll('Beginner',     '初級')
            .replaceAll('Intermediate', '中級')
            .replaceAll('Advanced',     '上級');
      }
      return existing;
    }

    final levels = <String>[];
    if (_isTruthy(g['org_skill_beginner']))     levels.add(_t('Beginner',     '初級'));
    if (_isTruthy(g['org_skill_intermediate'])) levels.add(_t('Intermediate', '中級'));
    if (_isTruthy(g['org_skill_advance']))      levels.add(_t('Advanced',     '上級'));
    if (levels.isNotEmpty) return levels.join(' | ');

    final type = (g['org_type'] ?? '').toString();
    return type == 'Professional'
        ? _t('Pro | Amateur', 'プロ | アマチュア')
        : _t('All levels', '全レベル');
  }

  // ── Schedule ──────────────────────────────────────────────────────────────
  String _getSchedule(Map<String, dynamic> g) {
    final existing = (g['org_schedule'] ?? g['org_meetup_time'] ?? '').toString().trim();
    // org_schedule is stored in EN — translate labels when in JP mode
    if (existing.isNotEmpty && existing != 'null') {
      if (_isJa) {
        return existing
            .replaceAll('Sun', '日').replaceAll('Mon', '月')
            .replaceAll('Tue', '火').replaceAll('Wed', '水')
            .replaceAll('Thu', '木').replaceAll('Fri', '金')
            .replaceAll('Sat', '土')
            .replaceAll('Mornings',   '午前')
            .replaceAll('Afternoons', '午後')
            .replaceAll('Evenings',   '夜間');
      }
      return existing;
    }

    final dayMap = _isJa
        ? {
      'org_meetup_sun':   '日', 'org_meetup_mon':   '月',
      'org_meetup_tues':  '火', 'org_meetup_weds':  '水',
      'org_meetup_thurs': '木', 'org_meetup_fri':   '金',
      'org_meetup_sat':   '土',
    }
        : {
      'org_meetup_sun':   'Sun', 'org_meetup_mon':   'Mon',
      'org_meetup_tues':  'Tue', 'org_meetup_weds':  'Wed',
      'org_meetup_thurs': 'Thu', 'org_meetup_fri':   'Fri',
      'org_meetup_sat':   'Sat',
    };

    final days = dayMap.entries
        .where((e) => _isTruthy(g[e.key]))
        .map((e) => e.value)
        .toList();

    final times = <String>[
      if (_isTruthy(g['org_meetup_time_mornings']))   _t('Mornings',   '午前'),
      if (_isTruthy(g['org_meetup_time_afternoons'])) _t('Afternoons', '午後'),
      if (_isTruthy(g['org_meetup_time_evenings']))   _t('Evenings',   '夜間'),
    ];

    if (days.isNotEmpty && times.isNotEmpty) {
      return '${days.join(' | ')}  ·  ${times.join(' | ')}';
    }
    if (days.isNotEmpty)  return days.join(' | ');
    if (times.isNotEmpty) return times.join(' | ');
    return _t('Flexible schedule', '柔軟なスケジュール');
  }

  // ── Age groups ────────────────────────────────────────────────────────────
  String _getAgeGroups(Map<String, dynamic> g) {
    final existing = (g['org_age_groups'] ?? '').toString().trim();
    if (existing.isNotEmpty && existing != 'null') {
      if (_isJa) {
        return existing
            .replaceAll('Juniors',  'ジュニア')
            .replaceAll('Students', '学生')
            .replaceAll('Adults',   '大人')
            .replaceAll('Seniors',  'シニア');
      }
      return existing;
    }

    final ages = <String>[];
    if (_isTruthy(g['org_age_juniors']))  ages.add(_t('Juniors',  'ジュニア'));
    if (_isTruthy(g['org_age_students'])) ages.add(_t('Students', '学生'));
    if (_isTruthy(g['org_age_adult']))    ages.add(_t('Adults',   '大人'));
    if (_isTruthy(g['org_age_seniors']))  ages.add(_t('Seniors',  'シニア'));
    return ages.isEmpty ? _t('All ages', '全年齢') : ages.join(' | ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Use pre-resolved fields injected by GroupsScreen ──────────────────
    // _resolved_name    → resolveGroupName(g, lang)  (org_name_jp when ja)
    // _resolved_location → resolveLocation(g, locMap, lang)
    // _lang             → 'en' | 'ja'
    final resolvedName     = (group['_resolved_name']     ?? '').toString();
    final resolvedLocation = (group['_resolved_location'] ?? '').toString();

    final displayName = resolvedName.isNotEmpty
        ? resolvedName
        : (group['org_name'] ?? 'Unnamed Group').toString();

    final imageUrl = (group['org_image'] ?? group['org_pic'] ?? '').toString();

    // Location: use pre-resolved string; fall back to provider only when
    // the card is rendered without enrichment (e.g. in other screens).
    final bool hasResolvedLocation = resolvedLocation.isNotEmpty;
    final orgLocId = (group['org_loc_id'] ?? '').toString();
    final locationAsync = hasResolvedLocation
        ? null
        : ref.watch(locationResolverProvider(orgLocId));

    Widget locationWidget;
    if (hasResolvedLocation) {
      locationWidget = _infoRow(Icons.location_on, resolvedLocation);
    } else {
      locationWidget = locationAsync!.when(
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
      );
    }

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
            // ── Group Image ───────────────────────────────────────────────
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

            // ── Group Details ─────────────────────────────────────────────
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
                          displayName,
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
                  locationWidget,
                  const SizedBox(height: 4),

                  // Skill levels
                  _infoRow(Icons.sports_tennis_rounded, _getSkillLevels(group)),
                  const SizedBox(height: 4),

                  // Schedule
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
                        child: Text(
                          _t('JOIN', '参加'),
                          style: const TextStyle(
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