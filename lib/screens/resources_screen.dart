import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ResourcesScreen
//
// Mirrors web app's ResourcesPage exactly:
//   • Fetches `resources` collection ordered by `order` ASC
//   • Splits docs by `category`: 'learn' | 'tools'
//   • Each doc: { id, category, order, en:{title,sub}, ja:{title,sub} }
//   • Tapping a row → ResourceDetailScreen(docId)
//   • Supports EN / JA language toggle (persisted in-page)
// ─────────────────────────────────────────────────────────────────────────────

class ResourcesScreen extends StatefulWidget {
  const ResourcesScreen({super.key});

  @override
  State<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends State<ResourcesScreen>
    with TickerProviderStateMixin {
  // ── Language toggle ────────────────────────────────────────────────────────
  String _lang = 'en'; // 'en' | 'ja'

  // ── Firestore data ─────────────────────────────────────────────────────────
  bool _loading = true;
  List<Map<String, dynamic>> _learnItems = [];
  List<Map<String, dynamic>> _toolsItems = [];

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _slideAnim = Tween<Offset>(
        begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    _fetchResources();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Fetch from Firestore ───────────────────────────────────────────────────
  // Tries orderBy('order') first; if that fails (missing index or field),
  // falls back to a plain collection fetch sorted client-side.
  Future<void> _fetchResources() async {
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = [];

    // Attempt 1: ordered query
    try {
      final snap = await FirebaseFirestore.instance
          .collection('resources')
          .orderBy('order')
          .get();
      docs = snap.docs;
      debugPrint('[ResourcesScreen] ordered fetch: ${docs.length} docs');
    } catch (e) {
      debugPrint('[ResourcesScreen] orderBy failed ($e), trying unordered...');
      // Attempt 2: plain fetch (no orderBy)
      try {
        final snap = await FirebaseFirestore.instance
            .collection('resources')
            .get();
        docs = snap.docs;
        debugPrint('[ResourcesScreen] unordered fetch: ${docs.length} docs');
      } catch (e2) {
        debugPrint('[ResourcesScreen] both fetches failed: $e2');
        if (mounted) setState(() => _loading = false);
        return;
      }
    }

    final learn = <Map<String, dynamic>>[];
    final tools = <Map<String, dynamic>>[];

    for (final doc in docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['_doc_id'] = doc.id;
      final category = (data['category'] ?? '').toString();
      debugPrint('[ResourcesScreen] doc ${doc.id}: category=$category, '
          'en.title=${(data['en'] is Map ? data['en']['title'] : '?')}');
      if (category == 'learn') learn.add(data);
      else if (category == 'tools') tools.add(data);
    }

    // Client-side sort by 'order' field (handles missing field gracefully)
    int _order(Map<String, dynamic> d) {
      final v = d['order'];
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 999;
      return 999;
    }
    learn.sort((a, b) => _order(a).compareTo(_order(b)));
    tools.sort((a, b) => _order(a).compareTo(_order(b)));

    if (mounted) {
      setState(() {
        _learnItems = learn;
        _toolsItems = tools;
        _loading = false;
      });
    }
  }

  // ── Localised string helper ────────────────────────────────────────────────
  String _t(Map<String, dynamic> doc, String key) {
    final langMap = doc[_lang] ?? doc['en'];
    if (langMap is Map) return (langMap[key] ?? '').toString();
    return '';
  }

  // ── Navigate to detail ─────────────────────────────────────────────────────
  void _openDetail(Map<String, dynamic> doc) {
    final id = (doc['_doc_id'] ?? doc['id'] ?? '').toString();
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResourceDetailScreen(docId: id, lang: _lang),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Resources',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 0.3)),
            actions: [
              // ── EN / JA toggle — mirrors web LangToggle ──────────────────
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _LangButton(
                        label: 'EN',
                        selected: _lang == 'en',
                        onTap: () => setState(() => _lang = 'en'),
                      ),
                      _LangButton(
                        label: '日本語',
                        selected: _lang == 'ja',
                        onTap: () => setState(() => _lang = 'ja'),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.85),
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -40, right: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)),
                  ),
                ),
                Positioned(
                  bottom: -20, left: -20,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05)),
                  ),
                ),
                Positioned(
                  bottom: 24, left: 24, right: 24,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _lang == 'ja'
                              ? 'あなたの学習ハブ 📚'
                              : 'Your Learning Hub 📚',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.2),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _lang == 'ja'
                              ? '日本のピックルボールを学び、発見し、探求しよう'
                              : 'Learn, discover, and explore pickleball in Japan',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w400),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Info banner ──────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _lang == 'ja'
                                  ? 'Pikuru内の情報ハブ'
                                  : 'Your information hub inside Pikuru',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary),
                            ),
                          ),
                        ]),
                      ),

                      const SizedBox(height: 28),

                      // ── Loading skeleton ──────────────────────────────────
                      if (_loading) ...[
                        _SkeletonSection(),
                        const SizedBox(height: 28),
                        _SkeletonSection(),
                      ] else ...[
                        // ── Learn Pickleball ─────────────────────────────
                        _SectionHeader(
                          label: _lang == 'ja'
                              ? 'ピックルボールを学ぶ'
                              : 'Learn Pickleball',
                          icon: Icons.school_rounded,
                        ),
                        const SizedBox(height: 12),
                        _ResourceCard(
                          items: _learnItems,
                          lang:  _lang,
                          tFn:   _t,
                          onTap: _openDetail,
                        ),

                        const SizedBox(height: 28),

                        // ── Helpful Tools ────────────────────────────────
                        _SectionHeader(
                          label: _lang == 'ja' ? '便利なツール' : 'Helpful Tools',
                          icon: Icons.build_rounded,
                        ),
                        const SizedBox(height: 12),
                        _ResourceCard(
                          items: _toolsItems,
                          lang:  _lang,
                          tFn:   _t,
                          onTap: _openDetail,
                        ),
                      ],

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Language toggle button
// ─────────────────────────────────────────────────────────────────────────────
class _LangButton extends StatelessWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _LangButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withOpacity(0.9)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize:   11,
                fontWeight: FontWeight.w700,
                color: selected
                    ? AppColors.primary
                    : Colors.white.withOpacity(0.7))),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String   label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:        AppColors.primary.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primary, size: 17),
      ),
      const SizedBox(width: 10),
      Text(label,
          style: const TextStyle(
              fontSize:   16,
              fontWeight: FontWeight.w800,
              color:      AppColors.primary,
              letterSpacing: 0.1)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resource card — wraps a list of rows in a white rounded card
// ─────────────────────────────────────────────────────────────────────────────
class _ResourceCard extends StatelessWidget {
  final List<Map<String, dynamic>>   items;
  final String                        lang;
  final String Function(Map<String, dynamic>, String) tFn;
  final void Function(Map<String, dynamic>)            onTap;

  const _ResourceCard({
    required this.items,
    required this.lang,
    required this.tFn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Center(
          child: Text('No resources found.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:       Border.all(color: AppColors.primary.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color:      AppColors.primary.withOpacity(0.07),
              blurRadius: 16,
              offset:     const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final idx  = entry.key;
          final doc  = entry.value;
          final isLast = idx == items.length - 1;
          // Web uses href === '#' for coming-soon; we check a 'soon' bool
          // or fall back to checking if the doc has no real content route.
          final isSoon = doc['soon'] == true ||
              (doc['href'] ?? '').toString() == '#';

          return _ResourceTile(
            title:   tFn(doc, 'title'),
            subtitle: tFn(doc, 'sub'),
            docId:   (doc['_doc_id'] ?? doc['id'] ?? '').toString(),
            isSoon:  isSoon,
            isLast:  isLast,
            onTap:   isSoon ? null : () => onTap(doc),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Resource tile row
// ─────────────────────────────────────────────────────────────────────────────
class _ResourceTile extends StatelessWidget {
  final String   title;
  final String   subtitle;
  final String   docId;
  final bool     isSoon;
  final bool     isLast;
  final VoidCallback? onTap;

  const _ResourceTile({
    required this.title,
    required this.subtitle,
    required this.docId,
    required this.isSoon,
    required this.isLast,
    required this.onTap,
  });

  // Mirror web getIcon() — maps doc id → icon
  IconData _iconForId(String id) {
    switch (id) {
      case 'what-is-pickleball':
      case 'what-is-pikuru':
        return Icons.help_outline_rounded;
      case 'pickleball-rules':
        return Icons.menu_book_rounded;
      case 'scoring-rules':
        return Icons.gavel_rounded;
      case 'diagrams':
        return Icons.image_outlined;
      case 'about-pikuru':
        return Icons.info_rounded;
      case 'tennis-bear':
        return Icons.place_rounded;
      case 'meetup':
        return Icons.group_rounded;
      case 'local-gyms':
        return Icons.fitness_center_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(children: [
            // Icon badge
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color:        AppColors.primary.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_iconForId(docId),
                  color: AppColors.primary, size: 19),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize:   14,
                              fontWeight: FontWeight.w700,
                              color: isSoon
                                  ? Colors.black.withOpacity(0.4)
                                  : const Color(0xFF1A1A1A))),
                    ),
                    if (isSoon)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:        AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Soon',
                            style: TextStyle(
                                fontSize:   10,
                                fontWeight: FontWeight.w700,
                                color:      AppColors.primary,
                                letterSpacing: 0.3)),
                      ),
                  ]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12,
                            color:    Colors.grey.shade500,
                            height:   1.4)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: isSoon
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.4),
                size: 20),
          ]),
        ),
      ),
      if (!isLast)
        Divider(
            height: 1, thickness: 1,
            indent: 68,
            color: AppColors.primary.withOpacity(0.08)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Loading skeleton
// ─────────────────────────────────────────────────────────────────────────────
class _SkeletonSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Section header skeleton
      Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
              color:        Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8)),
        ),
        const SizedBox(width: 10),
        Container(
            width: 140, height: 14,
            decoration: BoxDecoration(
                color:        Colors.grey.shade200,
                borderRadius: BorderRadius.circular(6))),
      ]),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color:        Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:       Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: List.generate(3, (i) => Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                      color:        Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: double.infinity, height: 12,
                          decoration: BoxDecoration(
                              color:        Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6))),
                      const SizedBox(height: 6),
                      Container(
                          width: 120, height: 10,
                          decoration: BoxDecoration(
                              color:        Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6))),
                    ]),
              ),
            ]),
          )),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ResourceDetailScreen
