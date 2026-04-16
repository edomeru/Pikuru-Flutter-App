import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/modal/join_group_modal.dart';
import 'package:pikuru/modal/mark_interested_modal.dart';
import 'package:pikuru/modal/share_group_modal.dart';

// ── Data helpers ──────────────────────────────────────────────────────────────

bool _isTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num)  return v != 0;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 't' || s == 'yes';
}

String _resolveSkillLevel(Map<String, dynamic> g) {
  final levels = <String>[];
  if (_isTruthy(g['org_skill_beginner']))     levels.add('Beginner');
  if (_isTruthy(g['org_skill_intermediate'])) levels.add('Intermediate');
  if (_isTruthy(g['org_skill_advance']))      levels.add('Advanced');
  if (levels.isNotEmpty) return levels.join(' | ');
  final type = (g['org_type'] ?? '').toString();
  return type == 'Professional' ? 'Pro | Amateur' : 'All levels';
}

String _resolveAgeGroups(Map<String, dynamic> g) {
  final ages = <String>[];
  if (_isTruthy(g['org_age_juniors']))  ages.add('Juniors');
  if (_isTruthy(g['org_age_students'])) ages.add('Students');
  if (_isTruthy(g['org_age_adult']))    ages.add('Adults');
  if (_isTruthy(g['org_age_seniors']))  ages.add('Seniors');
  return ages.isEmpty ? 'All ages' : ages.join(' | ');
}

