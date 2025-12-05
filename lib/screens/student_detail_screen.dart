// lib/screens/student_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../models/user_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/payment_manager.dart';
import '../widgets/common_app_bar.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final FirestoreService firestoreService;
  final UserRole userRole;

  StudentDetailScreen({
    required this.studentId,
    required this.firestoreService,
    required this.userRole,
  });

  @override
  _StudentDetailScreenState createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  final _compensatoryDaysController = TextEditingController();
  final _compensatoryReasonController = TextEditingController();
  final _paymentAmountController = TextEditingController();
  DateTime _selectedPaymentDate = DateTime.now();
  DateTime? _paymentForPeriodStart;
  DateTime? _manualServiceStartDate;

  @override
  void dispose() {
    _compensatoryDaysController.dispose();
    _compensatoryReasonController.dispose();
    _paymentAmountController.dispose();
    super.dispose();
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  void _recordPaymentDialog(Student student, List<MonthlyDueItem> billingPeriodsFromManager, AppSettings appSettings) {
    if (widget.userRole == UserRole.guest) return;

    _paymentAmountController.clear();
    _selectedPaymentDate = DateTime.now();
    _paymentForPeriodStart = null;

    List<MonthlyDueItem> selectablePeriods = List.from(billingPeriodsFromManager);

    if (selectablePeriods.isEmpty && student.originalServiceStartDate.isAfter(DateTime.now().subtract(Duration(days:1)))) {
      DateTime firstPeriodStart = student.originalServiceStartDate;
      String displaySuffix = (firstPeriodStart.day != 1) ? " (from ${DateFormat.d().format(firstPeriodStart)})" : "";
      DateTime firstPeriodEnd = DateTime(firstPeriodStart.year, firstPeriodStart.month + 1, 0);
      if (firstPeriodEnd.isAfter(student.effectiveMessEndDate)) {
        firstPeriodEnd = student.effectiveMessEndDate;
      }
      selectablePeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yy').format(firstPeriodStart) + displaySuffix,
          periodStartDate: firstPeriodStart,
          periodEndDate: firstPeriodEnd,
          feeDueForPeriod: appSettings.getFeeForDate(firstPeriodStart),
          amountPaidForPeriod: 0.0
      ));
    }
    if (selectablePeriods.isEmpty) {
      DateTime currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      selectablePeriods.add(MonthlyDueItem(
          monthYearDisplay: DateFormat('MMMM yy').format(currentMonth),
          periodStartDate: currentMonth,
          periodEndDate: DateTime(currentMonth.year, currentMonth.month + 1, 0),
          feeDueForPeriod: appSettings.getFeeForDate(currentMonth),
          amountPaidForPeriod: 0.0
      ));
    }


    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          final List<MonthlyDueItem> periodsForDropdown = selectablePeriods.where((due) => due.remainingForPeriod > 0).toList();

          if (_paymentForPeriodStart != null && !periodsForDropdown.any((p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!))) {
            _paymentForPeriodStart = periodsForDropdown.isNotEmpty ? periodsForDropdown.first.periodStartDate : null;
          } else if (_paymentForPeriodStart == null && periodsForDropdown.isNotEmpty) {
            _paymentForPeriodStart = periodsForDropdown.first.periodStartDate;
          }

          return AlertDialog(
            title: Text('Record Payment for ${student.name}'),
            content: Container(
              width: MediaQuery.of(dlgContext).size.width * 0.9,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  TextFormField(
                      controller: _paymentAmountController,
                      decoration: InputDecoration(labelText: 'Amount Paid', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                      keyboardType: TextInputType.numberWithOptions(decimal: true)),
                  SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Text('Payment Date: ${DateFormat.yMMMd().format(_selectedPaymentDate)}')),
                    TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('Change'),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                              context: dlgContext, initialDate: _selectedPaymentDate,
                              firstDate: DateTime(2020), lastDate: DateTime.now().add(Duration(days: 365)));
                          if (picked != null && picked != _selectedPaymentDate) {
                            stfSetState(() { _selectedPaymentDate = picked; });
                          }
                        })
                  ]),
                  SizedBox(height: 16),
                  if (periodsForDropdown.isNotEmpty)
                    DropdownButtonFormField<DateTime>(
                      decoration: InputDecoration(labelText: "Payment For Period Starting", border: OutlineInputBorder()),
                      value: _paymentForPeriodStart,
                      isExpanded: true,
                      items: periodsForDropdown
                          .map((dueItem) => DropdownMenuItem<DateTime>(
                        value: dueItem.periodStartDate,
                        child: Text(
                          "${dueItem.monthYearDisplay} (Due: ₹${dueItem.remainingForPeriod.toStringAsFixed(0)})",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                          .toList(),
                      onChanged: (DateTime? newValue) {
                        stfSetState(() { _paymentForPeriodStart = newValue; });
                      },
                      validator: (value) => value == null ? 'Please select a period' : null,
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text("No periods with outstanding dues available.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                ]),
              ),
            ),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
              ElevatedButton(
                  child: Text('Save Payment'),
                  onPressed: () async {
                    final amount = double.tryParse(_paymentAmountController.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter a valid positive amount.'), backgroundColor: Colors.red));
                      return;
                    }
                    if (_paymentForPeriodStart == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment period selected.'), backgroundColor: Colors.red));
                      return;
                    }

                    List<PaymentHistoryEntry> updatedHistory = List.from(student.paymentHistory);
                    MonthlyDueItem paidForPeriodDetails = selectablePeriods.firstWhere(
                            (p) => p.periodStartDate.isAtSameMomentAs(_paymentForPeriodStart!),
                        orElse: () => MonthlyDueItem(
                            monthYearDisplay: "Error: Period Not Found",
                            periodStartDate: _paymentForPeriodStart!,
                            periodEndDate: DateTime(_paymentForPeriodStart!.year, _paymentForPeriodStart!.month+1,0),
                            feeDueForPeriod: 0
                        )
                    );

                    updatedHistory.add(PaymentHistoryEntry(
                        paymentDate: _selectedPaymentDate,
                        cycleStartDate: paidForPeriodDetails.periodStartDate,
                        cycleEndDate: paidForPeriodDetails.periodEndDate,
                        paid: true,
                        amountPaid: amount
                    ));

                    // Creating a temporary student object to see the effect of the new payment.
                    final tempStudentForCalc = Student(
                      id: student.id, name: student.name,
                      messStartDate: student.messStartDate,
                      originalServiceStartDate: student.originalServiceStartDate,
                      compensatoryDays: student.compensatoryDays,
                      attendanceLog: student.attendanceLog,
                      paymentHistory: updatedHistory,
                      isArchived: student.isArchived,
                      serviceHistory: student.serviceHistory,
                    );

                    List<MonthlyDueItem> duesAfterPayment = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
                        tempStudentForCalc,
                        appSettings,
                        DateTime.now()
                    );
                    double totalRemainingAfterThisPayment = duesAfterPayment.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                    bool newCurrentCyclePaidFlag = totalRemainingAfterThisPayment <= 0;


                    try {
                      await widget.firestoreService.updateStudentPartial(student.id, {
                        'currentCyclePaid': newCurrentCyclePaidFlag,
                        'paymentHistory': updatedHistory.map((e) => e.toMap()).toList(),
                      });
                      if (!mounted) return;
                      Navigator.of(dlgContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payment of ₹$amount recorded for ${student.name}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving payment: $e'), backgroundColor: Colors.red,));
                    }
                  }),
            ],
          );
        });
      },
    );
  }

  void _addCompensatoryDaysDialog(Student student) {
    if (widget.userRole == UserRole.guest) return;

    _compensatoryDaysController.text = "0";
    _compensatoryReasonController.clear();
    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        return AlertDialog(
          title: Text('Add Compensatory Days'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            TextField(controller: _compensatoryDaysController, decoration: InputDecoration(labelText: 'Number of Days to Add', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            SizedBox(height: 10),
            TextField(controller: _compensatoryReasonController, decoration: InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()), maxLines: 2),
          ])),
          actions: <Widget>[
            TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
            ElevatedButton(
                child: Text('Add Days'),
                onPressed: () async {
                  final daysToAdd = int.tryParse(_compensatoryDaysController.text) ?? 0;
                  if (daysToAdd > 0) {
                    try {
                      // We need to update the end date of the last service period
                      List<Map<String, dynamic>> updatedHistory = List.from(student.serviceHistory);
                      if(updatedHistory.isNotEmpty) {
                        final lastPeriod = updatedHistory.last;
                        final currentEndDate = (lastPeriod['endDate'] as Timestamp).toDate();
                        final newEndDate = currentEndDate.add(Duration(days: daysToAdd));
                        updatedHistory.last['endDate'] = Timestamp.fromDate(newEndDate);

                        await widget.firestoreService.updateStudentPartial(student.id, {
                          'serviceHistory': updatedHistory,
                          'compensatoryDays': FieldValue.increment(daysToAdd)
                        });
                      }

                      if (!mounted) return;
                      Navigator.of(dlgContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$daysToAdd compensatory days added for ${student.name}')));
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding days: $e'), backgroundColor: Colors.red));
                    }
                  } else {
                    if (daysToAdd < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot add negative compensatory days.'), backgroundColor: Colors.orange));
                    } else {
                      Navigator.of(dlgContext).pop();
                    }
                  }
                }),
          ],
        );
      },
    );
  }

  void _startNewServicePeriodManually(Student student, DateTime manualStartDate) async {
    if (widget.userRole == UserRole.guest) return;
    if (student.isArchived) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot start new period for an archived student.'), backgroundColor: Colors.orange));
      return;
    }


    try {
      // Add a new entry to the service history
      final newPeriodEndDate = manualStartDate.add(Duration(days:29));
      final newPeriod = {
        'startDate': Timestamp.fromDate(manualStartDate),
        'endDate': Timestamp.fromDate(newPeriodEndDate),
      };

      // Get the existing history and add to it
      List<Map<String, dynamic>> updatedHistory = List.from(student.serviceHistory);
      updatedHistory.add(newPeriod);

      await widget.firestoreService.updateStudentPartial(student.id, {
        'messStartDate': Timestamp.fromDate(manualStartDate),
        'serviceHistory': updatedHistory,
        'compensatoryDays': 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('New service period for ${student.name} manually set to start from ${DateFormat.yMMMd().format(manualStartDate)}.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error starting new manual period: $e'), backgroundColor: Colors.red));
    }
  }


  void _showManualStartPeriodDialog(Student student) {
    if (widget.userRole == UserRole.guest || student.isArchived) return;

    _manualServiceStartDate = student.effectiveMessEndDate.add(Duration(days: 1));
    if (_manualServiceStartDate!.isBefore(DateTime.now())) {
      _manualServiceStartDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    }


    showDialog(
      context: context,
      builder: (BuildContext dlgContext) {
        DateTime? tempPickedDate = _manualServiceStartDate;
        return StatefulBuilder(
            builder: (stfContext, stfSetState) {
              return AlertDialog(
                title: Text('Start Future Service Period'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select a future start date for ${student.name}.'),
                    SizedBox(height: 20),
                    Text('Current Service Ends: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}'),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: Text('New Start Date: ${DateFormat.yMMMd().format(tempPickedDate!)}')),
                        TextButton.icon(
                          icon: Icon(Icons.calendar_today),
                          label: Text('Change'),
                          onPressed: () async {
                            DateTime firstPickerDate = student.effectiveMessEndDate.add(Duration(days: 1));
                            DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                            if (firstPickerDate.isBefore(today)) {
                              firstPickerDate = today;
                            }

                            final DateTime? picked = await showDatePicker(
                              context: dlgContext,
                              initialDate: tempPickedDate!,
                              firstDate: firstPickerDate,
                              lastDate: DateTime.now().add(Duration(days: 365 * 2)),
                            );
                            if (picked != null && picked != tempPickedDate) {
                              stfSetState(() {
                                tempPickedDate = picked;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                actions: <Widget>[
                  TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(dlgContext).pop()),
                  ElevatedButton(
                    child: Text('Set Start Date'),
                    onPressed: () {
                      if (tempPickedDate != null) {
                        _startNewServicePeriodManually(student, tempPickedDate!);
                        Navigator.of(dlgContext).pop();
                      }
                    },
                  ),
                ],
              );
            }
        );
      },
    );
  }

  void _startNextServicePeriodAuto(Student student) {
    // This function's logic needs to be re-evaluated with serviceHistory.
    // For now, we can make it call the manual start function with the day after the last period.
    DateTime newStartDate = student.effectiveMessEndDate.add(Duration(days:1));
    _startNewServicePeriodManually(student, newStartDate);
  }

  void _showArchiveConfirmationDialog(Student student) {
    if (widget.userRole != UserRole.owner || student.isArchived) return;

    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Confirm Archive'),
            content: Text('Are you sure you want to archive ${student.name}?\n\nThis student will be moved to the archived list and will not appear in active operations. This action can be performed even if payments are not settled. Their record will be preserved.'),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.orange[700]),
                  child: Text('Archive Student'),
                  onPressed: () async {
                    try {
                      await widget.firestoreService.setStudentArchiveStatus(student.id, true);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} has been archived.')));
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error archiving student: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
  }

  void _showDeleteConfirmationDialog(Student student) {
    if (widget.userRole != UserRole.owner) return;

    showDialog(
        context: context,
        builder: (BuildContext ctx) {
          return AlertDialog(
            title: Text('Confirm Delete'),
            content: Text('Are you sure you want to PERMANENTLY DELETE ${student.name} (${student.contactNumber})? This action cannot be undone and all historical data will be lost.\n\nConsider archiving if you want to retain records.'),
            actions: <Widget>[
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.of(ctx).pop()),
              TextButton(
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Delete Permanently'),
                  onPressed: () async {
                    try {
                      await widget.firestoreService.deleteStudent(student.id);
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      Navigator.of(context).pop(true);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} has been permanently deleted.')));
                    } catch (e) {
                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting: $e'), backgroundColor: Colors.red));
                    }
                  }),
            ],
          );
        });
  }


  void _prepareAttendanceEvents(Student student, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    eventsMap.clear();
    for (var entry in student.attendanceLog) {
      final day = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (eventsMap[day] == null) {
        eventsMap[day] = [];
      }
      eventsMap[day]!.add(entry.status);
    }
  }

  List<Widget> _getAttendanceMarkersForDay(BuildContext context, DateTime day, Map<DateTime, List<AttendanceStatus>> eventsMap) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    final statuses = eventsMap[normalizedDay];
    final theme = Theme.of(context);

    List<Widget> markers = [];
    if (statuses != null && statuses.contains(AttendanceStatus.present)) {
      markers.add(
        Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.85),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: Offset(0,1)
                  )
                ]
            ),
            padding: EdgeInsets.all(2.0),
            child: Icon(Icons.check, color: Colors.white, size: 11),
          ),
        ),
      );
    }
    else {
      markers.add(
        Positioned(
          right: 3,
          bottom: 3,
          child: Container(
            decoration: BoxDecoration(
                color: theme.colorScheme.error.withOpacity(0.8),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: Offset(0,1)
                  )
                ]
            ),
            padding: EdgeInsets.all(2.0),
            child: Icon(Icons.close, color: Colors.white, size: 11),
          ),
        ),
      );
    }
    return markers;
  }

  void _showAttendanceLogDialog(Student student) {
    Map<DateTime, List<AttendanceStatus>> _dialogAttendanceEvents = {};
    _prepareAttendanceEvents(student, _dialogAttendanceEvents);
    DateTime _dialogFocusedDay = DateTime.now();
    if (student.attendanceLog.isNotEmpty) {
      DateTime lastLoggedDate = student.attendanceLog.last.date;
      if (lastLoggedDate.isAfter(DateTime.now().subtract(Duration(days: 180))) && lastLoggedDate.isBefore(DateTime.now().add(Duration(days:30)))) {
        _dialogFocusedDay = lastLoggedDate;
      }
    }
    DateTime earliestFocus = student.originalServiceStartDate;
    if (student.messStartDate.isAfter(earliestFocus)) {
      earliestFocus = student.messStartDate;
    }


    if (_dialogFocusedDay.isBefore(earliestFocus) && earliestFocus.isBefore(DateTime.now().add(Duration(days:30)))) {
      _dialogFocusedDay = earliestFocus;
    }
    if (_dialogFocusedDay.isAfter(DateTime.now().add(Duration(days:90)))){
      _dialogFocusedDay = DateTime.now();
    }


    DateTime? _dialogSelectedDay = _dialogFocusedDay;
    CalendarFormat _dialogCalendarFormat = CalendarFormat.month;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                backgroundColor: theme.cardColor,

                title: Text(
                  "Attendance: ${student.name.split(" ").first}",
                  style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600
                  ),
                  textAlign: TextAlign.center,
                ),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  height: MediaQuery.of(context).size.height * 0.50,
                  child: TableCalendar<AttendanceStatus>(
                    firstDay: student.originalServiceStartDate.subtract(Duration(days:30)),
                    lastDay: student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2)),
                    focusedDay: _dialogFocusedDay,
                    calendarFormat: _dialogCalendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_dialogSelectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      DateTime firstValidDay = student.originalServiceStartDate.subtract(Duration(days:30));
                      DateTime lastValidDay = student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2));

                      if (!selectedDay.isBefore(firstValidDay) && !selectedDay.isAfter(lastValidDay)) {
                        setStateDialog(() {
                          _dialogSelectedDay = selectedDay;
                          _dialogFocusedDay = focusedDay;
                        });
                      }
                    },
                    onFormatChanged: (format) {
                      if (_dialogCalendarFormat != format) {
                        setStateDialog(() { _dialogCalendarFormat = format; });
                      }
                    },
                    onPageChanged: (focusedDay) {
                      DateTime firstValidDay = student.originalServiceStartDate.subtract(Duration(days:30));
                      DateTime lastValidDay = student.effectiveMessEndDate.add(Duration(days: 30)).isAfter(DateTime.now().add(Duration(days:365*2))) ? student.effectiveMessEndDate.add(Duration(days:30)) : DateTime.now().add(Duration(days: 365 * 2));

                      DateTime newFocusedDay = focusedDay;
                      if (focusedDay.isBefore(firstValidDay)){
                        newFocusedDay = firstValidDay;
                      } else if (focusedDay.isAfter(lastValidDay)){
                        newFocusedDay = lastValidDay;
                      }

                      if (isSameDay(_dialogFocusedDay, newFocusedDay)) return;

                      _dialogFocusedDay = newFocusedDay;
                      setStateDialog((){});
                    },
                    headerStyle: HeaderStyle(
                      titleTextStyle: theme.textTheme.titleLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                          fontSize: 18
                      ),
                      titleTextFormatter: (date, locale) => DateFormat.yMMMM(locale).format(date),
                      formatButtonTextStyle: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSecondary) ?? TextStyle(color: theme.colorScheme.onSecondary),
                      formatButtonDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(color: theme.colorScheme.secondary)
                      ),
                      formatButtonPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      formatButtonShowsNext: false,
                      leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.primary, size: 28),
                      rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.primary, size: 28),
                      headerPadding: EdgeInsets.symmetric(vertical: 8.0),
                      titleCentered: true,
                    ),
                    daysOfWeekHeight: 24.0,
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: theme.textTheme.bodySmall!.copyWith(
                          color: theme.textTheme.bodySmall!.color!.withOpacity(0.8),
                          fontWeight: FontWeight.w600
                      ),
                      weekendStyle: theme.textTheme.bodySmall!.copyWith(
                          color: theme.colorScheme.error.withOpacity(0.7),
                          fontWeight: FontWeight.w600
                      ),
                    ),
                    calendarStyle: CalendarStyle(
                      outsideDaysVisible: false,
                      defaultTextStyle: theme.textTheme.bodyMedium!.copyWith(fontSize: 14.5),
                      weekendTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.error, fontSize: 14.5),
                      holidayTextStyle: theme.textTheme.bodyMedium!.copyWith(color: Colors.blue[700], fontSize: 14.5),

                      todayTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onSecondary, fontWeight: FontWeight.bold, fontSize: 14.5),
                      todayDecoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        shape: BoxShape.circle,
                      ),
                      selectedTextStyle: theme.textTheme.bodyMedium!.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 14.5),
                      selectedDecoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0,1))
                          ]
                      ),
                      cellMargin: EdgeInsets.all(5.0),
                      cellAlignment: Alignment.center,
                      markersAlignment: Alignment.bottomCenter,
                      markerDecoration: BoxDecoration(
                          color: theme.colorScheme.secondary,
                          shape: BoxShape.circle
                      ),
                      markerSize: 5.0,
                      markersMaxCount: 1,
                      markerMargin: const EdgeInsets.only(top: 0.5),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (builderContext, date, events) {
                        if (date.isBefore(student.originalServiceStartDate) || date.isAfter(student.effectiveMessEndDate)) {
                          return SizedBox.shrink();
                        }
                        final markers = _getAttendanceMarkersForDay(builderContext, date, _dialogAttendanceEvents);
                        if (markers.isNotEmpty) {
                          return Stack(children: markers);
                        }
                        return null;
                      },
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Text("Close", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary, fontSize: 15)),
                      onPressed: () => Navigator.of(dialogContext).pop()
                  )
                ],
              );
            }
        );
      },
    );
  }

  Widget _buildDetailCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: Theme.of(context).primaryColor, size: 28),
              SizedBox(width: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            Divider(height: 20, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isEmphasized = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
              flex: 2,
              child: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]))
          ),
          SizedBox(width: 10),
          Flexible(
              flex: 3,
              child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isEmphasized ? FontWeight.bold : FontWeight.normal,
                      color: isEmphasized ? Colors.teal[700] : Colors.black87
                  )
              )
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isOwner = widget.userRole == UserRole.owner;

    return StreamBuilder<AppSettings>(
      stream: widget.firestoreService.getAppSettingsStream(),
      builder: (context, appSettingsSnapshot) {
        if (appSettingsSnapshot.connectionState == ConnectionState.waiting && !appSettingsSnapshot.hasData) {
          return Scaffold(appBar: CommonAppBar(title: "Loading Settings..."), body: Center(child: CircularProgressIndicator()));
        }
        if (appSettingsSnapshot.hasError) {
          return Scaffold(appBar: CommonAppBar(title: "Error"), body: Center(child: Text('Error loading app settings: ${appSettingsSnapshot.error}')));
        }

        final appSettings = appSettingsSnapshot.data!;

        return StreamBuilder<Student?>(
          stream: widget.firestoreService.getStudentStream(widget.studentId),
          builder: (context, studentSnapshot) {
            if (studentSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(appBar: CommonAppBar(title: "Loading Student..."), body: Center(child: CircularProgressIndicator()));
            }
            if (studentSnapshot.hasError) {
              return Scaffold(appBar: CommonAppBar(title: "Error"), body: Center(child: Text('Error: ${studentSnapshot.error}')));
            }
            if (!studentSnapshot.hasData || studentSnapshot.data == null) {
              return Scaffold(appBar: CommonAppBar(title: "Not Found"), body: Center(child: Text('Student not found.')));
            }

            final student = studentSnapshot.data!;
            final List<MonthlyDueItem> billingPeriods = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(student, appSettings, DateTime.now());
            final double totalRemainingAmount = billingPeriods.fold(0.0, (sum, item) => sum + item.remainingForPeriod);

            return WillPopScope(
              onWillPop: () async {
                Navigator.pop(context, true);
                return true;
              },
              child: Scaffold(
                appBar: CommonAppBar(
                  title: student.name + (student.isArchived ? " (Archived)" : ""),
                  actions: [
                    if (isOwner && !student.isArchived)
                      IconButton(
                        icon: Icon(Icons.archive_outlined, color: Colors.orange[700]),
                        tooltip: 'Archive Student',
                        onPressed: () => _showArchiveConfirmationDialog(student),
                      ),
                    if (isOwner)
                      IconButton(
                          icon: Icon(Icons.delete_outline, color: Colors.redAccent[100]),
                          tooltip: 'Delete Student Permanently',
                          onPressed: () => _showDeleteConfirmationDialog(student)
                      ),
                  ],
                ),
                body: Opacity(
                  opacity: student.isArchived ? 0.7 : 1.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ListView(
                      children: <Widget>[
                        if (student.isArchived)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Card(
                              color: Colors.grey[300],
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Text(
                                  "This student's record is ARCHIVED.",
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: Colors.black54),
                                ),
                              ),
                            ),
                          ),
                        _buildDetailCard(context, title: 'Student Info.', icon: Icons.person_pin_circle_outlined, children: [
                          _buildInfoRow('Name:', student.name),
                          _buildInfoRow('Contact (ID):', student.contactNumber),
                          _buildInfoRow('Status:', student.isArchived ? 'Archived' : 'Active', isEmphasized: student.isArchived),
                        ]),
                        SizedBox(height: 16),
                        _buildDetailCard(context, title: 'Mess Service Info.', icon: Icons.calendar_today_outlined, children: [
                          _buildInfoRow('Original Service Start:', DateFormat.yMMMd().format(student.originalServiceStartDate)),
                          _buildInfoRow('Current Cycle Start:', DateFormat.yMMMd().format(student.messStartDate)),
                          if (isOwner) _buildInfoRow('Compensatory Days:', '${student.compensatoryDays} days'),
                          _buildInfoRow('Effective Service End Date:', DateFormat.yMMMd().format(student.effectiveMessEndDate), isEmphasized: true),
                        ]),
                        SizedBox(height: 16),

                        if (isOwner)
                          _buildDetailCard(context, title: 'Payment Overview', icon: Icons.monetization_on_outlined, children: [
                            _buildInfoRow('Current Standard Fee:', '₹${appSettings.currentStandardFee.toStringAsFixed(2)}'),
                            _buildInfoRow('Total Remaining Dues (All Periods):', '₹${totalRemainingAmount.toStringAsFixed(2)}', isEmphasized: totalRemainingAmount > 0),
                            SizedBox(height: 10),
                            if (!student.isArchived)
                              ElevatedButton.icon(
                                  icon: Icon(Icons.payment),
                                  label: Text('Record New Payment'),
                                  onPressed: () => _recordPaymentDialog(student, billingPeriods, appSettings),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
                            SizedBox(height: 10),
                            Text("Billing Period Breakdown:", style: Theme.of(context).textTheme.titleMedium),
                            if (billingPeriods.isEmpty) Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text("No billing periods generated yet.", style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
                            ) else
                              SizedBox(
                                height: 120,
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: billingPeriods.map((dueItem) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("${dueItem.monthYearDisplay}:", style: Theme.of(context).textTheme.titleSmall),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                                            child: Text(
                                              "(Period: ${DateFormat.yMMMd().format(dueItem.periodStartDate)} - ${DateFormat.yMMMd().format(dueItem.periodEndDate)})",
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                                            child: Text(
                                              "Fee: ₹${dueItem.feeDueForPeriod.toStringAsFixed(0)}, Paid: ₹${dueItem.amountPaidForPeriod.toStringAsFixed(0)}, Rem: ₹${dueItem.remainingForPeriod.toStringAsFixed(0)} (${dueItem.status})",
                                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dueItem.status == "Paid" ? Colors.green : (dueItem.status == "Partially Paid" ? Colors.orange.shade700 : Colors.red.shade700)),
                                            ),
                                          ),
                                          if (billingPeriods.last != dueItem) Divider(height: 1, thickness: 0.5),
                                        ],
                                      ),
                                    )).toList(),
                                  ),
                                ),
                              ),
                            SizedBox(height: 10),
                            TextButton(onPressed: () {
                              if (student.paymentHistory.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No payment history for ${student.name}.'))); return;
                              }
                              _showPaymentHistoryDialog(student);
                            }, child: Text('View All Payment Entries')),
                          ]),
                        if (isOwner) SizedBox(height: 16),

                        _buildDetailCard(context, title: 'Attendance', icon: Icons.fact_check_outlined, children: [
                          TextButton(
                              onPressed: () => _showAttendanceLogDialog(student),
                              child: Text('View Attendance Calendar')
                          ),
                        ]),
                        SizedBox(height: 16),

                        if (isOwner && !student.isArchived)
                          _buildDetailCard(
                            context,
                            title: 'Manage Service',
                            icon: Icons.control_point_duplicate_outlined,
                            children: [
                              // Clean, full-width button for "Add Compensatory Days"
                              ElevatedButton(
                                onPressed: () => _addCompensatoryDaysDialog(student),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.add_circle_outline, size: 22),
                                    SizedBox(width: 12),
                                    Text('Add Compensatory Days'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Clean, full-width button for "Start Next Period (Auto)"
                              ElevatedButton(
                                onPressed: () => _startNextServicePeriodAuto(student),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.event_repeat_outlined, size: 22),
                                    SizedBox(width: 12),
                                    Text('Start Next Period (Auto)'),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Clean, full-width button for "Start Future Period (Manual)"
                              ElevatedButton(
                                onPressed: () => _showManualStartPeriodDialog(student),
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 48),
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.date_range_outlined, size: 22),
                                    SizedBox(width: 12),
                                    Text('Start Future Period (Manual)'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (isOwner && !student.isArchived) const SizedBox(height: 20),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPaymentHistoryDialog(Student student) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.grey[50],
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Payment History",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              SizedBox(height: 4),
              Text(
                student.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              SizedBox(height: 20),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: student.paymentHistory.length,
                  itemBuilder: (iCtx, idx) {
                    final entry = student.paymentHistory.reversed.toList()[idx];
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check, color: Colors.green, size: 20),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "₹${entry.amountPaid.toStringAsFixed(0)}",
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    DateFormat.yMMMd().format(entry.paymentDate),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500], fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "Period Start",
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[400], fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  DateFormat.yMMMd().format(entry.cycleStartDate),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                  ),
                  child: Text("Close", style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600, color: Colors.black87)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}