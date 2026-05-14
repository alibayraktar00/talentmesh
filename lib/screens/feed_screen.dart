import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme/app_colors.dart';
import '../core/services/project_service.dart';
import '../core/services/auth_service.dart';
import 'profile_screen.dart';
import '../providers/team_provider.dart';
import 'my_teams_screen.dart';
import 'search_screen.dart';
import 'friends_screen.dart';
import 'settings_screen.dart';
import '../core/services/team_service.dart';
import '../models/team_model.dart';
import 'team_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  int _selectedNavIndex = 0;
  final _projectService = ProjectService();
  final _teamService = TeamService();
  final _authService = AuthService();
  late Future<List<Map<String, dynamic>>> _projectsFuture;
  late Future<List<Map<String, dynamic>>> _smartMatchesFuture;
  final TeamProvider _teamProvider = TeamProvider();
  Set<String> _pendingTeamIds = {};
  int _teamsRefreshKey = 0;
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _projectsFuture = _projectService.fetchProjects();
    _smartMatchesFuture = _teamService.fetchSmartMatches();
    _fetchPendingRequests();
  }
  
  Future<void> _fetchPendingRequests() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await _client
          .from('team_requests')
          .select('team_id')
          .eq('user_id', user.id)
          .eq('status', 'pending');
      if (mounted) {
        setState(() {
          _pendingTeamIds = (res as List).map((e) => e['team_id'].toString()).toSet();
        });
      }
    } catch (_) {}
  }

  void _refresh() {
    setState(() {
      _projectsFuture = _projectService.fetchProjects();
      _smartMatchesFuture = _teamService.fetchSmartMatches();
      _teamsRefreshKey++;
    });
    _fetchPendingRequests();
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
        return 'Ana Sayfa';
      case 2:
        return 'Arkadaşlar';
      default:
        return 'Ana Sayfa';
    }
  }

  Widget _buildPageContent() {
    switch (_selectedNavIndex) {
      case 0:
        return MyTeamsScreen(key: ValueKey(_teamsRefreshKey), teamProvider: _teamProvider);
      case 1:
        return _buildFeedList();
      case 2:
        return const FriendsScreen();
      default:
        return _buildFeedList();
    }
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
    return RefreshIndicator(
      onRefresh: () async {
        _refresh();
        await Future.wait([_projectsFuture, _smartMatchesFuture]);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sana Uygun Takımlar 🔥
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Sana Uygun Takımlar 🔥',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingText,
                ),
              ),
            ),
            _buildSmartMatchesFuture(),

            // 2. Keşfet (Tüm İlanlar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Keşfet',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.headingText,
                ),
              ),
            ),
            _buildProjectsFuture(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartMatchesFuture() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _smartMatchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 180,
            child: Center(
              child: CircularProgressIndicator(color: AppColors.primaryAccent),
            ),
          );
        }
        if (snapshot.hasError) {
          return const SizedBox(
            height: 180,
            child: Center(child: Text('Bir hata oluştu.')),
          );
        }

        final matches = snapshot.data ?? [];
        if (matches.isEmpty) {
          return Container(
            height: 160,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            alignment: Alignment.center,
            child: Text(
              'Şu an profiline uygun takım bulunamadı. Yeteneklerini güncellemeyi deneyin.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.mutedText,
                height: 1.5,
              ),
            ),
          );
        }

        return SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: matches.length,
            itemBuilder: (context, index) {
              final teamMap = matches[index];
              return _buildMatchCard(teamMap);
            },
          ),
        );
      },
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> teamMap) {
    final team = Team.fromMap(teamMap, _teamService.currentUserId ?? '');

    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12, top: 4, bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısımdaki renkli bant
            Container(
              height: 6,
              color: team.color,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    team.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.bodyText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.mutedText),
                      const SizedBox(width: 4),
                      Text(
                        '${team.maxMembers} Kişilik',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 32,
                        width: 76,
                        child: ElevatedButton(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TeamDetailScreen(
                                  team: team,
                                  teamProvider: _teamProvider,
                                ),
                              ),
                            );
                            _fetchPendingRequests();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: team.color.withValues(alpha: 0.1),
                            foregroundColor: team.color,
                            elevation: 0,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _pendingTeamIds.contains(team.id) ? 'Bekliyor' : 'İncele',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectsFuture() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _projectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
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
                ],
              ),
            ),
          );
        }
        final projects = snapshot.data ?? [];
        if (projects.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.work_outline,
                    size: 48,
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
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
            icon: Icon(
              Icons.search,
              color: AppColors.headingText.withValues(alpha: 0.7),
              size: 26,
            ),
            tooltip: 'Ara',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: Icon(
              Icons.settings,
              color: AppColors.headingText.withValues(alpha: 0.7),
              size: 24,
            ),
            tooltip: 'Ayarlar',
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
                  onTap: () {
                    setState(() => _selectedNavIndex = 1);
                  },
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
                        child: const Center(
                          child: Icon(
                            Icons.home,
                            color: AppColors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ana Sayfa',
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
                  icon: Icons.people_outline,
                  activeIcon: Icons.people,
                  label: 'Arkadaşlar',
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
