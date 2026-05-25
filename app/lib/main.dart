import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'data/catalog_cache.dart';
import 'screens/home_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _initSqfliteForDesktop();
  await initializeDateFormatting('fr_FR', null);
  await CatalogCache.refresh();
  runApp(const PhytoNote());
}

void _initSqfliteForDesktop() {
  if (kIsWeb) return;
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

class PhytoNote extends StatelessWidget {
  const PhytoNote({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PhytoNote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
