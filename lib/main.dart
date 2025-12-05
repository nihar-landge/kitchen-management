// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'services/connectivity_service.dart';
import 'widgets/connectivity_banner.dart';
import 'screens/student_portal_screen.dart';
import 'services/firestore_service.dart';

const Color skBasilGreen = Color(0xFF38761D);
const Color skDeepGreen = Color(0xFF2D9A4B);

const Color skAmberYellow = Color(0xFFFFC107);
const Color skTomatoRed = Color(0xFFFF6347);
const Color skTerracotta = Color(0xFFE2725B);

const Color skBackgroundLight = Color(0xFFF7F7F7);
const Color skBackgroundWhite = Color(0xFFFFFFFF);
const Color skDarkText = Color(0xFF2F2F2F);
const Color skLightText = Color(0xFF6C6C6C);
const Color skPureBlack = Color(0xFF000000);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MessManagementApp());
}

class MessManagementApp extends StatelessWidget {
  const MessManagementApp({super.key});
  @override
  Widget build(BuildContext context) {


    final Color appPrimaryColor = skBasilGreen;
    final Color appSecondaryColor = skAmberYellow;
    final Color appErrorColor = skTomatoRed;

    return ChangeNotifierProvider(
      create: (context) => ConnectivityService(),
      child: MaterialApp(
        title: 'Student\'s Kitchen Mess',
        theme: ThemeData(
          primaryColor: appPrimaryColor,
          scaffoldBackgroundColor: skBackgroundLight,
          colorScheme: ColorScheme(
            primary: appPrimaryColor,
            onPrimary: skBackgroundWhite,
            secondary: appSecondaryColor,
            onSecondary: skDarkText,
            surface: skBackgroundWhite,
            onSurface: skDarkText,
            error: appErrorColor,
            onError: skBackgroundWhite,
            brightness: Brightness.light,
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: appPrimaryColor,
            foregroundColor: skBackgroundWhite,
            elevation: 1.0,
            titleTextStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              color: skBackgroundWhite,
            ),
            iconTheme: IconThemeData(color: skBackgroundWhite),
          ),
          textTheme: TextTheme(
            displayLarge: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold, color: skDarkText),
            displayMedium: GoogleFonts.outfit(fontSize: 40, fontWeight: FontWeight.bold, color: skDarkText),
            displaySmall: GoogleFonts.outfit(fontSize: 34, fontWeight: FontWeight.bold, color: skDarkText),
            headlineLarge: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: skDarkText),
            headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: skDarkText),
            headlineSmall: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w600, color: skDarkText),
            titleLarge: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w600, color: skDarkText),
            titleMedium: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.15),
            titleSmall: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.1),
            bodyLarge: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.5),
            bodyMedium: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w400, color: skDarkText, letterSpacing: 0.25),
            bodySmall: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w400, color: skLightText, letterSpacing: 0.4),
            labelLarge: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.bold, color: skBackgroundWhite, letterSpacing: 1.25),
            labelMedium: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: skDarkText, letterSpacing: 0.5),
            labelSmall: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w500, color: skLightText, letterSpacing: 0.5),
          ).apply(
            bodyColor: skDarkText,
            displayColor: skDarkText,
          ),
          cardTheme: CardThemeData(
            elevation: 2.0,
            color: skBackgroundWhite,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: appPrimaryColor,
              foregroundColor: skBackgroundWhite,
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 15),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: appPrimaryColor,
              textStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: appSecondaryColor,
            foregroundColor: skDarkText,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: skBackgroundWhite.withAlpha((255 * 0.8).round()),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appPrimaryColor.withAlpha(128)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: appPrimaryColor, width: 2),
            ),
            labelStyle: TextStyle(fontFamily: 'Poppins', color: appPrimaryColor),
            hintStyle: TextStyle(fontFamily: 'Poppins', color: skLightText),
            prefixIconColor: appPrimaryColor.withAlpha((255 * 0.7).round()),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: appPrimaryColor.withAlpha((255 * 0.1).round()),
            labelStyle: TextStyle(fontFamily: 'Poppins', color: appPrimaryColor, fontWeight: FontWeight.w500),
            selectedColor: appPrimaryColor,
            secondarySelectedColor: appPrimaryColor,
            secondaryLabelStyle: TextStyle(fontFamily: 'Poppins', color: skBackgroundWhite, fontWeight: FontWeight.w500),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            iconTheme: IconThemeData(color: appPrimaryColor, size: 18),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: skBackgroundWhite,
            selectedItemColor: appPrimaryColor,
            unselectedItemColor: skDarkText.withAlpha((255 * 0.6).round()),
            selectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600, fontSize: 11),
            unselectedLabelStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 10),
            elevation: 5,
            type: BottomNavigationBarType.fixed,
          ),
          iconTheme: IconThemeData(
            color: appPrimaryColor,
            size: 24.0,
          ),
          listTileTheme: ListTileThemeData(
            iconColor: appPrimaryColor,
            tileColor: skBackgroundWhite,
          ),
          dividerTheme: DividerThemeData(
            color: Colors.grey[300],
            thickness: 1,
          ),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: ZoomPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            },
          ),
        ),
        home: Uri.base.queryParameters['id'] != null
            ? StudentPortalScreen(
                studentId: Uri.base.queryParameters['id']!,
                firestoreService: FirestoreService(),
              )
            : LoginScreen(),
        builder: (context, child) {
          return Column(
            children: [
              ConnectivityBanner(),
              Expanded(child: child!),
            ],
          );
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}