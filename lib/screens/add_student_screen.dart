// lib/screens/add_student_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';
import '../services/firestore_service.dart';

class AddStudentScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  const AddStudentScreen({super.key, required this.firestoreService});

  @override
  AddStudentScreenState createState() => AddStudentScreenState();
}

class AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _studentName = '';
  String _contactNumber = '';
  DateTime _messStartDate = DateTime.now();
  bool _initialPaymentPaid = false;
  final _initialAmountController = TextEditingController();

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context, initialDate: _messStartDate,
        firstDate: DateTime(2020), lastDate: DateTime(2101));
    if (picked != null && picked != _messStartDate) {
      setState(() { _messStartDate = picked; });
    }
  }

  void _saveStudent() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      bool studentAlreadyExists = await widget.firestoreService.studentExists(_contactNumber);
      if (studentAlreadyExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: A student with this contact number already exists.'),
            backgroundColor: Colors.red));
        return;
      }

      final firstPeriodEndDate = _messStartDate.add(Duration(days: 29));

      List<PaymentHistoryEntry> initialPaymentHistory = [];
      if (_initialPaymentPaid) {
        double initialAmount = double.tryParse(_initialAmountController.text) ?? 0.0;
        if (initialAmount <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('If initial payment is paid, please enter a valid amount.'),
              backgroundColor: Colors.red));
          return;
        }

        initialPaymentHistory.add(PaymentHistoryEntry(
            paymentDate: DateTime.now(),
            cycleStartDate: _messStartDate,
            cycleEndDate: firstPeriodEndDate,
            paid: true,
            amountPaid: initialAmount
        ));
      }

      final firstServicePeriod = {
        'startDate': Timestamp.fromDate(_messStartDate),
        'endDate': Timestamp.fromDate(firstPeriodEndDate),
      };

      final newStudent = Student(
        id: _contactNumber,
        name: _studentName,
        messStartDate: _messStartDate,
        originalServiceStartDate: _messStartDate,
        paymentHistory: initialPaymentHistory,
        attendanceLog: [],
        serviceHistory: [firstServicePeriod],
      );

      try {
        await widget.firestoreService.addStudent(newStudent);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error saving student: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  void dispose() {
    _initialAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add New Student')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: <Widget>[
              TextFormField(
                  decoration: InputDecoration(labelText: 'Student Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => (v == null || v.isEmpty) ? 'Please enter student name' : null,
                  onSaved: (v) => _studentName = v!),
              SizedBox(height: 16),
              TextFormField(
                  decoration: InputDecoration(labelText: 'Contact Number (Unique ID)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone_outlined)),
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter contact number';
                    if (v.length < 10) return 'Contact number must be at least 10 digits';
                    return null;
                  },
                  onSaved: (v) => _contactNumber = v!),
              SizedBox(height: 16),
              Row(children: <Widget>[
                Expanded(child: Text('Mess Start Date: ${DateFormat.yMMMd().format(_messStartDate)}')),
                TextButton.icon(icon: Icon(Icons.calendar_today), label: Text('Select Date'), onPressed: () => _selectStartDate(context))
              ]),
              SizedBox(height: 16),
              SwitchListTile(
                  title: Text('Initial Payment Paid for First Service Period?'), value: _initialPaymentPaid,
                  onChanged: (v) => setState(() => _initialPaymentPaid = v),
                  secondary: Icon(_initialPaymentPaid ? Icons.attach_money : Icons.money_off), activeColor: Colors.teal),
              if (_initialPaymentPaid)
                Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: TextFormField(
                        controller: _initialAmountController,
                        decoration: InputDecoration(labelText: 'Initial Amount Paid', border: OutlineInputBorder(), prefixIcon: Icon(Icons.currency_rupee)),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (v) {
                          if (_initialPaymentPaid) {
                            if (v == null || v.isEmpty) return 'Please enter amount paid';
                            if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Please enter a valid positive amount';
                          }
                          return null;
                        })),
              SizedBox(height: 30),
              ElevatedButton.icon(
                  icon: Icon(Icons.save_alt_outlined), label: Text('Save Student'), onPressed: _saveStudent,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 12), textStyle: TextStyle(fontSize: 16))),
              SizedBox(height: 10),
              TextButton(child: Text('Cancel'), onPressed: () => Navigator.pop(context, false)),
            ],
          ),
        ),
      ),
    );
  }
}