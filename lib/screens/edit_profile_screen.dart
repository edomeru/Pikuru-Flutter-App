import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:pikuru/theme/material.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnim;

  final _formKey = GlobalKey<FormState>();
  final _firstNameController   = TextEditingController();
  final _lastNameController    = TextEditingController();
  final _addressController     = TextEditingController();
  final _descriptionController = TextEditingController();

  bool    _isLoading    = true;
  bool    _isSaving     = false;
  bool    _isPickingImg = false;
  String? _errorMessage;

  // Stored as the full data URL (e.g. "data:image/jpeg;base64,/9j/...")
  // because that's what the web app saves. We strip the prefix when decoding.
  String? _profileImgDataUrl;

  // Local file picked from device — shown as preview before saving
  File? _pickedImageFile;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700))
      ..forward();
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(
        parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserData());
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ── Strip data URL prefix to get raw base64 ───────────────────────
  // Web app saves "data:image/jpeg;base64,/9j/..."
  // base64Decode needs only "/9j/..." (after the comma)
  static String _rawBase64(String dataUrlOrBase64) {
    if (dataUrlOrBase64.contains(',')) {
      return dataUrlOrBase64.split(',').last;
    }
    return dataUrlOrBase64;
  }

  // ── Load profile from Firestore ───────────────────────────────────
  Future<void> _loadUserData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final doc = await FirebaseFirestore.instance
          .collection('registration')
          .doc(authUser.uid)
          .get();

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        _firstNameController.text   = (data['firstName']   ?? '').toString();
        _lastNameController.text    = (data['lastName']    ?? '').toString();
        _addressController.text     = (data['address']     ?? '').toString();
        _descriptionController.text = (data['description'] ?? '').toString();
        // Store the full value from Firestore (may be data URL or raw base64)
        _profileImgDataUrl = (data['profile_img'] as String?)
            ?.isNotEmpty == true ? data['profile_img'] as String : null;
      } else {
        final parts = (authUser.displayName ?? '').trim().split(' ');
        _firstNameController.text = parts.isNotEmpty ? parts.first : '';
        _lastNameController.text  = parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Failed to load profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Pick image from device ────────────────────────────────────────
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.photo_library_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Pick a photo from your device',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppColors.primary),
                ),
                title: const Text('Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                subtitle: const Text('Use your camera',
                    style: TextStyle(fontSize: 12, color: Colors.black45)),
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
        imageQuality: 85,
      );

      if (picked == null || !mounted) return;

      final file  = File(picked.path);
      final bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final resized = img.copyResize(decoded,
          width:  decoded.width  > decoded.height ? 400 : -1,
          height: decoded.height > decoded.width  ? 400 : -1);

      final compressed = img.encodeJpg(resized, quality: 85);

      // Save as raw base64 (Flutter-picked images don't need the data URL prefix)
      final base64Str = base64Encode(compressed);

      setState(() {
        _pickedImageFile   = file;       // local preview
        _profileImgDataUrl = base64Str;  // raw base64, no prefix needed
      });
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Could not load image. Please try another photo.',
          icon: Icons.error_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImg = false);
    }
  }

  // ── Save profile to Firestore ─────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final firstName = _firstNameController.text.trim();
      final lastName  = _lastNameController.text.trim();

      await FirebaseFirestore.instance
          .collection('registration')
          .doc(authUser.uid)
          .set({
        'firstName':   firstName,
        'lastName':    lastName,
        'address':     _addressController.text.trim(),
        'description': _descriptionController.text.trim(),
        'profile_img': _profileImgDataUrl ?? '',
      }, SetOptions(merge: true));

      await authUser.updateDisplayName('$firstName $lastName');

      if (mounted) {
        _showSnackBar(
          message: 'Profile updated successfully!',
          icon: Icons.check_circle_rounded,
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(
          message: 'Failed to save. Please try again.',
          icon: Icons.error_rounded,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackBar({
    required String message,
    required IconData icon,
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
      backgroundColor: isError ? Colors.red.shade400 : AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    ));
  }

  // ── Build avatar ──────────────────────────────────────────────────
  Widget _buildAvatar() {
    ImageProvider? imageProvider;

    if (_pickedImageFile != null) {
      // Freshly picked from device — use FileImage directly
      imageProvider = FileImage(_pickedImageFile!);
    } else if (_profileImgDataUrl != null && _profileImgDataUrl!.isNotEmpty) {
      // From Firestore — may be a data URL ("data:image/jpeg;base64,...")
      // OR raw base64 (saved by Flutter). Strip prefix if present.
      try {
        final raw = _rawBase64(_profileImgDataUrl!);
        imageProvider = MemoryImage(base64Decode(raw));
      } catch (_) {
        imageProvider = null; // fall through to placeholder
      }
    } else {
      // Fall back to Google/Firebase Auth photoURL
      final photoURL = FirebaseAuth.instance.currentUser?.photoURL;
      if (photoURL != null) imageProvider = NetworkImage(photoURL);
    }

    return GestureDetector(
      onTap: _isPickingImg ? null : _pickImage,
      child: Stack(
        children: [
          Container(
            width: 82, height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: ClipOval(
              child: _isPickingImg
                  ? Container(
                  color: AppColors.primary.withOpacity(0.2),
                  child: const Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )))
                  : imageProvider != null
                  ? Image(
                  image: imageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarPlaceholder())
                  : _avatarPlaceholder(),
            ),
          ),
          // Camera badge
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 1.5),
                boxShadow: [BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 14, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() => Container(
    color: AppColors.primary.withOpacity(0.2),
    child: Center(child: Icon(Icons.person_rounded,
        size: 40, color: Colors.white.withOpacity(0.9))),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text('Edit Profile',
                style: TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w600, fontSize: 18,
                    letterSpacing: 0.3)),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
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
                  Positioned(top: -40, right: -30,
                      child: Container(width: 170, height: 170,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.06)))),
                  Positioned(bottom: -20, left: -20,
                      child: Container(width: 120, height: 120,
                          decoration: BoxDecoration(shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05)))),
                  Positioned(
                    bottom: 18, left: 0, right: 0,
                    child: Column(
                      children: [
                        _buildAvatar(),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isPickingImg ? null : _pickImage,
                          child: Text(
                            _isPickingImg ? 'Loading...' : 'Edit picture',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                              decorationColor: Colors.white.withOpacity(0.88),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: Column(children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Loading your profile...',
                    style: TextStyle(color: Colors.black45, fontSize: 14)),
              ])),
            )
                : _errorMessage != null
                ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.error_outline,
                    color: Colors.red.shade400, size: 40),
                const SizedBox(height: 12),
                Text(_errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadUserData,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: const Text('Retry',
                      style: TextStyle(color: Colors.white)),
                ),
              ]),
            )
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader(label: 'Personal Info'),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _firstNameController,
                            label: 'First Name',
                            icon: Icons.badge_outlined,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'First name is required'
                                : null,
                          ),
                          _FieldDivider(),
                          _FormField(
                            controller: _lastNameController,
                            label: 'Last Name',
                            icon: Icons.badge_rounded,
                            isLast: true,
                            validator: (v) =>
                            v == null || v.trim().isEmpty
                                ? 'Last name is required'
                                : null,
                          ),
                        ]),

                        const SizedBox(height: 20),
                        const _SectionHeader(label: 'Location'),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _addressController,
                            label: 'Address',
                            hint: 'e.g. Shibuya, Tokyo',
                            icon: Icons.location_on_outlined,
                            isLast: true,
                          ),
                        ]),

                        const SizedBox(height: 20),
                        const _SectionHeader(label: 'About You'),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint: 'Tell the community about yourself...',
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
                            onPressed: (_isSaving || _isPickingImg)
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor:
                              AppColors.primary.withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(14)),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                width: 22, height: 22,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5))
                                : const Text('Save Changes',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
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
      border: Border.all(color: AppColors.primary.withOpacity(0.12)),
      boxShadow: [BoxShadow(
          color: AppColors.primary.withOpacity(0.06),
          blurRadius: 14, offset: const Offset(0, 4))],
    ),
    child: Column(children: children),
  );
}

class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, thickness: 1, indent: 56,
      color: AppColors.primary.withOpacity(0.08));
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 4, height: 18,
      decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 8),
    Text(label, style: const TextStyle(
        fontSize: 15, fontWeight: FontWeight.w800,
        color: AppColors.primary, letterSpacing: 0.1)),
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
    required this.controller, required this.label, required this.icon,
    this.hint, this.isLast = false, this.maxLines = 1, this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    validator: validator,
    maxLines: maxLines,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A)),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14,
          fontWeight: FontWeight.w500),
      floatingLabelStyle: const TextStyle(color: AppColors.primary,
          fontSize: 12, fontWeight: FontWeight.w600),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 16, right: 12),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      border: InputBorder.none, enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5)),
      contentPadding: EdgeInsets.symmetric(
          vertical: maxLines > 1 ? 16 : 18, horizontal: 0),
      filled: false,
    ),
  );
}