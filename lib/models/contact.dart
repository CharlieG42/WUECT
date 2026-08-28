import 'package:hive/hive.dart';

part 'contact.g.dart';

@HiveType(typeId: 0)
class Contact {
  @HiveField(0)
  final int? id;
  
  @HiveField(1)
  final String client; // Nom du client
  
  @HiveField(2)
  final String nom; // Nom du contact
  
  @HiveField(3)
  final String email;
  
  @HiveField(4)
  final String mobile;

  Contact({
    this.id,
    required this.client,
    required this.nom,
    required this.email,
    required this.mobile,
  });

  // Conversion en Map pour SQLite (gardé pour compatibilité)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'client': client,
      'nom': nom,
      'email': email,
      'mobile': mobile,
    };
  }

  // Création depuis un Map (SQLite) (gardé pour compatibilité)
  factory Contact.fromMap(Map<String, dynamic> map) {
    return Contact(
      id: map['id'],
      client: map['client'] ?? '',
      nom: map['nom'] ?? '',
      email: map['email'] ?? '',
      mobile: map['mobile'] ?? '',
    );
  }

  // Copie avec modification
  Contact copyWith({
    int? id,
    String? client,
    String? nom,
    String? email,
    String? mobile,
  }) {
    return Contact(
      id: id ?? this.id,
      client: client ?? this.client,
      nom: nom ?? this.nom,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
    );
  }
}
