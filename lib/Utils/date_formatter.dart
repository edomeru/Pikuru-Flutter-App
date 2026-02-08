class DateFormatter {
  static String weekday(int day) {
    const names = [
      "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"
    ];
    return names[day - 1];
  }

  static String month(int month) {
    const names = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return names[month - 1];
  }

  static String formatDateTime(DateTime date, DateTime time) {
    final formattedDate =
        "${weekday(date.weekday)}, ${month(date.month)} ${date.day}, ${date.year}";

    final formattedTime =
        "${time.hour}:${time.minute.toString().padLeft(2, '0')}";

    return "$formattedDate $formattedTime";
  }
}
