import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/meeting_provider.dart';

/// Yeni toplantı oluşturma dialog'u.
/// CreateTeamDialog ile paralel tasarım prensiplerine sahiptir.
void showCreateMeetingDialog(
  BuildContext context, {
  required String teamId,
  required MeetingProvider meetingProvider,
}) {
  showDialog(
    context: context,
    builder: (ctx) =>
        _CreateMeetingDialog(teamId: teamId, meetingProvider: meetingProvider),
  );
}

class _CreateMeetingDialog extends StatefulWidget {
  final String teamId;
  final MeetingProvider meetingProvider;

  const _CreateMeetingDialog({
    required this.teamId,
    required this.meetingProvider,
  });

  @override
  State<_CreateMeetingDialog> createState() => _CreateMeetingDialogState();
}

class _CreateMeetingDialogState extends State<_CreateMeetingDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _linkController = TextEditingController();
  bool _isSubmitting = false;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryAccent,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.headingText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryAccent,
              onPrimary: AppColors.white,
              surface: AppColors.white,
              onSurface: AppColors.headingText,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Toplantı başlığı gerekli.', isError: true);
      return;
    }
    if (_selectedDate == null) {
      _showSnackBar('Lütfen bir tarih seçin.', isError: true);
      return;
    }
    if (_selectedTime == null) {
      _showSnackBar('Lütfen bir saat seçin.', isError: true);
      return;
    }

    final meetingDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final description = _descriptionController.text.trim();
    final link = _linkController.text.trim();

    setState(() => _isSubmitting = true);

    try {
      await widget.meetingProvider.createMeeting(
        teamId: widget.teamId,
        title: title,
        description: description.isNotEmpty ? description : null,
        meetingDate: meetingDate,
        meetingLink: link.isNotEmpty ? link : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      _showSnackBar('Toplantı başarıyla oluşturuldu!');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showSnackBar(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFE53E3E)
            : AppColors.onlineGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ─────────────────────────────────────
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.videocam_rounded,
                    color: AppColors.primaryAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Yeni Toplantı Planla',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingText,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, size: 22),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.chipBg,
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Toplantı Başlığı ──────────────────────────
            _buildLabel('Toplantı Başlığı', isRequired: true),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration(
                hint: 'Örn: Sprint Planlama Toplantısı',
                prefixIcon: Icons.title_rounded,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            // ─── Açıklama ──────────────────────────────────
            _buildLabel('Açıklama / Gündem'),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: _inputDecoration(
                hint: 'Toplantı gündemi ve notları...',
                prefixIcon: Icons.notes_rounded,
              ),
              maxLines: 3,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 20),

            // ─── Tarih & Saat ───────────────────────────────
            _buildLabel('Tarih & Saat', isRequired: true),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildPickerChip(
                    icon: Icons.calendar_today_rounded,
                    label: _selectedDate != null
                        ? '${_selectedDate!.day.toString().padLeft(2, '0')}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.year}'
                        : 'Tarih Seç',
                    isSelected: _selectedDate != null,
                    onTap: _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerChip(
                    icon: Icons.access_time_rounded,
                    label: _selectedTime != null
                        ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
                        : 'Saat Seç',
                    isSelected: _selectedTime != null,
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ─── Toplantı Linki ─────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('Toplantı Linki'),
                TextButton.icon(
                  onPressed: () async {
                    final Uri url = Uri.parse('https://meet.google.com/new');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  },
                  icon: const Icon(Icons.videocam, size: 14),
                  label: const Text('Meet Oluştur'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6E61FF),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 0,
                    ),
                    minimumSize: const Size(0, 24),
                    textStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            TextField(
              controller: _linkController,
              decoration:
                  _inputDecoration(
                    hint: 'https://meet.google.com/...',
                    prefixIcon: Icons.link_rounded,
                  ).copyWith(
                    helperText:
                        'Otomatik link oluşturmak için "Meet Oluştur"a tıklayın, açılan linki kopyalayıp buraya yapıştırın.',
                    helperMaxLines: 2,
                    helperStyle: GoogleFonts.inter(
                      color: AppColors.mutedText.withValues(alpha: 0.8),
                      fontSize: 11,
                    ),
                  ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 28),

            // ─── Butonlar ───────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mutedText,
                      side: const BorderSide(color: AppColors.inputBorder),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'İptal',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Toplantı Oluştur',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Yardımcı Widget'lar ─────────────────────────────────────

  Widget _buildLabel(String text, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          text,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.bodyText,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(color: Color(0xFFE53E3E), fontSize: 14),
          ),
        ],
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(
        color: AppColors.mutedText.withValues(alpha: 0.7),
        fontSize: 14,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.mutedText, size: 20),
      filled: true,
      fillColor: AppColors.chipBg.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: AppColors.primaryAccent,
          width: 1.5,
        ),
      ),
    );
  }

  Widget _buildPickerChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isSubmitting ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryAccent.withValues(alpha: 0.1)
              : AppColors.chipBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primaryAccent : AppColors.mutedText,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primaryAccent
                      : AppColors.mutedText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
