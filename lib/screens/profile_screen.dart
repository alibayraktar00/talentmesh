import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Cover + Profile Photo ──
          SliverToBoxAdapter(child: _buildHeader(context)),
          // ── Contact Info ──
          SliverToBoxAdapter(child: _buildContactInfo()),
          // ── Open to Work Banner ──
          SliverToBoxAdapter(child: _buildOpenToWorkBanner()),
          // ── Profil Section ──
          SliverToBoxAdapter(child: _buildProfileSection()),
          // ── Deneyimler Section ──
          SliverToBoxAdapter(child: _buildExperienceSection()),
          // ── Diller Section ──
          SliverToBoxAdapter(child: _buildLanguagesSection()),
          // ── Yetenekler Section ──
          SliverToBoxAdapter(child: _buildSkillsSection()),
          // ── Bottom spacing ──
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  // ──────────────────────── HEADER ────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Cover photo
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
                colors: [
                  Colors.black.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
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
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
              color: AppColors.headingText,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),

        // Profile photo + name section
        Positioned(
          top: 105,
          left: 20,
          right: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile photo with green badge
              Stack(
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
                      backgroundImage: const NetworkImage(
                        'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.onlineGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.check,
                        color: AppColors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Name
              Text(
                'Akın Aslanoğlu',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 2),
              // Title
              Text(
                'Junior ML Engineer',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────── CONTACT INFO ────────────────────────
  Widget _buildContactInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 130, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContactRow(Icons.email_outlined, 'akin@example.com'),
          const SizedBox(height: 10),
          _buildContactRow(Icons.phone_outlined, '+90 555 555 55 55'),
          const SizedBox(height: 10),
          _buildContactRow(Icons.location_on_outlined, 'Kayseri'),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.mutedText),
        const SizedBox(width: 10),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.bodyText,
          ),
        ),
      ],
    );
  }

  // ──────────────────────── OPEN TO WORK ────────────────────────
  Widget _buildOpenToWorkBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.onlineGreen.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.onlineGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.work_outline,
              color: AppColors.onlineGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPEN TO WORK',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingText,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Looking for opportunities',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: AppColors.mutedText.withValues(alpha: 0.6),
            size: 22,
          ),
        ],
      ),
    );
  }

  // ──────────────────────── PROFILE ABOUT ────────────────────────
  Widget _buildProfileSection() {
    return _buildSection(
      title: 'Profil',
      showMore: false,
      child: Text(
        'Hey! I\'m a Junior Machine Learning Engineer with a passion for developing intelligent systems. My arumrs conter around advances in ML, NLP, and computer vis, and I\'ve gained core proficiency in Python, TensorFlow, and SQL through numerous academic projects.',
        style: GoogleFonts.inter(
          fontSize: 13.5,
          height: 1.55,
          fontWeight: FontWeight.w400,
          color: AppColors.bodyText,
        ),
      ),
    );
  }

  // ──────────────────────── EXPERIENCE ────────────────────────
  Widget _buildExperienceSection() {
    return _buildSection(
      title: 'Deneyimler',
      showMore: true,
      child: Column(
        children: [
          _buildExperienceItem(
            title: 'Machine Learning Intern',
            company: 'X Şirketi',
            period: 'Tem 2022 - Eyl 2022 · 3 ay · Kayseri',
            description:
                'Developed machine learning models for various prediction tasks using Python and TensorFlow.',
          ),
          const SizedBox(height: 16),
          Divider(
            color: AppColors.inputBorder.withValues(alpha: 0.6),
            height: 1,
          ),
          const SizedBox(height: 16),
          _buildExperienceItem(
            title: 'Software Developer Intern',
            company: 'Y Sirketi',
            period: 'Haz 2021 - Eyl 2021 · 4 ay · Kayseri',
            description:
                'Worked on developing web applications and automating backend processes.',
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceItem({
    required String title,
    required String company,
    required String period,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Experience icon
        Container(
          margin: const EdgeInsets.only(top: 2),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.work_outline,
            color: AppColors.primaryAccent,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                company,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.bodyText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                period,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.mutedText,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        color: AppColors.bodyText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────── LANGUAGES ────────────────────────
  Widget _buildLanguagesSection() {
    return _buildSection(
      title: 'Diller',
      showMore: true,
      child: Column(
        children: [
          _buildLanguageItem('Türkçe', 'Native'),
          const SizedBox(height: 8),
          _buildLanguageItem('English', 'B2'),
        ],
      ),
    );
  }

  Widget _buildLanguageItem(String language, String level) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppColors.primaryAccent,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$language · $level',
          style: GoogleFonts.inter(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: AppColors.bodyText,
          ),
        ),
      ],
    );
  }

  // ──────────────────────── SKILLS ────────────────────────
  Widget _buildSkillsSection() {
    final skills = ['Java', 'Python', 'TensorFlow', 'SQL', 'Flutter'];
    return _buildSection(
      title: 'Yetenekler',
      showMore: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: skills.map((skill) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.inputBorder.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Text(
              skill,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryDark,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────── SECTION WRAPPER ────────────────────────
  Widget _buildSection({
    required String title,
    required bool showMore,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingText,
                ),
              ),
              if (showMore)
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: AppColors.mutedText,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
