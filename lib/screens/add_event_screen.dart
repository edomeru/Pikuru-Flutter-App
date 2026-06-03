import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/add_event_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// i18n
// ─────────────────────────────────────────────────────────────────────────────
class _S {
  final String lang;
  const _S(this.lang);
  bool get isJa => lang == kLangJa;

  String get pageTitle   => isJa ? 'イベント追加'            : 'Add an Event';
  String get s1          => isJa ? '基本情報'                : 'Basic Details';
  String get s2          => isJa ? 'スケジュールと料金'       : 'Schedule & Fees';
  String get s3          => isJa ? '対象レベルと部門'         : 'Divisions & Levels';
  String get s4          => isJa ? '開催場所と主催者'         : 'Location & Org';
  String get s5          => isJa ? '説明とメディア'           : 'Description & Media';

  String get lblTitle    => isJa ? 'イベント名 *'            : 'Event Name *';
  String get lblType     => isJa ? 'イベントの種類 *'         : 'Event Type *';
  String get lblLink     => isJa ? '申し込み / イベントリンク' : 'Registration / Event Link';
  String get lblDate     => isJa ? '開催日 *'               : 'Date of Event *';
  String get lblDateEnd  => isJa ? '終了日 (任意)'           : 'End Date (Optional)';
  String get lblStart    => isJa ? '開始時間 * (例: 09:00)'  : 'Start Time (e.g. 09:00)';
  String get lblFee      => isJa ? '参加費 (例: 無料, ¥2000)': 'Fee (e.g. Free, ¥2000)';
  String get lblMax      => isJa ? '最大参加人数'             : 'Max Participants';
  String get lblStripe   => isJa ? 'Pikuruアプリで支払いを受け付けますか？' : 'Accept payment through Pikuru App?';
  String get stripeSub   => isJa ? '*Stripe手数料＋参加者1人あたり¥100の手数料がかかります。' : '*Stripe fees plus a ¥100 fee per participant will apply.';
  String get yes         => isJa ? 'はい'                   : 'Yes';
  String get no          => isJa ? 'いいえ'                 : 'No';
  String get lblSkill    => isJa ? 'スキルレベル'             : 'Skill Level';
  String get lblCat      => isJa ? 'イベントカテゴリー'        : 'Event Category';
  String get lblTourist  => isJa ? '観光客歓迎？'             : 'Tourist Friendly?';
  String get touristSub  => isJa ? '日本語が話せない観光客や訪問者を歓迎するイベントであることを示します。' : 'Welcoming to visitors and tourists, including non-Japanese speakers.';
  String get lblVenue    => isJa ? '会場名'                  : 'Venue Name / Hosted By';
  String get lblAddress  => isJa ? '会場の住所 *'             : 'Event Address *';
  String get lblMapLink  => isJa ? 'Googleマップリンク'       : 'Google Maps Link';
  String get lblOrgName  => isJa ? '主催者 (団体名)'          : 'Organization Name';
  String get lblContact  => isJa ? '連絡用メールアドレス *'    : 'Contact Email *';
  String get lblDesc     => isJa ? 'イベント説明 *'           : 'Event Description *';
  String get plDesc      => isJa ? 'イベントの詳細、ルール、スケジュールなどを記入してください。' : 'Talk about the event, rules, schedule, etc.';
  String get lblCover    => isJa ? '可能であればフライヤーを添付してください。' : 'Event Flyer / Cover Image';
  String get selImg      => isJa ? '画像を選択'               : 'Select Event Image';
  String get imgSub      => isJa ? 'この画像はサムネイルとして使われます。' : "We'll use this as the event thumbnail.";
  String get translateHint => isJa ? '送信時に EN・JP 両方へ自動翻訳されます' : 'Auto-translated to both EN & JP on submit';
  String get reviewNote  => isJa ? '送信されたイベントは審査後、48時間以内に公開されます。' : 'Submitted events go through a review process and will be visible within 48 hours of approval.';
  String get searchVenue => isJa ? '会場・住所を検索...'        : 'Search venue or address…';
  String get tapToDrop   => isJa ? 'タップしてピンを立てる'      : 'Tap map to drop a pin';
  String get back        => isJa ? '戻る'                   : 'Back';
  String get cont        => isJa ? '次へ'                   : 'Continue';
  String get create      => isJa ? 'イベントを作成'           : 'Create Event';
  String get errFields   => isJa ? 'タイトル、日付、住所、連絡先メールを入力してください。' : 'Please fill in Title, Date, Address, and Contact Email.';
  String get errExtLink  => isJa ? '外部登録URLを入力してください。' : 'Please enter the external registration URL.';
  String get noImageNote => isJa ? '画像なしで保存しました。'    : 'Could not upload image — saving without it.';
  String get submitted   => isJa ? 'イベントを審査に送信しました！' : 'Event submitted for review!';

