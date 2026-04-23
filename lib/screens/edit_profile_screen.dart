import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localization
// ─────────────────────────────────────────────────────────────────────────────
const _L = {
  kLangEn: {
    'title':            'Edit Profile',
    'editPicture':      'Edit picture',
    'loading':          'Loading your profile...',
    'retry':            'Retry',
    'sectionPersonal':  'Personal Info',
    'nickname':         'Nickname / Username',
    'nicknameHint':     'e.g. PickleMaster',
    'nicknameError':    'Nickname / Username is required',
    'sectionLocation':  'Location',
    'address':          'Address',
    'addressHint':      'e.g. Shibuya, Tokyo',
    'sectionAbout':     'About You',
    'description':      'Description',
    'descHint':         'Tell the community about yourself...',
    'saveChanges':      'Save Changes',
    'loadingPic':       'Loading...',
    'fromGallery':      'Choose from Gallery',
    'fromGalleryHint':  'Pick a photo from your device',
    'takePhoto':        'Take a Photo',
    'takePhotoHint':    'Use your camera',
    'savedOk':          'Profile updated successfully!',
    'savedErr':         'Failed to save. Please try again.',
    'imageErr':         'Could not load image. Please try another photo.',
    'loadErr':          'Failed to load profile.',
  },
  kLangJa: {
    'title':            'プロフィール編集',
    'editPicture':      '画像を編集',
    'loading':          'プロフィールを読み込み中...',
    'retry':            '再試行',
    'sectionPersonal':  '個人情報',
    'nickname':         'ニックネーム / ユーザー名',
    'nicknameHint':     '例: PickleMaster',
    'nicknameError':    'ニックネーム / ユーザー名は必須です',
    'sectionLocation':  '場所',
    'address':          '住所',
    'addressHint':      '例: 東京都渋谷区',
    'sectionAbout':     '自己紹介',
    'description':      '説明',
    'descHint':         'コミュニティに自己紹介をしましょう...',
    'saveChanges':      '変更を保存',
    'loadingPic':       '読み込み中...',
    'fromGallery':      'ギャラリーから選択',
    'fromGalleryHint':  'デバイスから写真を選ぶ',
    'takePhoto':        '写真を撮る',
    'takePhotoHint':    'カメラを使用する',
    'savedOk':          'プロフィールを更新しました！',
    'savedErr':         '保存に失敗しました。もう一度お試しください。',
    'imageErr':         '画像を読み込めませんでした。別の写真をお試しください。',
    'loadErr':          'プロフィールの読み込みに失敗しました。',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double>   _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset>   _slideAnim;

  final _formKey               = GlobalKey<FormState>();
  final _nicknameController    = TextEditingController();
  final _addressController     = TextEditingController();
  final _descriptionController = TextEditingController();

  bool    _isLoading    = true;
  bool    _isSaving     = false;
  bool    _isPickingImg = false;
  String? _errorMessage;

  String? _profileImgDataUrl;
  File?   _pickedImageFile;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance
        .addPostFrameCallback((_) => _loadUserData());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _nicknameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  static String _rawBase64(String dataUrlOrBase64) {
    if (dataUrlOrBase64.contains(','))
      return dataUrlOrBase64.split(',').last;
    return dataUrlOrBase64;
  }

  // ── Load profile ──────────────────────────────────────────────────────────
  Future<void> _loadUserData() async {
    final lang = ref.read(appLangProvider);
    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final docSnap = await FirebaseFirestore.instance
          .collection('registration')
          .doc(authUser.uid)
          .get();

      if (!mounted) return;

      if (docSnap.exists && docSnap.data() != null) {
        final data = docSnap.data()!;

        final nickname = (data['nickname'] ?? '').toString().trim();
        if (nickname.isNotEmpty) {
          _nicknameController.text = nickname;
        } else {
          final first = (data['firstName'] ?? '').toString().trim();
          final last  = (data['lastName']  ?? '').toString().trim();
          _nicknameController.text =
              [first, last].where((s) => s.isNotEmpty).join(' ');
        }

        _addressController.text =
            (data['address'] ?? '').toString();
        _descriptionController.text =
            (data['description'] ?? '').toString();
        _profileImgDataUrl =
        (data['profile_img'] as String?)?.isNotEmpty == true
            ? data['profile_img'] as String
            : null;
      } else {
        _nicknameController.text =
            FirebaseAuth.instance.currentUser?.displayName ?? '';
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = _t(lang, 'loadErr'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick image ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    final lang = ref.read(appLangProvider);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary),
                ),
                title: Text(_t(lang, 'fromGallery'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(_t(lang, 'fromGalleryHint'),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary),
                ),
                title: Text(_t(lang, 'takePhoto'),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: Text(_t(lang, 'takePhotoHint'),
                    style: const TextStyle(
                        fontSize: 12, color: Colors.black45)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;
    setState(() => _isPickingImg = true);
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: source,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85);
      if (picked == null || !mounted) return;

      final bytes   = await File(picked.path).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final resized = img.copyResize(decoded,
          width:  decoded.width  > decoded.height ? 400 : -1,
          height: decoded.height > decoded.width  ? 400 : -1);
      final compressed = img.encodeJpg(resized, quality: 85);
      final base64Str  = base64Encode(compressed);

      setState(() {
        _pickedImageFile   = File(picked.path);
        _profileImgDataUrl = base64Str;
      });
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          message: _t(lang, 'imageErr'),
          icon: Icons.error_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImg = false);
    }
  }

  // ── Save profile ──────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final lang = ref.read(appLangProvider);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final nickname = _nicknameController.text.trim();

      await FirebaseFirestore.instance
          .collection('registration')
          .doc(authUser.uid)
          .set({
        'nickname':    nickname,
        'address':     _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'profile_img': _profileImgDataUrl ?? '',
      }, SetOptions(merge: true));

      await authUser.updateDisplayName(nickname);

      if (mounted) {
        _showSnackBar(
          message: _t(lang, 'savedOk'),
          icon: Icons.check_circle_rounded,
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar(
          message: _t(lang, 'savedErr'),
          icon: Icons.error_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar({
    required String   message,
    required IconData icon,
    required bool     isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message,
                style:
                const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor:
      isError ? Colors.red.shade400 : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ));
  }

  // ── Avatar ────────────────────────────────────────────────────────────────
  Widget _buildAvatar(String lang) {
    ImageProvider? imageProvider;

    if (_pickedImageFile != null) {
      imageProvider = FileImage(_pickedImageFile!);
    } else if (_profileImgDataUrl != null &&
        _profileImgDataUrl!.isNotEmpty) {
      try {
        imageProvider = MemoryImage(
            base64Decode(_rawBase64(_profileImgDataUrl!)));
      } catch (_) {
        imageProvider = null;
      }
    } else {
      final photoURL =
          FirebaseAuth.instance.currentUser?.photoURL;
      if (photoURL != null) imageProvider = NetworkImage(photoURL);
    }

    return GestureDetector(
      onTap: _isPickingImg ? null : _pickImage,
      child: Stack(children: [
        Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4))],
          ),
          child: ClipOval(
            child: _isPickingImg
                ? Container(
                color: AppColors.primary.withOpacity(0.2),
                child: const Center(
                    child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5))))
                : imageProvider != null
                ? Image(
                image: imageProvider,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _avatarPlaceholder())
                : _avatarPlaceholder(),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border:
              Border.all(color: AppColors.primary, width: 1.5),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2))],
            ),
            child: const Icon(Icons.camera_alt_rounded,
                size: 14, color: AppColors.primary),
          ),
        ),
      ]),
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: AppColors.primary.withOpacity(0.2),
    child: Center(
        child: Icon(Icons.person_rounded,
            size: 40, color: Colors.white.withOpacity(0.9))),
  );

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);
    final t    = (String key) => _t(lang, key);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: Text(t('title'),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    letterSpacing: 0.3)),
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
                        width: 170, height: 170,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.06)))),
                Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                        width: 120, height: 120,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.05)))),
                Positioned(
                  bottom: 18, left: 0, right: 0,
                  child: Column(children: [
                    _buildAvatar(lang),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _isPickingImg ? null : _pickImage,
                      child: Text(
                        _isPickingImg
                            ? t('loadingPic')
                            : t('editPicture'),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor:
                          Colors.white.withOpacity(0.88),
                        ),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _isLoading
                ? Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Center(
                    child: Column(children: [
                      const CircularProgressIndicator(
                          color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(t('loading'),
                          style: const TextStyle(
                              color: Colors.black45, fontSize: 14)),
                    ])))
                : _errorMessage != null
                ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 40),
                  const SizedBox(height: 12),
                  Text(_errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black54)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserData,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(12))),
                    child: Text(t('retry'),
                        style: const TextStyle(
                            color: Colors.white)),
                  ),
                ]))
                : FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // ── Personal Info ───────────────
                        _SectionHeader(
                            label: t('sectionPersonal')),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _nicknameController,
                            label: t('nickname'),
                            hint: t('nicknameHint'),
                            icon: Icons.badge_outlined,
                            isLast: true,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? t('nicknameError')
                                : null,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // ── Location ────────────────────
                        _SectionHeader(
                            label: t('sectionLocation')),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _addressController,
                            label: t('address'),
                            hint: t('addressHint'),
                            icon: Icons.location_on_outlined,
                            isLast: true,
                          ),
                        ]),

                        const SizedBox(height: 20),

                        // ── About You ───────────────────
                        _SectionHeader(
                            label: t('sectionAbout')),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller:
                            _descriptionController,
                            label: t('description'),
                            hint: t('descHint'),
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                            isLast: true,
                          ),
                        ]),

                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: (_isSaving ||
                                _isPickingImg)
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              AppColors.primary,
                              disabledBackgroundColor:
                              AppColors.primary
                                  .withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(
                                      14)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                width: 22,
                                height: 22,
                                child:
                                CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5))
                                : Text(t('saveChanges'),
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: 0.3)),
                          ),
                        ),

                        const SizedBox(height: 40),
                      ],
                    ),
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

// ── Supporting widgets ────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final List<Widget> children;
  const _FieldCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border:
      Border.all(color: AppColors.primary.withOpacity(0.12)),
      boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(label,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.1)),
  ]);
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool isLast;
  final int maxLines;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.isLast   = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    maxLines: maxLines,
    style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A)),
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle:
      TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
          fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w600),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      prefixIconConstraints:
      const BoxConstraints(minWidth: 0, minHeight: 0),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(
              color: Colors.red.shade300, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(
              color: Colors.red.shade400, width: 1.5)),
      contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 16 : 18, horizontal: 0),
      filled: false,
    ),
  );
}