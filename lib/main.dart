import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> main() async {
  // Inicialização padrão do Firebase
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Solicita permissão de notificação e configura listeners do FCM
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Listener para mensagens em foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('[FCM] Mensagem em foreground: ${message.notification?.title}');
  });

  runApp(const PlantMonitorApp());
}

class PlantMonitorApp extends StatelessWidget {
  const PlantMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Plant Monitor',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBF5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFBF5),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const PlantMonitorScreen(),
    );
  }
}

/// Widget de monitoramento de plantas com medidor de umidade do solo.
/// Integra-se com Firebase (FCM) e consome dados de uma API remota.
class PlantMonitorScreen extends StatefulWidget {
  const PlantMonitorScreen({super.key});

  @override
  State<PlantMonitorScreen> createState() => _PlantMonitorScreenState();
}

class _PlantMonitorScreenState extends State<PlantMonitorScreen> {
  late double _moistureValue = 35.0;
  late String _statusText = 'Monitorando';
  bool _isLoading = true;
  String? _fcmToken;

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _fetchPlantData();
  }

  /// Inicializa o FCM e obtém o token de registro.
  Future<void> _initializeFCM() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] Registration Token: $token');
      if (mounted) {
        setState(() {
          _fcmToken = token;
        });
      }
      // Envia o token para o backend
      if (token != null) {
        await _sendFCMTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Erro ao obter token: $e');
    }
  }

  /// Envia o token FCM para o endpoint POST /fcm do backend.
  Future<void> _sendFCMTokenToBackend(String token) async {
    try {
      const apiUrl = 'https://tech-planta-api.vercel.app/fcm';
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'fcmToken': token}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FCM] Token enviado com sucesso para o backend');
      } else {
        debugPrint('[FCM] Erro ao enviar token: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[FCM] Erro ao enviar token para o backend: $e');
    }
  }

  /// Busca dados da planta (umidade e status) da API remota.
  Future<void> _fetchPlantData() async {
    try {
      const apiUrl = 'https://tech-planta-api.vercel.app/';
      final response = await http
          .get(Uri.parse(apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _moistureValue =
                (data['valor_unidade'] as num?)?.toDouble() ?? 35.0;
            _statusText = data['situacao_atual'] as String? ?? 'Monitorando';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        debugPrint('[API] Erro: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[API] Erro ao buscar dados: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Retorna a cor do indicador baseado na faixa de umidade.
  Color _getPointerColor(double value) {
    if (value <= 25) {
      return const Color(0xFFFF8C00); // Laranja - Triste
    } else if (value <= 50) {
      return const Color(0xFFFFD700); // Amarelo - Sério
    } else {
      return const Color(0xFF388E3C); // Verde - Feliz
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Plant Monitor',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Título do medidor
                    Text(
                      'SOIL MOISTURE',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Gauge Semi-Circular com 3 zonas de cor
                    SizedBox(
                      height: 280,
                      child: SfRadialGauge(
                        axes: [
                          RadialAxis(
                            minimum: 0,
                            maximum: 100,
                            startAngle: 180,
                            endAngle: 0,
                            showLabels: true,
                            showTicks: true,
                            labelOffset: 15,
                            majorTickStyle: const MajorTickStyle(
                              length: 8,
                              thickness: 1.5,
                            ),
                            minorTicksPerInterval: 4,
                            minorTickStyle: const MinorTickStyle(
                              length: 4,
                              thickness: 1,
                            ),
                            // Intervalo de rótulos: 0, 25, 50, 75, 100
                            interval: 25,
                            // Ranges com as 3 zonas de cor
                            ranges: [
                              // Triste (Laranja): 0 a 25%
                              GaugeRange(
                                startValue: 0,
                                endValue: 25,
                                color: const Color(0xFFFF8C00),
                                startWidth: 12,
                                endWidth: 12,
                              ),
                              // Sério (Amarelo): 25 a 50%
                              GaugeRange(
                                startValue: 25,
                                endValue: 50,
                                color: const Color(0xFFFFD700),
                                startWidth: 12,
                                endWidth: 12,
                              ),
                              // Feliz (Verde): 50 a 100%
                              GaugeRange(
                                startValue: 50,
                                endValue: 100,
                                color: const Color(0xFF388E3C),
                                startWidth: 12,
                                endWidth: 12,
                              ),
                            ],
                            pointers: [
                              NeedlePointer(
                                value: _moistureValue,
                                needleColor: _getPointerColor(_moistureValue),
                                needleStartWidth: 0,
                                needleEndWidth: 8,
                                needleLength: 0.8,
                                knobStyle: const KnobStyle(
                                  knobRadius: 0.08,
                                  color: Color(0xFF388E3C),
                                ),
                              ),
                            ],
                            axisLabelStyle: GaugeTextStyle(
                              fontSize: 12,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Valor em grande e fonte ousada
                    Text(
                      '${_moistureValue.toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                        fontSize: 56,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Status de monitoramento
                    Text(
                      _statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Botão de Atualizar
                    FilledButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                        });
                        _fetchPlantData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar Dados'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF388E3C),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Exibir FCM Token (debug)
                    if (_fcmToken != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FCM Token (Debug):',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _fcmToken!,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
