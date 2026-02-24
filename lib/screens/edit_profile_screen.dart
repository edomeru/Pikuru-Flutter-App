import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
    });
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

  // ── Load from Firestore 'registration' collection ─────────────────
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final uid = authUser.uid;
      debugPrint('Loading profile for uid: $uid');

      // ✅ Read directly from registration/{uid}
      final doc = await FirebaseFirestore.instance
          .collection('registration')
          .doc(uid)
          .get();

      debugPrint('Document exists: ${doc.exists}');

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        debugPrint('Data loaded: $data');
        _firstNameController.text = (data['firstName'] ?? '').toString();
        _lastNameController.text = (data['lastName'] ?? '').toString();
        _addressController.text = (data['address'] ?? '').toString();
        _descriptionController.text = (data['description'] ?? '').toString();
      } else {
        // Fallback: pre-fill from Firebase Auth display name
        final displayName = authUser.displayName ?? '';
        final parts = displayName.trim().split(' ');
        _firstNameController.text = parts.isNotEmpty ? parts.first : '';
        _lastNameController.text =
        parts.length > 1 ? parts.sublist(1).join(' ') : '';
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _errorMessage = 'Failed to load profile.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Save to Firestore 'registration' collection ───────────────────
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final authUser = FirebaseAuth.instance.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      final uid = authUser.uid;
      final firstName = _firstNameController.text.trim();
      final lastName = _lastNameController.text.trim();

      // ✅ Update registration/{uid} — merge so other fields are untouched
      await FirebaseFirestore.instance
          .collection('registration')
          .doc(uid)
          .set(
        {
          'firstName': firstName,
          'lastName': lastName,
          'address': _addressController.text.trim(),
          'description': _descriptionController.text.trim(),
        },
        SetOptions(merge: true), // keeps email, uid, createdAt intact
      );

      // Update Firebase Auth display name too
      await authUser.updateDisplayName('$firstName $lastName');

      debugPrint('✅ Profile saved to registration/$uid');

      if (mounted) {
        _showSnackBar(
          message: 'Profile updated successfully!',
          icon: Icons.check_circle_rounded,
          isError: false,
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade400 : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F9F5),
      body: CustomScrollView(
        slivers: [
          // ── Hero App Bar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.maybePop(context),
            ),
            title: const Text(
              'Edit Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            ),
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
                  Positioned(
                    top: -40, right: -30,
                    child: Container(
                      width: 170, height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -20, left: -20,
                    child: Container(
                      width: 120, height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 18, left: 0, right: 0,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 82, height: 82,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: user?.photoURL != null
                                    ? Image.network(user!.photoURL!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _avatarPlaceholder())
                                    : _avatarPlaceholder(),
                              ),
                            ),
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                width: 26, height: 26,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.primary, width: 1.5),
                                ),
                                child: Icon(Icons.camera_alt_rounded,
                                    size: 14, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Edit picture',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.88),
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.white.withOpacity(0.88),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 16),
                    Text('Loading your profile...',
                        style: TextStyle(
                            color: Colors.black45, fontSize: 14)),
                  ],
                ),
              ),
            )
                : _errorMessage != null
                ? Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.error_outline,
                      color: Colors.red.shade400, size: 40),
                  const SizedBox(height: 12),
                  Text(_errorMessage!,
                      textAlign: TextAlign.center,
                      style:
                      const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadUserData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Retry',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
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
                        // ── Personal Info ─────────────
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

                        // ── Location ──────────────────
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

                        // ── About You ─────────────────
                        const _SectionHeader(label: 'About You'),
                        const SizedBox(height: 12),
                        _FieldCard(children: [
                          _FormField(
                            controller: _descriptionController,
                            label: 'Description',
                            hint:
                            'Tell the community about yourself...',
                            icon: Icons.notes_rounded,
                            maxLines: 4,
                            isLast: true,
                          ),
                        ]),

                        const SizedBox(height: 32),

                        // ── Save Button ───────────────
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed:
                            _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors
                                  .primary
                                  .withOpacity(0.6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
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

  Widget _avatarPlaceholder() {
    return Container(
      color: AppColors.primary.withOpacity(0.2),
      child: Center(
        child: Icon(Icons.person_rounded,
            size: 40, color: Colors.white.withOpacity(0.9)),
      ),
    );
  }
}

// ── Field Card ────────────────────────────────────────────────────────
class _FieldCard extends StatelessWidget {
  final List<Widget> children;
  const _FieldCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ── Field Divider ─────────────────────────────────────────────────────
class _FieldDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: AppColors.primary.withOpacity(0.08),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

// ── Form Field ────────────────────────────────────────────────────────
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
    this.isLast = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Color(0xFF1A1A1A),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isLast ? 16 : 0),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(
            vertical: maxLines > 1 ? 16 : 18, horizontal: 0),
        filled: false,
      ),
    );
  }
}