import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class AddGroupScreen extends ConsumerStatefulWidget {
  const AddGroupScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<AddGroupScreen> createState() => _AddGroupScreenState();
}

class _AddGroupScreenState extends ConsumerState<AddGroupScreen> {
  late PageController _pageController;
  int _currentPage = 0;

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

  final List<String> _stepLabels = ['Basics', 'Location', 'Schedule', 'Members', 'Media', 'Review'];

  late TextEditingController _nameController;
  late TextEditingController _handleController;
  late TextEditingController _descController;
  late TextEditingController _locNameController;
  late TextEditingController _cityController;
  late TextEditingController _prefController;
  late TextEditingController _countryController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _socialController;

  String _orgType = 'For-Profit Club / Facility';

  static const List<String> _orgTypes = [
    'For-Profit Club / Facility',
    'Nonprofit / Federation',
    'Local Group',
  ];

  bool _mon = false, _tue = false, _wed = false, _thu = false;
  bool _fri = false, _sat = false, _sun = false;
  bool _mornings = false, _afternoons = false, _evenings = false;

  bool _skillBeginner     = false;
  bool _skillIntermediate = false;
  bool _skillAdvance      = false;
  bool _ageJuniors  = false;
  bool _ageStudents = false;
  bool _ageAdult    = true;
  bool _ageSeniors  = false;

  File? _imageFile;
  bool _isLoading = false;

  // ── Language Toggle ───────────────────────────────────────────────────────
  bool _isJpMode = false;

  // Cached JP translations — populated when submit resolves fields,
  // and also pre-fetched when the user switches to JP on the Review page.
  String _nameJp = '';
  String _prefJp = '';
  String _cityJp = '';
  String _descJp = '';

  // Whether a background preview-translation is running
  bool _isPreviewTranslating = false;

  // Convenience: pick EN or JP string based on current mode
  String _s(String en, String jp) => _isJpMode && jp.isNotEmpty ? jp : en;

  List<String> get _stepLabelsLoc => _isJpMode
      ? ['基本情報', '場所', 'スケジュール', 'メンバー', 'メディア', '確認']
      : ['Basics', 'Location', 'Schedule', 'Members', 'Media', 'Review'];

  @override
  void initState() {
    super.initState();
    _pageController    = PageController();
    _nameController    = TextEditingController();
    _handleController  = TextEditingController();
    _descController    = TextEditingController();
    _locNameController = TextEditingController();
    _cityController    = TextEditingController();
    _prefController    = TextEditingController();
    _countryController = TextEditingController(text: 'Japan');
    _emailController   = TextEditingController();
    _websiteController = TextEditingController();
    _socialController  = TextEditingController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in [
      _nameController, _handleController, _descController,
      _locNameController, _cityController,
      _prefController, _countryController,
      _emailController, _websiteController, _socialController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Language Detection ────────────────────────────────────────────────────
  /// Returns true if the string contains Japanese characters
  bool _isJapanese(String text) {
    if (text.trim().isEmpty) return false;
    // Check for Hiragana, Katakana, or CJK Unified Ideographs (Kanji)
    final japaneseRegex = RegExp(
      r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF]',
    );
    return japaneseRegex.hasMatch(text);
  }

  // ── Free Translation via Google Translate (unofficial endpoint) ───────────
  // Uses the same free endpoint that Google Translate web uses.
  // No API key or billing required. Free & unlimited for small volumes.
  // Language codes: 'en' = English, 'ja' = Japanese
  Future<String> _translate(String text, String targetLangCode) async {
    if (text.trim().isEmpty) return '';
    try {
      debugPrint('🌐 Translating to $targetLangCode: "$text"');

      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
            '?client=gtx'
            '&sl=auto'
            '&tl=$targetLangCode'
            '&dt=t'
            '&q=${Uri.encodeComponent(text)}',
      );

      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      debugPrint('📡 Translation HTTP status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        // Response format: [[["translated","original",null,null,1],...],...]
        final buffer = StringBuffer();
        for (final part in decoded[0] as List) {
          if (part[0] != null) buffer.write(part[0] as String);
        }
        final translated = buffer.toString().trim();
        debugPrint('✅ "$text" → "$translated"');
        return translated;
      } else {
        debugPrint('❌ Translation error ${response.statusCode}: ${response.body}');
        return text; // fallback: return original
      }
    } catch (e) {
      debugPrint('❌ Translation exception: $e');
      return text; // fallback: return original
    }
  }

