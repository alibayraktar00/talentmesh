import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileService = ProfileService();
  bool _isLoading = true;

  // ── Mevcut veriler ──
  String _fullName = '';
  String _title = '';
  String _department = '';
  String _email = '';
  String _phone = '';
  String _location = '';
  String _about = '';
  bool _openToWork = true;
  List<Map<String, String>> _experiences = [];
  List<Map<String, String>> _languages = [];
  List<String> _skills = [];

  // ── Yeni veriler ──
  String _avatarUrl = '';
  List<Map<String, String>> _education = [];
  List<Map<String, String>> _certificates = [];
  List<Map<String, String>> _projects = [];
  Map<String, String> _socialLinks = {};
  Map<String, String> _availability = {};
  List<String> _rolePreferences = [];
  int _completedProjects = 0;
  int _teamsJoined = 0;
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _profileService.fetchProfile();
    final reviews = await _profileService.fetchReviews();
    if (data != null) {
      setState(() {
        _fullName = data['full_name'] ?? '';
        _title = data['title'] ?? '';
        _department = data['department'] ?? '';
        _email = data['email'] ?? '';
        _phone = data['phone'] ?? '';
        _location = data['location'] ?? '';
        _about = data['bio'] ?? '';
        _openToWork = data['open_to_work'] ?? true;
        _experiences = _parseJsonList(data['experience']);
        _languages = _parseJsonList(data['languages']);
        _skills = List<String>.from(data['skills'] ?? []);
        _avatarUrl = data['avatar_url'] ?? '';
        
        if (data['school'] != null && data['school'].toString().isNotEmpty) {
          _education = [{
            'school': data['school']?.toString() ?? '',
            'department': data['department']?.toString() ?? '',
            'year': data['education_year']?.toString() ?? '',
            'degree': data['degree']?.toString() ?? '',
          }];
        } else {
          _education = [];
        }

        _certificates = _parseJsonList(data['certificates']);
        _projects = _parseJsonList(data['projects']);
        _socialLinks = _parseStringMap(data['social_media']);
        _availability = _parseStringMap(data['availability']);
        _rolePreferences = List<String>.from(data['looking_for'] ?? []);
        final stats = data['stats'] as Map<String, dynamic>? ?? {};
        _completedProjects = stats['completed_projects'] ?? 0;
        _teamsJoined = stats['teams_joined'] ?? 0;
        _reviews = reviews;
        _isLoading = false;
      });
    } else {
      setState(() {
        _reviews = reviews;
        _isLoading = false;
      });
    }
  }

  List<Map<String, String>> _parseJsonList(dynamic json) {
    if (json == null) return [];
    if (json is List) {
      return json.map((e) {
        if (e is Map) {
          return e.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        return <String, String>{};
      }).toList();
    }
    return [];
  }

  Map<String, String> _parseStringMap(dynamic json) {
    if (json == null) return {};
    if (json is Map) {
      return json.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }

  Future<void> _saveAll() async {
    try {
      await _profileService.upsertProfile({
        'full_name': _fullName,
        'title': _title,
        'department': _department,
        'email': _email,
        'phone': _phone,
        'location': _location,
        'about': _about,
        'open_to_work': _openToWork,
        'experiences': _experiences,
        'languages': _languages,
        'skills': _skills,
        'avatar_url': _avatarUrl,
        'education': _education,
        'certificates': _certificates,
        'projects': _projects,
        'social_links': _socialLinks,
        'availability': _availability,
        'role_preferences': _rolePreferences,
        'stats': {
          'completed_projects': _completedProjects,
          'teams_joined': _teamsJoined,
        },
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kaydedilemedi: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(context)),
          SliverToBoxAdapter(child: _buildContactInfo()),
          SliverToBoxAdapter(child: _buildOpenToWorkBanner()),
          SliverToBoxAdapter(child: _buildStatsSection()),
          SliverToBoxAdapter(child: _buildBadgesSection()),
          SliverToBoxAdapter(child: _buildProfileSection()),
          SliverToBoxAdapter(child: _buildAvailabilitySection()),
          SliverToBoxAdapter(child: _buildRolePreferencesSection()),
          SliverToBoxAdapter(child: _buildExperienceSection()),
          SliverToBoxAdapter(child: _buildEducationSection()),
          SliverToBoxAdapter(child: _buildCertificatesSection()),
          SliverToBoxAdapter(child: _buildProjectsSection()),
          SliverToBoxAdapter(child: _buildSkillsSection()),
          SliverToBoxAdapter(child: _buildLanguagesSection()),
          SliverToBoxAdapter(child: _buildSocialLinksSection()),
          SliverToBoxAdapter(child: _buildReviewsSection()),
          SliverToBoxAdapter(child: _buildQRSection()),
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ──────────────────────── HEADER ────────────────────────
  // ══════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryAccent.withValues(alpha: 0.15),
                AppColors.primaryDark.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            image: const DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1497366216548-37526070297c?w=800&q=80',
              ),
              fit: BoxFit.cover,
              opacity: 0.35,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.black.withValues(alpha: 0.08), Colors.transparent],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          child: _buildCircleButton(
            icon: Icons.arrow_back_ios_new,
            color: AppColors.headingText,
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        // Edit button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: _buildCircleButton(
            icon: Icons.edit_outlined,
            color: AppColors.primaryAccent,
            onTap: _showEditNameDialog,
          ),
        ),
        // Profile photo + name
        Positioned(
          top: 105,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.chipBg,
                        backgroundImage:
                            _avatarUrl.isNotEmpty ? NetworkImage(_avatarUrl) : null,
                        child: _avatarUrl.isEmpty
                            ? (_fullName.isNotEmpty
                                ? Text(_fullName[0].toUpperCase(),
                                    style: GoogleFonts.inter(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primaryAccent))
                                : const Icon(Icons.person,
                                    size: 40, color: AppColors.primaryAccent))
                            : null,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: AppColors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _fullName.isNotEmpty ? _fullName : 'İsminizi girin',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _fullName.isNotEmpty ? AppColors.headingText : AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _title.isNotEmpty ? _title : 'Ünvanınızı girin',
                style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(icon: Icon(icon, size: 18), color: color, onPressed: onTap),
    );
  }

  // ──────────────────────── CONTACT INFO ────────────────────────
  Widget _buildContactInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 130, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildContactRow(Icons.email_outlined, _email.isNotEmpty ? _email : 'E-posta ekleyin'),
                const SizedBox(height: 10),
                _buildContactRow(Icons.phone_outlined, _phone.isNotEmpty ? _phone : 'Telefon ekleyin'),
                const SizedBox(height: 10),
                _buildContactRow(Icons.location_on_outlined, _location.isNotEmpty ? _location : 'Konum ekleyin'),
              ],
            ),
          ),
          _buildEditIcon(_showEditContactDialog),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 10),
        Flexible(
          child: Text(text,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.bodyText)),
        ),
      ],
    );
  }

  // ──────────────────────── OPEN TO WORK ────────────────────────
  Widget _buildOpenToWorkBanner() {
    return GestureDetector(
      onTap: () async {
        final newValue = !_openToWork;
        setState(() => _openToWork = newValue);
        try {
          await _profileService.updateOpenToWork(newValue);
        } catch (e) {
          setState(() => _openToWork = !newValue);
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _openToWork ? AppColors.onlineGreen.withValues(alpha: 0.3) : AppColors.inputBorder,
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _openToWork ? AppColors.onlineGreen.withValues(alpha: 0.12) : AppColors.chipBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.work_outline,
                  color: _openToWork ? AppColors.onlineGreen : AppColors.mutedText, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_openToWork ? 'OPEN TO WORK' : 'NOT LOOKING',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingText, letterSpacing: 0.5)),
                  const SizedBox(height: 2),
                  Text(_openToWork ? 'Looking for opportunities' : 'Tap to change',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
                ],
              ),
            ),
            Switch(
              value: _openToWork,
              onChanged: (v) async { 
                setState(() => _openToWork = v);
                try {
                  await _profileService.updateOpenToWork(v);
                } catch (e) {
                  setState(() => _openToWork = !v);
                }
              },
              activeTrackColor: AppColors.onlineGreen,
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── 11. STATS ────────────────────────
  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('İstatistikler', style: _sectionTitleStyle()),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatCard(Icons.assignment_turned_in, '$_completedProjects', 'Tamamlanan\nProje'),
              const SizedBox(width: 12),
              _buildStatCard(Icons.groups, '$_teamsJoined', 'Katıldığı\nTakım'),
              const SizedBox(width: 12),
              _buildStatCard(Icons.star, _reviews.isNotEmpty
                  ? (_reviews.map((r) => r['rating'] as int? ?? 0).reduce((a, b) => a + b) / _reviews.length).toStringAsFixed(1)
                  : '0', 'Ortalama\nPuan'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryAccent, size: 24),
            const SizedBox(height: 8),
            Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.headingText)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedText, height: 1.3)),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── 10. BADGES ────────────────────────
  Widget _buildBadgesSection() {
    final badges = <Map<String, dynamic>>[];
    if (_completedProjects >= 1) badges.add({'icon': Icons.emoji_events, 'label': 'İlk Proje', 'color': const Color(0xFFFFB300)});
    if (_completedProjects >= 5) badges.add({'icon': Icons.workspace_premium, 'label': '5 Proje', 'color': const Color(0xFF7C4DFF)});
    if (_teamsJoined >= 3) badges.add({'icon': Icons.diversity_3, 'label': 'Takım Oyuncusu', 'color': AppColors.primaryAccent});
    if (_skills.length >= 5) badges.add({'icon': Icons.auto_awesome, 'label': 'Çok Yönlü', 'color': const Color(0xFF00BFA5)});
    if (_reviews.length >= 3) badges.add({'icon': Icons.thumb_up, 'label': 'Güvenilir', 'color': const Color(0xFFFF7043)});
    if (_about.length >= 100) badges.add({'icon': Icons.edit_note, 'label': 'Detaycı', 'color': const Color(0xFF42A5F5)});

    if (badges.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Başarı Rozetleri', style: _sectionTitleStyle()),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges.map((b) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (b['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (b['color'] as Color).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(b['icon'] as IconData, size: 16, color: b['color'] as Color),
                    const SizedBox(width: 6),
                    Text(b['label'] as String,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: b['color'] as Color)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── PROFILE ABOUT ────────────────────────
  Widget _buildProfileSection() {
    return _buildSection(
      title: 'Profil',
      onEdit: _showEditAboutDialog,
      child: Text(
        _about.isNotEmpty ? _about : 'Kendinizi tanıtın...',
        style: GoogleFonts.inter(
            fontSize: 13.5, height: 1.55, color: _about.isNotEmpty ? AppColors.bodyText : AppColors.mutedText),
      ),
    );
  }

  // ──────────────────────── 7. AVAILABILITY ────────────────────────
  Widget _buildAvailabilitySection() {
    return _buildSection(
      title: 'Müsaitlik Durumu',
      onEdit: _showEditAvailabilityDialog,
      child: _availability.isEmpty
          ? Text('Müsaitlik bilgisi ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_availability['hours_per_week']?.isNotEmpty == true)
                  _buildInfoRow(Icons.schedule, '${_availability['hours_per_week']} saat/hafta'),
                if (_availability['timezone']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.public, _availability['timezone']!),
                ],
                if (_availability['note']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.info_outline, _availability['note']!),
                ],
              ],
            ),
    );
  }

  // ──────────────────────── 8. ROLE PREFERENCES ────────────────────────
  Widget _buildRolePreferencesSection() {
    return _buildSection(
      title: 'Aranan Roller',
      onEdit: _showAddRoleDialog,
      child: _rolePreferences.isEmpty
          ? Text('Rol tercihi ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Wrap(
              spacing: 8, runSpacing: 8,
              children: _rolePreferences.map((role) => _buildDeletableChip(role, () async {
                setState(() => _rolePreferences.remove(role));
                try { await _profileService.updateDynamicProfileField('looking_for', _rolePreferences); } catch(e){}
              }, AppColors.primaryAccent)).toList(),
            ),
    );
  }

  // ──────────────────────── EXPERIENCE ────────────────────────
  Widget _buildExperienceSection() {
    return _buildSection(
      title: 'Deneyimler',
      onEdit: () => _showExperienceDialog(-1),
      child: _experiences.isEmpty
          ? Text('Deneyim ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              children: List.generate(_experiences.length, (i) {
                final e = _experiences[i];
                return Column(
                  children: [
                    if (i > 0) ...[const SizedBox(height: 12), Divider(color: AppColors.inputBorder.withValues(alpha: 0.6), height: 1), const SizedBox(height: 12)],
                    _buildTimelineItem(
                      icon: Icons.work_outline,
                      title: e['title'] ?? '',
                      subtitle: e['company'] ?? '',
                      meta: e['period'] ?? '',
                      description: e['description'] ?? '',
                      onTap: () => _showExperienceDialog(i),
                      onDelete: () async { setState(() => _experiences.removeAt(i)); try { await _profileService.updateDynamicProfileField('experience', _experiences); } catch(e){} },
                    ),
                  ],
                );
              }),
            ),
    );
  }

  // ──────────────────────── 1. EDUCATION ────────────────────────
  Widget _buildEducationSection() {
    return _buildSection(
      title: 'Eğitim',
      onEdit: () => _showEducationDialog(-1),
      child: _education.isEmpty
          ? Text('Eğitim bilgisi ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              children: List.generate(_education.length, (i) {
                final e = _education[i];
                return Column(
                  children: [
                    if (i > 0) ...[const SizedBox(height: 12), Divider(color: AppColors.inputBorder.withValues(alpha: 0.6), height: 1), const SizedBox(height: 12)],
                    _buildTimelineItem(
                      icon: Icons.school_outlined,
                      title: e['school'] ?? '',
                      subtitle: e['department'] ?? '',
                      meta: e['year'] ?? '',
                      description: e['degree'] ?? '',
                      onTap: () => _showEducationDialog(i),
                      onDelete: () async { setState(() => _education.removeAt(i)); try { await _profileService.updateEducation('', '', '', ''); } catch(e){} },
                    ),
                  ],
                );
              }),
            ),
    );
  }

  // ──────────────────────── 2. CERTIFICATES ────────────────────────
  Widget _buildCertificatesSection() {
    return _buildSection(
      title: 'Sertifikalar',
      onEdit: () => _showCertificateDialog(-1),
      child: _certificates.isEmpty
          ? Text('Sertifika ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              children: List.generate(_certificates.length, (i) {
                final c = _certificates[i];
                return Column(
                  children: [
                    if (i > 0) ...[const SizedBox(height: 12), Divider(color: AppColors.inputBorder.withValues(alpha: 0.6), height: 1), const SizedBox(height: 12)],
                    _buildTimelineItem(
                      icon: Icons.verified_outlined,
                      title: c['name'] ?? '',
                      subtitle: c['issuer'] ?? '',
                      meta: c['date'] ?? '',
                      description: '',
                      onTap: () => _showCertificateDialog(i),
                      onDelete: () async { setState(() => _certificates.removeAt(i)); try { await _profileService.updateDynamicProfileField('certificates', _certificates); } catch(e){} },
                    ),
                  ],
                );
              }),
            ),
    );
  }

  // ──────────────────────── 3. PROJECTS / PORTFOLIO ────────────────────────
  Widget _buildProjectsSection() {
    return _buildSection(
      title: 'Projeler / Portfolyo',
      onEdit: () => _showProjectDialog(-1),
      child: _projects.isEmpty
          ? Text('Proje ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              children: List.generate(_projects.length, (i) {
                final p = _projects[i];
                return Column(
                  children: [
                    if (i > 0) ...[const SizedBox(height: 12), Divider(color: AppColors.inputBorder.withValues(alpha: 0.6), height: 1), const SizedBox(height: 12)],
                    _buildTimelineItem(
                      icon: Icons.rocket_launch_outlined,
                      title: p['name'] ?? '',
                      subtitle: p['link'] ?? '',
                      meta: '',
                      description: p['description'] ?? '',
                      onTap: () => _showProjectDialog(i),
                      onDelete: () async { setState(() => _projects.removeAt(i)); try { await _profileService.updateDynamicProfileField('projects', _projects); } catch(e){} },
                    ),
                  ],
                );
              }),
            ),
    );
  }

  // ──────────────────────── SKILLS ────────────────────────
  Widget _buildSkillsSection() {
    return _buildSection(
      title: 'Yetenekler',
      onEdit: _showAddSkillDialog,
      child: _skills.isEmpty
          ? Text('Yetenek ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Wrap(
              spacing: 8, runSpacing: 8,
              children: _skills.map((s) => _buildDeletableChip(s, () async {
                setState(() => _skills.remove(s));
                try { await _profileService.updateDynamicProfileField('skills', _skills); } catch(e){}
              }, AppColors.primaryDark)).toList(),
            ),
    );
  }

  // ──────────────────────── LANGUAGES ────────────────────────
  Widget _buildLanguagesSection() {
    return _buildSection(
      title: 'Diller',
      onEdit: _showAddLanguageDialog,
      child: _languages.isEmpty
          ? Text('Dil ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              children: List.generate(_languages.length, (i) {
                final l = _languages[i];
                return Padding(
                  padding: EdgeInsets.only(top: i > 0 ? 8 : 0),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primaryAccent, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text('${l['language']} · ${l['level']}', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.bodyText))),
                      GestureDetector(onTap: () async { setState(() => _languages.removeAt(i)); try { await _profileService.updateDynamicProfileField('languages', _languages); } catch(e){} },
                          child: Icon(Icons.close, size: 16, color: AppColors.mutedText.withValues(alpha: 0.5))),
                    ],
                  ),
                );
              }),
            ),
    );
  }

  // ──────────────────────── 4. SOCIAL LINKS ────────────────────────
  Widget _buildSocialLinksSection() {
    return _buildSection(
      title: 'Sosyal Medya',
      onEdit: _showEditSocialLinksDialog,
      child: _socialLinks.isEmpty || _socialLinks.values.every((v) => v.isEmpty)
          ? Text('Sosyal medya linkleri ekleyin...', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_socialLinks['linkedin']?.isNotEmpty == true)
                  _buildSocialRow(Icons.link, 'LinkedIn', _socialLinks['linkedin']!),
                if (_socialLinks['github']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildSocialRow(Icons.code, 'GitHub', _socialLinks['github']!),
                ],
                if (_socialLinks['twitter']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildSocialRow(Icons.alternate_email, 'Twitter', _socialLinks['twitter']!),
                ],
                if (_socialLinks['website']?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  _buildSocialRow(Icons.language, 'Website', _socialLinks['website']!),
                ],
              ],
            ),
    );
  }

  Widget _buildSocialRow(IconData icon, String label, String url) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryAccent),
        const SizedBox(width: 10),
        Text('$label: ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.bodyText)),
        Expanded(
          child: Text(url, style: GoogleFonts.inter(fontSize: 13, color: AppColors.primaryAccent),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  // ──────────────────────── 6. REVIEWS ────────────────────────
  Widget _buildReviewsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Değerlendirmeler', style: _sectionTitleStyle()),
          const SizedBox(height: 14),
          _reviews.isEmpty
              ? Text('Henüz değerlendirme yok.', style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.mutedText))
              : Column(
                  children: _reviews.take(3).map((r) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.chipBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: List.generate(5, (i) => Icon(
                                i < (r['rating'] ?? 0) ? Icons.star : Icons.star_border,
                                size: 16, color: const Color(0xFFFFB300),
                              )),
                            ),
                            if ((r['comment'] ?? '').toString().isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(r['comment'].toString(),
                                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.bodyText, height: 1.4)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ──────────────────────── 12. QR CODE ────────────────────────
  Widget _buildQRSection() {
    final userId = _profileService.userId;
    if (userId == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text('Profili Paylaş', style: _sectionTitleStyle()),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: QrImageView(
              data: 'talentmesh://profile/$userId',
              version: QrVersions.auto,
              size: 180,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primaryDark),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.primaryAccent),
            ),
          ),
          const SizedBox(height: 10),
          Text('Bu QR kodu paylaşarak profilinize erişim sağlayın',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText)),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ──────────────────── SHARED WIDGETS ────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildSection({required String title, required VoidCallback onEdit, required Widget child}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: _sectionTitleStyle()),
              _buildEditIcon(onEdit),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildEditIcon(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32,
        decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.edit_outlined, color: AppColors.primaryAccent, size: 18),
      ),
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String meta,
    required String description,
    required VoidCallback onTap,
    required VoidCallback onDelete,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primaryAccent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.headingText)),
                if (subtitle.isNotEmpty) ...[const SizedBox(height: 2), Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.bodyText))],
                if (meta.isNotEmpty) ...[const SizedBox(height: 2), Text(meta, style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedText))],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(margin: const EdgeInsets.only(top: 6), width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.mutedText, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(description, style: GoogleFonts.inter(fontSize: 12.5, height: 1.5, color: AppColors.bodyText))),
                  ]),
                ],
              ],
            ),
          ),
          GestureDetector(onTap: onDelete, child: Icon(Icons.close, size: 16, color: AppColors.mutedText.withValues(alpha: 0.5))),
        ],
      ),
    );
  }

  Widget _buildDeletableChip(String label, VoidCallback onDelete, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inputBorder.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
          const SizedBox(width: 6),
          GestureDetector(onTap: onDelete, child: Icon(Icons.close, size: 14, color: AppColors.mutedText.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primaryAccent),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: GoogleFonts.inter(fontSize: 13.5, color: AppColors.bodyText))),
    ]);
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
  );

  TextStyle _sectionTitleStyle() => GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.headingText);

  // ══════════════════════════════════════════════════════════
  // ──────────────────── EDIT DIALOGS ────────────────────────
  // ══════════════════════════════════════════════════════════

  void _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512);
    if (picked != null) {
      final url = await _profileService.uploadAvatar(File(picked.path));
      if (url != null) setState(() => _avatarUrl = url);
    }
  }

  void _showEditNameDialog() {
    final nameC = TextEditingController(text: _fullName);
    final titleC = TextEditingController(text: _title);
    final deptC = TextEditingController(text: _department);
    _showSheet('Kişisel Bilgiler', [
      _buildField(nameC, 'Ad Soyad', Icons.person_outline),
      const SizedBox(height: 12),
      _buildField(titleC, 'Ünvan', Icons.badge_outlined),
      const SizedBox(height: 12),
      _buildField(deptC, 'Bölüm', Icons.school_outlined),
    ], () async { 
      setState(() { 
        _fullName = nameC.text.trim(); 
        _title = titleC.text.trim(); 
        _department = deptC.text.trim();
      }); 
      try {
        await _profileService.updateProfileField({
          'full_name': _fullName,
          'title': _title,
          'department': _department
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    });
  }

  void _showEditContactDialog() {
    final eC = TextEditingController(text: _email);
    final pC = TextEditingController(text: _phone);
    final lC = TextEditingController(text: _location);
    _showSheet('İletişim Bilgileri', [
      _buildField(eC, 'E-posta', Icons.email_outlined),
      const SizedBox(height: 12),
      _buildField(pC, 'Telefon', Icons.phone_outlined),
      const SizedBox(height: 12),
      _buildField(lC, 'Konum', Icons.location_on_outlined),
    ], () async { 
      setState(() { _email = eC.text.trim(); _phone = pC.text.trim(); _location = lC.text.trim(); }); 
      try { await _profileService.updateProfileField({'email': _email, 'phone': _phone, 'location': _location}); } catch (e) {} 
    });
  }

  void _showEditAboutDialog() {
    final c = TextEditingController(text: _about);
    _showSheet('Hakkında', [
      TextField(controller: c, maxLines: 5, style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText),
        decoration: InputDecoration(hintText: 'Kendinizi tanıtın...', hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
          filled: true, fillColor: AppColors.chipBg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    ], () async { setState(() => _about = c.text.trim()); try { await _profileService.updateProfileField({'bio': _about}); } catch(e) {} });
  }

  void _showExperienceDialog(int idx) {
    final isNew = idx < 0;
    final e = isNew ? <String, String>{} : _experiences[idx];
    final tC = TextEditingController(text: e['title'] ?? '');
    final cC = TextEditingController(text: e['company'] ?? '');
    final pC = TextEditingController(text: e['period'] ?? '');
    final dC = TextEditingController(text: e['description'] ?? '');
    _showSheet(isNew ? 'Deneyim Ekle' : 'Deneyim Düzenle', [
      _buildField(tC, 'Pozisyon', Icons.work_outline),
      const SizedBox(height: 12),
      _buildField(cC, 'Şirket', Icons.business_outlined),
      const SizedBox(height: 12),
      _buildField(pC, 'Dönem', Icons.date_range),
      const SizedBox(height: 12),
      _buildField(dC, 'Açıklama', Icons.description_outlined),
    ], () async {
      final m = {'title': tC.text.trim(), 'company': cC.text.trim(), 'period': pC.text.trim(), 'description': dC.text.trim()};
      setState(() { if (isNew) { _experiences.add(m); } else { _experiences[idx] = m; } });
      try {
        await _profileService.updateDynamicProfileField('experience', _experiences);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    });
  }

  void _showEducationDialog(int idx) {
    final isNew = idx < 0;
    final e = isNew ? <String, String>{} : _education[idx];
    final sC = TextEditingController(text: e['school'] ?? '');
    final dC = TextEditingController(text: e['department'] ?? '');
    final yC = TextEditingController(text: e['year'] ?? '');
    final deC = TextEditingController(text: e['degree'] ?? '');
    _showSheet(isNew ? 'Eğitim Ekle' : 'Eğitim Düzenle', [
      _buildField(sC, 'Okul', Icons.school_outlined),
      const SizedBox(height: 12),
      _buildField(dC, 'Bölüm', Icons.menu_book_outlined),
      const SizedBox(height: 12),
      _buildField(yC, 'Yıl (ör: 2020 - 2024)', Icons.date_range),
      const SizedBox(height: 12),
      _buildField(deC, 'Derece (ör: Lisans)', Icons.school),
    ], () async {
      final school = sC.text.trim();
      final department = dC.text.trim();
      final year = yC.text.trim();
      final degree = deC.text.trim();
      
      final m = {'school': school, 'department': department, 'year': year, 'degree': degree};
      setState(() { if (isNew) { _education.add(m); } else { _education[idx] = m; } });
      
      try {
        await _profileService.updateEducation(school, department, year, degree);
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eğitim kaydedilirken hata oluştu: $err')));
        }
      }
    });
  }

  void _showCertificateDialog(int idx) {
    final isNew = idx < 0;
    final c = isNew ? <String, String>{} : _certificates[idx];
    final nC = TextEditingController(text: c['name'] ?? '');
    final iC = TextEditingController(text: c['issuer'] ?? '');
    final dC = TextEditingController(text: c['date'] ?? '');
    _showSheet(isNew ? 'Sertifika Ekle' : 'Sertifika Düzenle', [
      _buildField(nC, 'Sertifika Adı', Icons.verified_outlined),
      const SizedBox(height: 12),
      _buildField(iC, 'Veren Kurum', Icons.business),
      const SizedBox(height: 12),
      _buildField(dC, 'Tarih', Icons.date_range),
    ], () async {
      final m = {'name': nC.text.trim(), 'issuer': iC.text.trim(), 'date': dC.text.trim()};
      setState(() { if (isNew) { _certificates.add(m); } else { _certificates[idx] = m; } });
      try { await _profileService.updateDynamicProfileField('certificates', _certificates); } catch(e) {}
    });
  }

  void _showProjectDialog(int idx) {
    final isNew = idx < 0;
    final p = isNew ? <String, String>{} : _projects[idx];
    final nC = TextEditingController(text: p['name'] ?? '');
    final dC = TextEditingController(text: p['description'] ?? '');
    final lC = TextEditingController(text: p['link'] ?? '');
    _showSheet(isNew ? 'Proje Ekle' : 'Proje Düzenle', [
      _buildField(nC, 'Proje Adı', Icons.rocket_launch_outlined),
      const SizedBox(height: 12),
      _buildField(dC, 'Açıklama', Icons.description_outlined),
      const SizedBox(height: 12),
      _buildField(lC, 'Link (GitHub, vs.)', Icons.link),
    ], () async {
      final m = {'name': nC.text.trim(), 'description': dC.text.trim(), 'link': lC.text.trim()};
      setState(() { if (isNew) { _projects.add(m); } else { _projects[idx] = m; } });
      try { await _profileService.updateDynamicProfileField('projects', _projects); } catch(e) {}
    });
  }

  void _showAddSkillDialog() {
    final c = TextEditingController();
    _showSheet('Yetenek Ekle', [_buildField(c, 'Yetenek (ör: Python)', Icons.code)], () async {
      final s = c.text.trim();
      if (s.isNotEmpty && !_skills.contains(s)) { 
        setState(() => _skills.add(s)); 
        try {
          await _profileService.addSkill(s);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    });
  }

  void _showAddLanguageDialog() {
    final c = TextEditingController();
    String level = 'B1';
    final levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2', 'Native'];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _buildSheetContent(ctx, 'Dil Ekle', [
          _buildField(c, 'Dil (ör: English)', Icons.language),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(color: AppColors.chipBg, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: level, isExpanded: true,
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText),
                items: levels.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                onChanged: (v) { if (v != null) setS(() => level = v); },
              ),
            ),
          ),
        ], () async {
          if (c.text.trim().isNotEmpty) {
            setState(() => _languages.add({'language': c.text.trim(), 'level': level}));
            try { await _profileService.updateDynamicProfileField('languages', _languages); } catch(e) {}
          }
          if (ctx.mounted) Navigator.pop(ctx);
        }),
      ),
    );
  }

  void _showEditSocialLinksDialog() {
    final liC = TextEditingController(text: _socialLinks['linkedin'] ?? '');
    final ghC = TextEditingController(text: _socialLinks['github'] ?? '');
    final twC = TextEditingController(text: _socialLinks['twitter'] ?? '');
    final weC = TextEditingController(text: _socialLinks['website'] ?? '');
    _showSheet('Sosyal Medya', [
      _buildField(liC, 'LinkedIn URL', Icons.link),
      const SizedBox(height: 12),
      _buildField(ghC, 'GitHub URL', Icons.code),
      const SizedBox(height: 12),
      _buildField(twC, 'Twitter URL', Icons.alternate_email),
      const SizedBox(height: 12),
      _buildField(weC, 'Website URL', Icons.language),
    ], () async {
      setState(() => _socialLinks = {
        'linkedin': liC.text.trim(), 'github': ghC.text.trim(),
        'twitter': twC.text.trim(), 'website': weC.text.trim(),
      });
      try { await _profileService.updateDynamicProfileField('social_media', _socialLinks); } catch(e) {}
    });
  }

  void _showEditAvailabilityDialog() {
    final hC = TextEditingController(text: _availability['hours_per_week'] ?? '');
    final tC = TextEditingController(text: _availability['timezone'] ?? '');
    final nC = TextEditingController(text: _availability['note'] ?? '');
    _showSheet('Müsaitlik Durumu', [
      _buildField(hC, 'Haftalık Saat (ör: 20)', Icons.schedule),
      const SizedBox(height: 12),
      _buildField(tC, 'Zaman Dilimi (ör: UTC+3)', Icons.public),
      const SizedBox(height: 12),
      _buildField(nC, 'Not (ör: Akşamları müsait)', Icons.info_outline),
    ], () async {
      setState(() => _availability = {
        'hours_per_week': hC.text.trim(), 'timezone': tC.text.trim(), 'note': nC.text.trim(),
      });
      try { await _profileService.updateDynamicProfileField('availability', _availability); } catch(e) {}
    });
  }

  void _showAddRoleDialog() {
    final c = TextEditingController();
    _showSheet('Rol Tercihi Ekle', [_buildField(c, 'Rol (ör: Backend Developer)', Icons.person_search)], () async {
      final r = c.text.trim();
      if (r.isNotEmpty && !_rolePreferences.contains(r)) { 
        setState(() => _rolePreferences.add(r)); 
        try {
          await _profileService.addLookingForRole(r);
        } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        }
      }
    });
  }

  // ──────────────────── SHEET HELPERS ────────────────────
  void _showSheet(String title, List<Widget> children, VoidCallback onSave) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSheetContent(ctx, title, children, () { onSave(); Navigator.pop(ctx); }),
    );
  }

  Widget _buildSheetContent(BuildContext ctx, String title, List<Widget> children, VoidCallback onSave) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.inputBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingText)),
            const SizedBox(height: 20),
            ...children,
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryAccent, foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0,
                ),
                child: Text('Kaydet', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController c, String hint, IconData icon) {
    return TextField(
      controller: c,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.bodyText),
      decoration: InputDecoration(
        hintText: hint, hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedText),
        prefixIcon: Icon(icon, size: 20, color: AppColors.mutedText),
        filled: true, fillColor: AppColors.chipBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
