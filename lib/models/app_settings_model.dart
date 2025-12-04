// lib/models/app_settings_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

const String appSettingsDocId = "app_config";

class FeeHistoryEntry {
  final DateTime effectiveDate;
  final double fee;

  FeeHistoryEntry({required this.effectiveDate, required this.fee});

  factory FeeHistoryEntry.fromMap(Map<String, dynamic> map) {
    return FeeHistoryEntry(
      effectiveDate: (map['effectiveDate'] as Timestamp).toDate(),
      fee: (map['fee'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'effectiveDate': Timestamp.fromDate(effectiveDate),
      'fee': fee,
    };
  }
}

class AppSettings {
  final List<FeeHistoryEntry> feeHistory;

  AppSettings({required this.feeHistory});

  double getFeeForDate(DateTime date) {
    if (feeHistory.isEmpty) {
      return 2000.0;
    }
    List<FeeHistoryEntry> sortedHistory = List.from(feeHistory);
    sortedHistory.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));

    for (var entry in sortedHistory) {
      if (!date.isBefore(entry.effectiveDate)) {
        return entry.fee;
      }
    }
    return sortedHistory.last.fee;
  }

  double get currentStandardFee {
    if (feeHistory.isEmpty) return 2000.0;
    List<FeeHistoryEntry> sortedHistory = List.from(feeHistory);
    sortedHistory.sort((a, b) => b.effectiveDate.compareTo(a.effectiveDate));
    return sortedHistory.first.fee;
  }

  factory AppSettings.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final historyData = data['feeHistory'] as List<dynamic>? ?? [];
    return AppSettings(
      feeHistory: historyData.map((e) => FeeHistoryEntry.fromMap(e)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'feeHistory': feeHistory.map((e) => e.toMap()).toList(),
    };
  }
}