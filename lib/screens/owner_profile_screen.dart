// lib/screens/owner_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../models/app_settings_model.dart';

class OwnerProfileScreen extends StatefulWidget {
  final FirestoreService firestoreService;
  final bool showPasswordSection;

  OwnerProfileScreen({required this.firestoreService, this.showPasswordSection = false});

  @override
  _OwnerProfileScreenState createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _feeController = TextEditingController();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  double _currentStandardFee = 0.0;
  DateTime _effectiveDate = DateTime.now();
  String? _passwordChangeError;
  bool _isPasswordChanging = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month + 1, 1);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.showPasswordSection) {
        _scrollToPasswordSection();
      }
    });
  }

  @override
  void dispose() {
    _feeController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  final _passwordSectionKey = GlobalKey();

  void _scrollToPasswordSection() {
    Scrollable.ensureVisible(
      _passwordSectionKey.currentContext!,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _selectEffectiveDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: _effectiveDate,
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (picked != null && picked != _effectiveDate) {
      setState(() {
        _effectiveDate = picked;
      });
    }
  }

  void _saveNewFee() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final newFee = double.tryParse(_feeController.text);
      if (newFee != null && newFee > 0) {
        try {
          await widget.firestoreService.addNewFee(newFee, _effectiveDate);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('New fee scheduled successfully!')),
          );
          _feeController.clear();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error scheduling fee: $e'), backgroundColor: Colors.red),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please enter a valid fee amount.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _changePassword() async {
    if (_passwordFormKey.currentState!.validate()) {
      setState(() {
        _isPasswordChanging = true;
        _passwordChangeError = null;
      });

      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _passwordChangeError = 'User not logged in.';
          return;
        }

        AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!,
          password: _currentPasswordController.text,
        );

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(_newPasswordController.text);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Password changed successfully!')),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmNewPasswordController.clear();
      } on FirebaseAuthException catch (e) {
        String message;
        if (e.code == 'wrong-password') {
          message = 'Incorrect current password.';
        } else if (e.code == 'requires-recent-login') {
          message = 'Please log out and log in again to change your password.';
        } else {
          message = 'An error occurred: ${e.message}';
        }
        setState(() {
          _passwordChangeError = message;
        });
      } catch (e) {
        setState(() {
          _passwordChangeError = 'An unexpected error occurred.';
        });
      } finally {
        setState(() {
          _isPasswordChanging = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.showPasswordSection ? 'Change Password' : 'Owner Profile & Fee Settings')),
      body: StreamBuilder<AppSettings>(
        stream: widget.firestoreService.getAppSettingsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading settings: ${snapshot.error}'));
          }

          _currentStandardFee = snapshot.data?.currentStandardFee ?? 2000.0;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: <Widget>[
                if (!widget.showPasswordSection) ...[
                  Text('Manage Fee Rules', style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: 20),
                  ListTile(
                    title: Text("Current Standard Fee", style: TextStyle(fontSize: 16)),
                    trailing: Text(
                      '₹${_currentStandardFee.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Divider(height: 30),
                  Form(
                    key: _formKey,
                    child: Column(children: [
                      TextFormField(
                        controller: _feeController,
                        decoration: InputDecoration(
                          labelText: 'New Fee Amount',
                          border: OutlineInputBorder(),
                          prefixText: '₹',
                        ),
                        keyboardType: TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter a fee amount.';
                          final fee = double.tryParse(value);
                          if (fee == null || fee <= 0) return 'Please enter a valid positive amount.';
                          if (fee == _currentStandardFee) return 'New fee must be different from the current fee.';
                          return null;
                        },
                      ),
                      SizedBox(height: 20),
                      Row(children: <Widget>[
                        Expanded(child: Text('Effective From: ${DateFormat.yMMMd().format(_effectiveDate)}')),
                        TextButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text('Change Date'),
                            onPressed: () => _selectEffectiveDate(context))
                      ]),
                      SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: Icon(Icons.save),
                        label: Text('Schedule New Fee'),
                        onPressed: _saveNewFee,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ]),
                  ),
                ],
                if (widget.showPasswordSection) ...[
                  SizedBox(height: 30),
                  Divider(height: 30),
                  Text('Change Password', style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: 20),
                  Form(
                    key: _passwordFormKey,
                    child: Column(
                      key: _passwordSectionKey,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                          validator: (v) => (v == null || v.isEmpty) ? 'Please enter your current password.' : null,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter a new password.';
                            if (v.length < 6) return 'Password must be at least 6 characters.';
                            return null;
                          },
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmNewPasswordController,
                          obscureText: true,
                          decoration: InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                          validator: (v) {
                            if (v != _newPasswordController.text) return 'Passwords do not match.';
                            return null;
                          },
                        ),
                        SizedBox(height: 20),
                        if (_passwordChangeError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: Text(_passwordChangeError!, style: TextStyle(color: Colors.red)),
                          ),
                        _isPasswordChanging
                            ? Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                          icon: Icon(Icons.vpn_key),
                          label: Text('Change Password'),
                          onPressed: _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}