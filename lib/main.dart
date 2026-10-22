import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
void main(){
  runApp(const HealthCoreApp());
}
class HealthCoreApp extends StatelessWidget{
  const HealthCoreApp({super.key});
@override
Widget build(BuildContext context){
  return const MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'HealthCore',
    home: WelcomeScreen(),
  );
}
}