import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/providers.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/utils/date_formatter.dart';
import 'package:pikuru/modal/group_detail_modal.dart';
import 'package:pikuru/modal/share_group_modal.dart';
import 'package:pikuru/screens/group_chat_screen.dart';

// ── Data helpers ──────────────────────────────────────────────────────────────

bool _isTruthy(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num)  return v != 0;
  final s = v.toString().toLowerCase().trim();
  return s == 'true' || s == '1' || s == 't' || s == 'yes';
}

// ── Lang-aware resolvers ──────────────────────────────────────────────────────

String _field(Map<String, dynamic> g, String enKey, String jpKey, String lang) {
  if (lang == 'ja') {
    final jp = (g[jpKey] ?? '').toString().trim();
    if (jp.isNotEmpty && jp != 'null') return jp;
  }
  return (g[enKey] ?? '').toString().trim();
}

String _resolveOrgType(String rawType, String lang) {
  if (lang != 'ja') return rawType;
  switch (rawType) {
    case 'Local Group':  return 'ローカルグループ';
    case 'Professional': return 'プロフェッショナル';
    case 'Gym/Club':     return 'ジム・クラブ';
    default:             return rawType;
  }
}

String _resolveSkillLevel(Map<String, dynamic> g, String lang) {
  final existing = (g['org_skill_level'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
        ? existing
        .replaceAll('Beginner', '初級')
        .replaceAll('Intermediate', '中級')
        .replaceAll('Advanced', '上級')
        : existing;
  }
  final b  = lang == 'ja' ? '初級' : 'Beginner';
  final im = lang == 'ja' ? '中級' : 'Intermediate';
  final a  = lang == 'ja' ? '上級' : 'Advanced';
  final levels = <String>[];
  if (_isTruthy(g['org_skill_beginner']))     levels.add(b);
  if (_isTruthy(g['org_skill_intermediate'])) levels.add(im);
  if (_isTruthy(g['org_skill_advance']))      levels.add(a);
  if (levels.isNotEmpty) return levels.join(' | ');
  final type = (g['org_type'] ?? '').toString();
  return type == 'Professional'
      ? (lang == 'ja' ? 'プロ | アマチュア' : 'Pro | Amateur')
      : (lang == 'ja' ? '全レベル' : 'All levels');
}

String _resolveAgeGroups(Map<String, dynamic> g, String lang) {
  final existing = (g['org_age_groups'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
        ? existing
        .replaceAll('Juniors', 'ジュニア')
        .replaceAll('Students', '学生')
        .replaceAll('Adults', '大人')
        .replaceAll('Seniors', 'シニア')
        : existing;
  }
  String j(String en, String ja) => lang == 'ja' ? ja : en;
  final ages = <String>[];
  if (_isTruthy(g['org_age_juniors']))  ages.add(j('Juniors',  'ジュニア'));
  if (_isTruthy(g['org_age_students'])) ages.add(j('Students', '学生'));
  if (_isTruthy(g['org_age_adult']))    ages.add(j('Adults',   '大人'));
  if (_isTruthy(g['org_age_seniors']))  ages.add(j('Seniors',  'シニア'));
  return ages.isEmpty ? (lang == 'ja' ? '全年齢' : 'All ages') : ages.join(' | ');
}

String _resolveSchedule(Map<String, dynamic> g, String lang) {
  final existing =
  (g['org_schedule'] ?? g['org_meetup_time'] ?? '').toString().trim();
  if (existing.isNotEmpty && existing != 'null') {
    return lang == 'ja'
        ? existing
        .replaceAll('Sun', '日').replaceAll('Mon', '月')
        .replaceAll('Tue', '火').replaceAll('Wed', '水')
        .replaceAll('Thu', '木').replaceAll('Fri', '金')
        .replaceAll('Sat', '土')
        .replaceAll('Mornings',   '午前')
        .replaceAll('Afternoons', '午後')
        .replaceAll('Evenings',   '夜間')
        : existing;
  }
  String j(String en, String ja) => lang == 'ja' ? ja : en;
  final dayMap = {
    'org_meetup_sun':   j('Sun', '日'),
    'org_meetup_mon':   j('Mon', '月'),
    'org_meetup_tues':  j('Tue', '火'),
    'org_meetup_weds':  j('Wed', '水'),
    'org_meetup_thurs': j('Thu', '木'),
    'org_meetup_fri':   j('Fri', '金'),
    'org_meetup_sat':   j('Sat', '土'),
  };
  final days = dayMap.entries
      .where((e) => _isTruthy(g[e.key]))
      .map((e) => e.value)
      .toList();
  final times = <String>[
    if (_isTruthy(g['org_meetup_time_mornings']))   j('Mornings',   '午前'),
    if (_isTruthy(g['org_meetup_time_afternoons'])) j('Afternoons', '午後'),
    if (_isTruthy(g['org_meetup_time_evenings']))   j('Evenings',   '夜間'),
  ];
  if (days.isEmpty && times.isEmpty)
    return lang == 'ja' ? '柔軟なスケジュール' : 'Flexible schedule';
  if (days.isEmpty)  return times.join(' | ');
  if (times.isEmpty) return days.join(' | ');
  return '${days.join(' | ')}  ·  ${times.join(' | ')}';
}

String _resolveDescription(Map<String, dynamic> g, String lang) {
  final d = _field(g, 'org_description', 'org_description_jp', lang);
  if (d.isNotEmpty && d != 'null') return d;
  final name = _field(g, 'org_name', 'org_name_jp', lang);
  if (lang == 'ja') {
    switch ((g['org_type'] ?? '').toString()) {
      case 'Professional':
        return '$name のプロレベルのトーナメント情報や最新ニュースをチェック！';
      case 'Gym/Club':
        return '$name — 全レベル対応のオープンプレイやレッスンが楽しめる施設です。';
      case 'Local Group':
        return '誰でも参加できるフレンドリーな地元ピックルボールグループです。ぜひご参加ください！';
      default:
        return '$name に参加して、ピックルボールコミュニティとつながりましょう。初心者から上級者まで大歓迎！';
    }
  }
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
          "Whether you're a beginner or a seasoned player, everyone is welcome.";
  }
}

String _resolveLocationLabel(
    Map<String, dynamic> g, String lang, String providerLocation) {
  final pre = (g['_resolved_location'] ?? '').toString().trim();
  if (pre.isNotEmpty) return pre;
  if (lang == 'ja') {
    final city =
    (g['org_city_jp'] ?? g['org_city'] ?? '').toString().trim();
    final pref =
    (g['org_prefecture_jp'] ?? g['org_prefecture'] ?? '').toString().trim();
    final country = (g['org_country'] ?? '').toString().trim();
    if (city.isNotEmpty && pref.isNotEmpty) return '$city, $pref';
    if (city.isNotEmpty) return country.isNotEmpty ? '$city, $country' : city;
    if (pref.isNotEmpty) return pref;
    return providerLocation.isNotEmpty ? providerLocation : country;
  }
  return providerLocation.isNotEmpty
      ? providerLocation
      : (g['org_country'] ?? '').toString().trim();
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

  // null = loading, 'none' | 'interested' | 'active'
  String? _membershipStatus;
  bool _isFavorite = false;

  late AnimationController _animController;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _loadMembershipStatus();
    _animController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 550));
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(
            CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() { _animController.dispose(); super.dispose(); }

  Future<void> _loadMembershipStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _membershipStatus = 'none';
          _isFavorite = false;
        });
      }
      return;
    }
    final groupId = GroupDetailModals.resolveGroupId(widget.group);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('user_groups')
          .doc('${user.uid}_$groupId')
          .get();
      if (mounted) {
        if (snap.exists) {
          final data = snap.data();
          final status = data?['status']?.toString() ?? 'none';
          final isFav = data?['is_favorite'] == true;
          setState(() {
            _membershipStatus = status;
            _isFavorite = status == 'interested' || isFav;
          });
        } else {
          setState(() {
            _membershipStatus = 'none';
            _isFavorite = false;
          });
        }
      }
    } catch (e) {
      debugPrint('_loadMembershipStatus error: $e');
    }
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    final raw = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String get _orgId =>
      (widget.group['org_id'] ??
          widget.group['org_ID'] ??
          widget.group['_doc_id'] ??
          '')
          .toString();

  String _tr(String lang, String en, String ja) => lang == 'ja' ? ja : en;

  // ── JOIN handler ──────────────────────────────────────────────────────────
  // Only callable when NOT already active (button is disabled when active).
  Future<void> _handleJoin(String lang) async {
    if (_membershipStatus == 'active') return;
    final result = await GroupDetailModals.showJoin(
        context, widget.group, lang: lang);
    if (result != null && mounted) {
      _loadMembershipStatus();
    }
  }

  // ── INTERESTED handler ────────────────────────────────────────────────────
  // Works as a TOGGLE:
  //   active     → confirms → marks as favorite
  //   none       → confirms → marks as favorite
  //   interested → shows un-favorite confirm dialog → deletes doc or sets is_favorite to false
  Future<void> _handleInterested(String lang) async {
    final result = await GroupDetailModals.showInterested(
      context,
      widget.group,
      lang: lang,
      currentStatus: _membershipStatus ?? 'none',
      isFavorite: _isFavorite,
    );
    if (result != null && mounted) {
      _loadMembershipStatus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final g    = widget.group;

    final orgLocId      = (g['org_loc_id'] ?? '').toString();
    final locationAsync = ref.watch(locationResolverProvider(orgLocId));
    final providerLoc   = locationAsync.when(
        data: (l) => l, loading: () => '', error: (_, __) => '');

    final locationLabel = _resolveLocationLabel(g, lang, providerLoc).let((l) =>
    l.isNotEmpty
        ? l
        : (g['org_country'] ?? _tr(lang, 'Unknown location', '不明な場所'))
        .toString());

    final displayName   = _field(g, 'org_name', 'org_name_jp', lang)
        .let((v) => v.isNotEmpty ? v : _tr(lang, 'Unnamed Group', '名称不明'));
    final description   = _resolveDescription(g, lang);
    final skillLabel    = _resolveSkillLevel(g, lang);
    final ageLabel      = _resolveAgeGroups(g, lang);
    final scheduleLabel = _resolveSchedule(g, lang);

    final city       = _field(g, 'org_city',       'org_city_jp',       lang);
    final prefecture = _field(g, 'org_prefecture', 'org_prefecture_jp', lang);
    final social     = (g['org_social'] ?? '').toString().trim();

    final imageUrl     = (g['org_image'] ?? g['org_pic'] ?? '').toString();
    final website      = (g['org_website'] ?? '').toString().trim();
    final websiteLabel = website
        .replaceFirst(RegExp(r'^https?://'), '')
        .replaceFirst(RegExp(r'/$'), '');

    final rawType        = (g['org_type'] ?? '').toString();
    final translatedType = _resolveOrgType(rawType, lang);

    // ── Button state derivations ──────────────────────────────────────────
    final isActive     = _membershipStatus == 'active';
    final isInterested = _isFavorite;
    final isLoading    = _membershipStatus == null;

    // Join:       green & tappable when NOT active; gray when active
    // Interested: green & tappable when NOT interested (including when active!);
    //             gray when already interested
    // This makes the two buttons act as a radio/switch, matching the web app.

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [

          // ── Hero App Bar ──────────────────────────────────────────────
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
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: _LangPill(
                  lang: lang,
                  onChanged: (l) => ref.read(appLangProvider.notifier).setLang(l),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: _GlassButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => ShareGroupModal.show(context, group: g),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(fit: StackFit.expand, children: [
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
                                color: Colors.white54, strokeWidth: 2)));
                  },
                  errorBuilder: (_, __, ___) => Container(
                      color: AppColors.primary.withOpacity(0.2),
                      child: const Icon(Icons.group,
                          size: 80, color: Colors.white38)),
                )
                    : Container(
                    color: AppColors.primary.withOpacity(0.2),
                    child: const Icon(Icons.group,
                        size: 80, color: Colors.white38)),
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
                Positioned(
                  left: 20, right: 20, bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (rawType.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border:
                            Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(translatedType,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4)),
                        ),
                      Text(
                        displayName,
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
              ]),
            ),
          ),

          // ── Body ────────────────────────────────────────────────────
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
                      child: Text(description,
                          style: const TextStyle(
                              fontSize: 15, color: Colors.black87, height: 1.6)),
                    ),

                    const SizedBox(height: 24),

                    // ── Info Grid ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: _buildInfoItem(Icons.location_on, locationLabel)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInfoItem(Icons.people, ageLabel)),
                        ]),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: _buildInfoItem(Icons.calendar_month, scheduleLabel)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInfoItem(Icons.sports, skillLabel)),
                        ]),
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
                        if (prefecture.isNotEmpty ||
                            city.isNotEmpty ||
                            social.isNotEmpty)
                          Padding(
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
                                    onTap: () => _launchUrl(social),
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
                                              decorationColor: AppColors.primary
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
                          ),
                      ]),
                    ),

                    const SizedBox(height: 32),

                    // ── Join & Interested Buttons ──────────────────────
                    // Behaviour matches web app exactly:
                    //   • Join      → disabled (gray) only when isActive
                    //   • Interested → disabled (gray) only when isInterested
                    //   • Clicking Interested while active TOGGLES back to
                    //     interested (re-enables Join)
                    //   • The "already joined" banner shows only when active
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(children: [
                        Row(children: [

                          // ── JOIN ──────────────────────────────────────
                          Expanded(
                            child: isLoading
                                ? Container(
                              height: 52,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary),
                                ),
                              ),
                            )
                                : GestureDetector(
                              onTap: isActive
                                  ? null
                                  : () => _handleJoin(lang),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.grey.shade200
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isActive
                                      ? _tr(lang, 'Joined ✓', '参加済み ✓')
                                      : _tr(lang, 'Join', '参加'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? Colors.grey.shade600
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 16),

                          // ── INTERESTED ────────────────────────────────
                          // Always tappable. When already favorited, shows
                          // un-favorite confirm dialog to remove.
                          Expanded(
                            child: isLoading
                                ? Container(
                              height: 52,
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.grey.shade300, width: 2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            )
                                : GestureDetector(
                              onTap: () => _handleInterested(lang),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                height: 52,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: isInterested
                                        ? const Color(0xFFF58C46)
                                        : AppColors.primary,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  isInterested
                                      ? _tr(lang, 'Favorited ✓', 'お気に入り ✓')
                                      : _tr(lang, 'Favorite', 'お気に入り'),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isInterested
                                        ? const Color(0xFFF58C46)
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ]),

                        // Open Chat Group button — shown to active members only
                        if (isActive) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupChatScreen(group: widget.group),
                                ),
                              );
                            },
                            child: Container(
                              height: 52,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF2d6a3f), Color(0xFF4a9c5e)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded,
                                      color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    _tr(lang, 'Open Chat Group', 'チャットグループを開く'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Joined banner — only when active
                        if (isActive) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _tr(lang, 'You have already joined this group',
                                      'このグループにはすでに参加しています'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ]),
                          ),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 32),

                    // ── Upcoming Events ────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _tr(lang, 'Upcoming Events', '今後のイベント'),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.black),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _tr(lang, 'View all', 'すべて見る'),
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildUpcomingEventsList(lang),
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
          child: Text(text,
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildUpcomingEventsList(String lang) {
    if (_orgId.isEmpty) return _buildEmptyEvents(lang);
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
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text('Error loading events.\n${snapshot.error}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                    textAlign: TextAlign.center),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(
              height: 100, child: Center(child: CircularProgressIndicator()));
        }
        final events = snapshot.data!.docs;
        if (events.isEmpty) return _buildEmptyEvents(lang);
        return Column(
          children: events
              .take(3)
              .map((doc) =>
              _buildEventItem(doc.data() as Map<String, dynamic>, lang))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyEvents(String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Center(
          child: Text(
            _tr(lang, 'No upcoming events yet',
                'まだ予定されているイベントはありません'),
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _buildEventItem(Map<String, dynamic> event, String lang) {
    final Timestamp? dateTs = event['event_date'] ?? event['event_start_date'];
    final Timestamp? timeTs = event['event_start_time'] ?? event['event_date'];
    if (dateTs == null) return const SizedBox.shrink();
    final date       = dateTs.toDate();
    final time       = timeTs?.toDate() ?? date;
    final eventLocId = (event['event_loc_id'] ?? '').toString();

    final eventTitle = lang == 'ja'
        ? ((event['event_title_jp'] ??
        event['event_name_jp'] ??
        event['event_title'] ??
        event['event_name'] ??
        _tr(lang, 'Untitled Event', '無題のイベント'))
        .toString())
        : ((event['event_title'] ?? event['event_name'] ?? 'Untitled Event')
        .toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          // Date badge
          Container(
            width: 62,
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Text(
                DateFormatter.month(date.month).substring(0, 3).toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.5),
              ),
              const SizedBox(height: 2),
              Text('${date.day}',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      height: 1.1)),
              const SizedBox(height: 2),
              Text('${date.year}',
                  style: const TextStyle(
                      fontSize: 10,
                      color: Colors.black38,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
          // Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(eventTitle,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D23)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.access_time_rounded,
                        size: 12, color: Colors.black38),
                    const SizedBox(width: 4),
                    Text(
                        '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.black45)),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on_rounded,
                        size: 12, color: Colors.black38),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Consumer(builder: (context, ref, _) {
                        final loc = ref
                            .watch(locationResolverProvider(eventLocId));
                        return loc.when(
                          data: (l) => Text(l,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black45),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          loading: () =>
                          const Text('...', style: TextStyle(fontSize: 12)),
                          error: (_, __) => Text(_tr(lang, 'Unknown', '不明'),
                              style: const TextStyle(fontSize: 12)),
                        );
                      }),
                    ),
                  ]),
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
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 13),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Extension helper ──────────────────────────────────────────────────────────
extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}

// ── Lang pill widget ──────────────────────────────────────────────────────────
class _LangPill extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onChanged;
  const _LangPill({required this.lang, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        _pill('EN', lang == 'en'),
        _pill('JP', lang == 'ja'),
      ]),
    );
  }

  Widget _pill(String label, bool selected) {
    return GestureDetector(
      onTap: () => onChanged(label == 'EN' ? 'en' : 'ja'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : Colors.white.withOpacity(0.55),
            )),
      ),
    );
  }
}

// ── Glass back/share button ───────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 40, height: 40,
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