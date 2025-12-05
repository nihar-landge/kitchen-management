import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Import for Timer

import '../models/student_model.dart';
import '../models/user_model.dart'; // Import UserRole
import '../models/user_model.dart'; // Import UserRole
import '../services/firestore_service.dart';
import '../widgets/common_app_bar.dart';

class AttendanceScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserRole userRole; // Add userRole parameter

  const AttendanceScreen({
    super.key, // Add super.key and make constructor const
    required this.firestoreService,
    required this.userRole,
  });

  @override
  AttendanceScreenState createState() => AttendanceScreenState();
}

class AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  // Set a default meal type, which will be updated in initState
  MealType _selectedMealType = MealType.morning;
  final Map<String, AttendanceStatus> _attendanceStatusMap = {};
  List<Student> _allActiveStudentsForDate = [];
  List<Student> _displayedStudents = [];
  bool _isLoading = true;
  String _searchTerm = "";
  bool _sortAbsenteesTop = false;
  int _absentCount = 0;
  bool _hasUnsavedChanges = false;

  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateMealTypeBasedOnTime(); // Set initial meal type based on time
    _loadActiveStudentsAndInitializeAttendance();

    // Optional: Set up a timer to auto-refresh if the screen is left open across the time boundary
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _updateMealTypeBasedOnTime(fromTimer: true);
    });

    _searchController.addListener(() {
      if (_searchController.text != _searchTerm) {
        setStateIfMounted(() {
          _searchTerm = _searchController.text;
          _filterAndSortDisplayedStudents();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _timer?.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }

  void setStateIfMounted(f) {
    if (mounted) setState(f);
  }

  /// Sets the meal type based on the current time of day.
  /// Morning meal is default before 4 PM, Night meal is default after 4 PM.
  void _updateMealTypeBasedOnTime({bool fromTimer = false}) {
    final now = DateTime.now();
    // Only auto-update if the selected date is today
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      final newMealType = now.hour < 16 ? MealType.morning : MealType.night; // 4 PM threshold

      // If the meal type changes, update the state and reload data.
      // The `fromTimer` check prevents unnecessary reloads if the user has manually changed the selection.
      if (_selectedMealType != newMealType || !fromTimer) {
        setStateIfMounted(() {
          _selectedMealType = newMealType;
        });

        // If called from a timer, we might want to reload the data
        if (fromTimer) {
          _loadActiveStudentsAndInitializeAttendance();
        }
      }
    }
  }


  Future<void> _loadActiveStudentsAndInitializeAttendance() async {
    setStateIfMounted(() { _isLoading = true; });
    try {
      List<Student> allStudents = await widget.firestoreService.getStudentsStream().first;

      _allActiveStudentsForDate = allStudents.where((s) {
        DateTime serviceStartDay = DateTime(s.messStartDate.year, s.messStartDate.month, s.messStartDate.day);
        DateTime serviceEndDay = DateTime(s.effectiveMessEndDate.year, s.effectiveMessEndDate.month, s.effectiveMessEndDate.day);
        DateTime selectedDayOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

        return (selectedDayOnly.isAtSameMomentAs(serviceStartDay) || selectedDayOnly.isAfter(serviceStartDay)) &&
            (selectedDayOnly.isAtSameMomentAs(serviceEndDay) || selectedDayOnly.isBefore(serviceEndDay.add(const Duration(days:1))) );
      }).toList();

      _attendanceStatusMap.clear();
      for (var student in _allActiveStudentsForDate) {
        var existingEntry = student.attendanceLog.firstWhere(
                (entry) => entry.date.year == _selectedDate.year &&
                entry.date.month == _selectedDate.month &&
                entry.date.day == _selectedDate.day &&
                entry.mealType == _selectedMealType,
            orElse: () => AttendanceEntry(date: _selectedDate, mealType: _selectedMealType, status: AttendanceStatus.absent)
        );
        _attendanceStatusMap[student.id] = existingEntry.status;
      }
      _filterAndSortDisplayedStudents();
    } catch (e) {
      if (!mounted) return;
      // print("Error loading students for attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading students: $e"), backgroundColor: Colors.red,));
    }
    setStateIfMounted(() { 
      _isLoading = false; 
      _hasUnsavedChanges = false;
    });
  }

  void _filterAndSortDisplayedStudents() {
    List<Student> tempStudents = List.from(_allActiveStudentsForDate);

    if (_searchTerm.isNotEmpty) {
      String lowerSearchTerm = _searchTerm.toLowerCase();
      tempStudents = tempStudents.where((student) {
        return student.name.toLowerCase().contains(lowerSearchTerm) ||
            student.id.contains(lowerSearchTerm);
      }).toList();
    }

    if (_sortAbsenteesTop) {
      tempStudents.sort((a, b) {
        bool isAAbsent = _attendanceStatusMap[a.id] == AttendanceStatus.absent;
        bool isBAbsent = _attendanceStatusMap[b.id] == AttendanceStatus.absent;
        if (isAAbsent && !isBAbsent) return -1;
        if (!isAAbsent && isBAbsent) return 1;
        return a.name.compareTo(b.name);
      });
    } else {
      tempStudents.sort((a, b) => a.name.compareTo(b.name));
    }

    _displayedStudents = tempStudents;
    _calculateAbsentCount();

    setStateIfMounted((){});
  }

  void _calculateAbsentCount() {
    _absentCount = _displayedStudents.where((student) => _attendanceStatusMap[student.id] == AttendanceStatus.absent).length;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: _selectedDate,
        firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 7)));
    if (picked != null && picked != _selectedDate) {
      setStateIfMounted(() {
        _selectedDate = picked;
        // After picking a new date, check if it's today and update meal type accordingly
        _updateMealTypeBasedOnTime();
      });
      _loadActiveStudentsAndInitializeAttendance();
    }
  }

  void _saveAttendance() async {
    // Guest can mark attendance, but saving might be an owner-only action.
    // For now, let's assume guests can also save. If not, add a role check:
    // if (widget.userRole == UserRole.guest) {
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guests cannot save attendance changes.')));
    //   return;
    // }

    if (_allActiveStudentsForDate.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active students to save attendance for.')));
      return;
    }
    setStateIfMounted(() { _isLoading = true; });

    WriteBatch batch = FirebaseFirestore.instance.batch();

    for (var student in _allActiveStudentsForDate) {
      final status = _attendanceStatusMap[student.id];
      if (status == null) continue;

      List<AttendanceEntry> updatedLog = List.from(student.attendanceLog);
      updatedLog.removeWhere((entry) =>
      entry.date.year == _selectedDate.year &&
          entry.date.month == _selectedDate.month &&
          entry.date.day == _selectedDate.day &&
          entry.mealType == _selectedMealType);
      updatedLog.add(AttendanceEntry(
          date: _selectedDate, mealType: _selectedMealType, status: status));

      DocumentReference studentRef = FirebaseFirestore.instance.collection('students').doc(student.id);
      batch.update(studentRef, {'attendanceLog': updatedLog.map((e) => e.toMap()).toList()});
    }

    try {
      await batch.commit();
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (context.mounted) Navigator.of(context).pop(true);
          });
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.green, size: 40),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Saved!",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red));
    } finally {
      setStateIfMounted(() { 
        _isLoading = false; 
        _hasUnsavedChanges = false;
      });
      // Optionally re-fetch to confirm, or trust local state if UI updates correctly
      // _loadActiveStudentsAndInitializeAttendance();
    }
  }

  Widget _buildSearchField() {
    return TextField(
      key: const ValueKey('searchField'),
      controller: _searchController,
      focusNode: _searchFocusNode,
      autofocus: true,
      decoration: InputDecoration(
        hintText: 'Search Name or ID...',
        border: InputBorder.none,
        hintStyle: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor?.withAlpha(179)),
      ),
      style: TextStyle(color: Theme.of(context).appBarTheme.foregroundColor, fontSize: 16.0),
    );
  }

  Widget _buildAttendanceButton({
    required String label,
    required bool isSelected,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          border: Border.all(color: color, width: 1.5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // final bool isOwner = widget.userRole == UserRole.owner; // Not used yet, but good to have

    return Scaffold(
      appBar: CommonAppBar(
        title: '', // Ignored because titleWidget is provided
        titleWidget: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            );
          },
          child: _hasUnsavedChanges
              ? ElevatedButton.icon(
                  key: const ValueKey('saveButton'),
                  onPressed: _saveAttendance,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Save Attendance"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Theme.of(context).primaryColor,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                )
              : Text(
                  'Mark Attendance',
                  key: const ValueKey('titleText'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
        centerTitle: false,
        actions: <Widget>[
          // Date Selector
          TextButton.icon(
            onPressed: () => _selectDate(context),
            icon: const Icon(Icons.calendar_today, color: Colors.white, size: 16),
            label: Text(
              DateFormat('MMM d').format(_selectedDate),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: TextButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8)),
          ),
          // Meal Selector
          IconButton(
            icon: Icon(
              _selectedMealType == MealType.morning ? Icons.wb_sunny : Icons.nightlight_round,
              color: Colors.white,
            ),
            tooltip: _selectedMealType == MealType.morning ? "Morning (Switch to Night)" : "Night (Switch to Morning)",
            onPressed: () {
              setStateIfMounted(() {
                _selectedMealType = _selectedMealType == MealType.morning ? MealType.night : MealType.morning;
                _loadActiveStudentsAndInitializeAttendance();
              });
            },
          ),
          // Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setStateIfMounted(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchFocusNode.unfocus();
                  _searchController.clear();
                  // Listener will handle clearing _searchTerm and re-filtering
                }
              });
            },
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search Name or ID...',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      suffixIcon: TextButton(
                        onPressed: () {
                          _searchController.clear();
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text("Clear", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ),
              )
            : null,
      ),
      floatingActionButton: null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: <Widget>[
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Switch(
                        value: _sortAbsenteesTop,
                        onChanged: (value) {
                          setStateIfMounted(() {
                            _sortAbsenteesTop = value;
                            _filterAndSortDisplayedStudents();
                          });
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                      const Text("Show Absentees First"),
                    ],
                  ),
                  Text("Absent: $_absentCount / ${_displayedStudents.length}", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              )
          ),
          Expanded(
              child: _displayedStudents.isEmpty
                  ? Center(child: Text(_searchTerm.isNotEmpty ? 'No students found matching "$_searchTerm".' : 'No active students for the selected date.'))
                  : ListView.builder(
                  itemCount: _displayedStudents.length,
                  itemBuilder: (context, index) {
                    final student = _displayedStudents[index];
                    final currentStatus = _attendanceStatusMap[student.id] ?? AttendanceStatus.absent;
                    return Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                        color: Colors.white,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                                title: Text(student.name, style: Theme.of(context).textTheme.titleMedium),
                                subtitle: Text("ID: ${student.id}", style: Theme.of(context).textTheme.bodySmall),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                                  _buildAttendanceButton(
                                    label: 'Present',
                                    isSelected: currentStatus == AttendanceStatus.present,
                                    color: Colors.green,
                                    icon: Icons.check,
                                    onTap: () {
                                      if (currentStatus != AttendanceStatus.present) {
                                        setStateIfMounted(() {
                                          _attendanceStatusMap[student.id] = AttendanceStatus.present;
                                          _calculateAbsentCount();
                                          _hasUnsavedChanges = true;
                                          if (_sortAbsenteesTop) _filterAndSortDisplayedStudents();
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _buildAttendanceButton(
                                    label: 'Absent',
                                    isSelected: currentStatus == AttendanceStatus.absent,
                                    color: Theme.of(context).colorScheme.error,
                                    icon: Icons.close,
                                    onTap: () {
                                      if (currentStatus != AttendanceStatus.absent) {
                                        setStateIfMounted(() {
                                          _attendanceStatusMap[student.id] = AttendanceStatus.absent;
                                          _calculateAbsentCount();
                                          _hasUnsavedChanges = true;
                                          if (_sortAbsenteesTop) _filterAndSortDisplayedStudents();
                                        });
                                      }
                                    },
                                  ),
                                ]))));
                  })),
        ],
      ),
    );
  }
}