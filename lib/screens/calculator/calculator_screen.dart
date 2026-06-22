import 'package:flutter/material.dart';
import 'screens/home_calc_screen.dart';

class CalculatorScreen extends StatelessWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provide a Navigator wrapper if needed, but a simple Scaffold works too.
    return const HomeCalcScreen();
  }
}
