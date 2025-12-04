// lib/utils/string_extensions.dart
extension StringExtension on String {
  String capitalize() {
    if (this.isEmpty) {
      return "";
    }
    if (this.length == 1) {
      return this.toUpperCase();
    }
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
