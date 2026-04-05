import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/app_colors.dart';
import '../models/team_model.dart';
import '../providers/team_provider.dart';

/// Takım oluşturma Bottom Sheet'ini gösterir.
/// [teamProvider] üzerinden oluşturulan takımı global listeye ekler.
/// [onTeamCreated] callback'i ile başarı sonrası sayfa geçişi yapılır.
void showCreateTeamSheet(
  BuildContext context, {
  required TeamProvider teamProvider,
  VoidCallback? onTeamCreated,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateTeamSheet(
      teamProvider: teamProvider,
      onTeamCreated: onTeamCreated,
    ),
  );
}

class _CreateTeamSheet extends StatefulWidget {
  final TeamProvider teamProvider;
  final VoidCallback? onTeamCreated;

  const _CreateTeamSheet({
    required this.teamProvider,
    this.onTeamCreated,
  });

  @override
  State<_CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<_CreateTeamSheet>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _teamNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  // ── Seçilebilir roller ──
  final List<String> _allRoles = [
    'Flutter Dev',
    'Backend Dev',
    'Frontend Dev',
    'ML Engineer',
    'Data Scientist',
    'UI/UX Designer',
    'DevOps',
    'QA Tester',
    'Product Manager',
    'Game Dev',
    '3D Artist',
    'Mobile Dev',
  ];

  // ── Seçilebilir yetenekler ──
  final List<String> _allSkills = [
    'Python',
    'Dart',
    'Flutter',
    'JavaScript',
    'TypeScript',
    'React',
    'Node.js',
    'TensorFlow',
    'PyTorch',
    'Firebase',
    'Docker',
    'AWS',
    'Figma',
    'Unity',
    'C#',
    'Java',
    'SQL',
    'MongoDB',
    'Go',
    'Rust',
  ];

  final Set<String> _selectedRoles = {};
  final Set<String> _selectedSkills = {};
  int _maxMembers = 5;
  bool _isSubmitting = false;