//
// Mirrors web app's DynamicResourcePage ([id]/page.tsx):
//   • Fetches doc(db, 'resources', id) from Firestore
//   • Renders dynamically based on which fields exist in the localised map:
//     – t.sections   → multi-section grid layout (Rules/Scoring style)
//     – t.content    → single content block with optional images, keywords,
//                      greatForPoints (Meetup/Gyms/TennisBear style)
//     – t.aboutOrigin→ custom "What is Pikuru" / About layout
// ─────────────────────────────────────────────────────────────────────────────
class ResourceDetailScreen extends StatefulWidget {
  final String docId;
  final String lang;

  const ResourceDetailScreen(
      {super.key, required this.docId, required this.lang});

  @override
  State<ResourceDetailScreen> createState() => _ResourceDetailScreenState();
}

class _ResourceDetailScreenState extends State<ResourceDetailScreen>
    with TickerProviderStateMixin {
  bool   _loading  = true;
  Map<String, dynamic>? _docData;
  late String _lang;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _lang = widget.lang;

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    _fetch();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('resources')
          .doc(widget.docId)
          .get();
      if (mounted) {
        setState(() {
          _docData = snap.exists
              ? Map<String, dynamic>.from(snap.data()!)
              : null;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('[ResourceDetailScreen] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Localised content map ──────────────────────────────────────────────────
  Map<String, dynamic> get _t {
    if (_docData == null) return {};
    final langMap = _docData![_lang] ?? _docData!['en'];
    if (langMap is Map) return Map<String, dynamic>.from(langMap);
    return {};
  }

  String _s(String key) => (_t[key] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final hero    = _s('hero').isNotEmpty ? _s('hero') : _s('title');
    final heroSub = _s('heroSub').isNotEmpty ? _s('heroSub') : _s('sub');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero AppBar ────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      _LangButton(
                        label: 'EN',
                        selected: _lang == 'en',
                        onTap: () => setState(() => _lang = 'en'),
                      ),
                      _LangButton(
                        label: '日本語',
                        selected: _lang == 'ja',
                        onTap: () => setState(() => _lang = 'ja'),
                      ),
                    ]),
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary.withOpacity(0.85),
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: -40, right: -30,
                  child: Container(
                    width: 160, height: 160,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06)),
                  ),
                ),
                Positioned(
                  bottom: 24, left: 24, right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hero.isNotEmpty ? hero : 'Resource',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                              height: 1.2)),
                      if (heroSub.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(heroSub,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.72))),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),

          // ── Body ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _loading
                ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5)),
            )
                : _docData == null
                ? _buildNotFound()
                : FadeTransition(
              opacity: _fadeAnim,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 24),
                child: _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Text('Resource not found.',
            style: TextStyle(color: Colors.black38, fontSize: 15)),
      ),
    );
  }

  // ── Dynamic content renderer ───────────────────────────────────────────────
  Widget _buildContent() {
    final t = _t;

    // ── RENDERER 1: sections (Rules / Scoring style) ───────────────────
    if (t['sections'] is List && (t['sections'] as List).isNotEmpty) {
      return _buildSectionsLayout(t['sections'] as List);
    }

    // ── RENDERER 2: aboutOrigin (What is Pikuru / About style) ─────────
    if (t['aboutOrigin'] is Map) {
      return _buildAboutLayout(t);
    }

    // ── RENDERER 3: plain content block ────────────────────────────────
    if (t['content'] != null) {
      return _buildContentBlock(t);
    }

    return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No content available.',
              style: TextStyle(color: Colors.black38)),
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENDERER 1 — multi-section grid
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionsLayout(List sections) {
    return Column(
      children: sections.map<Widget>((sec) {
        final secMap = sec is Map ? Map<String, dynamic>.from(sec) : {};
        final title  = (secMap['title']  ?? '').toString();
        final points = secMap['points'] is List
            ? (secMap['points'] as List).map((e) => e.toString()).toList()
            : <String>[];
        final highlight = (secMap['highlight'] ?? '').toString();

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color:        Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:       Border.all(color: AppColors.primary.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                  color:      AppColors.primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset:     const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color:        AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize:   16,
                          fontWeight: FontWeight.w800,
                          color:      Color(0xFF0D0D0D))),
                ),
              ]),
              const SizedBox(height: 16),
              // Bullet points
              ...points.map((pt) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20, height: 20,
                      margin: const EdgeInsets.only(top: 1, right: 10),
                      decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.check_rounded,
                          size: 12, color: AppColors.primary),
                    ),
                    Expanded(
                      child: Text(pt,
                          style: const TextStyle(
                              fontSize: 14,
                              height:   1.5,
                              color:    Color(0xFF333438))),
                    ),
                  ],
                ),
              )),
              // Highlight callout
              if (highlight.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color:  AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(highlight,
                          style: const TextStyle(
                              fontSize:   13,
                              fontWeight: FontWeight.w600,
                              color:      AppColors.primary)),
                    ),
                  ]),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENDERER 2 — About / What is Pikuru layout
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAboutLayout(Map<String, dynamic> t) {
    final origin    = t['aboutOrigin'] is Map
        ? Map<String, dynamic>.from(t['aboutOrigin'] as Map)
        : <String, dynamic>{};
    final joinUs    = t['joinUs'] is Map
        ? Map<String, dynamic>.from(t['joinUs'] as Map)
        : <String, dynamic>{};
    final whatWeOffer = t['whatWeOffer'] is Map
        ? Map<String, dynamic>.from(t['whatWeOffer'] as Map)
        : <String, dynamic>{};
    final followUs  = t['followUs'] is Map
        ? Map<String, dynamic>.from(t['followUs'] as Map)
        : <String, dynamic>{};

    final offerItems = whatWeOffer['items'] is List
        ? (whatWeOffer['items'] as List)
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList()
        : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ── Origin ──────────────────────────────────────────────────────
        if (origin.isNotEmpty) ...[
          _DetailSectionLabel(
              (origin['title'] ?? '').toString()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecor(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((origin['p1'] ?? '').isNotEmpty)
                  _BodyText((origin['p1'] ?? '').toString()),
                if ((origin['p2'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BodyText((origin['p2'] ?? '').toString()),
                ],
                if ((origin['highlight'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:  AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 3,
                          height: 48,
                          decoration: BoxDecoration(
                              color:        AppColors.primary.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              (origin['highlight'] ?? '').toString(),
                              style: const TextStyle(
                                  fontSize:   14,
                                  fontStyle:  FontStyle.italic,
                                  height:     1.5,
                                  color:      Color(0xFF333438))),
                        ),
                      ],
                    ),
                  ),
                ],
                if ((origin['p3'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _BodyText((origin['p3'] ?? '').toString()),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── What We Offer ────────────────────────────────────────────────
        if (offerItems.isNotEmpty) ...[
          _DetailSectionLabel(
              (whatWeOffer['title'] ?? '').toString()),
          const SizedBox(height: 12),
          ...offerItems.map((item) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: _cardDecor(),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color:        AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(_iconForKey(item['icon'] ?? ''),
                    color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text((item['title'] ?? '').toString(),
                        style: const TextStyle(
                            fontSize:   14,
                            fontWeight: FontWeight.w700,
                            color:      Color(0xFF1A1A1A))),
                    const SizedBox(height: 2),
                    Text((item['sub'] ?? '').toString(),
                        style: TextStyle(
                            fontSize: 12,
                            color:    Colors.grey.shade500)),
                  ],
                ),
              ),
            ]),
          )),
          const SizedBox(height: 24),
        ],

        // ── Join Us ──────────────────────────────────────────────────────
        if (joinUs.isNotEmpty) ...[
          _DetailSectionLabel((joinUs['title'] ?? '').toString()),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecor(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((joinUs['p1'] ?? '').isNotEmpty)
                  _BodyText((joinUs['p1'] ?? '').toString()),
                if ((joinUs['p2'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text((joinUs['p2'] ?? '').toString(),
                      style: const TextStyle(
                          fontSize:   14,
                          fontWeight: FontWeight.w700,
                          color:      AppColors.primary,
                          height:     1.5)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // ── Follow Us ────────────────────────────────────────────────────
        if (followUs.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.85),
                  AppColors.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(children: [
              Text((followUs['title'] ?? '').toString(),
                  style: const TextStyle(
                      fontSize:   20,
                      fontWeight: FontWeight.w900,
                      color:      Colors.white,
                      letterSpacing: -0.4)),
              const SizedBox(height: 6),
              Text((followUs['sub'] ?? '').toString(),
                  style: TextStyle(
                      fontSize: 13,
                      color:    Colors.white.withOpacity(0.8))),
              const SizedBox(height: 20),
              // Social icon row
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _SocialBtn(icon: Icons.camera_alt_rounded),  // Instagram
                const SizedBox(width: 12),
                _SocialBtn(icon: Icons.facebook_rounded),    // Facebook
                const SizedBox(width: 12),
                _SocialBtn(icon: Icons.play_arrow_rounded),  // YouTube
                const SizedBox(width: 12),
                _SocialBtn(label: 'LINE'),
              ]),
            ]),
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RENDERER 3 — plain content block
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildContentBlock(Map<String, dynamic> t) {
    final content       = (t['content'] ?? '').toString();
    final images        = t['images'] is List
        ? (t['images'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final keywords      = t['keywords'] is List
        ? (t['keywords'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final searchTitle   = (t['searchTitle'] ?? '').toString();
    final greatForTitle = (t['greatForTitle'] ?? '').toString();
    final greatForPts   = t['greatForPoints'] is List
        ? (t['greatForPoints'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content paragraphs
        if (content.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: _cardDecor(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: content
                  .split('\n\n')
                  .where((p) => p.trim().isNotEmpty)
                  .map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _BodyText(p.trim()),
              ))
                  .toList(),
            ),
          ),

        // Images
        if (images.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...images.map((url) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:       Border.all(
                    color: AppColors.primary.withOpacity(0.12))),
            clipBehavior: Clip.antiAlias,
            child: Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox(height: 0)),
          )),
        ],

        // Great For points (Meetup style)
        if (greatForPts.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (greatForTitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(greatForTitle.toUpperCase(),
                  style: const TextStyle(
                      fontSize:   11,
                      fontWeight: FontWeight.w800,
                      color:      AppColors.primary,
                      letterSpacing: 1.0)),
            ),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: greatForPts.map((pt) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle),
                  child: Icon(Icons.check_rounded,
                      size: 13, color: AppColors.primary),
                ),
                const SizedBox(width: 8),
                Text(pt,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF333438))),
              ],
            )).toList(),
          ),
        ],

        // Keywords (Local Gyms style)
        if (keywords.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:        AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border:       Border.all(
                  color: AppColors.primary.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (searchTitle.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.search_rounded,
                        color: AppColors.primary, size: 16),
                    const SizedBox(width: 8),
                    Text(searchTitle.toUpperCase(),
                        style: const TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w800,
                            color:      AppColors.primary,
                            letterSpacing: 1.0)),
                  ]),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: keywords.map((kw) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color:        AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Text(kw,
                        style: const TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w700,
                            color:      AppColors.primary)),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
      ],
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  BoxDecoration _cardDecor() => BoxDecoration(
    color:        Colors.white,
    borderRadius: BorderRadius.circular(16),
    border:       Border.all(color: AppColors.primary.withOpacity(0.12)),
    boxShadow: [
      BoxShadow(
          color:      AppColors.primary.withOpacity(0.06),
          blurRadius: 12,
          offset:     const Offset(0, 3)),
    ],
  );

  // Mirror web getIcon() for detail screen
  IconData _iconForKey(String key) {
    switch (key) {
      case 'map-pin':  return Icons.place_rounded;
      case 'calendar': return Icons.calendar_month_rounded;
      case 'search':   return Icons.search_rounded;
      case 'news':     return Icons.newspaper_rounded;
      case 'phone':    return Icons.smartphone_rounded;
      default:         return Icons.circle_outlined;
    }
  }
}

// ── Shared detail screen sub-widgets ─────────────────────────────────────────
class _DetailSectionLabel extends StatelessWidget {
  final String label;
  const _DetailSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4, height: 20,
        decoration: BoxDecoration(
            color:        AppColors.primary,
            borderRadius: BorderRadius.circular(2)),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize:   17,
                fontWeight: FontWeight.w800,
                color:      Color(0xFF0D0D0D),
                letterSpacing: -0.3)),
      ),
    ]);
  }
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontSize: 14, height: 1.65, color: Color(0xFF444548)));
  }
}

class _SocialBtn extends StatelessWidget {
  final IconData? icon;
  final String?   label;
  const _SocialBtn({this.icon, this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  label != null ? null : 48,
      height: 48,
      padding: label != null
          ? const EdgeInsets.symmetric(horizontal: 16)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Center(
        child: label != null
            ? Text(label!,
            style: const TextStyle(
                color:      Colors.white,
                fontWeight: FontWeight.w800,
                fontSize:   14))
            : Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}