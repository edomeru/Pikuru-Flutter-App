import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/providers/app_language_provider.dart';
import 'package:pikuru/screens/group_detail_screen.dart';
import 'package:pikuru/screens/individual_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Localised strings
// ─────────────────────────────────────────────────────────────────────────────
const _kLangEn = 'en';
const _kLangJa = 'ja';

const _L = {
  _kLangEn: {
    'unknownUser':   'Unknown User',
    'chatWith':      'Chat with',
    'about':         'About',
    'groupsJoined':  'Groups Joined',
    'noDescription': 'No description provided.',
    'noneFound':     'None found.',
    'users':         'Users',
    'userProfile':   'User Profile',
  },
  _kLangJa: {
    'unknownUser':   '不明なユーザー',
    'chatWith':      'チャットする',
    'about':         'について',
    'groupsJoined':  '参加グループ',
    'noDescription': '説明はありません。',
    'noneFound':     '見つかりませんでした。',
    'users':         'ユーザー',
    'userProfile':   'ユーザープロフィール',
  },
};

String _t(String lang, String key) =>
    _L[lang]?[key] ?? _L[_kLangEn]![key]!;

// ─────────────────────────────────────────────────────────────────────────────
// UserProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final String initialName;
  final String initialAvatar;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.initialName = '',
    this.initialAvatar = '',
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  String _name        = '';
  String _address     = '';
  String _description = '';

  // ── Two separate avatar sources, mirroring web toImgSrc priority ──────────
  // profile_img (base64 or data: uri) — highest priority
  String _profileImg  = '';
  // photoURL (Google / http URL) — fallback
  String _photoUrl    = '';

  bool _loadingProfile = true;

  List<Map<String, dynamic>> _userGroups = [];

  late final Stream<DocumentSnapshot> _profileStream;
  late final Stream<QuerySnapshot>    _groupsStream;

  @override
  void initState() {
    super.initState();
    _name      = widget.initialName;
    // Seed photoUrl from the initial avatar passed by SearchScreen
    // (avatarUrl already gives us the http URL)
    _photoUrl  = widget.initialAvatar;

    _profileStream = FirebaseFirestore.instance
        .collection('registration')
        .doc(widget.userId)
        .snapshots();

    _groupsStream = FirebaseFirestore.instance
        .collection('user_groups')
        .where('user_id', isEqualTo: widget.userId)
        .where('status',  isEqualTo: 'active')
        .snapshots();
  }

  // ── Resolve the best available avatar to an ImageProvider ─────────────────
  // Priority: profile_img (base64/data-uri) → photoURL (http) → null
  // Mirrors web app's toImgSrc() + priority logic exactly.
  ImageProvider? get _resolvedAvatarImage {
    // 1. Try profile_img (base64 stored image)
    if (_profileImg.isNotEmpty) {
      try {
        String src = _profileImg;
        // Wrap raw base64 in data-uri if needed
        if (!src.startsWith('data:') && !src.startsWith('http')) {
          src = 'data:image/jpeg;base64,$src';
        }
        if (src.startsWith('http')) return NetworkImage(src);
        if (src.startsWith('data:')) {
          final comma = src.indexOf(',');
          if (comma != -1) {
            return MemoryImage(base64Decode(src.substring(comma + 1)));
          }
        }
      } catch (_) {}
    }
    // 2. Fall back to photoURL (Google Auth or any http URL)
    if (_photoUrl.isNotEmpty) {
      try {
        return NetworkImage(_photoUrl);
      } catch (_) {}
    }
    return null;
  }

  // ── The raw string used when opening IndividualChatScreen ─────────────────
  String get _avatarRawForChat {
    if (_profileImg.isNotEmpty) return _profileImg;
    return _photoUrl;
  }

  String _parseName(Map<String, dynamic> d) {
    final nick  = (d['nickname']  ?? '').toString().trim();
    final first = (d['firstName'] ?? '').toString().trim();
    final last  = (d['lastName']  ?? '').toString().trim();
    if (nick.isNotEmpty) return nick;
    if (first.isNotEmpty && last.isNotEmpty) return '$first $last';
    if (first.isNotEmpty) return first;
    return '';
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    return name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
  }

  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IndividualChatScreen(
          otherUserId:     widget.userId,
          otherUserName:   _name,
          otherUserAvatar: _avatarRawForChat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appLangProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _profileStream,
        builder: (context, profileSnap) {
          if (profileSnap.hasData && profileSnap.data!.exists) {
            final d = profileSnap.data!.data() as Map<String, dynamic>;

            final parsed = _parseName(d);
            if (parsed.isNotEmpty) _name = parsed;

            _address     = (d['address']     ?? '').toString();
            _description = (d['description'] ?? '').toString();

            // ── Populate both avatar fields from Firestore ─────────────────
            // profile_img: base64 portrait stored by the user
            final rawProfileImg = (d['profile_img'] ?? '').toString().trim();
            if (rawProfileImg.isNotEmpty) _profileImg = rawProfileImg;

            // photoURL: Google / social auth URL
            final rawPhotoUrl = (d['photoURL'] ?? '').toString().trim();
            if (rawPhotoUrl.isNotEmpty) _photoUrl = rawPhotoUrl;

            _loadingProfile = false;
          } else if (profileSnap.connectionState == ConnectionState.active) {
            _loadingProfile = false;
          }

          if (_loadingProfile) {
            return const Scaffold(
              backgroundColor: Color(0xFFF2F4F7),
              body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }

          final displayName  = _name.isNotEmpty ? _name : _t(lang, 'unknownUser');
          final initials     = _initials(displayName);
          // Resolve inside build so every StreamBuilder rebuild gets fresh data
          final avatarImage  = _resolvedAvatarImage;

          return StreamBuilder<QuerySnapshot>(
            stream: _groupsStream,
            builder: (context, groupsSnap) {
              if (groupsSnap.hasData) {
                _userGroups = groupsSnap.data!.docs
                    .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
                    .toList();
              }

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildCover(context, displayName, initials, avatarImage, lang),
                  ),
                  SliverToBoxAdapter(
                    child: _buildBreadcrumb(displayName, lang),
                  ),
                  SliverToBoxAdapter(
                    child: _buildContent(context, displayName, lang),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Cover ─────────────────────────────────────────────────────────────────
  Widget _buildCover(
      BuildContext context,
      String displayName,
      String initials,
      ImageProvider? avatarImage,
      String lang,
      ) {
    return SizedBox(
      height: 280,
      child: Stack(
        clipBehavior: Clip.none,
        children: [

          // Layer 1: gradient fallback (always shown behind everything)
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end:   Alignment.bottomRight,
                colors: [Color(0xFF1a3d27), Color(0xFF4a9c5e)],
              ),
            ),
          ),

          // Layer 2: avatar as full-bleed hero image
          // Mirrors web: <img className="w-full h-full object-cover object-[center_20%]">
          if (avatarImage != null)
            Positioned.fill(
              child: Image(
                image: avatarImage,
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.6),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),

          // Layer 3: dark gradient overlay so text stays readable
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end:   Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.10),
                    Colors.black.withOpacity(0.80),
                  ],
                ),
              ),
            ),
          ),

          // Layer 4: thin accent line at bottom of cover
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.6),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _iconCircleButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),

          // Badge + name + address
          Positioned(
            bottom: 64,
            left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: Colors.white.withOpacity(0.28), width: 1),
                    ),
                    child: Text(
                      _t(lang, 'userProfile'),
                      style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w900,
                      color: Colors.white, height: 1.1, letterSpacing: -0.5,
                      shadows: [Shadow(blurRadius: 12, color: Colors.black38)],
                    ),
                  ),
                  if (_address.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(children: [
                      const Text('📍', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        _address,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ),

          // Avatar circle — half in / half out of cover
          Positioned(
            bottom: -44,
            left: 20,
            child: _buildAvatarCircle(avatarImage, initials),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarCircle(ImageProvider? avatarImage, String initials) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarImage != null
            ? Image(
          image: avatarImage,
          fit: BoxFit.cover,
          width: 88,
          height: 88,
          errorBuilder: (_, __, ___) => _avatarFallback(initials, size: 88),
        )
            : _avatarFallback(initials, size: 88),
      ),
    );
  }

  Widget _avatarFallback(String initials, {required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [Color(0xFF1a3d27), Color(0xFF4a9c5e)],
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: size * 0.32,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ── Breadcrumb ────────────────────────────────────────────────────────────
  Widget _buildBreadcrumb(String displayName, String lang) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(left: 16, right: 16, top: 56, bottom: 14),
      child: Row(
        children: [
          Text(
            _t(lang, 'users'),
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text('>', style: TextStyle(fontSize: 12, color: Colors.black.withOpacity(0.25))),
          ),
          Expanded(
            child: Text(
              displayName,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────
  Widget _buildContent(BuildContext context, String displayName, String lang) {
    final isWide = MediaQuery.of(context).size.width >= 700;
    final aboutCard  = _buildAboutCard(displayName, lang);
    final groupsCard = _buildGroupsSection(displayName, lang);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: isWide
          ? Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: aboutCard),
          const SizedBox(width: 16),
          Expanded(child: groupsCard),
        ],
      )
          : Column(
        children: [
          aboutCard,
          const SizedBox(height: 16),
          groupsCard,
        ],
      ),
    );
  }

  // ── About card ────────────────────────────────────────────────────────────
  Widget _buildAboutCard(String displayName, String lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _openChat,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        lang == _kLangJa
                            ? '$displayName${_t(lang, 'chatWith')}'
                            : '${_t(lang, 'chatWith')} $displayName',
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.black.withOpacity(0.06), width: 1),
                ),
                child: Icon(Icons.notifications_outlined, color: Colors.black.withOpacity(0.35), size: 22),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.black.withOpacity(0.06), height: 1),
          ),

          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_t(lang, 'about')} $displayName',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: Color(0xFF0D0D0D), letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _description.isNotEmpty ? _description : _t(lang, 'noDescription'),
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.50), height: 1.55,
              ),
            ),
          ),

          if (_address.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 17),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _address,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Groups section ────────────────────────────────────────────────────────
  Widget _buildGroupsSection(String displayName, String lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 6)],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _t(lang, 'groupsJoined'),
              style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w900,
                color: Color(0xFF0D0D0D), letterSpacing: -0.3,
              ),
            ),
            if (_userGroups.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.primary.withOpacity(0.25), width: 1),
                ),
                child: Text(
                  '${_userGroups.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        if (_userGroups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              _t(lang, 'noneFound'),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black.withOpacity(0.35)),
            ),
          )
        else
          ...(_userGroups.map((group) => _buildGroupCard(group))),
      ],
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final groupName  = (group['group_name']  ?? '').toString();
    final groupImage = (group['group_image'] ?? '').toString();

    ImageProvider? groupImageProvider;
    if (groupImage.isNotEmpty) {
      try {
        if (groupImage.startsWith('http')) {
          groupImageProvider = NetworkImage(groupImage);
        } else {
          groupImageProvider = MemoryImage(base64Decode(groupImage));
        }
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => GroupDetailScreen(group: group)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 14, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.08),
              ),
              child: ClipOval(
                child: groupImageProvider != null
                    ? Image(image: groupImageProvider, fit: BoxFit.cover)
                    : Center(
                  child: Text(
                    groupName.isNotEmpty ? groupName[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A), letterSpacing: -0.2,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reusable icon circle button ───────────────────────────────────────────
  Widget _iconCircleButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.40),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}