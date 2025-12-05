// lib/screens/students_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'student_detail_screen.dart';
import 'add_student_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../widgets/common_app_bar.dart';
import '../models/app_settings_model.dart';
import '../utils/payment_manager.dart';


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
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _filterOption = 'Active'; // Default filter

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _navigateToAddStudent() async {
    if (widget.userRole == UserRole.owner) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => AddStudentScreen(firestoreService: widget.firestoreService)),
      );

      print("DEBUG: StudentsScreen received result: $result");
      
      if (result != null && result is String) {
        print("DEBUG: Result is valid string, showing dialog");
        if (!mounted) return;
        _showShareDialog(result);
      } else {
        print("DEBUG: Result is null or not string");
      }
      
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _showShareDialog(String studentId) {
    // We need to fetch the student name or pass it back. 
    // For simplicity, we can just use the ID or fetch the student.
    // Since we just added them, fetching might be async. 
    // Let's just pass the name back from AddStudentScreen too? 
    // Or just show the link.
    
    // Better approach: Let's assume we can construct the link immediately.
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Student Added!"),
        content: Text("Would you like to share the portal link with them now?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("No"),
          ),
          ElevatedButton.icon(
            icon: FaIcon(FontAwesomeIcons.whatsapp, size: 16),
            label: Text("Share on WhatsApp"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              final String url = "https://kitchen-management-b6d85.web.app/?id=$studentId";
              final String text = "Hello, here is your personal portal link to check your mess details: $url";
              
              String phone = studentId.replaceAll(RegExp(r'[^0-9]'), '');
              if (phone.length == 10) {
                phone = "91$phone";
              }
              
              final Uri whatsappUri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(text)}");
              
              try {
                if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
                  throw 'Could not launch $whatsappUri';
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Could not open WhatsApp: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
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
    StudentArchiveStatusFilter archiveFilter = StudentArchiveStatusFilter.all;
    if (_filterOption == 'Active') {
      archiveFilter = StudentArchiveStatusFilter.active;
    } else if (_filterOption == 'Archived') {
      archiveFilter = StudentArchiveStatusFilter.archived;
    }

    return Scaffold(
      appBar: CommonAppBar(
        title: 'Students List',
        actions: [
          if (widget.userRole == UserRole.owner)
            IconButton(
              icon: Icon(Icons.person_add_alt_1),
              onPressed: _navigateToAddStudent,
              tooltip: 'Add Student',
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchTerm = "";
                }
              });
            },
          ),
          PopupMenuButton<String>(
            initialValue: _filterOption,
            onSelected: (value) {
              setState(() {
                _filterOption = value;
              });
            },
            itemBuilder: (BuildContext context) {
              return {'All', 'Active', 'Archived'}.map((String choice) {
                return PopupMenuItem<String>(
                  value: choice,
                  child: Text(choice),
                );
              }).toList();
            },
          ),
        ],
        bottom: _isSearching
            ? PreferredSize(
                preferredSize: Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      fillColor: Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      suffixIcon: TextButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchTerm = "";
                          });
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.grey),
                        child: const Text("Clear", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value;
                      });
                    },
                  ),
                ),
              )
            : null,
      ),
      body: Column(
        children: <Widget>[
          // Removed the old search TextField from here
          Expanded(
            child: StreamBuilder<AppSettings>(
              stream: widget.firestoreService.getAppSettingsStream(),
              builder: (context, appSettingsSnapshot) {
                if (appSettingsSnapshot.hasError) return Center(child: Text('Error: ${appSettingsSnapshot.error}'));
                if (appSettingsSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                final appSettings = appSettingsSnapshot.data ?? AppSettings(feeHistory: []);

                return StreamBuilder<List<Student>>(
                  // Fetching non-archived students by default
                  stream: widget.firestoreService.getStudentsStream(
                    nameSearchTerm: _searchTerm.isNotEmpty ? _searchTerm : null,
                    archiveStatusFilter: archiveFilter,
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

                        // Calculate payment status
                        bool isPaidForCurrentCycle = false;
                        if (displayPaidStatusIcon) {
                          List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
                              student, appSettings, DateTime.now());
                          
                          // Check if there are ANY pending dues for active periods
                          // We want to show "Due" if they owe money for the current or past active periods.
                          // If they have fully paid everything up to now, show "Paid".
                          
                          double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);
                          isPaidForCurrentCycle = totalRemaining <= 0;
                        }

                        // Determine if service has ended for display purposes, even if not archived
                        bool serviceHasEnded = student.effectiveMessEndDate.isBefore(DateTime.now());
                        String subtitleText = 'Contact: ${student.contactNumber}\n';
                        if (serviceHasEnded) {
                          subtitleText += 'Service Ended: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)}';
                        } else {
                          subtitleText += 'Ends: ${DateFormat.yMMMd().format(student.effectiveMessEndDate)} (Rem: ${student.daysRemaining} days)';
                        }


                        return Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          // Optionally, slightly dim students whose service has ended but are not yet archived
                          color: serviceHasEnded ? Colors.grey[100] : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: ListTile(
                              leading: displayPaidStatusIcon ? CircleAvatar(
                                backgroundColor: isPaidForCurrentCycle
                                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.error.withOpacity(0.2),
                                child: Icon(
                                    isPaidForCurrentCycle ? Icons.check : Icons.info_outline,
                                    color: isPaidForCurrentCycle
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error
                                ),
                              ) : Icon(Icons.person_pin_circle_outlined, color: Theme.of(context).colorScheme.primary),
                              title: Hero(
                                tag: 'student_name_${student.id}',
                                child: Material(
                                  type: MaterialType.transparency,
                                  child: Text(student.name, style: Theme.of(context).textTheme.titleMedium),
                                ),
                              ),
                              subtitle: Text(subtitleText, style: Theme.of(context).textTheme.bodySmall),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.userRole == UserRole.owner)
                                    IconButton(
                                      icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                      onPressed: () async {
                                        final String url = "https://kitchen-management-b6d85.web.app/?id=${student.id}";
                                        final String text = "Hello ${student.name}, here is your personal portal link to check your mess details: $url";
                                        // Clean the phone number
                                        String phone = student.id.replaceAll(RegExp(r'[^0-9]'), '');
                                        // Remove leading zeros
                                        if (phone.startsWith('0')) {
                                          phone = phone.substring(1);
                                        }
                                        // Add India country code if length is 10
                                        if (phone.length == 10) {
                                          phone = "91$phone";
                                        }
                                        
                                        final Uri whatsappUri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(text)}");
                                        
                                        try {
                                          if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
                                            throw 'Could not launch $whatsappUri';
                                          }
                                        } catch (e) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text("Could not open WhatsApp: $e")),
                                          );
                                        }
                                      },
                                    ),
                                  Icon(Icons.arrow_forward_ios, size: 16),
                                ],
                              ),
                              isThreeLine: true,
                              onTap: () => _navigateToStudentDetail(student),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}
