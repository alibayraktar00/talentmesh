import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _selectedNavIndex = 0;

  // ── Sample Data ──
  final List<Map<String, dynamic>> _projects = [
    {
      'title': 'Mobile Game Development Team',
      'roles': 'Unity Developer • 3D Artist • UI/UX Designer',
      'lead': 'Amn Rash',
      'description':
          'Project description: Teamness a mobile game in building namedenvinas for creatives and reasperprise promotion...',
      'tags': ['Python', 'Unity', 'Design'],
    },
    {
      'title': 'Mobile Game Development',
      'roles': 'Unity Developer • 3D Artist • UI/UX Designer',
      'lead': 'Amn Rash',
      'description':
          'Project description: In complicing game crevors and developments. In titling, neunation and nove problemis...',
      'tags': ['Python', 'Unity', 'Design'],
    },
    {
      'title': 'Mobile Game Development',
      'roles': 'Unity Developer • 3D Artist • UI/UX Designer',
      'lead': 'Amn Rash',
      'description':
          'Project description: Innovation game smeeting and developments. In titling, neunation and nove problemis...',
      'tags': ['Python', 'Unity', 'Design'],
    },
    {
      'title': 'Project DeveloiTeam',
      'roles': 'Unity Developer • 3D Artist • UI/UX Designer',
      'lead': 'Amn Resh',
      'description':
          'Project description: In project and tndfrm development and enoundage; common gvaturuals for your promotor...',
      'tags': ['Python', 'Unity', 'Design'],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Bar ──
            _buildTopBar(),
            // ── Page Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text(
                'İlanlar',
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingText,
                ),
              ),
            ),
            // ── Project Cards ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 100),
                physics: const BouncingScrollPhysics(),
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  return _buildProjectCard(_projects[index], index);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ──────────────────────── TOP BAR ────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          // Avatar with online indicator
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryAccent.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: const CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.chipBg,
                  child: Icon(
                    Icons.person,
                    color: AppColors.primaryAccent,
                    size: 22,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 1,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.onlineGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Search icon – simple, no container background
          IconButton(
            onPressed: () {},
            icon: Icon(
              Icons.search,
              color: AppColors.headingText.withValues(alpha: 0.7),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── PROJECT CARD ────────────────────────
  Widget _buildProjectCard(Map<String, dynamic> project, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // ── Left accent border ──
                Container(
                  width: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryAccent,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                // ── Card content ──
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          project['title'],
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headingText,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Roles
                        Text(
                          project['roles'],
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Project lead row
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.chipBg,
                              child: const Icon(
                                Icons.person_outline,
                                size: 12,
                                color: AppColors.primaryAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Projet lead: ',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.mutedText,
                              ),
                            ),
                            Text(
                              project['lead'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          project['description'],
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children:
                              (project['tags'] as List<String>).map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.chipBg,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                tag,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── BOTTOM NAV ──────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            children: [
              // ── Left: Kişiler ──
              Expanded(
                child: _buildNavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Kişiler',
                  index: 0,
                ),
              ),

              // ── Center: Takım Oluştur ──
              Expanded(
                child: GestureDetector(
                  onTap: () {},
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryAccent
                                  .withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.group_add,
                              color: AppColors.white,
                              size: 26,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: AppColors.white.withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: AppColors.white,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Takım Oluştur',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Right: Gruplar ──
              Expanded(
                child: _buildNavItem(
                  icon: Icons.groups_outlined,
                  activeIcon: Icons.groups,
                  label: 'Gruplar',
                  index: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
  }) {
    final bool isActive = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedNavIndex = index);
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isActive ? activeIcon : icon,
            color: isActive ? AppColors.primaryAccent : AppColors.mutedText,
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primaryAccent : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
