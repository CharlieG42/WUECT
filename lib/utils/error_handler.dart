import 'package:flutter/material.dart';

class ErrorHandler {
  /// Affiche un SnackBar simple. `error=true` => fond rouge, sinon vert.
  static void showSnackBar(BuildContext context, String message, {bool error = false}) {
    final snack = SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
    );
    ScaffoldMessenger.of(context).showSnackBar(snack);
  }
}