  // ── Registration Option strings (mirrors web app T exactly) ────────────────
  String get lblRegOption        => isJa ? '登録方法のオプション'          : 'Registration Option';
  String get regOptionPikuru     => isJa ? 'Pikuruで登録を受け付ける'      : 'Register through Pikuru';
  String get regOptionPikuruSub  => isJa ? '参加者はこのアプリ内で直接登録を行います。' : 'Participants register directly on this app.';
  String get regOptionExternal   => isJa ? '外部の登録リンクを使用する'     : 'External Registration Link';
  String get regOptionExtSub     => isJa ? '参加者を外部の登録用のウェブサイトにリダイレクトします。' : 'Redirect participants to an external registration website.';
  String get lblExternalLink     => isJa ? '外部の登録URL *'              : 'External Registration URL *';

  // Skills
  String get skillBeginner => isJa ? '初級' : 'Beginner';
  String get skillAmateur  => isJa ? '中級' : 'Amateur';
  String get skillPro      => isJa ? '上級' : 'Pro';

  // Categories
  String get catMs => isJa ? '男子シングルス'  : "Men's Singles";
  String get catWs => isJa ? '女子シングルス'  : "Women's Singles";
  String get catMd => isJa ? '男子ダブルス'   : "Men's Doubles";
  String get catWd => isJa ? '女子ダブルス'   : "Women's Doubles";
  String get catMx => isJa ? 'ミックスダブルス' : 'Mixed Doubles';
  String get catJu => isJa ? 'ジュニア'       : 'Juniors';
  String get catCo => isJa ? '学生'           : 'Collegiate';
  String get catSe => isJa ? 'シニア'         : 'Seniors';

