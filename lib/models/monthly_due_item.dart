// Concept for lib/models/monthly_due_item.dart (or similar)
class MonthlyDueItem {
  final String monthYearDisplay; // e.g., "April 2025"
  final DateTime monthStartDate; // e.g., DateTime(2025, 4, 1)
  final double feeDueForMonth;
  double amountPaidForMonth;
  String status; // "Paid", "Unpaid", "Partially Paid"

  MonthlyDueItem({
    required this.monthYearDisplay,
    required this.monthStartDate,
    required this.feeDueForMonth,
    this.amountPaidForMonth = 0.0,
  }) : status = (amountPaidForMonth >= feeDueForMonth)
      ? "Paid"
      : (amountPaidForMonth > 0 ? "Partially Paid" : "Unpaid");

  double get remainingForMonth => feeDueForMonth - amountPaidForMonth;

  void updateStatus() {
    status = (amountPaidForMonth >= feeDueForMonth)
        ? "Paid"
        : (amountPaidForMonth > 0 ? "Partially Paid" : "Unpaid");
  }
}