import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/student_model.dart';
import '../models/app_settings_model.dart';
import '../services/firestore_service.dart';
import '../services/firestore_service.dart';
import '../utils/payment_manager.dart';
import '../widgets/common_app_bar.dart';

class StudentPortalScreen extends StatefulWidget {
  final String studentId;
  final FirestoreService firestoreService;

  const StudentPortalScreen({
    Key? key,
    required this.studentId,
    required this.firestoreService,
  }) : super(key: key);

  @override
  State<StudentPortalScreen> createState() => _StudentPortalScreenState();
}

class _StudentPortalScreenState extends State<StudentPortalScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: CommonAppBar(
        title: 'Student Portal',
        centerTitle: true,
        leading: SizedBox(), // No back button
      ),
      body: StreamBuilder<Student?>(
        stream: widget.firestoreService.getStudentStream(widget.studentId),
        builder: (context, studentSnapshot) {
          if (studentSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (studentSnapshot.hasError) {
            return Center(child: Text('Error: ${studentSnapshot.error}'));
          }

          final student = studentSnapshot.data;

          if (student == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'Student not found.\nPlease check the link or contact the mess owner.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return StreamBuilder<AppSettings>(
            stream: widget.firestoreService.getAppSettingsStream(),
            builder: (context, settingsSnapshot) {
              if (settingsSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: SizedBox());
              }

              final appSettings = settingsSnapshot.data ?? AppSettings(feeHistory: []);

              // Calculate Dues
              List<MonthlyDueItem> duesList = PaymentManager.calculateBillingPeriodsWithPaymentAllocation(
                  student, appSettings, DateTime.now());
              double totalRemaining = duesList.fold(0.0, (sum, item) => sum + item.remainingForPeriod);

              // Calculate Days Remaining
              int daysLeft = student.daysRemaining;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 40,
                              backgroundColor: Color(0xFFE8F5E9),
                              child: Icon(Icons.person, size: 40, color: Color(0xFF2E7D32)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2F2F2F),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              student.contactNumber,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Status Cards Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'Days Left',
                            value: '$daysLeft',
                            subtitle: 'Days',
                            color: daysLeft < 5 ? Colors.red : const Color(0xFF2E7D32),
                            icon: Icons.timer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStatusCard(
                            context,
                            title: 'Dues Pending',
                            value: '₹${totalRemaining.toStringAsFixed(0)}',
                            subtitle: 'Total',
                            color: totalRemaining > 0 ? Colors.orange[800]! : Colors.grey,
                            icon: Icons.currency_rupee,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Service Info
                    const Text(
                      "Current Subscription",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F2F2F)),
                    ),
                    // Recent Attendance (Calendar View)
                    const Text(
                      "Attendance Calendar",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2F2F2F)),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: TableCalendar(
                          firstDay: student.messStartDate.subtract(const Duration(days: 365)),
                          lastDay: student.effectiveMessEndDate.add(const Duration(days: 365)),
                          focusedDay: _focusedDay,
                          calendarFormat: _calendarFormat,
                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                          onDaySelected: (selectedDay, focusedDay) {
                            if (!isSameDay(_selectedDay, selectedDay)) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            }
                          },
                          onFormatChanged: (format) {
                            if (_calendarFormat != format) {
                              setState(() {
                                _calendarFormat = format;
                              });
                            }
                          },
                          onPageChanged: (focusedDay) {
                            _focusedDay = focusedDay;
                          },
                          calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            defaultTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Color(0xFF2F2F2F)),
                            weekendTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Colors.red),
                            holidayTextStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Colors.blue[700]),
                            todayTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Colors.black87, fontWeight: FontWeight.bold),
                            todayDecoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            selectedTextStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 14.5, color: Colors.white, fontWeight: FontWeight.bold),
                            selectedDecoration: const BoxDecoration(
                                color: Color(0xFF38761D), // skBasilGreen
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0,1))
                                ]
                            ),
                            cellMargin: const EdgeInsets.all(5.0),
                            cellAlignment: Alignment.center,
                            markersAlignment: Alignment.bottomCenter,
                            markerDecoration: const BoxDecoration(
                                color: Colors.transparent, // Handled by builder
                                shape: BoxShape.circle
                            ),
                            markerSize: 5.0,
                            markersMaxCount: 1,
                            markerMargin: const EdgeInsets.only(top: 0.5),
                          ),
                          calendarBuilders: CalendarBuilders(
                            markerBuilder: (context, date, events) {
                              final attendanceForDay = student.attendanceLog.where((entry) => isSameDay(entry.date, date)).toList();
                              if (attendanceForDay.isEmpty) return null;

                              // Show the latest entry for the day if multiple exist (though usually 1 per day logic requested)
                              // Or show a stack if needed. For now, showing the last one to match "mark 1 time" logic visually or just the primary one.
                              // Actually, the user said "attendance will mark 1 time", so we take the first/only one.
                              final entry = attendanceForDay.last; 

                              return Positioned(
                                right: 3,
                                bottom: 3,
                                child: Container(
                                  decoration: BoxDecoration(
                                      color: entry.status == AttendanceStatus.present 
                                          ? const Color(0xFF38761D).withOpacity(0.85) // skBasilGreen
                                          : Colors.red.withOpacity(0.8),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withOpacity(0.2),
                                            blurRadius: 2,
                                            offset: const Offset(0,1)
                                        )
                                      ]
                                  ),
                                  padding: const EdgeInsets.all(3.0),
                                  child: Icon(
                                    entry.status == AttendanceStatus.present ? Icons.check : Icons.close,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                          headerStyle: HeaderStyle(
                            formatButtonVisible: false,
                            titleCentered: true,
                            titleTextStyle: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF38761D)),
                            leftChevronIcon: const Icon(Icons.chevron_left, color: Color(0xFF38761D)),
                            rightChevronIcon: const Icon(Icons.chevron_right, color: Color(0xFF38761D)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2F2F2F))),
            ],
          ),
        ),
      ],
    );
  }
}
