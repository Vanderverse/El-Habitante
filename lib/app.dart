import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'data/file_habitat_repository.dart';
import 'data/habitat_repository.dart';
import 'presentation/habitat_screen.dart';

class ElHabitanteApp extends StatelessWidget {
  const ElHabitanteApp({super.key, this.repositoryFactory});

  final Future<HabitatRepository> Function()? repositoryFactory;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'El Habitante',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff728a79),
        brightness: Brightness.dark,
        surface: const Color(0xff1b2429),
      ),
      useMaterial3: true,
    ),
    home: HabitatScreen(
      repositoryFactory: repositoryFactory ??
          () async => FileHabitatRepository(
            await getApplicationSupportDirectory(),
          ),
    ),
  );
}
