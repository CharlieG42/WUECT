import 'package:flutter/services.dart';

/// TextInputFormatter qui accepte les décimales avec point OU virgule
/// et les convertit automatiquement en point pour le parsing
class DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remplacer les virgules par des points pour standardiser
    String newText = newValue.text.replaceAll(',', '.');
    
    // Autoriser uniquement : chiffres, point décimal, et signe négatif au début
    // Maximum un seul point décimal
    if (newText.isEmpty) {
      return newValue.copyWith(text: newText);
    }
    
    // Vérifier que seul le premier caractère peut être '-'
    if (newText.startsWith('-')) {
      // Le reste ne doit contenir que des chiffres et au plus un point
      String rest = newText.substring(1);
      if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(rest)) {
        return oldValue;
      }
      // Vérifier qu'il n'y a qu'un seul point
      if (rest.split('.').length > 2) {
        return oldValue;
      }
    } else {
      // Doit contenir que des chiffres et au plus un point
      if (!RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(newText)) {
        return oldValue;
      }
      // Vérifier qu'il n'y a qu'un seul point
      if (newText.split('.').length > 2) {
        return oldValue;
      }
    }
    
    return newValue.copyWith(text: newText);
  }
}

/// Formatter plus strict qui accepte aussi les virgules comme séparateurs de milliers
/// mais cela peut compliquer le parsing. Pour l'instant, on reste simple.
class DecimalTextInputFormatterWithComma extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text;
    
    // Si le texte est vide, accepter
    if (text.isEmpty) {
      return newValue;
    }
    
    // Remplacer les virgules par des points
    text = text.replaceAll(',', '.');
    
    // Vérifier le format : optionnel - suivi de chiffres et optionnel . suivi de chiffres
    // Ne pas permettre plusieurs points
    if (!RegExp(r'^-?[0-9]*\.?[0-9]*$').hasMatch(text)) {
      return oldValue;
    }
    
    // Vérifier qu'il n'y a pas plus d'un point
    if (text.split('.').length > 2) {
      return oldValue;
    }
    
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