  // Takım renkleri havuzu
  final List<Color> _teamColors = const [
    Color(0xFF4A7C82),
    Color(0xFF6C63FF),
    Color(0xFF00BFA6),
    Color(0xFFFF6B6B),
    Color(0xFFFFB347),
    Color(0xFF7C4DFF),
    Color(0xFF26A69A),
    Color(0xFFEF5350),
  ];

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    _descriptionController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Bottom Sheet yüksekliği — ekranın %92'si
    final sheetHeight = MediaQuery.of(context).size.height * 0.92;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => child!,
      child: Container(
        height: sheetHeight,
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag Handle + Header ──
            _buildSheetHeader(),
            // ── Form İçeriği ──
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Takım Adı ──
                      _buildSectionLabel('Takım Adı', Icons.group_outlined),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _teamNameController,
                        hint: 'Takımınıza bir isim verin',
                        icon: Icons.edit_outlined,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Takım adı boş bırakılamaz';
                          }
                          if (value.trim().length < 2) {
                            return 'Takım adı en az 2 karakter olmalı';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Takım Açıklaması ──
                      _buildSectionLabel(
                          'Takım Açıklaması', Icons.description_outlined),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _descriptionController,
                        hint: 'Takımınızın amacını ve projenizi açıklayın...',
                        icon: Icons.notes_outlined,
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Açıklama boş bırakılamaz';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),

                      // ── Maksimum Üye Sayısı ──
                      _buildSectionLabel(
                          'Maksimum Üye Sayısı', Icons.people_outline),
                      const SizedBox(height: 12),
                      _buildMemberCounter(),
                      const SizedBox(height: 24),

                      // ── Aranan Roller ──
                      _buildSectionLabel('Aranan Roller', Icons.work_outline),
                      const SizedBox(height: 4),
                      Text(
                        'Takımınız için gereken pozisyonları seçin',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildChipSelector(
                        items: _allRoles,
                        selected: _selectedRoles,
                        accentColor: AppColors.primaryAccent,
                      ),
                      const SizedBox(height: 24),

                      // ── Gerekli Yetenekler ──
                      _buildSectionLabel(
                          'Gerekli Yetenekler', Icons.code_outlined),
                      const SizedBox(height: 4),
                      Text(
                        'Projede kullanılacak teknolojileri seçin',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildChipSelector(
                        items: _allSkills,
                        selected: _selectedSkills,
                        accentColor: const Color(0xFF6C63FF),
                      ),
                      const SizedBox(height: 32),

                      // ── Oluştur Butonu ──
                      _buildSubmitButton(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────── SHEET HEADER ────────────────────────
  Widget _buildSheetHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.mutedText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                // Başlık ikonu
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group_add_rounded,
                    color: AppColors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Yeni Takım Oluştur',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.headingText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ekip arkadaşlarını bul ve projeye başla',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                // Kapat butonu
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.chipBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────── SECTION LABEL ────────────────────────
  Widget _buildSectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primaryAccent),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.headingText,
          ),
        ),
      ],
    );
  }

  // ──────────────────────── TEXT FIELD ────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
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
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.headingText,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.mutedText.withValues(alpha: 0.6),
          ),
          prefixIcon: maxLines == 1
              ? Padding(
                  padding: const EdgeInsets.only(left: 14, right: 10),
                  child: Icon(icon, size: 20, color: AppColors.primaryAccent),
                )
              : null,
          prefixIconConstraints: maxLines == 1
              ? const BoxConstraints(minWidth: 44, minHeight: 44)
              : null,
          contentPadding: EdgeInsets.fromLTRB(
            maxLines > 1 ? 16 : 0,
            14,
            16,
            14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.inputBorder, width: 1),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.inputBorder.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: AppColors.primaryAccent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFE53E3E), width: 1),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.white,
        ),
      ),
    );
  }

  // ──────────────────────── MEMBER COUNTER ────────────────────────
  Widget _buildMemberCounter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.inputBorder.withValues(alpha: 0.5),
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 20,
              color: AppColors.primaryAccent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_maxMembers Kişi',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.headingText,
                  ),
                ),
                Text(
                  'Takım kapasitesi',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          _buildCounterButton(
            icon: Icons.remove,
            onTap: () {
              if (_maxMembers > 2) setState(() => _maxMembers--);
            },
            enabled: _maxMembers > 2,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '$_maxMembers',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryAccent,
              ),
            ),
          ),
          _buildCounterButton(
            icon: Icons.add,
            onTap: () {
              if (_maxMembers < 20) setState(() => _maxMembers++);
            },
            enabled: _maxMembers < 20,
          ),
        ],
      ),
    );
  }

  Widget _buildCounterButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool enabled,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : AppColors.chipBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled
                ? AppColors.primaryAccent.withValues(alpha: 0.3)
                : AppColors.inputBorder.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? AppColors.primaryAccent
              : AppColors.mutedText.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  // ──────────────────────── CHIP SELECTOR ────────────────────────
  Widget _buildChipSelector({
    required List<String> items,
    required Set<String> selected,
    required Color accentColor,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selected.contains(item);
        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selected.remove(item);
              } else {
                selected.add(item);
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.12)
                  : AppColors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? accentColor.withValues(alpha: 0.5)
                    : AppColors.inputBorder.withValues(alpha: 0.6),
                width: 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected) ...[
                  Icon(Icons.check_circle, size: 14, color: accentColor),
                  const SizedBox(width: 5),
                ],
                Text(
                  item,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? accentColor : AppColors.bodyText,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────── SUBMIT BUTTON ────────────────────────
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Container(
        decoration: BoxDecoration(
          gradient: _isSubmitting ? null : AppColors.primaryGradient,
          color: _isSubmitting ? AppColors.mutedText : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: _isSubmitting
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryAccent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: _isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.white,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.rocket_launch_outlined, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Takımı Oluştur',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  // ──────────────────────── FORM SUBMIT ────────────────────────
  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    // Rol seçimi kontrolü
    if (_selectedRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen en az bir rol seçin',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          backgroundColor: const Color(0xFFE53E3E),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Rastgele renk seç
    final colorIndex =
        DateTime.now().millisecondsSinceEpoch % _teamColors.length;

    // Team objesi oluştur ve provider'a ekle
    final newTeam = Team(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _teamNameController.text.trim(),
      description: _descriptionController.text.trim(),
      roles: _selectedRoles.toList(),
      skills: _selectedSkills.toList(),
      maxMembers: _maxMembers,
      currentMembers: 1,
      isOwner: true,
      color: _teamColors[colorIndex],
    );

    widget.teamProvider.addTeam(newTeam);

    // Kısa gecikme ile UX iyileştirmesi (loading hissi)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;

      // Bottom Sheet'i kapat
      Navigator.of(context).pop();

      // Başarı Snackbar'ı göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '"${newTeam.name}" takımı başarıyla oluşturuldu! 🎉',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.onlineGreen,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );

      // "Gruplar" sekmesine yönlendir
      widget.onTeamCreated?.call();
    });
  }
}