  List<String> get typeKeys => [
    'Professional Tournament', 'Global Tournament', 'Japan Tournament',
    'Open Play', 'Trial Session', 'Local Event',
    'Lessons/Clinics', 'Weekly Play / Recurring Play',
  ];
  String localizeType(String key) {
    if (!isJa) return key;
    const m = {
      'Professional Tournament':      'プロトーナメント',
      'Global Tournament':            'グローバルトーナメント',
      'Japan Tournament':             '日本トーナメント',
      'Open Play':                    'オープンプレイ',
      'Trial Session':                '体験セッション',
      'Local Event':                  'ローカルイベント',
      'Lessons/Clinics':              'レッスン・クリニック',
      'Weekly Play / Recurring Play': '定期プレイ',
    };
    return m[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
bool _isJapanese(String t) =>
    RegExp(r'[\u3040-\u30FF\u4E00-\u9FFF\uFF65-\uFF9F]').hasMatch(t);

Future<String> _translateText(String text, String targetLang) async {
  if (text.trim().isEmpty) return text;
  try {
    final uri = Uri.parse(
      'https://translate.googleapis.com/translate_a/single'
          '?client=gtx&sl=auto&tl=$targetLang&dt=t'
          '&q=${Uri.encodeComponent(text)}',
    );
    final client = HttpClient();
    final request = await client.getUrl(uri);
    final response = await request.close();
    final raw = await response.transform(const Utf8Decoder()).join();
    final decoded = jsonDecode(raw) as List;
    return (decoded[0] as List)
        .map((item) => (item as List).first?.toString() ?? '')
        .join();
  } catch (_) { return text; }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class AddEventScreen extends ConsumerStatefulWidget {
  const AddEventScreen({
    super.key,
    this.initialOrgName,
    this.initialVenueName,
    this.initialCity,
    this.initialPrefecture,
    this.initialCountry,
    this.initialContactEmail,
    this.initialLink,
  });

  final String? initialOrgName;
  final String? initialVenueName;
  final String? initialCity;
  final String? initialPrefecture;
  final String? initialCountry;
  final String? initialContactEmail;
  final String? initialLink;

  @override
  ConsumerState<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends ConsumerState<AddEventScreen> {
  late PageController _pageController;
  int _currentPage = 0;

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg         = Color(0xFFF4FAF5);
  static const Color _surface    = Color(0xFFFFFFFF);
  static const Color _primary    = Color(0xFF2E7D4F);
  static const Color _accent     = Color(0xFF52B76E);
  static const Color _accentSoft = Color(0xFFD6EFD9);
  static const Color _textDark   = Color(0xFF1A2E1F);
  static const Color _textMid    = Color(0xFF4A6651);
  static const Color _textLight  = Color(0xFF8FB398);
  static const Color _border     = Color(0xFFCDE5D1);
  static const Color _errorRed   = Color(0xFFE53935);

  _S get s => _S(ref.watch(appLangProvider));
  List<String> get _stepLabels => [s.s1, s.s2, s.s3, s.s4, s.s5];

  // ── Controllers ───────────────────────────────────────────────────────────
  late TextEditingController _titleController;
  late TextEditingController _linkController;
  late TextEditingController _feeController;
  late TextEditingController _maxController;
  late TextEditingController _contactController;
  late TextEditingController _descController;
  late TextEditingController _startTimeController;
  late TextEditingController _venueNameController;
  late TextEditingController _venueAddressController;
  late TextEditingController _venueMapLinkController;
  late TextEditingController _orgNameController;
  late TextEditingController _mapSearchController;
  late TextEditingController _externalLinkController;

  // ── Map state ─────────────────────────────────────────────────────────────
  GoogleMapController? _mapController;
  LatLng  _mapCenter    = const LatLng(35.6895, 139.6917);
  LatLng? _markerPos;
  bool    _searchLoading = false;
  Timer?  _searchDebounce;

  // ── Form state ────────────────────────────────────────────────────────────
  String    _eventType         = 'Open Play';
  String    _registrationType  = 'pikuru';
  DateTime? _eventDate;
  DateTime? _eventDateEnd;
  bool _acceptStripe    = false;
  bool _touristFriendly = false;
  bool _skillBeginner   = false;
  bool _skillAmateur    = false;
  bool _skillPro        = false;
  bool _catMs = false, _catWs = false, _catMd = false, _catWd = false;
  bool _catMx = false, _catJu = false, _catCo = false, _catSe = false;

  File? _imageFile;
  bool  _isLoading = false;

  @override
  void initState() {
    super.initState();
    _pageController         = PageController();
    _titleController        = TextEditingController();
    _linkController         = TextEditingController();
    _feeController          = TextEditingController();
    _maxController          = TextEditingController();
    _contactController      = TextEditingController();
    _descController         = TextEditingController();
    _startTimeController    = TextEditingController();
    _venueNameController    = TextEditingController();
    _venueAddressController = TextEditingController();
    _venueMapLinkController = TextEditingController();
    _orgNameController      = TextEditingController();
    _mapSearchController    = TextEditingController();
    _externalLinkController = TextEditingController();

    if (widget.initialOrgName?.isNotEmpty == true)
      _orgNameController.text = widget.initialOrgName!;
    if (widget.initialVenueName?.isNotEmpty == true)
      _venueNameController.text = widget.initialVenueName!;
    if (widget.initialCity?.isNotEmpty == true) {
      _venueAddressController.text = [
        widget.initialVenueName ?? '',
        widget.initialCity ?? '',
        widget.initialPrefecture ?? '',
        widget.initialCountry ?? '',
      ].where((s) => s.isNotEmpty).join(', ');
    }
    if (widget.initialContactEmail?.isNotEmpty == true)
      _contactController.text = widget.initialContactEmail!;
    if (widget.initialLink?.isNotEmpty == true)
      _linkController.text = widget.initialLink!;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    _searchDebounce?.cancel();
    for (final c in [
      _titleController, _linkController, _feeController, _maxController,
      _contactController, _descController, _startTimeController,
      _venueNameController, _venueAddressController, _venueMapLinkController,
      _orgNameController, _mapSearchController, _externalLinkController,
    ]) { c.dispose(); }
    super.dispose();
  }

  // ── Map helpers ───────────────────────────────────────────────────────────
  Future<void> _onMapTap(LatLng pos) async {
    setState(() => _markerPos = pos);
    _mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    await _fillFromLatLng(pos);
  }

  Future<void> _fillFromLatLng(LatLng pos) async {
    final mapsLink =
        'https://www.google.com/maps/search/?api=1&query=${pos.latitude},${pos.longitude}';
    setState(() => _venueMapLinkController.text = mapsLink);
    try {
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.street, p.locality, p.administrativeArea, p.country]
            .where((s) => s != null && s.isNotEmpty).toList();
        final rawName   = p.name?.trim() ?? '';
        final street    = p.street?.trim() ?? '';
        final isNumeric = RegExp(r'^[\d\-‐–—/\s]+$').hasMatch(rawName);
        final isPrefix  = street.isNotEmpty && street.startsWith(rawName) &&
            rawName.length <= street.length;
        final isValid   = rawName.isNotEmpty && !isNumeric &&
            rawName != street && !isPrefix;
        setState(() {
          _venueAddressController.text = parts.join(', ');
          if (_venueNameController.text.isEmpty && isValid) {
            _venueNameController.text = rawName;
          }
        });
      }
    } catch (_) {}
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) return;
    _searchDebounce = Timer(const Duration(milliseconds: 600),
            () => _searchPlace(query));
  }

  Future<void> _searchPlace(String query) async {
    if (!mounted) return;
    setState(() => _searchLoading = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        final pos = LatLng(loc.latitude, loc.longitude);
        setState(() { _markerPos = pos; _mapCenter = pos; _searchLoading = false; });
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pos, 15));
        await _fillFromLatLng(pos);
        _mapSearchController.clear();
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        if (mounted) setState(() => _searchLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  // ── Image ─────────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 85);
    if (picked != null && mounted) setState(() => _imageFile = File(picked.path));
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final title   = _titleController.text.trim();
    final address = _venueAddressController.text.trim();
    final contact = _contactController.text.trim();
    final desc    = _descController.text.trim();

    if (title.isEmpty || _eventDate == null || address.isEmpty || contact.isEmpty) {
      _showSnack(s.errFields, isError: true);
      return;
    }

    if (_registrationType == 'external' &&
        _externalLinkController.text.trim().isEmpty) {
      _showSnack(s.errExtLink, isError: true);
      return;
    }

    // ── Get the current authenticated user's UID (mirrors web app: user.uid) ─
    final currentUser = FirebaseAuth.instance.currentUser;
    final submittedByUid = currentUser?.uid ?? '';

    setState(() => _isLoading = true);
    try {
      // ── Image upload ──────────────────────────────────────────────────────
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final storageRef = FirebaseStorage.instance.ref(
              'event_images/${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}');
          final snap = await storageRef.putFile(_imageFile!)
              .timeout(const Duration(seconds: 30));
          imageUrl = await snap.ref.getDownloadURL();
        } catch (_) {
          if (mounted) _showSnack(s.noImageNote);
        }
      }

      // ── Bilingual title ───────────────────────────────────────────────────
      String titleEn, titleJp;
      if (_isJapanese(title)) {
        titleJp = title;
        titleEn = await _translateText(title, 'en');
      } else {
        titleEn = title;
        titleJp = await _translateText(title, 'ja');
      }

      // ── Bilingual description ─────────────────────────────────────────────
      String descEn, descJp;
      if (_isJapanese(desc)) {
        descJp = desc;
        descEn = await _translateText(desc, 'en');
      } else {
        descEn = desc;
        descJp = await _translateText(desc, 'ja');
      }

      // ── Timestamps ────────────────────────────────────────────────────────
      final eventDateTs    = Timestamp.fromDate(_eventDate!);
      final eventDateEndTs = _eventDateEnd != null
          ? Timestamp.fromDate(_eventDateEnd!) : null;
      Timestamp? startTs;
      final timeStr = _startTimeController.text.trim();
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          startTs = Timestamp.fromDate(DateTime(
            _eventDate!.year, _eventDate!.month, _eventDate!.day,
            int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0,
          ));
        }
      }