String _resolveSchedule(Map<String, dynamic> g) {
  final t = (g['org_meetup_time'] ?? '').toString().trim();
  if (t.isNotEmpty && t != 'null') return t;
  final dayMap = {
    'org_meetup_sun': 'Sun', 'org_meetup_mon': 'Mon',
    'org_meetup_tues': 'Tue', 'org_meetup_weds': 'Wed',
    'org_meetup_thurs': 'Thu', 'org_meetup_fri': 'Fri',
    'org_meetup_sat': 'Sat',
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
  if (days.isEmpty && times.isEmpty) return 'Flexible schedule';
  if (days.isEmpty)  return times.join(' | ');
  if (times.isEmpty) return days.join(' | ');
  return '${days.join(' | ')}  ·  ${times.join(' | ')}';
}

String _resolveDescription(Map<String, dynamic> g) {
  final d = (g['org_description'] ?? '').toString().trim();
  if (d.isNotEmpty && d != 'null') return d;
  final name = (g['org_name'] ?? 'this group').toString();
  switch ((g['org_type'] ?? '').toString()) {
    case 'Professional':
      return 'Follow $name for professional-level pickleball tournaments, '
          'top-tier competition, and the latest tour news.';
    case 'Gym/Club':
      return 'Join $name — a dedicated pickleball facility offering '
          'open play, lessons, and a welcoming community for all skill levels.';
    case 'Local Group':
      return 'A friendly local pickleball group open to all. '
          'Come out, rally with neighbours, and enjoy the game!';
    default:
      return 'Join $name and connect with the pickleball community. '
          'Whether you\'re a beginner or a seasoned player, everyone is welcome.';
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GroupDetailScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> group;
  const GroupDetailScreen({super.key, required this.group});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  bool? _isJoined;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _checkJoinStatus();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkJoinStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { setState(() => _isJoined = false); return; }
    final joined = await JoinGroupModal.isAlreadyJoined(user.uid, widget.group);
    if (mounted) setState(() => _isJoined = joined);
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final raw = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── NEW: launch social link ───────────────────────────────────────────────
  Future<void> _launchSocial(String url) async {
    if (url.isEmpty) return;
    final raw = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String get _orgId =>
      (widget.group['org_id'] ??
          widget.group['org_ID'] ??
          widget.group['_doc_id'] ??
          '')
          .toString();

  @override
  Widget build(BuildContext context) {
    final orgLocId = (widget.group['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));

    final locationLabel = locationAsync.when(
      data: (l) {
        if (l.isEmpty) {
          final country = (widget.group['org_country'] ?? '').toString();
          return country.isNotEmpty ? country : 'Unknown location';
        }
        return l;
      },
      loading: () => 'Loading...',
      error: (_, __) {
        final country = (widget.group['org_country'] ?? '').toString();
        return country.isNotEmpty ? country : 'Unknown';
      },
    );

    final skillLabel = (widget.group['org_skill_level'] ?? '').toString().trim().isNotEmpty
        ? widget.group['org_skill_level'].toString()
        : _resolveSkillLevel(widget.group);
    final ageLabel = (widget.group['org_age_groups'] ?? '').toString().trim().isNotEmpty
        ? widget.group['org_age_groups'].toString()
        : _resolveAgeGroups(widget.group);
    final scheduleLabel = (widget.group['org_schedule'] ?? '').toString().trim().isNotEmpty
        ? widget.group['org_schedule'].toString()
        : _resolveSchedule(widget.group);

    final imageUrl =
    (widget.group['org_image'] ?? widget.group['org_pic'] ?? '').toString();

    final website = (widget.group['org_website'] ?? '').toString().trim();
    final websiteLabel = website
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            automaticallyImplyLeading: false,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _GlassButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => ShareGroupModal.show(
                    context,
                    group: widget.group,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero image
                  imageUrl.isNotEmpty
                      ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (ctx, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: AppColors.primary.withOpacity(0.15),
                        child: const Center(
                          child: CircularProgressIndicator(
                              color: Colors.white54, strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.2),
                      child: const Icon(Icons.group,
                          size: 80, color: Colors.white38),
                    ),
                  )
                      : Container(
                    color: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.group,
                        size: 80, color: Colors.white38),
                  ),

                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.58),
                        ],
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),

                  // Type badge + org name
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if ((widget.group['org_type'] ?? '').toString().isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: Text(
                              widget.group['org_type'].toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        Text(
                          widget.group['org_name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                            height: 1.15,
                            shadows: [
                              Shadow(
                                  color: Colors.black38,
                                  blurRadius: 10,
                                  offset: Offset(0, 2))
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),

                    // Description
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        _resolveDescription(widget.group),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                          height: 1.6,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Info Grid (2 × 2) + website ───────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildInfoItem(
                                  Icons.location_on, locationLabel)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInfoItem(
                                  Icons.people, ageLabel)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(child: _buildInfoItem(
                                  Icons.calendar_month, scheduleLabel)),
                              const SizedBox(width: 16),
                              Expanded(child: _buildInfoItem(
                                  Icons.sports, skillLabel)),
                            ],
                          ),

                          // Website — only rendered when org_website is set
                          if (websiteLabel.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => _launchUrl(website),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(Icons.language_rounded,
                                      color: AppColors.primary, size: 22),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      websiteLabel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                        decorationColor:
                                        AppColors.primary.withOpacity(0.5),
                                        height: 1.4,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded,
                                      size: 14,
                                      color: AppColors.primary.withOpacity(0.6)),
                                ],
                              ),
                            ),
                          ],

                          // ── NEW: org_prefecture, org_city, org_social ──
                          Builder(builder: (context) {
                            final prefecture =
                            (widget.group['org_prefecture'] ?? '').toString().trim();
                            final city =
                            (widget.group['org_city'] ?? '').toString().trim();
                            final social =
                            (widget.group['org_social'] ?? '').toString().trim();

                            if (prefecture.isEmpty && city.isEmpty && social.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (prefecture.isNotEmpty || city.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: _buildInfoItem(
                                        Icons.map_outlined,
                                        [city, prefecture]
                                            .where((s) => s.isNotEmpty)
                                            .join(', '),
                                      ),
                                    ),
                                  if (social.isNotEmpty)
                                    GestureDetector(
                                      onTap: () => _launchSocial(social),
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                        children: [
                                          Icon(Icons.link_rounded,
                                              color: AppColors.primary, size: 22),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              social
                                                  .replaceFirst(
                                                  RegExp(r'^https?://'), '')
                                                  .replaceFirst(
                                                  RegExp(r'/$'), ''),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w500,
                                                decoration:
                                                TextDecoration.underline,
                                                decorationColor:
                                                AppColors.primary
                                                    .withOpacity(0.5),
                                                height: 1.4,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(Icons.open_in_new_rounded,
                                              size: 14,
                                              color: AppColors.primary
                                                  .withOpacity(0.6)),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Join & Interested Buttons ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isJoined == true
                                      ? null
                                      : () async {
                                    await JoinGroupModal.show(
                                        context, widget.group);
                                    _checkJoinStatus();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isJoined == true
                                        ? Colors.grey.shade300
                                        : AppColors.primary,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
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
                                  onPressed: () => MarkInterestedModal.show(
                                      context, widget.group),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    side: const BorderSide(
                                        color: AppColors.primary, width: 2),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                        BorderRadius.circular(12)),
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

                    // ── Upcoming Events ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upcoming Events',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildUpcomingEventsList(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
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
    if (_orgId.isEmpty) return _buildEmptyEvents();

    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('event_org_id', isEqualTo: _orgId)
          .where('event_active', isEqualTo: true)
          .where('event_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .orderBy('event_date')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Error loading events.\n${snapshot.error}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()));
        }
        final events = snapshot.data!.docs;
        if (events.isEmpty) return _buildEmptyEvents();

        return Column(
          children: events
              .take(3)
              .map((doc) =>
              _buildEventItem(doc.data() as Map<String, dynamic>))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyEvents() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text('No upcoming events yet',
              style: TextStyle(fontSize: 14, color: Colors.black54)),
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event) {
    final Timestamp? dateTs = event['event_date'] ?? event['event_start_date'];
    final Timestamp? timeTs = event['event_start_time'] ?? event['event_date'];
    if (dateTs == null) return const SizedBox.shrink();

    final date       = dateTs.toDate();
    final time       = timeTs?.toDate() ?? date;
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

    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 12),
      child: GestureDetector(
        onTap: () => MarkInterestedModal.show(context, eventWithGroup),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Date badge
              Container(
                width: 62,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormatter.month(date.month)
                          .substring(0, 3)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${date.year}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Event details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event['event_title'] ??
                            event['event_name'] ??
                            'Untitled Event',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D23),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Text(
                            '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black45),
                          ),
                          const SizedBox(width: 10),
                          const Icon(Icons.location_on_rounded,
                              size: 12, color: Colors.black38),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, _) {
                                final loc = ref.watch(
                                    locationResolverProvider(eventLocId));
                                return loc.when(
                                  data: (l) => Text(l,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.black45),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  loading: () => const Text('...',
                                      style: TextStyle(fontSize: 12)),
                                  error: (_, __) => const Text('Unknown',
                                      style: TextStyle(fontSize: 12)),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Arrow
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared components ─────────────────────────────────────────────────────────

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        shape: BoxShape.circle,
        border:
        Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}