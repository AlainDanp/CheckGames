import 'package:flutter/material.dart';

abstract class AppSnackbar{
  static void error(BuildContext context, String message){
    _show(context, message, backgroundColor: const Color(0xFFB00020));
  }
  static void warning(BuildContext context, String message){
    _show(context,message,backgroundColor: const Color(0xFFF57C00));
  }
  static void info(BuildContext context, String message) {
    _show(context, message, backgroundColor: const Color(0xFF1565C0));
  }

  static void _show(
      BuildContext context,
      String message, {
        required Color backgroundColor,
  }) {
    if(!context.mounted) return;
    ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: backgroundColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        )
    );
  }

}