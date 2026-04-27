class ChatTimeFormat {
  static String hhmm(DateTime utc) {
    final local = utc.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String dmy(DateTime utc) {
    final d = utc.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  static String inboxFlexible(DateTime utc) {
    final d = utc.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(d.year, d.month, d.day);
    final diffDays = today.difference(date).inDays;

    if (diffDays == 0) return hhmm(utc);
    if (diffDays == 1) return 'Dün';

    if (d.year == now.year) {
      // 24 Nisan
      return '${d.day} ${_monthTr(d.month)}';
    }
    // 24.04.2026
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }

  static String _monthTr(int m) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    if (m < 1 || m > 12) return '';
    return months[m - 1];
  }
}

