import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'app_drawer.dart'; // <-- HomeContainer lives here

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<bool> hasInternetAccess() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initApp() async {
    try {
      print("Checking internet...");
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none || !await hasInternetAccess()) {
        setState(() {
          _errorMessage = "No internet connection.\nPlease enable WiFi or mobile data.";
        });
        return;
      }

      print("Initializing Firebase...");
      await Firebase.initializeApp();
      print("Firebase initialized successfully!");

      await Future.delayed(const Duration(seconds: 3));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeContainer()),
      );
    } catch (e) {
      print("Firebase initialization failed: $e");
      setState(() {
        _errorMessage = "Failed to connect to Firebase.\nPlease check your config.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blueAccent,
      body: Center(
        child: _errorMessage == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SafeVoice',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Let’s Change the World to a Safer, Peaceful Place.\n'
                    'Every Contribution is Appreciated',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                      });
                      _initApp();
                    },
                    child: const Text("Try Again"),
                  ),
                ],
              ),
      ),
    );
  }
}