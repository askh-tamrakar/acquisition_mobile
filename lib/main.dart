import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:acquisition_mobile/view_models/main_view_model.dart';
import 'package:acquisition_mobile/ui/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MainViewModel(),
      child: MaterialApp(
        title: 'Acquisition App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
