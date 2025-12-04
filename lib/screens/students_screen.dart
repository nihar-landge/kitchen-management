// lib/screens/students_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'student_detail_screen.dart';
import 'add_student_screen.dart';


class StudentsScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final UserRole userRole;

  StudentsScreen({
    required this.firestoreService,
    required this.userRole,
    Key? key,
  }) : super(key: key);

  @override
  _StudentsScreenState createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  String _searchTerm = '';

  void _navigateToAddStudent() {
    if (widget.userRole == UserRole.owner) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: widget.firestoreService)),
      ).then((_) {
        // Optional: refresh list or listen for changes if needed after adding
        setState(() {});
      });
    }
  }

  void _navigateToStudentDetail(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentDetailScreen(
          studentId: student.id,
          firestoreService: widget.firestoreService,
          userRole: widget.userRole,
        ),
      ),
    ).then((_) {
      // Optional: refresh list or listen for changes if needed after viewing details
      setState(() {});
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Students List')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Search Students by Name (starts with)...',
                hintText: 'Enter name...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) {
                setState(() { _searchTerm = value; });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Student>>(
              // Fetching non-archived students by default
              stream: widget.firestoreService.getStudentsStream(
                nameSearchTerm: _searchTerm.isNotEmpty ? _searchTerm : null,
                archiveStatusFilter: StudentArchiveStatusFilter.active,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final studentsToDisplay = snapshot.data ?? [];

                if (studentsToDisplay.isEmpty) {
                  return Center(
                      child: Text(_searchTerm.isNotEmpty
                          ? 'No students found matching "$_searchTerm".'
                          : 'No current students. Add a student or check the archived list in Settings.')
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.only(bottom: 100),
                  itemCount: studentsToDisplay.length,
                  itemBuilder: (context, index) {
                    final student = studentsToDisplay[index];
                    bool displayPaidStatusIcon = widget.userRole == UserRole.owner;

                    // Determine if service has ended for display purposes, even if not archived
                    bool serviceHasEnded = student.effectiveMessEndDate.isBefore(DateTime.now());
                    String subtitleText = 'Contact: ${student.contactNumber}\n';
                    if (serviceHasEnded) {
                      subtitleText += 'Service Ended: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}';
                    } else {
                      subtitleText += 'Ends: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)} (Rem: ${student.daysRemaining} days)';
                    }


                    return Card(
                      // Optionally, slightly dim students whose service has ended but are not yet archived
                      color: serviceHasEnded ? Colors.grey[100] : null,
                      child: ListTile(
                        leading: displayPaidStatusIcon ? CircleAvatar(
                          backgroundColor: student.currentCyclePaid
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                              : Theme.of(context).colorScheme.error.withOpacity(0.2),
                          child: Icon(
                              student.currentCyclePaid ? Icons.check : Icons.close,
                              color: student.currentCyclePaid
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.error
                          ),
                        ) : Icon(Icons.person_pin_circle_outlined, color: Theme.of(context).colorScheme.primary),
                        title: Hero(
                          tag: 'student_name_${student.id}',
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(student.name, style: TextStyle(fontWeight: FontWeight.w500)),
                          ),
                        ),
                        subtitle: Text(subtitleText),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        isThreeLine: true,
                        onTap: () => _navigateToStudentDetail(student),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.userRole == UserRole.owner
          ? Padding(
              padding: const EdgeInsets.only(bottom: 140.0),
              child: FloatingActionButton.extended(
                onPressed: _navigateToAddStudent,
                icon: Icon(Icons.add),
                label: Text('Add Student'),
              ),
            )
          : null,
    );
  }
}