      // ── Firestore document ────────────────────────────────────────────────
      await FirebaseFirestore.instance.collection('events').add({
        // Review flags
        'event_pending_review': true,
        'event_checked':        false,
        'event_active':         false,
        'event_status':         false,

        'event_added':   FieldValue.serverTimestamp(),
        'event_created': FieldValue.serverTimestamp(),
        'event_updated': FieldValue.serverTimestamp(),

        // Bilingual title
        'event_title':    titleEn,
        'event_title_en': titleEn,
        'event_title_jp': titleJp,

        'event_type': _eventType,
        'event_link': _linkController.text.trim(),

        // Registration option fields (mirrors web app docData exactly)
        'registration_type': _registrationType,
        'external_registration_link': _registrationType == 'external'
            ? _externalLinkController.text.trim()
            : '',

        'event_date':       eventDateTs,
        'event_date_end':   eventDateEndTs,
        'event_time':       startTs,
        'event_start_date': startTs,
        'event_fee':        _feeController.text.trim(),
        'event_limit':      _maxController.text.trim().isNotEmpty
            ? int.tryParse(_maxController.text.trim()) : null,
        'event_stripe_setup': _acceptStripe,

        'event_skill_level_beginner': _skillBeginner,
        'event_skill_level_amateur':  _skillAmateur,
        'event_skill_level_pro':      _skillPro,

        'event_category_menssingle':    _catMs,
        'event_category_womenssingle':  _catWs,
        'event_category_mensdoubles':   _catMd,
        'event_category_womensdoubles': _catWd,
        'event_category_mixeddoubles':  _catMx,
        'event_category_juniors':       _catJu,
        'event_category_collegiate':    _catCo,
        'event_category_seniors':       _catSe,

        'event_touristfriendly': _touristFriendly,

        'event_venue_name':    _venueNameController.text.trim(),
        'event_venue_address': address,
        'event_venue_link':    _venueMapLinkController.text.trim(),
        'event_org_name':      _orgNameController.text.trim(),
        'event_loc_id':        '',
        'event_org_id':        '',

        'event_contact':        contact,
        'event_description_en': descEn,
        'event_description_jp': descJp,

        'event_pic':           imageUrl,
        'event_pic_thumbnail': imageUrl,

        // ── FIXED: populate submittedBy and event_addedby with the current
        //    user's UID, exactly as the web app does with user.uid ────────────
        'event_addedby': submittedByUid,
        'submittedBy':   submittedByUid,
      });

