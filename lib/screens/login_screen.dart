// lib/screens/login_screen.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/biometric_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


import '../models/user_model.dart';
import 'main_screen.dart';

const Color skBasilGreen = Color(0xFF38761D);
const Color skDeepGreen = Color(0xFF2D9A4B);
const Color skBackgroundLight = Color(0xFFF7F7F7);


class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passcodeController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final BiometricService _biometricService = BiometricService();
  bool _canCheckBiometrics = false;

  final String _ownerEmail = "admin@your-app.com";
  final String _guestEmail = "guest@your-app.com";

  UserRole _selectedRole = UserRole.guest;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  void _checkBiometrics() async {
    if (kIsWeb) return;
    bool canAuth = await _biometricService.canAuthenticate();
    if (mounted) {
      setState(() {
        _canCheckBiometrics = canAuth;
      });
    }
  }


  void _loginWithBiometrics() async {
    if (kIsWeb) return;
    // First, check if biometrics are available and authenticated
    if (await _biometricService.authenticate()) {
      // Read the stored credentials from the device's secure storage
      final String? storedEmail = await _storage.read(key: 'userEmail');
      final String? storedPassword = await _storage.read(key: 'userPassword');

      // If both are available, attempt to sign in to Firebase with them
      if (storedEmail != null && storedPassword != null) {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: storedEmail,
            password: storedPassword,
          );
          // If login is successful, navigate to the main screen
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(userRole: _selectedRole),
            ),
          );
        } catch (e) {
          // Handle any login errors
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to log in with stored credentials. Please use password.')),
            );
          }
        }
      } else {
        // If no credentials were found, prompt the user to use the password login first
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in with your password first to enable this feature.')),
          );
        }
      }
    }
  }


  void _login() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      String enteredPassword = _passcodeController.text;
      String emailToUse;

      if (_selectedRole == UserRole.owner) {
        emailToUse = _ownerEmail;
      } else {
        emailToUse = _guestEmail;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailToUse,
          password: enteredPassword,
        );

        if (userCredential.user != null) {
          await _storage.write(key: 'userEmail', value: emailToUse);
          await _storage.write(key: 'userPassword', value: enteredPassword);
          UserRole appRole = _selectedRole;
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainScreen(userRole: appRole),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        String friendlyErrorMessage = "An error occurred. Please try again.";
        if (e.code == 'user-not-found' || e.code == 'invalid-credential' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
          friendlyErrorMessage = "Incorrect email or password for the selected role.";
        } else if (e.code == 'wrong-password') {
          friendlyErrorMessage = "Incorrect password for the selected role.";
        } else if (e.code == 'invalid-email') {
          friendlyErrorMessage = "The email address for this role ($emailToUse) is not valid.";
        } else if (e.code == 'network-request-failed') {
          friendlyErrorMessage = "Network error. Please check your connection.";
        } else {
          friendlyErrorMessage = "Login failed. Please check your credentials and try again.";
          print('Firebase Auth Error: ${e.code} - ${e.message}');
        }
        if (mounted) {
          setState(() {
            _errorMessage = friendlyErrorMessage;
          });
        }
      } catch (e) {
        print('Generic Error during login: $e');
        if (mounted) {
          setState(() {
            _errorMessage = "An unexpected error occurred during login.";
          });
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _passcodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          CustomPaint(
            painter: _LoginBackgroundPainter(
              primaryColor: skBasilGreen,
              lightGreen: skDeepGreen.withOpacity(0.4),
              lighterGreen: skBasilGreen.withOpacity(0.2),
              baseBackgroundColor: skBackgroundLight,
            ),
            child: Container(),
            size: Size.infinite,
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    margin: EdgeInsets.only(bottom: 25.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(120.0),
                      child: Image.asset(
                        'assets/images/student_kitchen.png',
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(Icons.food_bank_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.7));
                        },
                      ),
                    ),
                  ),
                  Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.0)),
                    color: theme.cardColor.withOpacity(0.95),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Text(
                              "Welcome to Student's Kitchen",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              "Mess Management",
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                            SizedBox(height: 30),
                            DropdownButtonFormField<UserRole>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                  labelText: 'Select Role',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  prefixIcon: Icon(
                                    _selectedRole == UserRole.owner ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                                    color: theme.colorScheme.primary,
                                  ),
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.8)
                              ),
                              items: UserRole.values.map((UserRole role) {
                                return DropdownMenuItem<UserRole>(
                                  value: role,
                                  child: Text(
                                    role == UserRole.owner ? 'Owner (Admin)' : 'Guest' ,
                                    style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                                  ),
                                );
                              }).toList(),
                              onChanged: (UserRole? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedRole = newValue;
                                    _errorMessage = null;
                                    _passcodeController.clear();
                                  });
                                }
                              },
                              style: theme.textTheme.bodyLarge,
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _passcodeController,
                              decoration: InputDecoration(
                                  labelText: 'Enter Password',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                                  hintText: 'Password',
                                  filled: true,
                                  fillColor: theme.scaffoldBackgroundColor.withOpacity(0.8)
                              ),
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a password.';
                                }
                                return null;
                              },
                              style: theme.textTheme.bodyLarge,
                            ),
                            SizedBox(height: 15),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14, fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            SizedBox(height: 25),
                            _isLoading
                                ? Center(child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            ))
                                : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: EdgeInsets.symmetric(vertical: 16),
                                textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                elevation: 3,
                              ),
                              onPressed: _login,
                              child: Text('Login'),
                            ),
                            if (_canCheckBiometrics) ...[
                              const SizedBox(height: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.fingerprint),
                                label: const Text('Login with Fingerprint'),
                                onPressed: _loginWithBiometrics,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  elevation: 3,
                                ),
                              ),
                            ],

                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  final Color primaryColor;
  final Color lightGreen;
  final Color lighterGreen;
  final Color baseBackgroundColor;

  _LoginBackgroundPainter({
    required this.primaryColor,
    required this.lightGreen,
    required this.lighterGreen,
    required this.baseBackgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint..color = baseBackgroundColor);

    final random = math.Random(123);

    paint.color = lighterGreen.withOpacity(0.3 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + random.nextDouble() * 15);
    var path1 = Path();
    path1.moveTo(size.width * -0.1, size.height * 0.1);
    path1.quadraticBezierTo(size.width * 0.2, size.height * 0.5, size.width * 0.6, size.height * 0.3);
    path1.quadraticBezierTo(size.width * 1.1, size.height * 0.6, size.width * 0.7, size.height * 1.1);
    path1.quadraticBezierTo(size.width * 0.3, size.height * 1.2, size.width * -0.1, size.height * 0.8);
    path1.close();
    canvas.drawPath(path1, paint);

    paint.color = lightGreen.withOpacity(0.4 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 25 + random.nextDouble() * 10);
    var path2 = Path();
    path2.moveTo(size.width * 0.5, size.height * -0.2);
    path2.quadraticBezierTo(size.width * 0.8, size.height * 0.2, size.width * 1.2, size.height * 0.4);
    path2.quadraticBezierTo(size.width * 0.9, size.height * 0.8, size.width * 0.4, size.height * 1.2);
    path2.quadraticBezierTo(size.width * 0.1, size.height * 0.7, size.width * 0.5, size.height * -0.2);
    path2.close();
    canvas.drawPath(path2, paint);

    paint.color = primaryColor.withOpacity(0.25 + random.nextDouble() * 0.15);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 15 + random.nextDouble() * 10);
    canvas.drawCircle(Offset(size.width * (0.7 + random.nextDouble() * 0.2), size.height * (0.2 + random.nextDouble() * 0.2)), size.width * (0.3 + random.nextDouble() * 0.15), paint);

    paint.color = lightGreen.withOpacity(0.35 + random.nextDouble() * 0.2);
    paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 30 + random.nextDouble() * 10);
    canvas.drawOval(Rect.fromCenter(center: Offset(size.width * (0.15 + random.nextDouble() * 0.2), size.height * (0.7 + random.nextDouble() * 0.2)), width: size.width * (0.5 + random.nextDouble() * 0.2), height: size.height * (0.4 + random.nextDouble() * 0.2)), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
