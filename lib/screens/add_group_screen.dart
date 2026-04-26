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
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localization strings
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'addGroup':           'Add a Group',
    'stepBasics':         'Basics',
    'stepLocation':       'Location',
    'stepSchedule':       'Schedule',
    'stepMembers':        'Members',
    'stepMedia':          'Media',
    'stepReview':         'Review',
    'basicTitle':         'Basic Details',
    'basicSub':           'Name, type & description',
    'groupName':          'Group / Org Name *',
    'groupNameHint':      'e.g. Tokyo Pickleball Club',
    'handle':             'Handle / Short Name *',
    'handleHint':         'e.g. tokyo_pickleball',
    'groupType':          'Group Type',
    'visibility':         'Active and Publicly Listed',
    'visPub':             'Public',
    'visPubDesc':         'Searchable and open for anyone to join',
    'visPriv':            'Private',
    'visPrivDesc':        'Accessible via a private link that you can share',
    'description':        'Description',
    'descHint':           'Tell people about this group...',
    'translateNote':      "You can enter Name, Description, City and Prefecture in English or Japanese — we'll auto-translate the other language for you.",
    'locationTitle':      'Location & Contact',
    'locationSub':        'Where does this group meet?',
    'homeCourt':          'Home Court / Primary Location',
    'homeCourtHint':      'e.g. Yoyogi Park Court 3',
    'city':               'City',
    'cityHint':           'e.g. Shinjuku / 新宿',
    'prefecture':         'Prefecture',
    'prefHint':           'e.g. Tokyo / 東京',
    'country':            'Country',
    'email':              'Contact Email',
    'website':            'Website',
    'social':             'Social Media Link (e.g. Instagram)',
    'scheduleTitle':      'Meetup Schedule',
    'scheduleSub':        'When does this group typically meet?',
    'days':               'Typical Meetup Days',
    'times':              'Typical Times',
    'mon': 'Mon', 'tue': 'Tue', 'wed': 'Wed', 'thu': 'Thu',
    'fri': 'Fri', 'sat': 'Sat', 'sun': 'Sun',
    'mornings':           'Mornings',
    'afternoons':         'Afternoons',
    'evenings':           'Evenings',
    'membersTitle':       'Demographics',
    'membersSub':         'Who is this group for?',
    'skillLevels':        'Target Skill Levels',
    'beginner':           'Beginner',
    'intermediate':       'Intermediate',
    'advanced':           'Advanced',
    'ageGroups':          'Age Groups',
    'juniors':            'Juniors',
    'students':           'Students',
    'adults':             'Adults',
    'seniors':            'Seniors',
    'mediaTitle':         'Profile Image',
    'mediaSub':           'Cover image for your group',
    'profilePicLabel':    'Profile / Cover Picture',
    'selectImage':        'Select Group Image',
    'imageCaption':       "We'll use this for your group's avatar and listings",
    'changeImage':        'Change',
    'reviewTitle':        'Review & Submit',
    'reviewSub':          'Double-check before submitting',
    'translatingMsg':     'Translating fields…',
    'reviewBasics':       'Basic Details',
    'reviewLocation':     'Location & Contact',
    'reviewSchedule':     'Schedule',
    'reviewMembers':      'Demographics',
    'reviewMedia':        'Media',
    'reviewName':         'Name',
    'reviewHandle':       'Handle',
    'reviewType':         'Type',
    'reviewVisibility':   'Visibility',
    'reviewDesc':         'Description',
    'reviewLoc':          'Location',
    'reviewCity':         'City',
    'reviewPref':         'Prefecture',
    'reviewCountry':      'Country',
    'reviewEmail':        'Email',
    'reviewWebsite':      'Website',
    'reviewSocial':       'Social',
    'reviewDays':         'Days',
    'reviewTimes':        'Times',
    'reviewSkills':       'Skills',
    'reviewAges':         'Ages',
    'reviewImage':        'Image',
    'imageSelected':      'Selected ✓',
    'imageNone':          'None',
    'translationNotice':  'Name, Description, City and Prefecture will be automatically translated to both English and Japanese before saving.',
    'approvalNotice':     'Your group will be submitted for review. Once approved, it will appear publicly.',
    'back':               'Back',
    'continue':           'Continue',
    'submit':             'Submit for Review',
    'translatingJp':      'Translating to Japanese…',
    'signInError':        'You must be signed in to create a group.',
    'fillError':          'Please fill in Group Name and Handle.',
    'noImageMsg':         'Image upload timed out — saving without image.',
    'imgFailMsg':         'Image upload failed — saving without image.',
    'successMsg':         'Group is under review. It will be added to our system within 48 hours!',
    'errorMsg':           'Error saving group: ',
  },
  kLangJa: {
    'addGroup':           'グループを追加',
    'stepBasics':         '基本情報',
    'stepLocation':       '場所',
    'stepSchedule':       'スケジュール',
    'stepMembers':        'メンバー',
    'stepMedia':          'メディア',
    'stepReview':         '確認',
    'basicTitle':         '基本情報',
    'basicSub':           '名前・種類・説明',
    'groupName':          'グループ名 *',
    'groupNameHint':      '例: 東京ピックルボールクラブ',
    'handle':             'ハンドル名 *',
    'handleHint':         '例: tokyo_pickleball',
    'groupType':          'グループタイプ',
    'visibility':         '公開設定',
    'visPub':             '公開',
    'visPubDesc':         '検索可能で、誰でも参加できます',
    'visPriv':            '非公開',
    'visPrivDesc':        '共有可能なプライベートリンク経由でのみアクセス可能',
    'description':        '説明',
    'descHint':           'このグループについて教えてください...',
    'translateNote':      '名前・説明・市区町村・都道府県は英語または日本語で入力できます。もう一方の言語は自動翻訳されます。',
    'locationTitle':      '場所・連絡先',
    'locationSub':        'このグループはどこで活動しますか？',
    'homeCourt':          'ホームコート・主な活動場所',
    'homeCourtHint':      '例: 代々木公園コート3',
    'city':               '市区町村',
    'cityHint':           '例: 新宿',
    'prefecture':         '都道府県',
    'prefHint':           '例: 東京',
    'country':            '国',
    'email':              '連絡先メール',
    'website':            'ウェブサイト',
    'social':             'SNSリンク（例: Instagram）',
    'scheduleTitle':      '活動スケジュール',
    'scheduleSub':        'このグループはいつ活動しますか？',
    'days':               '活動日',
    'times':              '活動時間帯',
    'mon': '月', 'tue': '火', 'wed': '水', 'thu': '木',
    'fri': '金', 'sat': '土', 'sun': '日',
    'mornings':           '午前',
    'afternoons':         '午後',
    'evenings':           '夜',
    'membersTitle':       'メンバー情報',
    'membersSub':         'このグループは誰向けですか？',
    'skillLevels':        'スキルレベル',
    'beginner':           '初心者',
    'intermediate':       '中級',
    'advanced':           '上級',
    'ageGroups':          '年齢層',
    'juniors':            'ジュニア',
    'students':           '学生',
    'adults':             '大人',
    'seniors':            'シニア',
    'mediaTitle':         'プロフィール画像',
    'mediaSub':           'グループのカバー画像',
    'profilePicLabel':    'プロフィール・カバー画像',
    'selectImage':        'グループ画像を選択',
    'imageCaption':       'グループのアバターやリストに使用されます',
    'changeImage':        '変更',
    'reviewTitle':        '確認・送信',
    'reviewSub':          '送信前にご確認ください',
    'translatingMsg':     '翻訳中…',
    'reviewBasics':       '基本情報',
    'reviewLocation':     '場所・連絡先',
    'reviewSchedule':     'スケジュール',
    'reviewMembers':      'メンバー情報',
    'reviewMedia':        'メディア',
    'reviewName':         '名前',
    'reviewHandle':       'ハンドル名',
    'reviewType':         'タイプ',
    'reviewVisibility':   '公開設定',
    'reviewDesc':         '説明',
    'reviewLoc':          '場所',
    'reviewCity':         '市区町村',
    'reviewPref':         '都道府県',
    'reviewCountry':      '国',
    'reviewEmail':        'メール',
    'reviewWebsite':      'ウェブサイト',
    'reviewSocial':       'SNS',
    'reviewDays':         '活動日',
    'reviewTimes':        '活動時間帯',
    'reviewSkills':       'スキル',
    'reviewAges':         '年齢層',
    'reviewImage':        '画像',
    'imageSelected':      '選択済み ✓',
    'imageNone':          'なし',
    'translationNotice':  '名前・説明・市区町村・都道府県は英語と日本語の両方に自動翻訳されて保存されます。',
    'approvalNotice':     'グループは審査に送信されます。承認後、公開されます。',
    'back':               '戻る',
    'continue':           '次へ',
    'submit':             '審査に送信',
    'translatingJp':      '日本語に翻訳中…',
    'signInError':        'グループを作成するにはサインインが必要です。',
    'fillError':          'グループ名とハンドル名を入力してください。',
    'noImageMsg':         '画像のアップロードがタイムアウトしました。画像なしで保存します。',
    'imgFailMsg':         '画像のアップロードに失敗しました。画像なしで保存します。',
    'successMsg':         'グループは審査中です。48時間以内にシステムに追加されます！',
    'errorMsg':           'グループの保存中にエラーが発生しました：',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
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

  // ── Visibility ────────────────────────────────────────────────────────────
  bool _isPublic = true;

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

  // Cached JP translations
  String _nameJp = '';
  String _prefJp = '';
  String _cityJp = '';
  String _descJp = '';

  bool _isPreviewTranslating = false;

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

  // ── Language helpers ──────────────────────────────────────────────────────
  bool get _isJpMode => ref.read(appLangProvider) == kLangJa;

  bool _isJapanese(String text) {
    if (text.trim().isEmpty) return false;
    final japaneseRegex = RegExp(
      r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF\u3400-\u4DBF]',
    );
    return japaneseRegex.hasMatch(text);
  }

  Future<String> _translate(String text, String targetLangCode) async {
    if (text.trim().isEmpty) return '';
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
            '?client=gtx&sl=auto&tl=$targetLangCode&dt=t'
            '&q=${Uri.encodeComponent(text)}',
      );
      final response =
      await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final buffer = StringBuffer();
        for (final part in decoded[0] as List) {
          if (part[0] != null) buffer.write(part[0] as String);
        }
        return buffer.toString().trim();
      }
      return text;
    } catch (_) {
      return text;
    }
  }

  Future<Map<String, String>> _resolveField(String value) async {
    if (value.trim().isEmpty) return {'en': '', 'jp': ''};
    if (_isJapanese(value)) {
      final en = await _translate(value, 'en');
      return {'en': en, 'jp': value};
    } else {
      final jp = await _translate(value, 'ja');
      return {'en': value, 'jp': jp};
    }
  }

  Future<void> _previewTranslations() async {
    if (_isPreviewTranslating) return;
    setState(() => _isPreviewTranslating = true);
    try {
      final results = await Future.wait([
        _resolveField(_nameController.text.trim()),
        _resolveField(_prefController.text.trim()),
        _resolveField(_cityController.text.trim()),
        _resolveField(_descController.text.trim()),
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
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
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
        final num =
            int.tryParse(id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (num > maxNum) maxNum = num;
      }
      return 'O-${(maxNum + 1).toString().padLeft(10, '0')}';
    } catch (_) {
      final fallback =
          DateTime.now().millisecondsSinceEpoch % 10000000000;
      return 'O-${fallback.toString().padLeft(10, '0')}';
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────
  Future<void> _submitForm() async {
    final lang = ref.read(appLangProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack(_t(lang, 'signInError'), isError: true);
      return;
    }
    if (_nameController.text.trim().isEmpty ||
        _handleController.text.trim().isEmpty) {
      _showSnack(_t(lang, 'fillError'), isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_t(lang, 'translatingMsg')),
          duration: const Duration(seconds: 60),
          behavior: SnackBarBehavior.floating,
        ));
      }

      final results = await Future.wait([
        _resolveField(_nameController.text.trim()),
        _resolveField(_prefController.text.trim()),
        _resolveField(_cityController.text.trim()),
        _resolveField(_descController.text.trim()),
      ]);

      final nameMap = results[0];
      final prefMap = results[1];
      final cityMap = results[2];
      final descMap = results[3];

      _nameJp = nameMap['jp'] ?? '';
      _prefJp = prefMap['jp'] ?? '';
      _cityJp = cityMap['jp'] ?? '';
      _descJp = descMap['jp'] ?? '';

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

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
          if (mounted) _showSnack(_t(lang, 'noImageMsg'));
        } catch (_) {
          if (mounted) _showSnack(_t(lang, 'imgFailMsg'));
        }
      }

      final orgId = await _generateOrgId();

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
        'org_city':            cityMap['en'],
        'org_city_jp':         cityMap['jp'],
        'org_contact_email':   _emailController.text.trim(),
        'org_country':         _countryController.text.trim(),
        'org_created_at':      FieldValue.serverTimestamp(),
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
        'org_name':            nameMap['en'],
        'org_name_jp':         nameMap['jp'],
        'org_prefecture':      prefMap['en'],
        'org_prefecture_jp':   prefMap['jp'],
        'org_public':          _isPublic,  // ← uses the toggle value
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
        _showSnack(_t(lang, 'successMsg'));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnack('${_t(lang, 'errorMsg')}$e', isError: true);
      }
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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final t    = (String key) => _t(lang, key);
    final isJp = lang == kLangJa;

    final stepLabels = [
      t('stepBasics'), t('stepLocation'), t('stepSchedule'),
      t('stepMembers'), t('stepMedia'),   t('stepReview'),
    ];

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
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 16, color: _textDark),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(t('addGroup'),
              style: const TextStyle(
                  color: _textDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: -0.5)),
          Text(stepLabels[_currentPage],
              style: const TextStyle(
                  color: _accent, fontWeight: FontWeight.w500, fontSize: 12)),
        ]),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () async {
                final newLang = isJp ? kLangEn : kLangJa;
                await ref.read(appLangProvider.notifier).setLang(newLang);
                if (newLang == kLangJa &&
                    _currentPage == 5 &&
                    _nameJp.isEmpty) {
                  _previewTranslations();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isJp ? _primary : _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isJp ? _primary : _border, width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('EN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: !isJp
                              ? _primary
                              : Colors.white.withOpacity(0.6))),
                  const SizedBox(width: 4),
                  Text('|',
                      style: TextStyle(
                          fontSize: 10,
                          color: isJp
                              ? Colors.white.withOpacity(0.4)
                              : _border)),
                  const SizedBox(width: 4),
                  Text('JP',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isJp ? Colors.white : _textLight)),
                ]),
              ),
            ),
          ),
        ],
      ),
      body: Column(children: [
        _buildStepIndicator(stepLabels),
        Expanded(
          child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (i) => setState(() => _currentPage = i),
            children: [
              _buildBasicsPage(lang),
              _buildLocationPage(lang),
              _buildSchedulePage(lang),
              _buildMembersPage(lang),
              _buildMediaPage(lang),
              _buildReviewPage(lang),
            ],
          ),
        ),
      ]),
      bottomNavigationBar: _buildBottomNav(lang, stepLabels),
    );
  }

  // ── Step Indicator ────────────────────────────────────────────────────────
  Widget _buildStepIndicator(List<String> stepLabels) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: List.generate(stepLabels.length, (i) {
          final active = i <= _currentPage;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 4,
                  decoration: BoxDecoration(
                      color: active ? _accent : _border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              if (i < stepLabels.length - 1) const SizedBox(width: 4),
            ]),
          );
        }),
      ),
    );
  }

  // ── Page 1 — Basic Details ────────────────────────────────────────────────
  Widget _buildBasicsPage(String lang) {
    final t = (String key) => _t(lang, key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(t('basicTitle'), t('basicSub'), Icons.groups_outlined),
        _buildTextField(
            label: t('groupName'),
            controller: _nameController,
            hint: t('groupNameHint')),
        const SizedBox(height: 14),
        _buildTextField(
            label: t('handle'),
            controller: _handleController,
            hint: t('handleHint')),
        const SizedBox(height: 14),
        _buildLabel(t('groupType')),
        const SizedBox(height: 8),
        _buildSegmentedType(),
        const SizedBox(height: 20),

        // ── Visibility (Public / Private) ─────────────────────────────────
        _buildLabel(t('visibility')),
        const SizedBox(height: 10),
        _buildVisibilitySelector(lang),
        const SizedBox(height: 20),

        _buildTextField(
            label: t('description'),
            controller: _descController,
            hint: t('descHint'),
            maxLines: 3),
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
            Expanded(
              child: Text(t('translateNote'),
                  style: const TextStyle(
                      color: _textMid,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ── Visibility Selector ───────────────────────────────────────────────────
  Widget _buildVisibilitySelector(String lang) {
    final t = (String key) => _t(lang, key);
    return Row(children: [
      // Public option
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isPublic = true),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isPublic ? _primary.withOpacity(0.08) : _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _isPublic ? _primary : _border,
                width: _isPublic ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPublic ? _primary : Colors.transparent,
                    border: Border.all(
                      color: _isPublic ? _primary : _border,
                      width: 1.5,
                    ),
                  ),
                  child: _isPublic
                      ? Center(
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('visPub'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isPublic ? _primary : _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('visPubDesc'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _textLight,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      // Private option
      Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _isPublic = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: !_isPublic ? _primary.withOpacity(0.08) : _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: !_isPublic ? _primary : _border,
                width: !_isPublic ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 18,
                  height: 18,
                  margin: const EdgeInsets.only(top: 1),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !_isPublic ? _primary : Colors.transparent,
                    border: Border.all(
                      color: !_isPublic ? _primary : _border,
                      width: 1.5,
                    ),
                  ),
                  child: !_isPublic
                      ? Center(
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                    ),
                  )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('visPriv'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: !_isPublic ? _primary : _textDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('visPrivDesc'),
                        style: const TextStyle(
                          fontSize: 10,
                          color: _textLight,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSegmentedType() {
    return Wrap(
      spacing: 8, runSpacing: 8,
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _primary : _surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: selected ? _primary : _border,
                  width: selected ? 1.5 : 1),
              boxShadow: selected
                  ? [BoxShadow(
                  color: _primary.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3))]
                  : [],
            ),
            child: Text(displayLabel,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _textMid)),
          ),
        );
      }).toList(),
    );
  }

  // ── Page 2 — Location & Contact ───────────────────────────────────────────
  Widget _buildLocationPage(String lang) {
    final t = (String key) => _t(lang, key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            t('locationTitle'), t('locationSub'), Icons.place_outlined),
        _buildTextField(
            label: t('homeCourt'),
            controller: _locNameController,
            hint: t('homeCourtHint')),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _buildTextField(
                label: t('city'),
                controller: _cityController,
                hint: t('cityHint')),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildTextField(
                label: t('prefecture'),
                controller: _prefController,
                hint: t('prefHint')),
          ),
        ]),
        const SizedBox(height: 14),
        _buildTextField(
            label: t('country'),
            controller: _countryController,
            hint: 'Japan'),
        const SizedBox(height: 20),
        _buildTextField(
            label: t('email'),
            controller: _emailController,
            hint: 'info@group.com',
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _buildTextField(
            label: t('website'),
            controller: _websiteController,
            hint: 'https://example.com',
            keyboardType: TextInputType.url),
        const SizedBox(height: 14),
        _buildTextField(
            label: t('social'),
            controller: _socialController,
            hint: 'https://instagram.com/...',
            keyboardType: TextInputType.url),
      ]),
    );
  }

  // ── Page 3 — Schedule ─────────────────────────────────────────────────────
  Widget _buildSchedulePage(String lang) {
    final t = (String key) => _t(lang, key);
    final days = [
      (t('mon'), _mon, (bool v) => setState(() => _mon = v)),
      (t('tue'), _tue, (bool v) => setState(() => _tue = v)),
      (t('wed'), _wed, (bool v) => setState(() => _wed = v)),
      (t('thu'), _thu, (bool v) => setState(() => _thu = v)),
      (t('fri'), _fri, (bool v) => setState(() => _fri = v)),
      (t('sat'), _sat, (bool v) => setState(() => _sat = v)),
      (t('sun'), _sun, (bool v) => setState(() => _sun = v)),
    ];
    final times = [
      (t('mornings'),   _mornings,   (bool v) => setState(() => _mornings   = v)),
      (t('afternoons'), _afternoons, (bool v) => setState(() => _afternoons = v)),
      (t('evenings'),   _evenings,   (bool v) => setState(() => _evenings   = v)),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            t('scheduleTitle'), t('scheduleSub'), Icons.calendar_today_outlined),
        _buildLabel(t('days')),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: days.map((d) {
            final (label, value, onChanged) = d;
            return GestureDetector(
              onTap: () => onChanged(!value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 52, height: 44,
                decoration: BoxDecoration(
                  color: value ? _primary : _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: value ? _primary : _border,
                      width: value ? 1.5 : 1),
                  boxShadow: value
                      ? [BoxShadow(
                      color: _primary.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2))]
                      : [],
                ),
                child: Center(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: value ? Colors.white : _textMid)),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        _buildLabel(t('times')),
        const SizedBox(height: 10),
        Row(
          children: times.asMap().entries.map((e) {
            final (label, value, onChanged) = e.value;
            final isLast = e.key == times.length - 1;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: EdgeInsets.only(right: isLast ? 0 : 10),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: value ? _primary : _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: value ? _primary : _border,
                        width: value ? 1.5 : 1),
                    boxShadow: value
                        ? [BoxShadow(
                        color: _primary.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2))]
                        : [],
                  ),
                  child: Text(label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: value ? Colors.white : _textMid)),
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ── Page 4 — Demographics ─────────────────────────────────────────────────
  Widget _buildMembersPage(String lang) {
    final t = (String key) => _t(lang, key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            t('membersTitle'), t('membersSub'), Icons.people_outline),
        _buildLabel(t('skillLevels')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildSkillChip(t('beginner'),     _skillBeginner,     (v) => setState(() => _skillBeginner     = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip(t('intermediate'), _skillIntermediate, (v) => setState(() => _skillIntermediate = v))),
          const SizedBox(width: 10),
          Expanded(child: _buildSkillChip(t('advanced'),     _skillAdvance,      (v) => setState(() => _skillAdvance      = v))),
        ]),
        const SizedBox(height: 24),
        _buildLabel(t('ageGroups')),
        const SizedBox(height: 10),
        _buildSectionCard(children: [
          _buildCategoryRow(t('juniors'),  _ageJuniors,  (v) => setState(() => _ageJuniors  = v), Icons.child_care_outlined),
          _buildCategoryRow(t('students'), _ageStudents, (v) => setState(() => _ageStudents = v), Icons.school_outlined),
          _buildCategoryRow(t('adults'),   _ageAdult,    (v) => setState(() => _ageAdult    = v), Icons.person_outline),
          _buildCategoryRow(t('seniors'),  _ageSeniors,  (v) => setState(() => _ageSeniors  = v), Icons.elderly_outlined),
        ]),
      ]),
    );
  }

  // ── Page 5 — Media ────────────────────────────────────────────────────────
  Widget _buildMediaPage(String lang) {
    final t = (String key) => _t(lang, key);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(
            t('mediaTitle'), t('mediaSub'), Icons.image_outlined),
        _buildLabel(t('profilePicLabel')),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _imageFile != null ? 200 : 130,
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
              Positioned(
                bottom: 8, right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                      color: _textDark.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(t('changeImage'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
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
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: _primary, size: 26),
                ),
                const SizedBox(height: 10),
                Text(t('selectImage'),
                    style: const TextStyle(
                        color: _textMid,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(t('imageCaption'),
                    style: TextStyle(color: _textLight, fontSize: 11)),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  // ── Page 6 — Review ───────────────────────────────────────────────────────
  Widget _buildReviewPage(String lang) {
    final t    = (String key) => _t(lang, key);
    final isJp = lang == kLangJa;

    final selectedDays = [
      if (_mon) t('mon'), if (_tue) t('tue'), if (_wed) t('wed'),
      if (_thu) t('thu'), if (_fri) t('fri'),
      if (_sat) t('sat'), if (_sun) t('sun'),
    ];
    final selectedTimes = [
      if (_mornings)   t('mornings'),
      if (_afternoons) t('afternoons'),
      if (_evenings)   t('evenings'),
    ];
    final selectedSkills = [
      if (_skillBeginner)     t('beginner'),
      if (_skillIntermediate) t('intermediate'),
      if (_skillAdvance)      t('advanced'),
    ];
    final selectedAges = [
      if (_ageJuniors)  t('juniors'),
      if (_ageStudents) t('students'),
      if (_ageAdult)    t('adults'),
      if (_ageSeniors)  t('seniors'),
    ];

    final reviewName = isJp
        ? (_nameJp.isNotEmpty ? _nameJp : _nameController.text.trim())
        : _nameController.text.trim();
    final reviewDesc = isJp
        ? (_descJp.isNotEmpty ? _descJp : _descController.text.trim())
        : _descController.text.trim();
    final reviewCity = isJp
        ? (_cityJp.isNotEmpty ? _cityJp : _cityController.text.trim())
        : _cityController.text.trim();
    final reviewPref = isJp
        ? (_prefJp.isNotEmpty ? _prefJp : _prefController.text.trim())
        : _prefController.text.trim();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildPageHeader(t('reviewTitle'), t('reviewSub'), Icons.checklist_outlined),

        if (isJp && _isPreviewTranslating)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF90CAF9).withOpacity(0.5)),
            ),
            child: Row(children: [
              const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF1976D2))),
              const SizedBox(width: 10),
              Text(t('translatingJp'),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w500)),
            ]),
          ),

        _buildReviewSection(t('reviewBasics'), Icons.groups_outlined, [
          _buildReviewRow(t('reviewName'),       reviewName),
          _buildReviewRow(t('reviewHandle'),     _handleController.text.trim()),
          _buildReviewRow(t('reviewType'),       _orgType),
          _buildReviewRow(t('reviewVisibility'), _isPublic ? t('visPub') : t('visPriv')),
          _buildReviewRow(t('reviewDesc'),       reviewDesc),
        ]),
        const SizedBox(height: 14),
        _buildReviewSection(t('reviewLocation'), Icons.place_outlined, [
          _buildReviewRow(t('reviewLoc'),     _locNameController.text.trim()),
          _buildReviewRow(t('reviewCity'),    reviewCity),
          _buildReviewRow(t('reviewPref'),    reviewPref),
          _buildReviewRow(t('reviewCountry'), _countryController.text.trim()),
          _buildReviewRow(t('reviewEmail'),   _emailController.text.trim()),
          _buildReviewRow(t('reviewWebsite'), _websiteController.text.trim()),
          _buildReviewRow(t('reviewSocial'),  _socialController.text.trim()),
        ]),
        const SizedBox(height: 14),
        _buildReviewSection(t('reviewSchedule'), Icons.calendar_today_outlined, [
          _buildReviewRow(t('reviewDays'),  selectedDays.isEmpty  ? '—' : selectedDays.join(', ')),
          _buildReviewRow(t('reviewTimes'), selectedTimes.isEmpty ? '—' : selectedTimes.join(', ')),
        ]),
        const SizedBox(height: 14),
        _buildReviewSection(t('reviewMembers'), Icons.people_outline, [
          _buildReviewRow(t('reviewSkills'), selectedSkills.isEmpty ? '—' : selectedSkills.join(', ')),
          _buildReviewRow(t('reviewAges'),   selectedAges.isEmpty  ? '—' : selectedAges.join(', ')),
        ]),
        const SizedBox(height: 14),
        _buildReviewSection(t('reviewMedia'), Icons.image_outlined, [
          _buildReviewRow(t('reviewImage'),
              _imageFile != null ? t('imageSelected') : t('imageNone')),
        ]),
        const SizedBox(height: 14),
        _buildInfoBox(
          const Color(0xFFE8F4FF),
          const Color(0xFF90CAF9),
          const Icon(Icons.translate_rounded, size: 18, color: Color(0xFF1976D2)),
          t('translationNotice'),
          const TextStyle(color: Color(0xFF1565C0), fontSize: 12,
              fontWeight: FontWeight.w500, height: 1.4),
        ),
        const SizedBox(height: 14),
        _buildInfoBox(
          _accentSoft,
          _accent.withOpacity(0.4),
          const Icon(Icons.info_outline_rounded, size: 18, color: _primary),
          t('approvalNotice'),
          const TextStyle(color: _textMid, fontSize: 12,
              fontWeight: FontWeight.w500, height: 1.4),
        ),
      ]),
    );
  }

  Widget _buildInfoBox(Color bg, Color border, Icon icon, String text,
      TextStyle style) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        icon,
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: style)),
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
        boxShadow: [BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
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
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const Divider(height: 1, color: _border),
        ...rows,
      ]),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    final display = value.isEmpty ? '—' : value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: const TextStyle(
                  color: _textLight, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: Text(display,
              style: TextStyle(
                  color: value.isEmpty ? _textLight : _textDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontStyle: value.isEmpty ? FontStyle.italic : FontStyle.normal)),
        ),
      ]),
    );
  }

  // ── Bottom Nav ────────────────────────────────────────────────────────────
  Widget _buildBottomNav(String lang, List<String> stepLabels) {
    final t      = (String key) => _t(lang, key);
    final isLast = _currentPage == stepLabels.length - 1;
    return Container(
      color: _surface,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        left: 20, right: 20, top: 16,
      ),
      child: Row(children: [
        if (_currentPage > 0) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(t('back'),
                  style: const TextStyle(
                      color: _textMid,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
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
                    curve: Curves.easeInOut);
                if (_currentPage == 4 &&
                    lang == kLangJa &&
                    _nameJp.isEmpty) {
                  Future.delayed(
                      const Duration(milliseconds: 350),
                      _previewTranslations);
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
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white)))
                : Text(isLast ? t('submit') : t('continue'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15)),
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
              color: _accentSoft, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: _primary, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    color: _textDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.3)),
            const SizedBox(height: 2),
            Text(subtitle,
                style: const TextStyle(color: _textLight, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: const TextStyle(
          color: _textMid,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2));

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
            color: _textDark, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textLight, fontSize: 14),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border, width: 1)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accent, width: 1.5)),
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [BoxShadow(
              color: _primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3))]
              : [BoxShadow(
              color: _primary.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1))],
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected ? Colors.white : _textMid,
                fontSize: 12,
                fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(
            color: _primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2))],
      ),
      child: Column(
        children: children.asMap().entries.map((e) {
          final isLast = e.key == children.length - 1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            e.value,
            if (!isLast)
              const Divider(
                  height: 1, color: _border, indent: 16, endIndent: 16),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Icon(icon, size: 18, color: value ? _primary : _textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: value ? _textDark : _textMid,
                    fontSize: 14,
                    fontWeight:
                    value ? FontWeight.w600 : FontWeight.w500)),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: value ? _primary : Colors.transparent,
              border: Border.all(
                  color: value ? _primary : _border, width: 1.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: value
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
        ]),
      ),
    );
  }
}