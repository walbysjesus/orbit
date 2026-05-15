import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController documentNumberController =
      TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController cityController = TextEditingController();

  bool _obscurePassword = true;
  String? documentType;
  String? country;
  AccountType _accountType = AccountType.general;
  final TextEditingController organizationNameController =
      TextEditingController();
  final TextEditingController organizationIdController =
      TextEditingController();
  final TextEditingController seatsController =
      TextEditingController(text: '25');
  String _organizationSector = 'petrolera';

  final List<String> _organizationSectors = const [
    'petrolera',
    'energia',
    'gobierno',
    'mineria',
    'logistica',
    'otra',
  ];

  final List<String> documentTypes = [
    'Cédula',
    'Tarjeta de identidad (menores de 12 años)',
    'Pasaporte',
    'DNI',
    'NIT',
    'Driver License',
    'National ID',
    'Otro',
  ];

  final List<String> countries = [
    'Antigua y Barbuda',
    'Argentina',
    'Bahamas',
    'Barbados',
    'Belice',
    'Bolivia',
    'Brasil',
    'Canadá',
    'Chile',
    'Colombia',
    'Costa Rica',
    'Cuba',
    'Dominica',
    'Ecuador',
    'El Salvador',
    'Estados Unidos',
    'Granada',
    'Guatemala',
    'Guyana',
    'Haití',
    'Honduras',
    'Jamaica',
    'México',
    'Nicaragua',
    'Panamá',
    'Paraguay',
    'Perú',
    'República Dominicana',
    'San Cristóbal y Nieves',
    'San Vicente y las Granadinas',
    'Santa Lucía',
    'Surinam',
    'Trinidad y Tobago',
    'Uruguay',
    'Venezuela',
  ];

  static const Map<String, String> _countryApiNames = {
    'Antigua y Barbuda': 'Antigua and Barbuda',
    'Argentina': 'Argentina',
    'Bahamas': 'Bahamas',
    'Barbados': 'Barbados',
    'Belice': 'Belize',
    'Bolivia': 'Bolivia',
    'Brasil': 'Brazil',
    'Canadá': 'Canada',
    'Chile': 'Chile',
    'Colombia': 'Colombia',
    'Costa Rica': 'Costa Rica',
    'Cuba': 'Cuba',
    'Dominica': 'Dominica',
    'Ecuador': 'Ecuador',
    'El Salvador': 'El Salvador',
    'Estados Unidos': 'United States',
    'Granada': 'Grenada',
    'Guatemala': 'Guatemala',
    'Guyana': 'Guyana',
    'Haití': 'Haiti',
    'Honduras': 'Honduras',
    'Jamaica': 'Jamaica',
    'México': 'Mexico',
    'Nicaragua': 'Nicaragua',
    'Panamá': 'Panama',
    'Paraguay': 'Paraguay',
    'Perú': 'Peru',
    'República Dominicana': 'Dominican Republic',
    'San Cristóbal y Nieves': 'Saint Kitts and Nevis',
    'San Vicente y las Granadinas': 'Saint Vincent and the Grenadines',
    'Santa Lucía': 'Saint Lucia',
    'Surinam': 'Suriname',
    'Trinidad y Tobago': 'Trinidad and Tobago',
    'Uruguay': 'Uruguay',
    'Venezuela': 'Venezuela',
  };

  List<String> _availableCities = [];
  bool _isLoadingCities = false;

  final Map<String, List<String>> citiesByCountry = {
    'Antigua y Barbuda': [
      'Saint John\'s (Saint John)',
      'All Saints (Saint John)',
      'Liberta (Saint Paul)',
      'Potters Village (Saint John)',
      'Parham (Saint Peter)'
    ],
    'Argentina': [
      'Buenos Aires (CABA)',
      'Córdoba (Córdoba)',
      'Rosario (Santa Fe)',
      'Mendoza (Mendoza)',
      'La Plata (Buenos Aires)'
    ],
    'Bahamas': [
      'Nassau (New Providence)',
      'Freeport (Grand Bahama)',
      'Marsh Harbour (Abaco)',
      'George Town (Exuma)',
      'West End (Grand Bahama)'
    ],
    'Barbados': [
      'Bridgetown (Saint Michael)',
      'Holetown (Saint James)',
      'Speightstown (Saint Peter)',
      'Oistins (Christ Church)',
      'Bathsheba (Saint Joseph)'
    ],
    'Belice': [
      'Belmopán (Cayo)',
      'Ciudad de Belice (Belize)',
      'San Ignacio (Cayo)',
      'Orange Walk Town (Orange Walk)',
      'Dangriga (Stann Creek)'
    ],
    'Bolivia': [
      'La Paz (La Paz)',
      'Santa Cruz de la Sierra (Santa Cruz)',
      'Cochabamba (Cochabamba)',
      'Sucre (Chuquisaca)',
      'El Alto (La Paz)'
    ],
    'Brasil': [
      'São Paulo (São Paulo)',
      'Rio de Janeiro (Rio de Janeiro)',
      'Brasília (Distrito Federal)',
      'Salvador (Bahia)',
      'Fortaleza (Ceará)'
    ],
    'Canadá': [
      'Toronto (Ontario)',
      'Vancouver (British Columbia)',
      'Montreal (Quebec)',
      'Calgary (Alberta)',
      'Ottawa (Ontario)'
    ],
    'Chile': [
      'Santiago (Región Metropolitana)',
      'Valparaíso (Valparaíso)',
      'Concepción (Biobío)',
      'Antofagasta (Antofagasta)',
      'La Serena (Coquimbo)'
    ],
    'Colombia': [
      'Bogotá (Cundinamarca)',
      'Medellín (Antioquia)',
      'Cali (Valle del Cauca)',
      'Barranquilla (Atlántico)',
      'Cartagena (Bolívar)'
    ],
    'Costa Rica': [
      'San José (San José)',
      'Alajuela (Alajuela)',
      'Cartago (Cartago)',
      'Heredia (Heredia)',
      'Liberia (Guanacaste)'
    ],
    'Cuba': [
      'La Habana (La Habana)',
      'Santiago de Cuba (Santiago de Cuba)',
      'Camagüey (Camagüey)',
      'Holguín (Holguín)',
      'Santa Clara (Villa Clara)'
    ],
    'Dominica': [
      'Roseau (Saint George)',
      'Portsmouth (Saint John)',
      'Marigot (Saint Andrew)',
      'Berekua (Saint Patrick)',
      'Mahaut (Saint Paul)'
    ],
    'Ecuador': [
      'Quito (Pichincha)',
      'Guayaquil (Guayas)',
      'Cuenca (Azuay)',
      'Santo Domingo (Santo Domingo de los Tsáchilas)',
      'Manta (Manabí)'
    ],
    'El Salvador': [
      'San Salvador (San Salvador)',
      'Santa Ana (Santa Ana)',
      'San Miguel (San Miguel)',
      'Soyapango (San Salvador)',
      'Santa Tecla (La Libertad)'
    ],
    'Estados Unidos': [
      'New York (New York)',
      'Los Angeles (California)',
      'Chicago (Illinois)',
      'Miami (Florida)',
      'Houston (Texas)'
    ],
    'Granada': [
      'Saint George\'s (Saint George)',
      'Grenville (Saint Andrew)',
      'Gouyave (Saint John)',
      'Victoria (Saint Mark)',
      'Sauteurs (Saint Patrick)'
    ],
    'Guatemala': [
      'Ciudad de Guatemala (Guatemala)',
      'Quetzaltenango (Quetzaltenango)',
      'Escuintla (Escuintla)',
      'Puerto Barrios (Izabal)',
      'Cobán (Alta Verapaz)'
    ],
    'Guyana': [
      'Georgetown (Demerara-Mahaica)',
      'Linden (Upper Demerara-Berbice)',
      'New Amsterdam (East Berbice-Corentyne)',
      'Anna Regina (Pomeroon-Supenaam)',
      'Bartica (Cuyuni-Mazaruni)'
    ],
    'Haití': [
      'Puerto Príncipe (Ouest)',
      'Cap-Haïtien (Nord)',
      'Gonaïves (Artibonite)',
      'Les Cayes (Sud)',
      'Jacmel (Sud-Est)'
    ],
    'Honduras': [
      'Tegucigalpa (Francisco Morazán)',
      'San Pedro Sula (Cortés)',
      'La Ceiba (Atlántida)',
      'Choloma (Cortés)',
      'Comayagua (Comayagua)'
    ],
    'Jamaica': [
      'Kingston (Kingston)',
      'Montego Bay (Saint James)',
      'Spanish Town (Saint Catherine)',
      'Portmore (Saint Catherine)',
      'Mandeville (Manchester)'
    ],
    'México': [
      'Ciudad de México (CDMX)',
      'Monterrey (Nuevo León)',
      'Guadalajara (Jalisco)',
      'Puebla (Puebla)',
      'Cancún (Quintana Roo)'
    ],
    'Nicaragua': [
      'Managua (Managua)',
      'León (León)',
      'Masaya (Masaya)',
      'Chinandega (Chinandega)',
      'Estelí (Estelí)'
    ],
    'Panamá': [
      'Ciudad de Panamá (Panamá)',
      'San Miguelito (Panamá)',
      'Colón (Colón)',
      'David (Chiriquí)',
      'Santiago (Veraguas)'
    ],
    'Paraguay': [
      'Asunción (Capital)',
      'Ciudad del Este (Alto Paraná)',
      'Encarnación (Itapúa)',
      'San Lorenzo (Central)',
      'Luque (Central)'
    ],
    'Perú': [
      'Lima (Lima)',
      'Arequipa (Arequipa)',
      'Trujillo (La Libertad)',
      'Cusco (Cusco)',
      'Piura (Piura)'
    ],
    'República Dominicana': [
      'Santo Domingo (Distrito Nacional)',
      'Santiago de los Caballeros (Santiago)',
      'La Romana (La Romana)',
      'San Pedro de Macorís (San Pedro de Macorís)',
      'Punta Cana (La Altagracia)'
    ],
    'San Cristóbal y Nieves': [
      'Basseterre (Saint George Basseterre)',
      'Charlestown (Saint Paul Charlestown)',
      'Sandy Point Town (Saint Anne Sandy Point)',
      'Cayon (Saint Mary Cayon)',
      'Dieppe Bay Town (Saint John Capisterre)'
    ],
    'San Vicente y las Granadinas': [
      'Kingstown (Saint George)',
      'Georgetown (Charlotte)',
      'Barrouallie (Saint Patrick)',
      'Port Elizabeth (Grenadines)',
      'Chateaubelair (Saint David)'
    ],
    'Santa Lucía': [
      'Castries (Castries)',
      'Vieux Fort (Vieux Fort)',
      'Gros Islet (Gros Islet)',
      'Soufrière (Soufrière)',
      'Dennery (Dennery)'
    ],
    'Surinam': [
      'Paramaribo (Paramaribo)',
      'Lelydorp (Wanica)',
      'Nieuw Nickerie (Nickerie)',
      'Moengo (Marowijne)',
      'Albina (Marowijne)'
    ],
    'Trinidad y Tobago': [
      'Puerto España (Port of Spain)',
      'San Fernando (San Fernando)',
      'Arima (Borough of Arima)',
      'Chaguanas (Chaguanas)',
      'Scarborough (Tobago)'
    ],
    'Uruguay': [
      'Montevideo (Montevideo)',
      'Salto (Salto)',
      'Paysandú (Paysandú)',
      'Las Piedras (Canelones)',
      'Maldonado (Maldonado)'
    ],
    'Venezuela': [
      'Caracas (Distrito Capital)',
      'Maracaibo (Zulia)',
      'Valencia (Carabobo)',
      'Barquisimeto (Lara)',
      'Maracay (Aragua)'
    ],
  };

  @override
  void dispose() {
    fullNameController.dispose();
    documentNumberController.dispose();
    emailController.dispose();
    passwordController.dispose();
    cityController.dispose();
    organizationNameController.dispose();
    organizationIdController.dispose();
    seatsController.dispose();
    super.dispose();
  }

  Future<void> _loadCitiesForCountry(String selectedCountry) async {
    setState(() {
      _isLoadingCities = true;
      _availableCities = [];
    });

    final apiCountryName = _countryApiNames[selectedCountry] ?? selectedCountry;

    try {
      final response = await http
          .post(
            Uri.parse('https://countriesnow.space/api/v0.1/countries/cities'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'country': apiCountryName}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data = decoded['data'];
      if (data is! List) {
        return;
      }

      final cleaned = data
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (!mounted) return;
      setState(() {
        _availableCities = cleaned;
      });
    } catch (_) {
      // Fallback silencioso: se mantiene entrada manual de ciudad.
    } finally {
      if (mounted) {
        setState(() {
          if (_availableCities.isEmpty &&
              citiesByCountry.containsKey(selectedCountry)) {
            _availableCities =
                List<String>.from(citiesByCountry[selectedCountry]!);
          }
          _isLoadingCities = false;
        });
      }
    }
  }

  Future<void> _registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await AuthService.register(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        fullName: fullNameController.text.trim(),
        documentType: documentType,
        documentNumber: documentNumberController.text.trim(),
        country: country,
        city: cityController.text.trim(),
        accountType: _accountType,
        organizationName: _accountType == AccountType.enterpriseAdmin
            ? organizationNameController.text.trim()
            : null,
        organizationSector: _accountType == AccountType.enterpriseAdmin
            ? _organizationSector
            : null,
        seatsRequested: _accountType == AccountType.enterpriseAdmin
            ? int.tryParse(seatsController.text.trim())
            : null,
        organizationId: _accountType == AccountType.enterpriseEmployee
            ? organizationIdController.text.trim()
            : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Registro exitoso! Bienvenido a Orbit.'),
          backgroundColor: Color(0xFF0A4D8F),
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString().replaceAll("Exception:", "").trim()}',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0A4D8F)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'CREATE ACCOUNT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0A4D8F),
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<AccountType>(
                    initialValue: _accountType,
                    dropdownColor: const Color(0xFFFFFFFF),
                    decoration: _inputDecoration('Tipo de cuenta'),
                    style: const TextStyle(color: Color(0xFF123A5B)),
                    items: const [
                      DropdownMenuItem(
                        value: AccountType.general,
                        child: Text('Personas'),
                      ),
                      DropdownMenuItem(
                        value: AccountType.enterpriseAdmin,
                        child: Text('Empresa / Gobiernos'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _accountType = value;
                      });
                    },
                  ),
                ),
                if (_accountType == AccountType.enterpriseAdmin) ...[
                  _inputField(
                    label: 'Nombre de la organización',
                    controller: organizationNameController,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      initialValue: _organizationSector,
                      dropdownColor: const Color(0xFFFFFFFF),
                      decoration: _inputDecoration('Sector'),
                      style: const TextStyle(color: Color(0xFF123A5B)),
                      items: _organizationSectors
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _organizationSector = value;
                        });
                      },
                    ),
                  ),
                  _inputField(
                    label: 'Cupos iniciales (empleados)',
                    controller: seatsController,
                    keyboardType: TextInputType.number,
                  ),
                ],
                _inputField(
                  label: 'Full Name',
                  controller: fullNameController,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: documentType,
                    dropdownColor: const Color(0xFFFFFFFF),
                    decoration: _inputDecoration('Document Type'),
                    style: const TextStyle(color: Color(0xFF123A5B)),
                    items: documentTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) => setState(() => documentType = value),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Required field'
                        : null,
                  ),
                ),
                _inputField(
                  label: 'Document Number',
                  controller: documentNumberController,
                  keyboardType: TextInputType.number,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: country,
                    dropdownColor: const Color(0xFFFFFFFF),
                    decoration: _inputDecoration('Country'),
                    style: const TextStyle(color: Color(0xFF123A5B)),
                    items: countries
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        country = value;
                        cityController.clear();
                      });
                      if (value != null) {
                        _loadCitiesForCountry(value);
                      }
                    },
                    validator: (value) => value == null || value.isEmpty
                        ? 'Required field'
                        : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (country == null)
                        TextFormField(
                          enabled: false,
                          decoration: _inputDecoration('City/State').copyWith(
                            hintText: 'Selecciona primero un país',
                          ),
                        )
                      else
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (_availableCities.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            final query = textEditingValue.text.toLowerCase();
                            if (query.isEmpty) {
                              return _availableCities.take(30);
                            }
                            return _availableCities.where(
                              (cityName) =>
                                  cityName.toLowerCase().contains(query),
                            );
                          },
                          onSelected: (selection) {
                            cityController.text = selection;
                          },
                          fieldViewBuilder: (context, controller, focusNode,
                              onFieldSubmitted) {
                            if (controller.text != cityController.text) {
                              controller.text = cityController.text;
                              controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: controller.text.length),
                              );
                            }
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              style: const TextStyle(color: Color(0xFF123A5B)),
                              decoration:
                                  _inputDecoration('City/State').copyWith(
                                hintText: _availableCities.isEmpty
                                    ? 'Escribe tu ciudad'
                                    : 'Escribe o selecciona tu ciudad',
                              ),
                              onChanged: (value) => cityController.text = value,
                              validator: (value) =>
                                  value == null || value.trim().isEmpty
                                      ? 'Required field'
                                      : null,
                            );
                          },
                        ),
                      if (_isLoadingCities)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Cargando ciudades...',
                            style: TextStyle(
                              color: Color(0xFF5A7388),
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                _inputField(
                  label: 'Email',
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Color(0xFF123A5B)),
                    decoration: _inputDecoration('Password').copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: const Color(0xFF0A4D8F),
                        ),
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required field';
                      }
                      if (value.length < 8) {
                        return 'La contraseña debe tener al menos 8 caracteres';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(value)) {
                        return 'Debe contener al menos una mayúscula';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(value)) {
                        return 'Debe contener al menos un número';
                      }
                      if (!RegExp(r'[!@#\$&*~%^?¿.,;:_\-]').hasMatch(value)) {
                        return 'Debe contener al menos un carácter especial';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 30),
                _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3389FF),
                        ),
                      )
                    : ElevatedButton(
                        onPressed: _registerUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A4D8F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Registrarme',
                          style: TextStyle(
                            fontSize: 18,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                      ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    '¿Ya tienes una cuenta? Inicia sesión',
                    style: TextStyle(
                      color: Color(0xFF0A4D8F),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => _showPrivacyDialog(context),
                    child: const Text(
                      'Al registrarte, aceptas nuestra Política de Privacidad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF5A7388),
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Política de Privacidad'),
        content: SingleChildScrollView(
          child: Text(_privacyText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  static const String _privacyText = '''
Política de Privacidad - Orbit
Fecha de entrada en vigor: 18/01/2026
...
''';

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Color(0xFF123A5B)),
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: _inputDecoration(label),
        validator: (value) =>
            value == null || value.isEmpty ? 'Required field' : null,
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFF5A7388)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFFBCD8EE)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Color(0xFF0A4D8F)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}