  // ── Bilingual Field Resolution ────────────────────────────────────────────
  /// Given a field value, returns a map with EN and JP variants.
  /// If the value is Japanese, translates to EN; if EN, translates to JP.
  Future<Map<String, String>> _resolveField(String value) async {
    if (value.trim().isEmpty) return {'en': '', 'jp': ''};

    if (_isJapanese(value)) {
      // Input is JP → translate to EN
      final en = await _translate(value, 'en');
      return {'en': en, 'jp': value};
    } else {
      // Input is EN → translate to JP
      final jp = await _translate(value, 'ja');
      return {'en': value, 'jp': jp};
    }
  }

  // ── Preview Translation (triggered when user toggles JP on Review page) ───
  Future<void> _previewTranslations() async {
    if (_isPreviewTranslating) return;
    setState(() => _isPreviewTranslating = true);
    try {
      final nameRaw = _nameController.text.trim();
      final prefRaw = _prefController.text.trim();
      final cityRaw = _cityController.text.trim();
      final descRaw = _descController.text.trim();

      final results = await Future.wait([
        _resolveField(nameRaw),
        _resolveField(prefRaw),
        _resolveField(cityRaw),
        _resolveField(descRaw),
      ]);

      if (mounted) {
        setState(() {
          _nameJp = results[0]['jp'] ?? '';
          _prefJp = results[1]['jp'] ?? '';
          _cityJp = results[2]['jp'] ?? '';
          _descJp = results[3]['jp'] ?? '';
          _isPreviewTranslating = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isPreviewTranslating = false);
    }
  }

  // ── Image Picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ── Generate Org ID ───────────────────────────────────────────────────────
  Future<String> _generateOrgId() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();

      int maxNum = 0;
      for (final doc in snap.docs) {
        final id  = doc.data()['org_id']?.toString() ?? '';
        final num = int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      return 'O-${(maxNum + 1).toString().padLeft(10, '0')}';
    } catch (_) {
      final fallback = DateTime.now().millisecondsSinceEpoch % 10000000000;
      return 'O-${fallback.toString().padLeft(10, '0')}';
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('You must be signed in to create a group.', isError: true);
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _handleController.text.trim().isEmpty) {
      _showSnack('Please fill in Group Name and Handle.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ── Translate bilingual fields ──────────────────────────────────────
      // Show a more informative snack while translating
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Translating fields…'),
          duration: Duration(seconds: 60),
          behavior: SnackBarBehavior.floating,
        ));
      }

      final nameRaw   = _nameController.text.trim();
      final prefRaw   = _prefController.text.trim();
      final cityRaw   = _cityController.text.trim();
      final descRaw   = _descController.text.trim();

      // Resolve all four fields concurrently
      final results = await Future.wait([
        _resolveField(nameRaw),
        _resolveField(prefRaw),
        _resolveField(cityRaw),
        _resolveField(descRaw),
      ]);

      final nameMap = results[0];
      final prefMap = results[1];
      final cityMap = results[2];
      final descMap = results[3];

      // Cache for review preview
      _nameJp = nameMap['jp'] ?? '';
      _prefJp = prefMap['jp'] ?? '';
      _cityJp = cityMap['jp'] ?? '';
      _descJp = descMap['jp'] ?? '';

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // ── Image upload ────────────────────────────────────────────────────
      String imageUrl = '';
      if (_imageFile != null) {
        try {
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${_imageFile!.path.split('/').last}';
          final storageRef =
          FirebaseStorage.instance.ref('org_images/$fileName');

          final snapshot = await storageRef
              .putFile(_imageFile!)
              .timeout(const Duration(seconds: 60));

          if (snapshot.state == TaskState.success) {
            imageUrl = await snapshot.ref.getDownloadURL();
          }
        } on TimeoutException {
          debugPrint('Image upload timed out');
          if (mounted) {
            _showSnack('Image upload timed out — saving without image.');
          }
        } catch (e) {
          debugPrint('Image upload failed: $e');
          if (mounted) {
            _showSnack('Image upload failed — saving without image.');
          }
        }
      }

      final orgId = await _generateOrgId();

      // ── Firestore document ───────────────────────────────────────────────
      // EN fields are stored in the primary field names (org_name, org_prefecture,
      // org_city, org_description) and JP translations in the _jp variants,
      // mirroring the web app's data structure exactly.
      await FirebaseFirestore.instance.collection('organizations').add({
        'org_id':              orgId,
        'org_active':          false,
        'org_pending_review':  true,
        'org_checked':         false,
        'org_addedby':         user.uid,
        'org_added':           FieldValue.serverTimestamp(),
        'org_age_adult':       _ageAdult,
        'org_age_juniors':     _ageJuniors,
        'org_age_seniors':     _ageSeniors,
        'org_age_students':    _ageStudents,

        // ── Bilingual: city ──────────────────────────────────────────────
        'org_city':            cityMap['en'],
        'org_city_jp':         cityMap['jp'],

        'org_contact_email':   _emailController.text.trim(),
        'org_country':         _countryController.text.trim(),
        'org_created_at':      FieldValue.serverTimestamp(),

        // ── Bilingual: description ───────────────────────────────────────
        'org_description':     descMap['en'],
        'org_description_jp':  descMap['jp'],

        'org_handle_name':     _handleController.text.trim(),
        'org_image':           imageUrl,
        'org_loc_id':          '',
        'org_venue_loc_name':  _locNameController.text.trim(),
        'org_meetup_fri':      _fri,
        'org_meetup_mon':      _mon,
        'org_meetup_sat':      _sat,
        'org_meetup_sun':      _sun,
        'org_meetup_thurs':    _thu,
        'org_meetup_time_afternoons': _afternoons,
        'org_meetup_time_evenings':   _evenings,
        'org_meetup_time_mornings':   _mornings,
        'org_meetup_tues':     _tue,
        'org_meetup_weds':     _wed,

        // ── Bilingual: name ──────────────────────────────────────────────
        'org_name':            nameMap['en'],
        'org_name_jp':         nameMap['jp'],

        // ── Bilingual: prefecture ────────────────────────────────────────
        'org_prefecture':      prefMap['en'],
        'org_prefecture_jp':   prefMap['jp'],

        'org_public':          false,
        'org_skill_advance':   _skillAdvance,
        'org_skill_beginner':  _skillBeginner,
        'org_skill_intermediate': _skillIntermediate,
        'org_social':          _socialController.text.trim(),
        'org_type':            _orgType,
        'org_website':         _websiteController.text.trim(),
        'submittedBy':         user.uid,
      });

      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Group is under review. It will be added to our system within 48 hours!');
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Submit error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('Error saving group: $e', isError: true);
      }
    }
  }

  // ── Snackbar ──────────────────────────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _errorRed : _primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(
            _s('Add a Group', 'グループを追加'),
            style: const TextStyle(
              color: _textDark,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            _stepLabelsLoc[_currentPage],
            style: const TextStyle(
              color: _accent,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ]),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() => _isJpMode = !_isJpMode);
                // If user switches to JP on the review page, auto-fetch translations
                if (_isJpMode && _currentPage == 5 && _nameJp.isEmpty) {
                  _previewTranslations();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _isJpMode ? _primary : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isJpMode ? _primary : _border,
                    width: 1.5,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'EN',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: !_isJpMode ? _primary : Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text('|', style: TextStyle(fontSize: 10, color: _isJpMode ? Colors.white.withOpacity(0.4) : _border)),
                  const SizedBox(width: 4),
                  Text(
                    'JP',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _isJpMode ? Colors.white : _textLight,
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        _buildStepIndicator(),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildBasicsPage(),
              _buildLocationPage(),
              _buildSchedulePage(),
              _buildMembersPage(),
              _buildMediaPage(),
              _buildReviewPage(),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(_stepLabelsLoc.length, (i) {
          final active = i <= _currentPage;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                    color: active ? _accent : _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < _stepLabelsLoc.length - 1) const SizedBox(width: 4),
            ]),
          );
        }),
      ),
    );
  }

  // ── Page 1 — Basic Details ────────────────────────────────────────────────
  Widget _buildBasicsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Basic Details', '基本情報'), _s('Name, type & description', '名前・種類・説明'), Icons.groups_outlined),
        _buildTextField(
          label: _s('Group / Org Name *', 'グループ名 *'),
          controller: _nameController,
          hint: _s('e.g. Tokyo Pickleball Club', '例: 東京ピックルボールクラブ'),
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: _s('Handle / Short Name *', 'ハンドル名 *'),
          controller: _handleController,
          hint: _s('e.g. tokyo_pickleball', '例: tokyo_pickleball'),
        ),
        const SizedBox(height: 14),
        _buildLabel(_s('Group Type', 'グループタイプ')),
        const SizedBox(height: 8),
        _buildSegmentedType(),
        const SizedBox(height: 20),
        _buildTextField(
          label: _s('Description', '説明'),
          controller: _descController,
          hint: _s('Tell people about this group...', 'このグループについて教えてください...'),
          maxLines: 3,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _accent.withOpacity(0.3)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.translate_rounded, size: 16, color: _primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'You can enter Name, Description, City and Prefecture in English or Japanese — we\'ll auto-translate the other language for you.',
                style: TextStyle(
                  color: _textMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSegmentedType() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _orgTypes.map((type) {
        final selected = _orgType == type;
        final displayLabel = switch (type) {
          'For-Profit Club / Facility' => 'Club / Facility',
          'Nonprofit / Federation'     => 'Nonprofit / Federation',
          'Local Group'                => 'Local Group',
          _                            => type,
        };
        return GestureDetector(
          onTap: () => setState(() => _orgType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: selected ? _primary : _border,
                width: selected ? 1.5 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: _primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ]
                  : [],
            ),
            child: Text(
              displayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _textMid,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Page 2 — Location & Contact ───────────────────────────────────────────
  Widget _buildLocationPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Location & Contact', '場所・連絡先'),
            _s('Where does this group meet?', 'このグループはどこで活動しますか？'),
            Icons.place_outlined),
        _buildTextField(
          label: _s('Home Court / Primary Location', 'ホームコート・主な活動場所'),
          controller: _locNameController,
          hint: _s('e.g. Yoyogi Park Court 3', '例: 代々木公園コート3'),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _buildTextField(
              label: _s('City', '市区町村'),
              controller: _cityController,
              hint: _s('e.g. Shinjuku / 新宿', '例: 新宿'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(
              label: _s('Prefecture', '都道府県'),
              controller: _prefController,
              hint: _s('e.g. Tokyo / 東京', '例: 東京'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
          label: _s('Country', '国'),
          controller: _countryController,
          hint: 'Japan',
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: _s('Contact Email', '連絡先メール'),
          controller: _emailController,
          hint: 'info@group.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: _s('Website', 'ウェブサイト'),
          controller: _websiteController,
          hint: 'https://example.com',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          label: _s('Social Media Link (e.g. Instagram)', 'SNSリンク（例: Instagram）'),
          controller: _socialController,
          hint: 'https://instagram.com/...',
          keyboardType: TextInputType.url,
        ),
      ]),
    );
  }

  // ── Page 3 — Schedule ─────────────────────────────────────────────────────
  Widget _buildSchedulePage() {
    final days = [
      ('Mon', _mon, (bool v) => setState(() => _mon = v)),
      ('Tue', _tue, (bool v) => setState(() => _tue = v)),
      ('Wed', _wed, (bool v) => setState(() => _wed = v)),
      ('Thu', _thu, (bool v) => setState(() => _thu = v)),
      ('Fri', _fri, (bool v) => setState(() => _fri = v)),
      ('Sat', _sat, (bool v) => setState(() => _sat = v)),
      ('Sun', _sun, (bool v) => setState(() => _sun = v)),
    ];
    final times = [
      ('Mornings',   _mornings,   (bool v) => setState(() => _mornings   = v)),
      ('Afternoons', _afternoons, (bool v) => setState(() => _afternoons = v)),
      ('Evenings',   _evenings,   (bool v) => setState(() => _evenings   = v)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Meetup Schedule', '活動スケジュール'),
            _s('When does this group typically meet?', 'このグループはいつ活動しますか？'),
            Icons.calendar_today_outlined),
        _buildLabel(_s('Typical Meetup Days', '活動日')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: days.map((d) {
            final (label, value, onChanged) = d;
            return GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52,
                height: 44,
                decoration: BoxDecoration(
                  color: value ? _primary : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: value ? _primary : _border,
                    width: value ? 1.5 : 1,
                  ),
                  boxShadow: value
                      ? [
                    BoxShadow(
                      color: _primary.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: value ? Colors.white : _textMid,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildLabel(_s('Typical Times', '活動時間帯')),
        const SizedBox(height: 10),
        Row(
          children: times.map((t) {
            final (label, value, onChanged) = t;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin:
                  EdgeInsets.only(right: label != 'Evenings' ? 10 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value ? _primary : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: value ? _primary : _border,
                      width: value ? 1.5 : 1,
                    ),
                    boxShadow: value
                        ? [
                      BoxShadow(
                        color: _primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ]
                        : [],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: value ? Colors.white : _textMid,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Page 4 — Demographics ─────────────────────────────────────────────────
  Widget _buildMembersPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Demographics', 'メンバー情報'),
            _s('Who is this group for?', 'このグループは誰向けですか？'),
            Icons.people_outline),
        _buildLabel(_s('Target Skill Levels', 'スキルレベル')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _buildSkillChip(_s('Beginner', '初心者'), _skillBeginner,
                    (v) => setState(() => _skillBeginner = v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSkillChip(_s('Intermediate', '中級'), _skillIntermediate,
                    (v) => setState(() => _skillIntermediate = v)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSkillChip(_s('Advanced', '上級'), _skillAdvance,
                    (v) => setState(() => _skillAdvance = v)),
          ),
        ]),
        const SizedBox(height: 24),
        _buildLabel(_s('Age Groups', '年齢層')),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow(_s('Juniors', 'ジュニア'), _ageJuniors,
                  (v) => setState(() => _ageJuniors = v),
              Icons.child_care_outlined),
          _buildCategoryRow(_s('Students', '学生'), _ageStudents,
                  (v) => setState(() => _ageStudents = v),
              Icons.school_outlined),
          _buildCategoryRow(_s('Adults', '大人'), _ageAdult,
                  (v) => setState(() => _ageAdult = v),
              Icons.person_outline),
          _buildCategoryRow(_s('Seniors', 'シニア'), _ageSeniors,
                  (v) => setState(() => _ageSeniors = v),
              Icons.elderly_outlined),
        ]),
      ]),
    );
  }

  // ── Page 5 — Media ────────────────────────────────────────────────────────
  Widget _buildMediaPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Profile Image', 'プロフィール画像'),
            _s('Cover image for your group', 'グループのカバー画像'),
            Icons.image_outlined),
        _buildLabel(_s('Profile / Cover Picture', 'プロフィール・カバー画像')),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 130,
            decoration: BoxDecoration(
              color:
              _imageFile != null ? Colors.transparent : _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _imageFile != null ? _accent : _border,
                width: _imageFile != null ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.hardEdge,
            child: _imageFile != null
                ? Stack(fit: StackFit.expand, children: [
              Image.file(_imageFile!, fit: BoxFit.cover),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _textDark.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_rounded,
                            size: 13, color: Colors.white),
                        SizedBox(width: 5),
                        Text('Change',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ]),
                ),
              ),
            ])
                : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                      Icons.add_photo_alternate_outlined,
                      color: _primary,
                      size: 26),
                ),
                const SizedBox(height: 10),
                Text(_s('Select Group Image', 'グループ画像を選択'),
                    style: const TextStyle(
                      color: _textMid,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const SizedBox(height: 2),
                Text(
                    _s("We'll use this for your group's avatar and listings", 'グループのアバターやリストに使用されます'),
                    style: TextStyle(
                        color: _textLight, fontSize: 11)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Page 6 — Review ───────────────────────────────────────────────────────
  Widget _buildReviewPage() {
    // Days — use JP labels when in JP mode
    final selectedDays = [
      if (_mon) _s('Mon', '月'),
      if (_tue) _s('Tue', '火'),
      if (_wed) _s('Wed', '水'),
      if (_thu) _s('Thu', '木'),
      if (_fri) _s('Fri', '金'),
      if (_sat) _s('Sat', '土'),
      if (_sun) _s('Sun', '日'),
    ];
    final selectedTimes = [
      if (_mornings)   _s('Mornings', '午前'),
      if (_afternoons) _s('Afternoons', '午後'),
      if (_evenings)   _s('Evenings', '夜'),
    ];
    final selectedSkills = [
      if (_skillBeginner)     _s('Beginner', '初心者'),
      if (_skillIntermediate) _s('Intermediate', '中級'),
      if (_skillAdvance)      _s('Advanced', '上級'),
    ];
    final selectedAges = [
      if (_ageJuniors)  _s('Juniors', 'ジュニア'),
      if (_ageStudents) _s('Students', '学生'),
      if (_ageAdult)    _s('Adults', '大人'),
      if (_ageSeniors)  _s('Seniors', 'シニア'),
    ];

    // Show JP translated values in review when JP mode is active
    final reviewName = _isJpMode
        ? (_nameJp.isNotEmpty ? _nameJp : _nameController.text.trim())
        : _nameController.text.trim();
    final reviewDesc = _isJpMode
        ? (_descJp.isNotEmpty ? _descJp : _descController.text.trim())
        : _descController.text.trim();
    final reviewCity = _isJpMode
        ? (_cityJp.isNotEmpty ? _cityJp : _cityController.text.trim())
        : _cityController.text.trim();
    final reviewPref = _isJpMode
        ? (_prefJp.isNotEmpty ? _prefJp : _prefController.text.trim())
        : _prefController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            _s('Review & Submit', '確認・送信'),
            _s('Double-check before submitting', '送信前にご確認ください'),
            Icons.checklist_outlined),

        // JP preview loading indicator
        if (_isJpMode && _isPreviewTranslating)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.5)),
            ),
            child: const Row(children: [
              SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1976D2)),
              ),
              SizedBox(width: 10),
              Text('日本語に翻訳中…', style: TextStyle(fontSize: 12, color: Color(0xFF1565C0), fontWeight: FontWeight.w500)),
            ]),
          ),

        _buildReviewSection(_s('Basic Details', '基本情報'), Icons.groups_outlined, [
          _buildReviewRow(_s('Name', '名前'), reviewName),
          _buildReviewRow(_s('Handle', 'ハンドル名'), _handleController.text.trim()),
          _buildReviewRow(_s('Type', 'タイプ'), _orgType),
          _buildReviewRow(_s('Description', '説明'), reviewDesc),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection(_s('Location & Contact', '場所・連絡先'), Icons.place_outlined, [
          _buildReviewRow(_s('Location', '場所'), _locNameController.text.trim()),
          _buildReviewRow(_s('City', '市区町村'), reviewCity),
          _buildReviewRow(_s('Prefecture', '都道府県'), reviewPref),
          _buildReviewRow(_s('Country', '国'), _countryController.text.trim()),
          _buildReviewRow(_s('Email', 'メール'), _emailController.text.trim()),
          _buildReviewRow(_s('Website', 'ウェブサイト'), _websiteController.text.trim()),
          _buildReviewRow(_s('Social', 'SNS'), _socialController.text.trim()),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection(_s('Schedule', 'スケジュール'), Icons.calendar_today_outlined, [
          _buildReviewRow(_s('Days', '活動日'),
              selectedDays.isEmpty ? '—' : selectedDays.join(', ')),
          _buildReviewRow(_s('Times', '活動時間帯'),
              selectedTimes.isEmpty ? '—' : selectedTimes.join(', ')),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection(_s('Demographics', 'メンバー情報'), Icons.people_outline, [
          _buildReviewRow(_s('Skills', 'スキル'),
              selectedSkills.isEmpty ? '—' : selectedSkills.join(', ')),
          _buildReviewRow(_s('Ages', '年齢層'),
              selectedAges.isEmpty ? '—' : selectedAges.join(', ')),
        ]),
        const SizedBox(height: 14),

        _buildReviewSection(_s('Media', 'メディア'), Icons.image_outlined, [
          _buildReviewRow(
              _s('Image', '画像'), _imageFile != null ? _s('Selected ✓', '選択済み ✓') : _s('None', 'なし')),
        ]),
        const SizedBox(height: 14),

        // Translation notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F4FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF90CAF9).withOpacity(0.6)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.translate_rounded, size: 18, color: Color(0xFF1976D2)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _s(
                  'Name, Description, City and Prefecture will be automatically translated to both English and Japanese before saving.',
                  '名前・説明・市区町村・都道府県は英語と日本語の両方に自動翻訳されて保存されます。',
                ),
                style: const TextStyle(
                  color: Color(0xFF1565C0),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _accent.withOpacity(0.4)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: _primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _s(
                  'Your group will be submitted for review. Once approved, it will appear publicly.',
                  'グループは審査に送信されます。承認後、公開されます。',
                ),
                style: const TextStyle(
                  color: _textMid,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildReviewSection(
      String title, IconData icon, List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(children: [
            Icon(icon, size: 16, color: _primary),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                )),
          ]),
        ),
        const Divider(height: 1, color: _border),
        ...rows,
      ]),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final display = value.isEmpty ? '—' : value;
    final isEmpty = value.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                color: _textLight,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              )),
        ),
        Expanded(
          child: Text(
            display,
            style: TextStyle(
              color: isEmpty ? _textLight : _textDark,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ]),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav() {
    final isLast = _currentPage == _stepLabels.length - 1;
    return Container(
      color: _surface,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20,
        right: 20,
        top: 16,
      ),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(_s('Back', '戻る'),
                  style: const TextStyle(
                    color: _textMid,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  )),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () {
              if (isLast) {
                _submitForm();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
                // Pre-fetch JP translations when arriving at Review page
                if (_currentPage == 4 && _isJpMode && _nameJp.isEmpty) {
                  Future.delayed(const Duration(milliseconds: 350), _previewTranslations);
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              disabledBackgroundColor: _accent.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : Text(
              isLast ? _s('Submit for Review', '審査に送信') : _s('Continue', '次へ'),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Shared Widgets ────────────────────────────────────────────────────────
  Widget _buildPageHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _accentSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: _textDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      letterSpacing: -0.3,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: _textLight, fontSize: 12)),
              ]),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _textMid,
      fontSize: 13,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
  );

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildLabel(label),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: _textDark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
          const TextStyle(color: _textLight, fontSize: 14),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
            const BorderSide(color: _accent, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 13),
        ),
      ),
    ]);
  }

  Widget _buildSkillChip(
      String label, bool selected, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primary : _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? _primary : _border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ]
              : [
            BoxShadow(
              color: _primary.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? Colors.white : _textMid,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            e.value,
            if (!isLast)
              const Divider(
                  height: 1,
                  color: _border,
                  indent: 16,
                  endIndent: 16),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryRow(String label, bool value,
      ValueChanged<bool> onChanged, IconData icon) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon,
              size: 18, color: value ? _primary : _textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: value ? _textDark : _textMid,
                fontSize: 14,
                fontWeight:
                value ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(
                color: value ? _primary : _border,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(Icons.check,
                size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}