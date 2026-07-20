import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/theme/material.dart';

// ── Firestore model ───────────────────────────────────────────────────────────
class _ValueItem {
  final String icon;
  final String title;
  final String titleJp;
  final String desc;
  final String descJp;

  const _ValueItem({
    required this.icon,
    required this.title,
    required this.titleJp,
    required this.desc,
    required this.descJp,
  });

  factory _ValueItem.fromMap(Map<String, dynamic> m) => _ValueItem(
    icon:    (m['icon']     ?? '').toString(),
    title:   (m['title']    ?? '').toString(),
    titleJp: (m['title_jp'] ?? '').toString(),
    desc:    (m['desc']     ?? '').toString(),
    descJp:  (m['desc_jp']  ?? '').toString(),
  );
}

class _AboutDoc {
  final String headline;
  final String headlineJp;
  final String tagline;
  final String taglineJp;
  final String intro;
  final String introJp;
  final String introBold;
  final String introBoldJp;
  final String whyBody;
  final String whyBodyJp;
  final List<String> whyPoints;
  final List<String> whyPointsJp;
  final List<String> questions;
  final List<String> questionsJp;
  final String questionsCta;
  final String questionsCtaJp;
  final String ctaBody;
  final String ctaBodyJp;
  final List<_ValueItem> values;

  const _AboutDoc({
    required this.headline,       required this.headlineJp,
    required this.tagline,        required this.taglineJp,
    required this.intro,          required this.introJp,
    required this.introBold,      required this.introBoldJp,
    required this.whyBody,        required this.whyBodyJp,
    required this.whyPoints,      required this.whyPointsJp,
    required this.questions,      required this.questionsJp,
    required this.questionsCta,   required this.questionsCtaJp,
    required this.ctaBody,        required this.ctaBodyJp,
    required this.values,
  });

