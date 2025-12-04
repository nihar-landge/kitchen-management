// lib/screens/payments_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';
import '../utils/payment_manager.dart';

class PaymentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final Function(Student) onViewStudent;
  final String? initialFilterOption;

  PaymentsScreen({
    Key? key,
    required this.firestoreService,
    required this.onViewStudent,
    this.initialFilterOption,
  }) : super(key: key);

  @override
  _PaymentsScreenState createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String _filterOption = 'All Dues';
  bool _sortByHighestDues = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialFilterOption != null && (
        widget.initialFilterOption == 'Dues > 0' ||
            widget.initialFilterOption == 'Dues > 500' ||
            widget.initialFilterOption == 'Dues > 1000'
    )) {
      _filterOption = widget.initialFilterOption!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Payment Dues Overview'),
        actions: [
          IconButton(
            icon: Icon(_sortByHighestDues ? Icons.arrow_downward : Icons.arrow_upward),
            tooltip: _sortByHighestDues ? "Sort: Highest Dues First" : "Sort: Lowest Dues First",
            onPressed: () {
              setState(() {
                _sortByHighestDues = !_sortByHighestDues;
              });
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: "Filter by Dues",
            initialValue: _filterOption,
            onSelected: (String value) {
              setState(() {
                _filterOption = value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'All Dues', child: Text('Show All Students')),
              const PopupMenuItem<String>(value: 'Dues > 0', child: Text('Any Dues Remaining (> ₹0)')),
              const PopupMenuItem<String>(value: 'Dues > 500', child: Text('Dues > ₹500')),
              const PopupMenuItem<String>(value: 'Dues > 1000', child: Text('Dues > ₹1000')),
              const PopupMenuItem<String>(value: 'Fully Paid', child: Text('Show Fully Paid')),
            ],
          )
        ],
      ),
      body: StreamBuilder<AppSettings>(
        stream: widget.firestoreService.getAppSettingsStream(),
        builder: (context, appSettingsSnapshot) {
          if (!appSettingsSnapshot.hasData && appSettingsSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (appSettingsSnapshot.hasError) {
            return Center(child: Text('Error loading settings: ${appSettingsSnapshot.error}'));
          }
          final appSettings = appSettingsSnapshot.data!;

          return StreamBuilder<List<Student>>(
            stream: widget.firestoreService.getStudentsStream(archiveStatusFilter: StudentArchiveStatusFilter.active),
            builder: (context, studentSnapshot) {
              if (studentSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              }
              if (studentSnapshot.hasError) {
                return Center(child: Text('Error loading students: ${studentSnapshot.error}'));
              }

              List<Student> allStudents = studentSnapshot.data ?? [];
              List<Map<String, dynamic>> studentsWithDues = [];

              for (var student in allStudents) {
                List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(student, appSettings, DateTime.now());
                double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                double totalPaidForAllMonths = duesList.fold(0.0, (sum, item) => sum + item.amountPaidForPeriod);
                studentsWithDues.add({
                  'student': student,
                  'totalRemaining': totalRemaining,
                  'totalPaid': totalPaidForAllMonths,
                });
              }

              List<Map<String, dynamic>> filteredStudentsWithDues = [];
              if (_filterOption == 'All Dues') {
                filteredStudentsWithDues = List.from(studentsWithDues);
              } else if (_filterOption == 'Dues > 0') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 0).toList();
              } else if (_filterOption == 'Dues > 500') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 500).toList();
              } else if (_filterOption == 'Dues > 1000') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) > 1000).toList();
              } else if (_filterOption == 'Fully Paid') {
                filteredStudentsWithDues = studentsWithDues.where((s) => (s['totalRemaining'] as double) <= 0).toList();
              }

              filteredStudentsWithDues.sort((a, b) {
                double duesA = a['totalRemaining'] as double;
                double duesB = b['totalRemaining'] as double;
                if (_sortByHighestDues) {
                  return duesB.compareTo(duesA);
                }
                return duesA.compareTo(duesB);
              });

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Chip(
                        label: Text('Showing: $_filterOption (${filteredStudentsWithDues.length} students)'),
                        avatar: Icon(Icons.info_outline)
                    ),
                  ),
                  Expanded(
                    child: filteredStudentsWithDues.isEmpty
                        ? Center(child: Text('No students match the filter "$_filterOption".'))
                        : ListView.builder(
                        padding: EdgeInsets.only(bottom: 100),
                        itemCount: filteredStudentsWithDues.length,
                        itemBuilder: (context, index) {
                          final studentData = filteredStudentsWithDues[index];
                          final student = studentData['student'] as Student;
                          final totalRemaining = studentData['totalRemaining'] as double;
                          final totalPaid = studentData['totalPaid'] as double;


                          double totalBillable = totalPaid + totalRemaining;
                          double progress = totalBillable == 0 ? 1.0 : totalPaid / totalBillable;
                          if (progress > 1.0) progress = 1.0;
                          if (progress < 0.0) progress = 0.0;

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            color: Colors.white,
                            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: InkWell(
                              onTap: () => widget.onViewStudent(student),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(student.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                                              SizedBox(height: 2),
                                              Text('Ends: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                            ],
                                          ),
                                        ),
                                        Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                                      ],
                                    ),
                                    SizedBox(height: 16),
                                    
                                    Stack(
                                      children: [
                                        Container(
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Container(
                                              height: 6,
                                              width: constraints.maxWidth * progress,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(10),
                                                // Apple System Colors for a "Premium" flat look
                                                color: progress >= 1.0
                                                    ? Color(0xFF34C759)
                                                    : (progress > 0.5
                                                        ? Color(0xFFFF9500)
                                                        : Color(0xFFFF3B30)),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Paid: ₹${totalPaid.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.green[700], fontWeight: FontWeight.w600)),
                                        Text('Due: ₹${totalRemaining.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}