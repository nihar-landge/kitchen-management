// lib/screens/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';
import '../utils/payment_manager.dart';
import '../services/voice_command_service.dart';

import '../widgets/voice_assistant_overlay.dart';

class DashboardScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;
  final VoidCallback onNavigateToAttendance;
  final VoidCallback onNavigateToStudentsScreen;
  final VoidCallback onNavigateToPaymentsScreenFiltered;
  final VoidCallback onNavigateToAddStudent;
  final Function(Student) onViewStudentDetails;

  final String ownerName = "Owner";

  DashboardScreen({
    required this.firestoreService,
    required this.userRole,
    required this.onNavigateToAttendance,
    required this.onNavigateToStudentsScreen,
    required this.onNavigateToPaymentsScreenFiltered,
    required this.onNavigateToAddStudent,
    required this.onViewStudentDetails,
    Key? key,
  }) : super(key: key);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final VoiceCommandService _voiceService = VoiceCommandService();
  
  late Stream<List<Student>> _studentsStream;
  late Stream<AppSettings> _appSettingsStream;

  bool _isListening = false;
  String _voiceText = "";
  VoiceCommand? _pendingCommand;
  List<String>? _pendingAnnouncementNames; // Store names to announce

  @override
  void initState() {
    super.initState();
    _initVoiceService();
    _studentsStream = widget.firestoreService.getStudentsStream(archiveStatusFilter: StudentArchiveStatusFilter.active);
    _appSettingsStream = widget.firestoreService.getAppSettingsStream();
  }

  Future<void> _initVoiceService() async {
    await Permission.microphone.request();
    await _voiceService.initialize();
  }

  Future<void> _toggleListening(List<Student> students, AppSettings appSettings) async {
    if (_isListening) {
      _voiceService.stop();
      setState(() {
        _isListening = false;
        _voiceText = "";
        _pendingCommand = null;
        _pendingAnnouncementNames = null;
      });
      return;
    }

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _showSnackBar("Microphone permission required", isError: true);
        return;
      }
    }

    setState(() {
      _isListening = true;
      _voiceText = "Listening...";
      _pendingCommand = null;
      _pendingAnnouncementNames = null;
    });

    _startVoiceFlow(students, appSettings);
  }

  void _startVoiceFlow(List<Student> students, AppSettings appSettings) {
    _voiceService.listen(
      students: students,
      onResult: (text) {
        setState(() => _voiceText = text);
      },
      onCommandRecognized: (command) => _handleVoiceCommand(command, students, appSettings),
    );
  }

  void _handleVoiceCommand(VoiceCommand command, List<Student> students, AppSettings appSettings) async {
    if (command.error != null) {
      setState(() => _voiceText = "Error: ${command.error}");
      await _voiceService.speak("Sorry, I didn't catch that.");
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) setState(() => _isListening = false);
      });
      return;
    }

    if (_pendingCommand == null && _pendingAnnouncementNames == null) {
      if (command.intent == VoiceIntent.markAttendance || command.intent == VoiceIntent.checkDues) {
        if (command.student != null) {
          setState(() {
            _pendingCommand = command;
            _voiceText = "Did you mean ${command.student!.name}?";
          });
          await _voiceService.speak("Did you mean ${command.student!.name}?");
          _startVoiceFlow(students, appSettings); // Listen for confirmation
        } else {
          setState(() => _voiceText = "Student not found.");
          await _voiceService.speak("Student not found.");
          Future.delayed(Duration(seconds: 2), () {
            if (mounted) setState(() => _isListening = false);
          });
        }
      } else if (command.intent == VoiceIntent.checkLunchCount) {
         DateTime now = DateTime.now();
         MealType currentMeal = now.hour < 16 ? MealType.morning : MealType.night;
         String mealName = currentMeal == MealType.morning ? "Lunch" : "Dinner";
         DateTime today = DateTime(now.year, now.month, now.day);

         List<String> remainingNames = [];
         for (var s in students) {
            bool isActive = !today.isBefore(DateTime(s.messStartDate.year, s.messStartDate.month, s.messStartDate.day)) && 
                            !today.isAfter(DateTime(s.effectiveMessEndDate.year, s.effectiveMessEndDate.month, s.effectiveMessEndDate.day));
            
            if (isActive) {
              bool hasEaten = s.attendanceLog.any((entry) => 
                DateTime(entry.date.year, entry.date.month, entry.date.day).isAtSameMomentAs(today) &&
                entry.mealType == currentMeal &&
                entry.status == AttendanceStatus.present
              );
              
              if (!hasEaten) {
                remainingNames.add(s.name);
              }
            }
         }

         int count = remainingNames.length;
         String response = "There are $count people remaining for $mealName.";
         
         setState(() {
           _voiceText = response;
           _pendingAnnouncementNames = remainingNames; // Store remaining names
         });
         
         await _voiceService.speak(response);
         
         if (count > 0) {
            await _voiceService.speak("Should I announce their names?");
            setState(() => _voiceText = "Should I announce names?");
            _startVoiceFlow(students, appSettings); // Listen for Yes/No
         } else {
            Future.delayed(Duration(seconds: 2), () {
              if (mounted) setState(() => _isListening = false);
            });
         }

      } else {
        setState(() => _voiceText = "Unknown command.");
        await _voiceService.speak("I didn't understand.");
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) setState(() => _isListening = false);
        });
      }
    } 
    else {
      if (command.intent == VoiceIntent.confirmation) {
        if (_pendingAnnouncementNames != null) {
           setState(() => _voiceText = "Announcing names...");
           await _voiceService.speak("Here is the list.");
           for (var name in _pendingAnnouncementNames!) {
             await _voiceService.speak(name);
           }
           setState(() {
             _voiceText = "Done.";
             _pendingAnnouncementNames = null;
           });
           Future.delayed(Duration(seconds: 1), () {
              if (mounted) setState(() => _isListening = false);
           });
        } else {
           setState(() => _voiceText = "Confirmed!");
           await _voiceService.speak("Okay, done.");
           _executeCommand(_pendingCommand!, appSettings);
           Future.delayed(Duration(seconds: 1), () {
             if (mounted) setState(() => _isListening = false);
           });
        }
      } else if (command.intent == VoiceIntent.rejection) {
        setState(() => _voiceText = "Cancelled.");
        await _voiceService.speak("Okay.");
        Future.delayed(Duration(seconds: 1), () {
          if (mounted) setState(() => _isListening = false);
        });
      } else {
        await _voiceService.speak("Please say Yes or No.");
        _startVoiceFlow(students, appSettings);
      }
    }
  }

  void _executeCommand(VoiceCommand command, AppSettings appSettings) async {
    final student = command.student!;
    if (command.intent == VoiceIntent.markAttendance) {
      DateTime now = DateTime.now();
      MealType currentMeal = now.hour < 16 ? MealType.morning : MealType.night;
      try {
        await widget.firestoreService.addAttendanceEntry(student.id, AttendanceEntry(
          date: DateTime.now(),
          status: AttendanceStatus.present,
          mealType: currentMeal,
        ));
        _showSnackBar("Marked ${student.name} Present ✅");
      } catch (e) {
        _showSnackBar("Error: $e", isError: true);
      }
    } else if (command.intent == VoiceIntent.checkDues) {
      List<MonthlyDueItem> dues = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(student, appSettings, DateTime.now());
      double totalDue = dues.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
      _showDialog("Dues for ${student.name}", "Total Pending: ₹${totalDue.toStringAsFixed(0)}");
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showDialog(String title, String content) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      content: Text(content, style: GoogleFonts.poppins(fontSize: 18)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text("OK"))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Student>>(
      stream: _studentsStream,
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final students = studentSnapshot.data ?? [];

        return StreamBuilder<AppSettings>(
          stream: _appSettingsStream,
          builder: (context, appSettingsSnapshot) {
            final appSettings = appSettingsSnapshot.data ?? AppSettings(feeHistory: []);

            return Scaffold(
              appBar: AppBar(
                title: AnimatedSwitcher(
                  duration: Duration(milliseconds: 300),
                  child: _isListening 
                    ? Text(
                        _voiceText, 
                        key: ValueKey(_voiceText),
                        style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic)
                      )
                    : Text(
                        widget.userRole == UserRole.owner ? 'Owner Dashboard' : 'Guest Dashboard', 
                        key: ValueKey('title'),
                        style: TextStyle(fontWeight: FontWeight.bold)
                      ),
                ),
                backgroundColor: _isListening ? Colors.indigo : Theme.of(context).primaryColor,
                elevation: 0,
                actions: [
                  if (widget.userRole == UserRole.owner)
                    IconButton(
                      icon: Icon(_isListening ? Icons.stop_circle_outlined : Icons.mic),
                      onPressed: () => _toggleListening(students, appSettings),
                    ),
                  SizedBox(width: 10),
                ],
              ),
              floatingActionButton: null, 
              body: _buildDashboardContent(context, students, appSettings),
            );
          },
        );
      },
    );
  }

  Widget _buildDashboardContent(BuildContext context, List<Student> students, AppSettings appSettings) {
    int activeStudentsCount = students.where((s) => s.effectiveMessEndDate.isAfter(DateTime.now())).length;

    int newPaymentsDueCount = 0;
    if (widget.userRole == UserRole.owner) {
      for (var student in students) {
        List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
            student,
            appSettings, 
            DateTime.now()
        );
        double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
        if (totalRemaining > 0) {
          newPaymentsDueCount++;
        }
      }
    }

    DateTime now = DateTime.now();
    MealType currentMealType;
    String mealTypeLabel;

    if (now.hour < 16) {
      currentMealType = MealType.morning;
      mealTypeLabel = "Morning";
    } else {
      currentMealType = MealType.night;
      mealTypeLabel = "Night";
    }

    DateTime todayForAttendance = DateTime(now.year, now.month, now.day);
    int presentTodayCount = 0;
    int totalActiveTodayForAttendance = 0;

    for (var student in students) {
      DateTime serviceStartDateNormalized = DateTime(student.messStartDate.year, student.messStartDate.month, student.messStartDate.day);
      DateTime serviceEndDateNormalized = DateTime(student.effectiveMessEndDate.year, student.effectiveMessEndDate.month, student.effectiveMessEndDate.day);

      bool isActiveToday = !todayForAttendance.isBefore(serviceStartDateNormalized) &&
          !todayForAttendance.isAfter(serviceEndDateNormalized);

      if (isActiveToday) {
        totalActiveTodayForAttendance++;
        bool wasPresentForCurrentMeal = student.attendanceLog.any((entry) {
          DateTime entryDateNormalized = DateTime(entry.date.year, entry.date.month, entry.date.day);
          return entryDateNormalized.isAtSameMomentAs(todayForAttendance) &&
              entry.status == AttendanceStatus.present &&
              entry.mealType == currentMealType;
        });
        if (wasPresentForCurrentMeal) {
          presentTodayCount++;
        }
      }
    }
    String attendanceTodayText = (totalActiveTodayForAttendance - presentTodayCount).toString();

    List<Map<String, dynamic>> studentNotificationsData = [];
    for (var student in students) {
      final diffDays = student.effectiveMessEndDate.difference(DateTime.now()).inDays;
      List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
          student, appSettings, DateTime.now());
      double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
      bool isUnpaid = totalRemaining > 0;

      bool shouldDisplay = false;
      if (widget.userRole == UserRole.owner) {
        if ((diffDays >= 0 && diffDays <= 3) || (diffDays < 0 && isUnpaid)) {
          shouldDisplay = true;
        }
      } else {
        if (diffDays >= 0 && diffDays <= 3) {
          shouldDisplay = true;
        }
      }
      if (shouldDisplay) {
        studentNotificationsData.add({
          'student': student,
          'isUnpaid': isUnpaid,
          'totalRemaining': totalRemaining,
          'diffDays': diffDays,
        });
      }
    }
    studentNotificationsData.sort((a, b) {
      Student studentA = a['student'] as Student;
      Student studentB = b['student'] as Student;
      return studentA.effectiveMessEndDate.compareTo(studentB.effectiveMessEndDate);
    });

    return Container(
      color: Colors.grey[100],
      child: ListView(
        padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 100.0),
        children: <Widget>[
          Text(widget.userRole == UserRole.owner ? 'Hello, ${widget.ownerName}!' : 'Welcome, Guest!', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black87)),
          SizedBox(height: 20),

          LayoutBuilder(
              builder: (context, constraints) {
                bool isNarrowScreen = constraints.maxWidth < 550;
                List<Widget> firstRowWidgets = [];
                List<Widget> secondRowWidgets = [];

                String attendanceCardDisplayTitle;
                int attendanceIconFlex;
                int attendanceValueFlex;

                if (widget.userRole == UserRole.owner) {
                  attendanceCardDisplayTitle = 'Remaining ($mealTypeLabel)';
                  attendanceIconFlex = 3;
                  attendanceValueFlex = 2;
                } else {
                  attendanceCardDisplayTitle = "";
                  attendanceIconFlex = 2;
                  attendanceValueFlex = 8;
                }

                firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                    context,
                    'Active Students',
                    activeStudentsCount.toString(),
                    Icons.person_outline,
                    Theme.of(context).primaryColor,
                    onTap: widget.onNavigateToStudentsScreen,
                    iconFlexFactor: 3,
                    valueFlexFactor: 2
                )));
                firstRowWidgets.add(SizedBox(width: 10));

                if (widget.userRole == UserRole.owner) {
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                      context,
                      'Payment Due',
                      newPaymentsDueCount.toString(),
                      Icons.credit_card_off_outlined,
                      Theme.of(context).primaryColor,
                      onTap: widget.onNavigateToPaymentsScreenFiltered,
                      iconFlexFactor: 3,
                      valueFlexFactor: 2
                  )));

                  if (!isNarrowScreen) {
                    firstRowWidgets.add(SizedBox(width: 10));
                    firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                        context,
                        attendanceCardDisplayTitle,
                        attendanceTodayText,
                        Icons.event_available_outlined,
                        Theme.of(context).primaryColor,
                        onTap: widget.onNavigateToAttendance,
                        iconFlexFactor: attendanceIconFlex,
                        valueFlexFactor: attendanceValueFlex
                    )));
                  } else {
                    secondRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                        context,
                        attendanceCardDisplayTitle,
                        attendanceTodayText,
                        Icons.event_available_outlined,
                        Theme.of(context).primaryColor,
                        onTap: widget.onNavigateToAttendance,
                        isFullWidth: true,
                        iconFlexFactor: attendanceIconFlex,
                        valueFlexFactor: attendanceValueFlex
                    )));
                  }
                } else {
                  firstRowWidgets.add(Expanded(child: _buildSimpleSummaryCard(
                      context,
                      attendanceCardDisplayTitle,
                      attendanceTodayText,
                      Icons.event_available_outlined,
                      Theme.of(context).primaryColor,
                      onTap: widget.onNavigateToAttendance,
                      iconFlexFactor: attendanceIconFlex,
                      valueFlexFactor: attendanceValueFlex
                  )));
                }

                List<Widget> layoutChildren = [Row(children: firstRowWidgets)];
                if (secondRowWidgets.isNotEmpty) {
                  layoutChildren.add(SizedBox(height: 10));
                  layoutChildren.add(Row(children: secondRowWidgets));
                }
                return Column(children: layoutChildren);
              }
          ),
          SizedBox(height: 30),

          if (widget.userRole == UserRole.owner)
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.black54)),
          if (widget.userRole == UserRole.owner) SizedBox(height: 15),
          if (widget.userRole == UserRole.owner)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                      icon: Icon(Icons.person_add_alt_1, size: 20),
                      label: Text('Add', style: TextStyle(fontSize: 14)),
                      onPressed: widget.onNavigateToAddStudent,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical:15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      )
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                      icon: Icon(Icons.edit_calendar_outlined, size: 20),
                      label: Text('Mark Attendance', style: TextStyle(fontSize: 14)),
                      onPressed: widget.onNavigateToAttendance,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[400],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical:15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                      )
                  ),
                ),
              ],
            ),
          if (widget.userRole == UserRole.owner) SizedBox(height: 30),

          Text('Upcoming Cycle Endings / Dues:', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
          SizedBox(height: 10),
          studentNotificationsData.isEmpty
              ? Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(child: Text('No upcoming cycle endings${widget.userRole == UserRole.owner ? " or overdue payments" : ""}.', style: TextStyle(fontSize: 15))),
            ),
          )
              : Column(
            children: studentNotificationsData.map<Widget>((data) {
              final student = data['student'] as Student;
              final isUnpaid = data['isUnpaid'] as bool;
              final totalRemaining = data['totalRemaining'] as double;
              final diffDays = data['diffDays'] as int;

              String subtitleText = 'Mess ends on: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}';
              Color cardColor = Colors.pink.shade50;

              if (widget.userRole == UserRole.owner) {
                if (diffDays < 0 && isUnpaid) {
                  subtitleText += ' (Payment Overdue: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.red.shade100;
                } else if (isUnpaid) {
                  subtitleText += ' (Payment Pending: ₹${totalRemaining.toStringAsFixed(0)})';
                  cardColor = Colors.orange.shade100;
                } else {
                  subtitleText += ' (Paid)';
                  cardColor = Colors.green.shade50;
                }
              }

              return Card(
                elevation: 1, margin: EdgeInsets.symmetric(vertical: 5),
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_active_outlined,
                    color: isUnpaid ? (diffDays < 0 ? Colors.red.shade700 : Colors.orange.shade700) : Colors.green.shade700,
                  ),
                  title: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: Text(subtitleText, style: TextStyle(color: Colors.black87)),
                  trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
                  onTap: () => widget.onViewStudentDetails(student),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSummaryCard(
      BuildContext context,
      String title,
      String value,
      IconData? icon,
      Color cardColor,
      {VoidCallback? onTap,
        bool isFullWidth = false,
        int iconFlexFactor = 3,
        int valueFlexFactor = 2
      }) {
    return Card(
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: EdgeInsets.all(12.0),
          width: isFullWidth ? double.infinity : null,
          constraints: BoxConstraints(minHeight: 100),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: iconFlexFactor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (icon != null)
                      Icon(icon, size: 28, color: Colors.white.withOpacity(0.9)),
                    if (icon != null && title.isNotEmpty)
                      SizedBox(height: 10),
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: valueFlexFactor,
                child: Align(
                  alignment: Alignment(0.5, 0.0),
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}