import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Import for Timer

import '../models/student_model.dart';
import '../models/user_model.dart'; // Import UserRole
import '../services/firestore_service.dart';

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
    setStateIfMounted(() { _isLoading = false; });
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attendance saved successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving attendance: $e'), backgroundColor: Colors.red));
    } finally {
      setStateIfMounted(() { _isLoading = false; });
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

  @override
  Widget build(BuildContext context) {
    // final bool isOwner = widget.userRole == UserRole.owner; // Not used yet, but good to have

    return Scaffold(
      appBar: AppBar(
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: _isSearching
              ? _buildSearchField()
              : const Text('Mark Attendance', key: ValueKey('titleText')),
        ),
        actions: <Widget>[
          IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(child: child, scale: animation);
              },
              child: _isSearching
                  ? const Icon(Icons.close, key: ValueKey('closeIcon'))
                  : const Icon(Icons.search, key: ValueKey('searchIcon')),
            ),
            onPressed: () {
              setStateIfMounted(() {
                _isSearching = !_isSearching;
                if (_isSearching) {
                  _searchFocusNode.requestFocus();
                } else {
                  _searchFocusNode.unfocus();
                  _searchController.clear();
                }
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Card(
                elevation: 2,
                child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                        Text('Date: ${DateFormat.yMMMd().format(_selectedDate)}', style: Theme.of(context).textTheme.titleMedium),
                        TextButton.icon(icon: const Icon(Icons.calendar_month_outlined), label: const Text('Change Date'), onPressed: () => _selectDate(context))
                      ]),
                      const SizedBox(height: 10),
                      SegmentedButton<MealType>(
                          segments: const <ButtonSegment<MealType>>[
                            ButtonSegment<MealType>(value: MealType.morning, label: Text('Morning'), icon: Icon(Icons.wb_sunny_outlined)),
                            ButtonSegment<MealType>(value: MealType.night, label: Text('Night'), icon: Icon(Icons.nightlight_round_outlined)),
                          ],
                          selected: <MealType>{_selectedMealType},
                          onSelectionChanged: (Set<MealType> newSelection) {
                            setStateIfMounted(() { _selectedMealType = newSelection.first; });
                            _loadActiveStudentsAndInitializeAttendance();
                          },
                          style: SegmentedButton.styleFrom(
                            selectedForegroundColor: Theme.of(context).colorScheme.onPrimary,
                            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
                          )
                      ),
                    ]))
            ),
          ),
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
                  Text("Absent: $_absentCount / ${_displayedStudents.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                                title: Text(student.name),
                                subtitle: Text("ID: ${student.id}"),
                                trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                                  ChoiceChip(
                                    label: const Text('Present'),
                                    selected: currentStatus == AttendanceStatus.present,
                                    selectedColor: Colors.green.shade100,
                                    labelStyle: TextStyle(color: currentStatus == AttendanceStatus.present ? Colors.green.shade800 : Theme.of(context).textTheme.bodySmall?.color),
                                    onSelected: (sel) {
                                      if (sel) setStateIfMounted(() {
                                        _attendanceStatusMap[student.id] = AttendanceStatus.present;
                                        _calculateAbsentCount();
                                        if(_sortAbsenteesTop) _filterAndSortDisplayedStudents();
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Absent'),
                                    selected: currentStatus == AttendanceStatus.absent,
                                    selectedColor: Colors.red.shade100,
                                    labelStyle: TextStyle(color: currentStatus == AttendanceStatus.absent ? Colors.red.shade800 : Theme.of(context).textTheme.bodySmall?.color),
                                    onSelected: (sel) {
                                      if (sel) setStateIfMounted(() {
                                        _attendanceStatusMap[student.id] = AttendanceStatus.absent;
                                        _calculateAbsentCount();
                                        if(_sortAbsenteesTop) _filterAndSortDisplayedStudents();
                                      });
                                    },
                                  ),
                                ]))));
                  })),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 140.0),
            child: ElevatedButton.icon(
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Save All Attendance'),
                onPressed: _allActiveStudentsForDate.isNotEmpty ? _saveAttendance : null,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onPrimary)
                )
            ),
          ),
        ],
      ),
    );
  }
}