      if (mounted) {
        _showSnack(s.submitted);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _errorRed : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                  color: _primary.withOpacity(0.08),
                  blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(s.pageTitle, style: const TextStyle(
              color: _textDark, fontWeight: FontWeight.w800,
              fontSize: 18, letterSpacing: -0.5)),
          Text(_stepLabels[_currentPage], style: const TextStyle(
              color: _accent, fontWeight: FontWeight.w500, fontSize: 12)),
        ]),
        centerTitle: true,
      ),
      body: Column(children: [
        _buildStepIndicator(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildDetailsPage(),
              _buildSchedulePage(),
              _buildDivisionsPage(),
              _buildVenuePage(),
              _buildMediaPage(),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Step indicator
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_stepLabels.length, (i) {
          final active = i <= _currentPage;
          return Expanded(child: Row(children: [
            Expanded(child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                color: active ? _accent : _border,
                borderRadius: BorderRadius.circular(2),
              ),
            )),
            if (i < _stepLabels.length - 1) const SizedBox(width: 4),
          ]));
        }),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 1 – Basic Details
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDetailsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(s.s1, Icons.info_outline),

        // Event Name
        _buildTextField(label: s.lblTitle, controller: _titleController,
            hint: 'e.g. UTR Pickleball Japan Tour 2026'),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.translate_rounded, size: 13, color: _textLight),
          const SizedBox(width: 5),
          Text(s.translateHint, style: const TextStyle(color: _textLight, fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        // Registration Option
        _buildRegistrationOptionSection(),
        const SizedBox(height: 20),

        // Event Type
        _buildLabel(s.lblType),
        const SizedBox(height: 6),
        _buildDropdown(
          value: _eventType,
          items: s.typeKeys,
          onChanged: (v) => setState(() => _eventType = v!),
          labelBuilder: s.localizeType,
        ),
        const SizedBox(height: 14),

        // Link (shown only for pikuru type)
        if (_registrationType == 'pikuru') ...[
          _buildTextField(label: s.lblLink, controller: _linkController,
              hint: 'https://', keyboardType: TextInputType.url),
          const SizedBox(height: 20),
        ],

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _accentSoft,
              borderRadius: BorderRadius.circular(12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, size: 16, color: _primary),
            const SizedBox(width: 8),
            Expanded(child: Text(s.reviewNote, style: const TextStyle(
                color: _primary, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4))),
          ]),
        ),
      ]),
    );
  }

  // ── Registration Option section widget ────────────────────────────────────
  Widget _buildRegistrationOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(s.lblRegOption),
        const SizedBox(height: 10),

        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: _RegistrationOptionCard(
              title: s.regOptionPikuru,
              subtitle: s.regOptionPikuruSub,
              isSelected: _registrationType == 'pikuru',
              onTap: () => setState(() {
                _registrationType = 'pikuru';
              }),
              primaryColor: _primary,
              accentSoftColor: _accentSoft,
              borderColor: _border,
              surfaceColor: _surface,
              textDarkColor: _textDark,
              textLightColor: _textLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RegistrationOptionCard(
              title: s.regOptionExternal,
              subtitle: s.regOptionExtSub,
              isSelected: _registrationType == 'external',
              onTap: () => setState(() {
                _registrationType = 'external';
              }),
              primaryColor: _primary,
              accentSoftColor: _accentSoft,
              borderColor: _border,
              surfaceColor: _surface,
              textDarkColor: _textDark,
              textLightColor: _textLight,
            ),
          ),
        ]),

        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _registrationType == 'external'
              ? Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _buildTextField(
              label: s.lblExternalLink,
              controller: _externalLinkController,
              hint: 'https://',
              keyboardType: TextInputType.url,
            ),
          )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 2 – Schedule & Fees
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(s.s2, Icons.calendar_today_outlined),

        _buildLabel(s.lblDate),
        const SizedBox(height: 6),
        _buildDatePicker(value: _eventDate, hint: s.lblDate,
            onPicked: (d) => setState(() => _eventDate = d)),
        const SizedBox(height: 14),

        _buildLabel(s.lblDateEnd),
        const SizedBox(height: 6),
        _buildDatePicker(value: _eventDateEnd, hint: s.lblDateEnd,
            onPicked: (d) => setState(() => _eventDateEnd = d)),
        const SizedBox(height: 14),

        _buildTextField(label: s.lblStart, controller: _startTimeController,
            hint: '09:00', keyboardType: TextInputType.datetime),
        const SizedBox(height: 14),

        Row(children: [
          Expanded(child: _buildTextField(label: s.lblFee, controller: _feeController,
              hint: '¥2,000')),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(label: s.lblMax, controller: _maxController,
              hint: 'e.g. 64', keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 20),

        _buildSectionCard(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.lblStripe, style: const TextStyle(
                  color: _textDark, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                _buildRadioOption(s.yes, true, _acceptStripe,
                        (v) => setState(() => _acceptStripe = v)),
                const SizedBox(width: 24),
                _buildRadioOption(s.no, false, _acceptStripe,
                        (v) => setState(() => _acceptStripe = v)),
              ]),
              const SizedBox(height: 8),
              Text(s.stripeSub, style: const TextStyle(
                  color: _textLight, fontSize: 11, fontStyle: FontStyle.italic)),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 3 – Divisions & Levels
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDivisionsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(s.s3, Icons.emoji_events_outlined),

        _buildLabel(s.lblSkill),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildSkillChip(s.skillBeginner, _skillBeginner,
                  (v) => setState(() => _skillBeginner = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip(s.skillAmateur, _skillAmateur,
                  (v) => setState(() => _skillAmateur = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip(s.skillPro, _skillPro,
                  (v) => setState(() => _skillPro = v))),
        ]),

        const SizedBox(height: 24),
        _buildLabel(s.lblCat),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow(s.catMs, _catMs, (v) => setState(() => _catMs = v), Icons.person_outline),
          _buildCategoryRow(s.catWs, _catWs, (v) => setState(() => _catWs = v), Icons.person_outline),
          _buildCategoryRow(s.catMd, _catMd, (v) => setState(() => _catMd = v), Icons.people_outline),
          _buildCategoryRow(s.catWd, _catWd, (v) => setState(() => _catWd = v), Icons.people_outline),
          _buildCategoryRow(s.catMx, _catMx, (v) => setState(() => _catMx = v), Icons.people_outline),
          _buildCategoryRow(s.catJu, _catJu, (v) => setState(() => _catJu = v), Icons.child_care_outlined),
          _buildCategoryRow(s.catCo, _catCo, (v) => setState(() => _catCo = v), Icons.school_outlined),
          _buildCategoryRow(s.catSe, _catSe, (v) => setState(() => _catSe = v), Icons.elderly_outlined),
        ]),

        const SizedBox(height: 24),
        _buildSectionCard(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.lblTourist, style: const TextStyle(
                  color: _textDark, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(s.touristSub, style: const TextStyle(
                  color: _textLight, fontSize: 11, height: 1.4)),
              const SizedBox(height: 12),
              Row(children: [
                _buildRadioOption(s.yes, true, _touristFriendly,
                        (v) => setState(() => _touristFriendly = v)),
                const SizedBox(width: 24),
                _buildRadioOption(s.no, false, _touristFriendly,
                        (v) => setState(() => _touristFriendly = v)),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 4 – Venue
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildVenuePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(s.s4, Icons.place_outlined),

        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 300,
            decoration: BoxDecoration(
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(16)),
            child: Stack(children: [
              GoogleMap(
                initialCameraPosition:
                CameraPosition(target: _mapCenter, zoom: 13),
                onMapCreated: (c) => _mapController = c,
                onTap: _onMapTap,
                markers: _markerPos != null ? {
                  Marker(markerId: const MarkerId('venue'),
                      position: _markerPos!,
                      infoWindow: const InfoWindow(title: 'Event Venue')),
                } : {},
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),
              Positioned(
                top: 12, left: 12, right: 12,
                child: Container(
                  decoration: BoxDecoration(color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14),
                        blurRadius: 10, offset: const Offset(0, 3))],
                  ),
                  child: TextField(
                    controller: _mapSearchController,
                    onChanged: _onSearchChanged,
                    onSubmitted: _searchPlace,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(color: _textDark, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: s.searchVenue,
                      hintStyle: const TextStyle(color: _textLight, fontSize: 13),
                      prefixIcon: _searchLoading
                          ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(_accent))))
                          : const Icon(Icons.search_rounded, color: _textLight, size: 20),
                      suffixIcon: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _mapSearchController,
                        builder: (_, v, __) => v.text.isNotEmpty
                            ? IconButton(icon: const Icon(Icons.clear,
                            color: _textLight, size: 18),
                            onPressed: () => _mapSearchController.clear())
                            : const SizedBox.shrink(),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 14),
                    ),
                  ),
                ),
              ),
              if (_markerPos == null)
                Positioned(bottom: 12, left: 0, right: 0,
                  child: Center(child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                        color: _textDark.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(s.tapToDrop, style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  )),
                ),
            ]),
          ),
        ),

        const SizedBox(height: 16),
        _buildTextField(label: s.lblAddress, controller: _venueAddressController,
            hint: 'Auto-filled from map or type manually'),
        const SizedBox(height: 14),
        _buildTextField(label: s.lblMapLink, controller: _venueMapLinkController,
            hint: 'Auto-filled from map or paste link',
            keyboardType: TextInputType.url),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _buildTextField(label: s.lblVenue,
              controller: _venueNameController, hint: 'e.g. Shibuya Sports Center')),
          const SizedBox(width: 12),
          Expanded(child: _buildTextField(label: s.lblOrgName,
              controller: _orgNameController, hint: 'e.g. Tokyo Pickleball Assoc.')),
        ]),
        const SizedBox(height: 14),
        _buildTextField(label: s.lblContact, controller: _contactController,
            hint: 'email@example.com', keyboardType: TextInputType.emailAddress),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Page 5 – Description & Media
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(s.s5, Icons.image_outlined),

        _buildTextField(label: s.lblDesc, controller: _descController,
            hint: s.plDesc, maxLines: 6),
        const SizedBox(height: 6),
        Row(children: [
          Icon(Icons.translate_rounded, size: 13, color: _textLight),
          const SizedBox(width: 5),
          Text(s.translateHint,
              style: const TextStyle(color: _textLight, fontSize: 11)),
        ]),
        const SizedBox(height: 20),

        _buildLabel(s.lblCover),
        const SizedBox(height: 4),
        Text(s.imgSub, style: const TextStyle(color: _textLight, fontSize: 11)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 120,
            decoration: BoxDecoration(
              color: _imageFile != null ? Colors.transparent : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _imageFile != null ? _accent : _border,
                  width: _imageFile != null ? 1.5 : 1),
            ),
            clipBehavior: Clip.hardEdge,
            child: _imageFile != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Positioned(bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _textDark.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_rounded, size: 13, color: Colors.white),
                    SizedBox(width: 5),
                    Text('Change', style: TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: _primary, size: 24),
              ),
              const SizedBox(height: 8),
              Text(s.selImg, style: const TextStyle(
                  color: _textMid, fontSize: 13,
                  fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(s.imgSub, style: const TextStyle(
                  color: _textLight, fontSize: 11)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Bottom nav
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isLast = _currentPage == _stepLabels.length - 1;
    return Container(
      color: _surface,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          left: 20, right: 20, top: 16),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(child: OutlinedButton(
            onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut),
            style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: Text(s.back, style: const TextStyle(
                color: _textMid, fontWeight: FontWeight.w600, fontSize: 15)),
          )),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (isLast) {
                _submitForm();
              } else {
                _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut);
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _accent.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14))),
            child: _isLoading
                ? const SizedBox(height: 20, width: 20,
                child: CircularProgressIndicator(strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(isLast ? s.create : s.cont,
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Shared widget helpers
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPageHeader(String title, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _accentSoft,
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _primary, size: 22)),
      const SizedBox(width: 14),
      Text(title, style: const TextStyle(color: _textDark,
          fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.3)),
    ]),
  );

  Widget _buildLabel(String text) => Text(text, style: const TextStyle(
      color: _textMid, fontSize: 13, fontWeight: FontWeight.w700,
      letterSpacing: 0.2));

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _buildLabel(label),
    const SizedBox(height: 6),
    TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: _textDark, fontSize: 14,
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textLight, fontSize: 14),
        filled: true, fillColor: _surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _accent, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    ),
  ]);

  Widget _buildDatePicker({
    required DateTime? value,
    required String hint,
    required ValueChanged<DateTime> onPicked,
  }) => GestureDetector(
    onTap: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: value ?? DateTime.now().add(const Duration(days: 7)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(
              primary: _primary, onSurface: _textDark)),
          child: child!,
        ),
      );
      if (picked != null) onPicked(picked);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surface, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value != null ? _accent : _border),
      ),
      child: Row(children: [
        Icon(Icons.calendar_month_rounded,
            color: value != null ? _primary : _textLight, size: 18),
        const SizedBox(width: 10),
        Text(
          value != null
              ? s.isJa
              ? '${value.year}年${value.month}月${value.day}日'
              : '${value.year}/${value.month.toString().padLeft(2,'0')}/${value.day.toString().padLeft(2,'0')}'
              : hint,
          style: TextStyle(color: value != null ? _textDark : _textLight,
              fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ]),
    ),
  );

  Widget _buildRadioOption<T>(
      String label, T optionValue, T groupValue, ValueChanged<T> onChanged) {
    final selected = optionValue == groupValue;
    return GestureDetector(
      onTap: () => onChanged(optionValue),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 20, height: 20,
          decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? _primary : _border, width: 2)),
          child: selected ? Center(child: Container(width: 10, height: 10,
              decoration: const BoxDecoration(color: _primary,
                  shape: BoxShape.circle))) : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            color: selected ? _textDark : _textMid, fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ]),
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String Function(String) labelBuilder,
  }) => Container(
    decoration: BoxDecoration(color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border)),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isExpanded: true,
        icon: const Icon(Icons.keyboard_arrow_down_rounded,
            color: _textLight, size: 20),
        dropdownColor: _surface,
        style: const TextStyle(color: _textDark, fontSize: 14,
            fontWeight: FontWeight.w500),
        items: items.map((item) => DropdownMenuItem(value: item,
            child: Text(labelBuilder(item),
                style: const TextStyle(color: _textDark, fontSize: 14)))).toList(),
        onChanged: onChanged,
      ),
    ),
  );

  Widget _buildSkillChip(String label, bool selected, ValueChanged<bool> onChanged) =>
      GestureDetector(
        onTap: () => onChanged(!selected),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _primary : _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? _primary : _border,
                width: selected ? 1.5 : 1),
            boxShadow: selected
                ? [BoxShadow(color: _primary.withOpacity(0.25),
                blurRadius: 8, offset: const Offset(0, 3))]
                : [BoxShadow(color: _primary.withOpacity(0.04),
                blurRadius: 4, offset: const Offset(0, 1))],
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(color: selected ? Colors.white : _textMid,
                  fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      );

  Widget _buildSectionCard({required List<Widget> children}) => Container(
    decoration: BoxDecoration(color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: _primary.withOpacity(0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
    child: Column(
      children: children.asMap().entries.map((e) {
        final isLast = e.key == children.length - 1;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          e.value,
          if (!isLast) const Divider(height: 1, color: _border,
              indent: 16, endIndent: 16),
        ]);
      }).toList(),
    ),
  );

  Widget _buildCategoryRow(String label, bool value,
      ValueChanged<bool> onChanged, IconData icon) => InkWell(
    onTap: () => onChanged(!value),
    borderRadius: BorderRadius.circular(16),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, size: 18, color: value ? _primary : _textLight),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: TextStyle(
            color: value ? _textDark : _textMid, fontSize: 14,
            fontWeight: value ? FontWeight.w600 : FontWeight.w500))),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: value ? _primary : Colors.transparent,
            border: Border.all(color: value ? _primary : _border, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
        ),
      ]),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// Registration Option Card widget
// ═════════════════════════════════════════════════════════════════════════════
class _RegistrationOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final Color primaryColor;
  final Color accentSoftColor;
  final Color borderColor;
  final Color surfaceColor;
  final Color textDarkColor;
  final Color textLightColor;

  const _RegistrationOptionCard({
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.primaryColor,
    required this.accentSoftColor,
    required this.borderColor,
    required this.surfaceColor,
    required this.textDarkColor,
    required this.textLightColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? accentSoftColor : surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
              color: primaryColor.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 2))]
              : [BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? primaryColor : textDarkColor,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? primaryColor : borderColor,
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: textLightColor,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}