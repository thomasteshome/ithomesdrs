import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

// Import all screens
import 'firestore_safe.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'expert_dashboard.dart'; 
import 'dean_dashboard.dart'; 
import 'dept_head_dashboard.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Offline Persistence so experts don't lose data in low-signal areas
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const GicApp());
}

class GicApp extends StatelessWidget {
  const GicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GIC - Gofa Industrial College',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
          secondary: const Color(0xFFFFB300), 
        ),
      ),
      // The AuthGate handles all entry logic
      home: const AuthGate(),
      // Signup remains a named route because it's a sub-page of Login
      routes: {
        '/signup': (context) => const SignupScreen(),
      },
    );
  }
}

// --- THE SMART AUTH GATE ---
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If the user is NOT logged in, show the Login Screen
        if (!snapshot.hasData) {
          return const LoginScreen();
        }

        // 2. If the user IS logged in, determine their role
        return const RoleBaseWrapper();
      },
    );
  }
}

// --- THE ROLE WRAPPER (Replaces the old SplashScreen) ---
class RoleBaseWrapper extends StatelessWidget {
  const RoleBaseWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
      builder: (context, snapshot) {
        // Show the branding/loading screen while fetching the role
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingSplash();
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          // If no user document exists, log them out to prevent a stuck state
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        // Route to the correct dashboard based on Firestore role.
        // Use safe Map access: .get('role') throws a StateError when a legacy
        // user document has no role field, which would crash the whole app.
        final role = docStr(snapshot.data!, 'role');
        
        if (role == 'dean') return const DeanDashboard();
        if (role == 'deptHead') return const DeptHeadDashboard();
        return const ExpertDashboard();
      },
    );
  }
}

// --- STATIC LOADING SCREEN ---
class LoadingSplash extends StatelessWidget {
  const LoadingSplash({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF002171)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFFFB300)),
            SizedBox(height: 25),
            Text(
              "GIC SYSTEM",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Authenticating...",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}