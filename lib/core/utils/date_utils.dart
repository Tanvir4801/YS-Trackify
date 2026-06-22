import 'package:intl/intl.dart';

class AppDateUtils {
  static final DateFormat _keyFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayFormat = DateFormat('dd MMM yyyy');

  static String toDateKey(DateTime date) => _keyFormat.format(date);

  static String toDisplay(DateTime date) => _displayFormat.format(date);

  static DateTime fromDateKey(String dateKey) => _keyFormat.parse(dateKey);

  static DateTime startOfWeek(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(
      Duration(days: weekday - 1),
    );
  }
}
