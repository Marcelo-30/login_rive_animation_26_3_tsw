import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Encender el puente nativo antes de usar Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase usando las credenciales de firebase_options.dart
  await Firebase.initializeApp(options: firebaseOptions);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Torneos de fútbol',
      theme: ThemeData(colorScheme: .fromSeed(seedColor: Colors.deepPurple)),
      home: const LoginScreen(),
    );
  }
}
