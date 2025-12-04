// lib/screens/main_screen.dart
import 'package:flutter/material.dart';
import 'package:animations/animations.dart';

import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

import 'dashboard_screen.dart';
import 'students_screen.dart';
import 'add_student_screen.dart';
import 'student_detail_screen.dart';
import 'attendance_screen.dart';
import 'payments_screen.dart';
import 'settings_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MainScreen extends StatefulWidget {
  final UserRole userRole;

  MainScreen({required this.userRole, Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final FirestoreService _firestoreService = FirestoreService();
  String? _initialPaymentsFilter;

  late List<Widget> _widgetOptions;
  late List<BottomNavigationBarItem> _navBarItems;

  void _navigateToAddStudentFromDashboard() {
    if (widget.userRole == UserRole.owner) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: _firestoreService)),
      );
    }
  }

  void _navigateToStudentDetailFromDashboard(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          firestoreService: _firestoreService,
          userRole: widget.userRole,
        ),
      ),
    );
  }

  void _navigateToAttendanceScreen() {
    int attendanceIndex = _navBarItems.indexWhere((item) => item.label == 'Attendance');
    if (attendanceIndex != -1 && _selectedIndex != attendanceIndex) {
      setStateIfMounted(() { _selectedIndex = attendanceIndex; });
    }
  }

  void _navigateToStudentsScreenTab() {
    int studentsIndex = _navBarItems.indexWhere((item) => item.label == 'Students');
    if (studentsIndex != -1 && _selectedIndex != studentsIndex) {
      setStateIfMounted(() { _selectedIndex = studentsIndex; });
    }
  }

  void _navigateToPaymentsScreenFiltered() {
    if (widget.userRole == UserRole.owner) {
      int paymentsIndex = _navBarItems.indexWhere((item) => item.label == 'Payments');
      if (paymentsIndex != -1) {
        setStateIfMounted(() {
          _initialPaymentsFilter = "Dues > 0";
          _selectedIndex = paymentsIndex;
        });
      }
    }
  }


  Future<void> _handleAutomaticRenewals() async {
    // This process should only run for the owner.
    if (widget.userRole != UserRole.owner) {
      return;
    }

    try {
      // Get a list of all active students just once.
      final students = await _firestoreService
          .getStudentsStream(archiveStatusFilter: StudentArchiveStatusFilter.active)
          .first;

      final WriteBatch batch = FirebaseFirestore.instance.batch();
      int renewedCount = 0;
      final DateTime today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

      for (final student in students) {
        // Check if the student's service ended *before* today.
        if (student.effectiveMessEndDate.isBefore(today)) {

          // This is the renewal logic, taken from the detail screen.
          final DateTime newStartDate = student.effectiveMessEndDate.add(const Duration(days: 1));
          final newEndDate = newStartDate.add(const Duration(days: 29));

          final newPeriod = {
            'startDate': Timestamp.fromDate(newStartDate),
            'endDate': Timestamp.fromDate(newEndDate),
          };

          List<Map<String, dynamic>> updatedHistory = List.from(student.serviceHistory);
          updatedHistory.add(newPeriod);

          final DocumentReference studentRef = FirebaseFirestore.instance.collection('students').doc(student.id);

          // Add the update operation to a batch to do it all at once.
          batch.update(studentRef, {
            'messStartDate': Timestamp.fromDate(newStartDate),
            'serviceHistory': updatedHistory,
            'compensatoryDays': 0, // Reset compensatory days for the new cycle
          });
          renewedCount++;
        }
      }

      // If any students were renewed, commit all the changes to the database.
      if (renewedCount > 0) {
        await batch.commit();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$renewedCount student(s) were automatically renewed.'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      // Silently fail or log to console. We don't want to block the user.
      print('Error during automatic renewal check: $e');
    }
  }


  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  @override
  void initState() {
    super.initState();
    _buildNavItemsAndWidgetOptions();
    _handleAutomaticRenewals();
  }

  @override
  void didUpdateWidget(MainScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userRole != oldWidget.userRole) {
      _buildNavItemsAndWidgetOptions();
      // Ensure _selectedIndex is valid after role change
      if (_selectedIndex >= _widgetOptions.length && _widgetOptions.isNotEmpty) {
        _selectedIndex = 0;
      } else if (_widgetOptions.isEmpty) {
        // This case should ideally not happen if roles always have at least one screen
        _selectedIndex = 0;
      }
    }
  }


  void _buildNavItemsAndWidgetOptions() {
    _navBarItems = [];
    _widgetOptions = [];

    // Dashboard is always the first item (index 0)
    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'));
    _widgetOptions.add(DashboardScreen(
      firestoreService: _firestoreService,
      userRole: widget.userRole,
      onNavigateToAttendance: _navigateToAttendanceScreen,
      onNavigateToStudentsScreen: _navigateToStudentsScreenTab,
      onNavigateToPaymentsScreenFiltered: _navigateToPaymentsScreenFiltered,
      onNavigateToAddStudent: _navigateToAddStudentFromDashboard,
      onViewStudentDetails: _navigateToStudentDetailFromDashboard,
    ));

    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Students'));
    _widgetOptions.add(StudentsScreen(
      firestoreService: _firestoreService,
      userRole: widget.userRole,
    ));

    _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), activeIcon: Icon(Icons.check_circle), label: 'Attendance'));
    _widgetOptions.add(AttendanceScreen(
        firestoreService: _firestoreService,
        userRole: widget.userRole
    ));

    if (widget.userRole == UserRole.owner) {
      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.payment_outlined), activeIcon: Icon(Icons.payment), label: 'Payments'));
      _widgetOptions.add(PaymentsScreen(
        key: ValueKey('payments_screen_filter_$_initialPaymentsFilter'),
        firestoreService: _firestoreService,
        onViewStudent: _navigateToStudentDetailFromDashboard,
        initialFilterOption: _initialPaymentsFilter,
      ));

      _navBarItems.add(BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Settings'));
      _widgetOptions.add(SettingsScreen(
          firestoreService: _firestoreService,
          userRole: widget.userRole
      ));
    }

    // Reset _selectedIndex if it's out of bounds after rebuilding options
    if (_selectedIndex >= _widgetOptions.length && _widgetOptions.isNotEmpty) {
      _selectedIndex = 0;
    } else if (_widgetOptions.isEmpty) {
      _selectedIndex = 0; // Should not happen in normal flow
    }
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;

    setStateIfMounted(() {
      if (index < _navBarItems.length) {
        String tappedLabel = _navBarItems[index].label!;
        // Reset initial filter for PaymentsScreen if navigating away from it or to it directly
        // This logic ensures that if user taps "Payments" tab, it doesn't carry over a filter from a dashboard action.
        if (tappedLabel != 'Payments') {
          _initialPaymentsFilter = null;
        }
        _selectedIndex = index;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_navBarItems.isEmpty || _widgetOptions.isEmpty) {
      // This can happen briefly during role change, ensure options are built.
      _buildNavItemsAndWidgetOptions();
    }
    // Defensive check in case options are still empty (should be rare)
    if (_widgetOptions.isEmpty) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Ensure currentSelectedIndex is always valid
    int currentSelectedIndex = _selectedIndex;
    if (currentSelectedIndex >= _widgetOptions.length) {
      currentSelectedIndex = 0; // Default to Dashboard
    }

    return WillPopScope(
      onWillPop: () async {
        // If the current tab is not the Dashboard (index 0),
        // switch to the Dashboard tab and prevent app exit.
        if (_selectedIndex != 0) {
          setState(() {
            _selectedIndex = 0; // Index of Dashboard
            _initialPaymentsFilter = null;
          });
          return false;
        }
        // If already on the Dashboard, allow default back behavior (exit app).
        return true;
      },
      child: Scaffold(
        extendBody: true,
        body: PageTransitionSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (Widget child, Animation<double> primaryAnimation, Animation<double> secondaryAnimation) {
            return FadeTransition(
              opacity: primaryAnimation,
              child: child,
            );
          },
          child: KeyedSubtree(
            // Using a more robust key that includes role and selected index
            key: ValueKey('screen_${currentSelectedIndex}_role_${widget.userRole.index}'),
            child: _widgetOptions.elementAt(currentSelectedIndex),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BottomNavigationBar(
                items: _navBarItems,
                currentIndex: currentSelectedIndex,
                selectedItemColor: Theme.of(context).colorScheme.primary,
                unselectedItemColor: Colors.grey[600],
                onTap: _onItemTapped,
                type: BottomNavigationBarType.fixed,
                showUnselectedLabels: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
