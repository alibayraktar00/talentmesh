import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../core/services/project_service.dart';
import '../core/services/auth_service.dart';
import 'profile_screen.dart';
import '../providers/team_provider.dart';
import 'my_teams_screen.dart';
import 'create_team_screen.dart';
import 'teammates_screen.dart';
import 'search_screen.dart';
import 'friends_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _selectedNavIndex = 0;
  final _projectService = ProjectService();
  final _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _projectsFuture;
  final TeamProvider _teamProvider = TeamProvider();

  @override
  void initState() {
    super.initState();
    _projectsFuture = _projectService.fetchProjects();
  }

  void _refresh() {
    setState(() {
      _projectsFuture = _projectService.fetchProjects();
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    // AuthGate otomatik LoginScreen'e döner
  }

  String _getPageTitle() {
    switch (_selectedNavIndex) {
      case 0:
        return 'Takımlarım';
      case 1:
        return 'Arama';
      case 2:
        return 'Arkadaşlar';
      default:
        return 'Takımlarım';
    }
  }

  Widget _buildPageContent() {
    switch (_selectedNavIndex) {
      case 0:
        return MyTeamsScreen(teamProvider: _teamProvider);
      case 1:
        return const SearchScreen();
      case 2:
        return const FriendsScreen();
      default:
        return MyTeamsScreen(teamProvider: _teamProvider);
    }
  }

  void _openCreateTeamSheet() {
    showCreateTeamSheet(
      context,
      teamProvider: _teamProvider,
      onTeamCreated: () {
        setState(() => _selectedNavIndex = 0);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getPageTitle(),
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.headingText,
                    ),
                  ),
                  if (_selectedNavIndex == 0)
                    IconButton(
                      onPressed: _refresh,
                      icon: const Icon(
                        Icons.refresh,
                        color: AppColors.primaryAccent,
                      ),
                      tooltip: 'Yenile',
                    ),
                ],
              ),
            ),
            Expanded(child: _buildPageContent()),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildFeedList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'Veri yüklenemedi.',
                  style: GoogleFonts.inter(color: AppColors.mutedText),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _refresh,
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          );
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.work_outline,
                  size: 56,
                  color: AppColors.mutedText.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz ilan yok.',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 100),
          physics: const BouncingScrollPhysics(),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            return _buildProjectCard(projects[index], index);
          },
        );
      },
    );
  }

  // ──────────────────────── TOP BAR ────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
            child: Stack(
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
          ),
          const Spacer(),
          IconButton(
            onPressed: () {
              setState(() => _selectedNavIndex = 1);
            },
            icon: Icon(
              Icons.search,
              color: AppColors.headingText.withValues(alpha: 0.7),
              size: 26,
            ),
          ),
          // Çıkış butonu
          IconButton(
            onPressed: _signOut,
            icon: Icon(
              Icons.logout,
              color: AppColors.headingText.withValues(alpha: 0.5),
              size: 22,
            ),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
    );
  }

  // ──────────────────── PROJECT CARD ────────────────────────
  Widget _buildProjectCard(Map<String, dynamic> project, int index) {
    final tags = (project['tags'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project['title'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.headingText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          project['roles'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppColors.mutedText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.chipBg,
                              child: Icon(
                                Icons.person_outline,
                                size: 12,
                                color: AppColors.primaryAccent,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Project lead: ',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.mutedText,
                              ),
                            ),
                            Text(
                              project['lead_name'] ?? '',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.bodyText,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          project['description'] ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.45,
                            color: AppColors.bodyText,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
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
              Expanded(
                child: _buildNavItem(
                  icon: Icons.groups_3_outlined,
                  activeIcon: Icons.groups_3,
                  label: 'Takımlarım',
                  index: 0,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _openCreateTeamSheet,
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
                              color: AppColors.primaryAccent.withValues(
                                alpha: 0.4,
                              ),
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
              Expanded(
                child: _buildNavItem(
                  icon: Icons.search_outlined,
                  activeIcon: Icons.search,
                  label: 'Arama\n', // Hizalamayı korumak için
                  index: 1,
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Arkadaşlar\n',
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
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              height: 1.1,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.primaryAccent : AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
