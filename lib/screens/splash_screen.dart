import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:tarnobrzeg112/core/app_constants.dart';
import 'package:tarnobrzeg112/widgets/app_background.dart';
import 'package:tarnobrzeg112/widgets/tbg_logo.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lottie/rescue_pulse.json',
                width: 150,
                height: 150,
              ),
              const SizedBox(height: 12),
              const TbgLogo(size: 58),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  AppConstants.safetyNotice,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 350.ms).moveY(begin: 8, end: 0),
        ),
      ),
    );
  }
}
