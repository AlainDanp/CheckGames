import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'Bloc/checkgames_bloc.dart'; // ton bloc
import 'Bloc/checkgames_event.dart';
import 'ui/game_page.dart';

void main() {
  runApp(const CheckGamesApp());
}

class CheckGamesApp extends StatelessWidget {
  const CheckGamesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CheckGameBloc()..add(StartGame(['Vous', 'BOB', 'Paul'])),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CheckGames',
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.teal,
          brightness: Brightness.light,
        ),
        home: const GamePage(),
      ),
    );
  }
}