  factory _AboutDoc.fromMap(Map<String, dynamic> m) {
    List<String> strList(dynamic v) =>
        (v as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    return _AboutDoc(
      headline:       (m['headline']        ?? '').toString(),
      headlineJp:     (m['headline_jp']     ?? '').toString(),
      tagline:        (m['tagline']         ?? '').toString().replaceAll(r'\n', '\n'),
      taglineJp:      (m['tagline_jp']      ?? '').toString().replaceAll(r'\n', '\n'),
      intro:          (m['intro']           ?? '').toString(),
      introJp:        (m['intro_jp']        ?? '').toString(),
      introBold:      (m['intro_bold']      ?? '').toString(),
      introBoldJp:    (m['intro_bold_jp']   ?? '').toString(),
      whyBody:        (m['why_body']        ?? '').toString(),
      whyBodyJp:      (m['why_body_jp']     ?? '').toString(),
      whyPoints:      strList(m['why_points']),
      whyPointsJp:    strList(m['why_points_jp']),
      questions:      strList(m['questions']),
      questionsJp:    strList(m['questions_jp']),
      questionsCta:   (m['questions_cta']   ?? '').toString(),
      questionsCtaJp: (m['questions_cta_jp']?? '').toString(),
      ctaBody:        (m['cta_body']        ?? '').toString(),
      ctaBodyJp:      (m['cta_body_jp']     ?? '').toString(),
      values: (m['values'] as List<dynamic>? ?? [])
          .map((e) => _ValueItem.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────
class AboutPikuruScreen extends ConsumerStatefulWidget {
  const AboutPikuruScreen({super.key});

  @override
  ConsumerState<AboutPikuruScreen> createState() => _AboutPikuruScreenState();
}

class _AboutPikuruScreenState extends ConsumerState<AboutPikuruScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  _AboutDoc? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fetchAbout();
  }

  Future<void> _fetchAbout() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('about')
          .doc('about')
          .get();
      if (snap.exists && mounted) {
        setState(() {
          _data    = _AboutDoc.fromMap(snap.data()!);
          _loading = false;
        });
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // ── Language helpers ──────────────────────────────────────────────────────
  // Reads from global provider — no local state needed.
  bool get _isJa => ref.watch(appLangProvider) == kLangJa;

  String _p(String en, String jp) => (_isJa && jp.isNotEmpty) ? jp : en;
  List<String> _pl(List<String> en, List<String> jp) =>
      (_isJa && jp.isNotEmpty) ? jp : en;

  // ── Skeleton ──────────────────────────────────────────────────────────────
  Widget _skeleton({double height = 16, double? width}) => Container(
    height: height,
    width: width ?? double.infinity,
    margin: const EdgeInsets.only(bottom: 6),
    decoration: BoxDecoration(
      color: AppColors.primary.withOpacity(0.07),
      borderRadius: BorderRadius.circular(8),
    ),
  );

  @override
  Widget build(BuildContext context) {
    // Watch global lang so the whole build re-runs on any lang change.
    final lang = ref.watch(appLangProvider);
    final isJa = lang == kLangJa;

    final d = _data;

    final headline     = d == null ? '' : _p(d.headline,     d.headlineJp);
    final tagline      = d == null ? '' : _p(d.tagline,      d.taglineJp);
    final intro        = d == null ? '' : _p(d.intro,        d.introJp);
    final introBold    = d == null ? '' : _p(d.introBold,    d.introBoldJp);
    final whyBody      = d == null ? '' : _p(d.whyBody,      d.whyBodyJp);
    final whyPoints    = d == null ? <String>[] : _pl(d.whyPoints,  d.whyPointsJp);
    final questions    = d == null ? <String>[] : _pl(d.questions,  d.questionsJp);
    final questionsCta = d == null ? '' : _p(d.questionsCta, d.questionsCtaJp);
    final ctaBody      = d == null ? '' : _p(d.ctaBody,      d.ctaBodyJp);
    final values       = d?.values ?? <_ValueItem>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [

          // ── Hero App Bar ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            actions: [
              // Global lang toggle — tapping updates the whole app
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      final notifier = ref.read(appLangProvider.notifier);
                      notifier.setLang(isJa ? kLangEn : kLangJa);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.25)),
                      ),
                      child: Text(
                        isJa ? '日本語' : 'EN',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            title: Text(
              isJa ? 'Pikuruについて' : 'About Pikuru',
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600,
                fontSize: 18, letterSpacing: 0.3,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withOpacity(0.85),
                          AppColors.primary,
                          AppColors.primary.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                      top: -50, right: -30,
                      child: Container(
                          width: 180, height: 180,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06)))),
                  Positioned(
                      bottom: -30, left: -20,
                      child: Container(
                          width: 130, height: 130,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05)))),
                  Positioned(
                    bottom: 28, left: 24, right: 24,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _loading
                              ? Container(
                              height: 56, width: 260,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8)))
                              : Text(
                            headline,
                            style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w900,
                              color: Colors.white, letterSpacing: -0.5, height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _loading
                              ? Container(
                              height: 14, width: 140,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.10),
                                  borderRadius: BorderRadius.circular(6)))
                              : Text(
                            tagline,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.72),
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 28),

                      // ── Intro Card ──────────────────────────────────────
                      _HighlightCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                width: 4, height: 44,
                                decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(2))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _loading
                                  ? Column(children: [
                                _skeleton(height: 18),
                                _skeleton(height: 18, width: 200),
                              ])
                                  : RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    fontSize: 15,
                                    color: Colors.black87,
                                    height: 1.6,
                                  ),
                                  children: [
                                    TextSpan(text: intro),
                                    if (introBold.isNotEmpty) ...[
                                      const TextSpan(text: ' '),
                                      TextSpan(
                                        text: introBold,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Why Founded ─────────────────────────────────────
                      _SectionHeader(
                          title: isJa ? '設立の背景' : 'Why Pikuru Was Founded'),
                      const SizedBox(height: 12),

                      if (_loading)
                        _HighlightCard(
                            child: Column(children: [
                              _skeleton(),
                              _skeleton(),
                              _skeleton(width: 200),
                            ]))
                      else if (whyBody.isNotEmpty)
                        _HighlightCard(child: _BodyText(whyBody)),

                      if (whyPoints.isNotEmpty || _loading) ...[
                        const SizedBox(height: 12),
                        _loading
                            ? _HighlightCard(
                            child: Column(children: [
                              _skeleton(height: 28),
                              _skeleton(height: 28),
                              _skeleton(height: 28),
                            ]))
                            : _BulletCard(points: whyPoints),
                      ],

                      const SizedBox(height: 24),

                      // ── Questions Card ──────────────────────────────────
                      _SectionHeader(
                          title: isJa
                              ? '私たちが答えようとした問い'
                              : 'The Questions We Set Out to Answer'),
                      const SizedBox(height: 12),

                      _loading
                          ? _HighlightCard(
                          child: Column(children: [
                            _skeleton(height: 56),
                            _skeleton(height: 56),
                            _skeleton(height: 56),
                          ]))
                          : Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.primary.withOpacity(0.15)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.06),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Column(
                          children: [
                            ...questions.asMap().entries.map((e) {
                              final isLast =
                                  e.key == questions.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: isLast ? 0 : 12),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withOpacity(0.04),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withOpacity(0.10)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (e.key + 1)
                                            .toString()
                                            .padLeft(2, '0'),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.primary
                                              .withOpacity(0.5),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                            if (questionsCta.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Container(
                                  height: 1,
                                  color: AppColors.primary
                                      .withOpacity(0.08)),
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  questionsCta,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Values ──────────────────────────────────────────
                      _SectionHeader(
                          title: isJa ? '私たちの価値観' : 'Our Values'),
                      const SizedBox(height: 12),

                      _loading
                          ? Column(
                          children: [1, 2, 3]
                              .map((_) => Container(
                            height: 120,
                            margin: const EdgeInsets.only(
                                bottom: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withOpacity(0.05),
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                          ))
                              .toList())
                          : Column(
                        children: values.asMap().entries.map((e) {
                          final v = e.value;
                          final title = (isJa && v.titleJp.isNotEmpty)
                              ? v.titleJp
                              : v.title;
                          final desc = (isJa && v.descJp.isNotEmpty)
                              ? v.descJp
                              : v.desc;
                          return Container(
                            width: double.infinity,
                            margin: EdgeInsets.only(
                                bottom: e.key == values.length - 1
                                    ? 0
                                    : 12),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withOpacity(0.12)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary
                                        .withOpacity(0.10),
                                    borderRadius:
                                    BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(v.icon,
                                        style: const TextStyle(
                                            fontSize: 22)),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        desc,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF3A3A3A),
                                          height: 1.6,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 24),

                      // ── CTA Body ────────────────────────────────────────
                      if (_loading || ctaBody.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary.withOpacity(0.90),
                                AppColors.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: _loading
                              ? Column(children: [
                            _skeleton(height: 18),
                            _skeleton(height: 18, width: 200),
                          ])
                              : Text(
                            ctaBody,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              height: 1.6,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      const SizedBox(height: 48),
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

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _HighlightCard extends StatelessWidget {
  final Widget child;
  const _HighlightCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.07),
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: child,
  );
}

class _BulletCard extends StatelessWidget {
  final List<String> points;
  const _BulletCard({required this.points});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Column(
      children: points.asMap().entries.map((entry) {
        final isLast = entry.key == points.length - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(entry.value,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF3A3A3A),
                        height: 1.6,
                      ))),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 4,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
          child: Text(title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: 0.1,
              ))),
    ],
  );
}

class _BodyText extends StatelessWidget {
  final String text;
  const _BodyText(this.text);

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF3A3A3A),
        height: 1.7,
        letterSpacing: 0.1,
      ));
}