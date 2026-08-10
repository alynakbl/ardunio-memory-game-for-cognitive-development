import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final int savedHighScore = prefs.getInt('skh4_highscore') ?? 0;
  final int savedBestTime = prefs.getInt('skh4_best_time') ?? 999999;

  runApp(Skh4App(initialHighScore: savedHighScore, initialBestTime: savedBestTime));
}

class Skh4App extends StatelessWidget {
  final int initialHighScore;
  final int initialBestTime;

  const Skh4App({super.key, required this.initialHighScore, required this.initialBestTime});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SKH-4 Android',
      theme: ThemeData.dark(useMaterial3: true),
      home: MainMenuScreen(highScore: initialHighScore, bestTime: initialBestTime),
    );
  }
}

// ==========================================
// RAM ÜZERİNDE MATEMATİKSEL WAV SENTEZLEYİCİ
// ==========================================
Uint8List _generateWav(double frequency, int durationMs) {
  const int sampleRate = 44100;
  final int numSamples = (sampleRate * durationMs / 1000).round();
  final int dataSize = numSamples * 2;
  final int fileSize = 36 + dataSize;
  final ByteData byteData = ByteData(44 + dataSize);

  byteData.setUint32(0, 0x52494646, Endian.big);
  byteData.setUint32(4, fileSize, Endian.little);
  byteData.setUint32(8, 0x57415645, Endian.big);
  byteData.setUint32(12, 0x666D7420, Endian.big);
  byteData.setUint32(16, 16, Endian.little);
  byteData.setUint16(20, 1, Endian.little);
  byteData.setUint16(22, 1, Endian.little);
  byteData.setUint32(24, sampleRate, Endian.little);
  byteData.setUint32(28, sampleRate * 2, Endian.little);
  byteData.setUint16(32, 2, Endian.little);
  byteData.setUint16(34, 16, Endian.little);
  byteData.setUint32(36, 0x64617461, Endian.big);
  byteData.setUint32(40, dataSize, Endian.little);

  for (int i = 0; i < numSamples; i++) {
    final double t = i / sampleRate;
    final double sample = sin(2 * pi * frequency * t) > 0 ? 1.0 : -1.0;
    byteData.setInt16(44 + i * 2, (sample * 12000).toInt(), Endian.little);
  }
  return byteData.buffer.asUint8List();
}

// ==========================================
// ANA MENÜ
// ==========================================
class MainMenuScreen extends StatelessWidget {
  final int highScore;
  final int bestTime;

  const MainMenuScreen({super.key, required this.highScore, required this.bestTime});

  String _formatTime(int seconds) {
    if (seconds == 999999) return "--:--";
    final m = (seconds / 60).floor().toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SKH-4 Android Kontrol Paneli'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text("🏆 En Yüksek Rekorlar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text("Seviye: $highScore", style: const TextStyle(fontSize: 16, color: Colors.amberAccent)),
                    Text("Süre: ${_formatTime(bestTime)}", style: const TextStyle(fontSize: 16, color: Colors.greenAccent)),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _menuButton(context, Icons.bluetooth_connected, 'Arduino Bağlantı Modu (HM-10)',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ArduinoSyncScreen()))),
              const SizedBox(height: 12),
              _menuButton(context, Icons.wb_incandescent, 'Klasik Oyun Modu (Kolay)',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => SimulationScreen(currentHighScore: highScore, currentBestTime: bestTime, isAudioOnly: false)))),
              const SizedBox(height: 12),
              _menuButton(context, Icons.hearing, 'Ses Hafızası Modu (Zor)',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => SimulationScreen(currentHighScore: highScore, currentBestTime: bestTime, isAudioOnly: true)))),
              const SizedBox(height: 12),
              _menuButton(context, Icons.wifi, 'LAN Çok Oyunculu Mod (P2P)',
                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LobbyScreen())), color: Colors.teal),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton(BuildContext context, IconData icon, String label, VoidCallback onPressed, {Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 15)),
        style: color != null ? ElevatedButton.styleFrom(backgroundColor: color) : null,
        onPressed: onPressed,
      ),
    );
  }
}

// ==========================================
// ARDUINO DIREKT SENKRONİZASYON EKRANI (DİNAMİK LİSTE MODU)
// ==========================================
class ArduinoSyncScreen extends StatefulWidget {
  const ArduinoSyncScreen({super.key});

  @override
  State<ArduinoSyncScreen> createState() => _ArduinoSyncScreenState();
}

class _ArduinoSyncScreenState extends State<ArduinoSyncScreen> {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _writeCharacteristic;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<List<int>>? _notifySubscription;

  bool _isConnected = false;
  bool _isScanning = false;
  String _statusMessage = "Cihazları bulmak için tarama başlatın.";
  String _serialBuffer = "";

  List<ScanResult> _scanResults = [];

  int _activeLedIndex = -1;
  int _currentLevel = 0;
  int _lives = 3;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Color> _ledColors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.amberAccent];
  final List<double> _noteFrequencies = [262.0, 294.0, 392.0, 440.0];

  @override
  void initState() {
    super.initState();
    _checkAndroidPermissions();
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _notifySubscription?.cancel();
    _device?.disconnect();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkAndroidPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (!statuses[Permission.bluetoothScan]!.isGranted || !statuses[Permission.bluetoothConnect]!.isGranted) {
      setState(() => _statusMessage = "Hata: Android Bluetooth/Konum izinleri reddedildi.");
    }
  }

  void _startAndroidScan() {
    setState(() {
      _isScanning = true;
      _scanResults.clear();
      _statusMessage = "Etraftaki cihazlar aranıyor... (GPS'in açık olduğundan emin olun)";
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results.where((r) => r.device.platformName.isNotEmpty || r.device.advName.isNotEmpty).toList();
        });
      }
    });

    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && !_isConnected) {
        setState(() { _isScanning = false; _statusMessage = "Tarama tamamlandı. Lütfen listeden cihaz seçin."; });
      }
    });
  }

  Future<void> _connectToAndroidDevice(BluetoothDevice device) async {
    FlutterBluePlus.stopScan();
    _scanSubscription?.cancel();

    setState(() {
      _isScanning = false;
      _statusMessage = "${device.platformName.isEmpty ? device.advName : device.platformName} bağlanılıyor...";
    });

    try {
      await device.connect(timeout: const Duration(seconds: 10));
      _device = device;

      setState(() { _statusMessage = "Servis kanalları taranıyor..."; });

      List<BluetoothService> services = await device.discoverServices();
      bool foundUART = false;

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase().contains("FFE0")) {
          for (BluetoothCharacteristic char in service.characteristics) {
            if (char.uuid.toString().toUpperCase().contains("FFE1")) {
              _writeCharacteristic = char;
              await char.setNotifyValue(true);
              _notifySubscription = char.onValueReceived.listen(_onByteReceived);
              foundUART = true;
              break;
            }
          }
        }
      }

      if (!foundUART) {
        for (BluetoothService service in services) {
          for (BluetoothCharacteristic char in service.characteristics) {
            if ((char.properties.write || char.properties.writeWithoutResponse) &&
                (char.properties.notify || char.properties.indicate)) {
              _writeCharacteristic = char;
              await char.setNotifyValue(true);
              _notifySubscription = char.onValueReceived.listen(_onByteReceived);
              foundUART = true;
              break;
            }
          }
          if (foundUART) break;
        }
      }

      setState(() {
        _isConnected = true;
        _statusMessage = foundUART ? "Bağlantı Kuruldu. Veri bekleniyor..." : "Hata: Veri kanalı (UART) bulunamadı!";
      });

    } catch (e) {
      setState(() => _statusMessage = "Bağlantı hatası: $e");
    }
  }

  void _onByteReceived(List<int> value) {
    _serialBuffer += utf8.decode(value);
    while (_serialBuffer.contains('\n')) {
      int nlIndex = _serialBuffer.indexOf('\n');
      String command = _serialBuffer.substring(0, nlIndex).trim();
      _serialBuffer = _serialBuffer.substring(nlIndex + 1);

      if (command.startsWith("LED,")) {
        int index = int.parse(command.split(',')[1]);
        setState(() => _activeLedIndex = index);
        if (index != -1) _playLocalBuzzer(_noteFrequencies[index], 500);

        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _activeLedIndex == index) setState(() => _activeLedIndex = -1);
        });
      } else if (command.startsWith("STAGE,")) {
        var parts = command.split(',');
        setState(() {
          _currentLevel = int.parse(parts[1]);
          _lives = int.parse(parts[2]);
          _statusMessage = "Oyun Devam Ediyor...";
        });
      } else if (command == "WIN") {
        setState(() => _statusMessage = "🏆 Tebrikler, Kazandınız!");
      } else if (command == "LOSE") {
        setState(() => _statusMessage = "💀 Oyun Bitti!");
      } else if (command == "SUCCESS") {
        setState(() => _statusMessage = "Doğru Hamle!");
      }
    }
  }

  void _sendStringCommand(String payload) async {
    if (_writeCharacteristic != null && _isConnected) {
      await _writeCharacteristic!.write(utf8.encode("$payload\n"), withoutResponse: true);
    }
  }

  Future<void> _playLocalBuzzer(double freq, int durationMs) async {
    final Uint8List wavBytes = _generateWav(freq, durationMs);
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(wavBytes));
  }

  void _onPhoneTapStart(int index) {
    if (!_isConnected) return;
    setState(() => _activeLedIndex = index);
    _sendStringCommand("CLICK,$index");
    _playLocalBuzzer(_noteFrequencies[index], 2000);
  }

  void _onPhoneTapEnd() {
    if (!_isConnected) return;
    setState(() => _activeLedIndex = -1);
    Future.delayed(const Duration(milliseconds: 50), () => _audioPlayer.stop());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arduino Kontrolü'),
        actions: [
          Icon(_isConnected ? Icons.link : Icons.link_off, color: _isConnected ? Colors.green : Colors.red),
          const SizedBox(width: 16)
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blueGrey.withOpacity(0.2),
            child: Column(
              children: [
                if (_isConnected)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("Seviye: $_currentLevel", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text("Can: ${'❤️' * _lives}", style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                const SizedBox(height: 10),
                Text(_statusMessage, style: const TextStyle(fontStyle: FontStyle.italic), textAlign: TextAlign.center),
              ],
            ),
          ),
          if (_isConnected) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[700]), onPressed: () => _sendStringCommand("START_MODE,1"), child: const Text("Klasik Başlat"))),
                  const SizedBox(width: 16),
                  Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]), onPressed: () => _sendStringCommand("START_MODE,2"), child: const Text("Zor Başlat"))),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    bool isLit = _activeLedIndex == index;
                    return GestureDetector(
                      onTapDown: (_) => _onPhoneTapStart(index),
                      onTapUp: (_) => _onPhoneTapEnd(),
                      onTapCancel: () => _onPhoneTapEnd(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 50),
                        decoration: BoxDecoration(
                          color: isLit ? _ledColors[index] : _ledColors[index].withOpacity(0.15),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isLit ? Colors.white : Colors.transparent, width: 3),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          ] else ...[
            Expanded(
              child: _scanResults.isEmpty
                ? Center(child: Text(_isScanning ? "Etraftaki BLE Cihazlar Aranıyor..." : "Cihaz Bulunamadı."))
                : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final device = _scanResults[index].device;
                      final deviceName = device.platformName.isNotEmpty ? device.platformName : device.advName;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const Icon(Icons.bluetooth),
                          title: Text(deviceName.isNotEmpty ? deviceName : "Bilinmeyen Cihaz"),
                          subtitle: Text(device.remoteId.toString()),
                          trailing: ElevatedButton(
                            onPressed: () => _connectToAndroidDevice(device),
                            child: const Text("Bağlan"),
                          ),
                        ),
                      );
                    },
                  ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: _isScanning ? null : _startAndroidScan,
                  child: Text(_isScanning ? 'Taranıyor...' : 'Yeni Tarama Başlat')
                )
              ),
            )
          ]
        ],
      ),
    );
  }
}

// ==========================================
// TEK OYUNCULU MOD (YEREL SİMÜLATÖR)
// ==========================================
class SimulationScreen extends StatefulWidget {
  final int currentHighScore;
  final int currentBestTime;
  final bool isAudioOnly;

  const SimulationScreen({super.key, required this.currentHighScore, required this.currentBestTime, required this.isAudioOnly});

  @override
  State<SimulationScreen> createState() => _SimulationScreenState();
}

class _SimulationScreenState extends State<SimulationScreen> {
  int _highScore = 0;
  int _bestTime = 999999;
  int _level = 1;
  int _lives = 3;
  List<int> _sequence = [];
  int _userStepIndex = 0;

  bool _isPlayingSequence = false;
  bool _isTutorialPlaying = false;
  bool _isGameStarted = false;

  int _activeButtonIndex = -1;
  String _statusMessage = "";

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _uiTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Color> _buttonColors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.amberAccent];
  final List<double> _noteFrequencies = [262.0, 294.0, 392.0, 440.0];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _highScore = widget.currentHighScore;
    _bestTime = widget.currentBestTime;
    _statusMessage = widget.isAudioOnly ? "Zor Mod: Önce sesleri öğreneceksiniz." : "Işıkları ve ses frekanslarını takip et.";
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _stopwatch.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBuzzer(double freq, int durationMs) async {
    final Uint8List wavBytes = _generateWav(freq, durationMs);
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(wavBytes));
  }

  void _startGame() async {
    _stopwatch.reset();
    _uiTimer?.cancel();
    setState(() { _isGameStarted = true; _level = 1; _lives = 3; _sequence.clear(); });

    if (widget.isAudioOnly) {
      await _playTutorialSequence();
    }

    _stopwatch.start();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (timer) { if (mounted) setState(() {}); });
    _nextLevelPreparation();
  }

  Future<void> _playTutorialSequence() async {
    setState(() { _isTutorialPlaying = true; _statusMessage = "Sesleri Öğrenin..."; });
    await Future.delayed(const Duration(milliseconds: 500));

    for (int i = 0; i < 4; i++) {
      if (!mounted) return;
      setState(() => _activeButtonIndex = i);
      await _playBuzzer(_noteFrequencies[i], 600);
      await Future.delayed(const Duration(milliseconds: 600));
      setState(() => _activeButtonIndex = -1);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    setState(() { _statusMessage = "Oyun Başlıyor..."; _isTutorialPlaying = false; });
    await Future.delayed(const Duration(milliseconds: 800));
  }

  void _nextLevelPreparation() {
    int steps = _level < 7 ? _level + 2 : 8;
    _sequence.clear();
    for (int i = 0; i < steps; i++) { _sequence.add(_random.nextInt(4)); }
    _playSequence();
  }

  Future<void> _playSequence() async {
    setState(() { _isPlayingSequence = true; _userStepIndex = 0; _statusMessage = "Sıralama Oynatılıyor..."; });
    await Future.delayed(const Duration(milliseconds: 1000));

    int speedMs = max(200, 900 - (_level * 65));

    for (int buttonIndex in _sequence) {
      if (!mounted) return;
      if (!widget.isAudioOnly) setState(() => _activeButtonIndex = buttonIndex);

      await _playBuzzer(_noteFrequencies[buttonIndex], speedMs - 40);
      await Future.delayed(Duration(milliseconds: speedMs));
      setState(() => _activeButtonIndex = -1);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    setState(() { _isPlayingSequence = false; _statusMessage = "Senin Sıran!"; });
  }

  void _onButtonPressStart(int index) {
    if (_isPlayingSequence || _isTutorialPlaying || !_isGameStarted) return;
    setState(() => _activeButtonIndex = index);
    _playBuzzer(_noteFrequencies[index], 2000);
  }

  void _onButtonPressEnd(int index) {
    if (_isPlayingSequence || _isTutorialPlaying || !_isGameStarted || _activeButtonIndex != index) return;
    setState(() => _activeButtonIndex = -1);
    Future.delayed(const Duration(milliseconds: 50), () => _audioPlayer.stop());
    _handleButtonPress(index);
  }

  void _handleButtonPress(int index) {
    if (index == _sequence[_userStepIndex]) {
      setState(() => _userStepIndex++);
      if (_userStepIndex == _sequence.length) {
        _playBuzzer(784.0, 300);
        setState(() { _level++; _statusMessage = "Kusursuz!"; });
        Future.delayed(const Duration(milliseconds: 1200), _nextLevelPreparation);
      }
    } else {
      _playBuzzer(150.0, 800);
      setState(() {
        _lives--;
        if (_lives > 0) {
          _statusMessage = "Hatalı! $_lives Can Kaldı.";
          Future.delayed(const Duration(milliseconds: 1200), _playSequence);
        } else {
          _stopwatch.stop();
          _uiTimer?.cancel();
          _statusMessage = "Oyun Bitti! Skor Seviyeniz: $_level";
          _isGameStarted = false;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isAudioOnly ? 'Zor (Ses Modu)' : 'Kolay (Klasik)')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blueGrey.withOpacity(0.2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text("Seviye: $_level", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text("Süre: ${_stopwatch.elapsed.inSeconds}s", style: const TextStyle(fontSize: 18, color: Colors.cyanAccent)),
                Text("Can: ${'❤️' * _lives}", style: const TextStyle(fontSize: 18)),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.symmetric(vertical: 20.0), child: Text(_statusMessage, style: const TextStyle(fontSize: 16, fontStyle: FontStyle.italic))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                itemCount: 4,
                itemBuilder: (context, index) {
                  bool isLit = _activeButtonIndex == index;
                  return GestureDetector(
                    onTapDown: (_) => _onButtonPressStart(index),
                    onTapUp: (_) => _onButtonPressEnd(index),
                    onTapCancel: () => _onButtonPressEnd(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 50),
                      decoration: BoxDecoration(
                        color: isLit ? _buttonColors[index] : _buttonColors[index].withOpacity(0.25),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isLit ? Colors.white : Colors.transparent, width: 3),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: (_isPlayingSequence || _isTutorialPlaying) ? null : _startGame,
                child: Text(!_isGameStarted ? 'Oyunu Başlat' : 'Yeniden Başlat')
              )
            ),
          )
        ],
      ),
    );
  }
}

// ==========================================
// LAN ÇOK OYUNCULU P2P YÖNETİCİSİ (TCP SOKET)
// ==========================================
class LocalP2PManager {
  ServerSocket? _serverSocket;
  Socket? _socket;

  Function(Map<String, dynamic>)? onDataReceived;
  Function()? onConnected;
  Function()? onDisconnected;

  Future<String> hostGame({int port = 4040}) async {
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _serverSocket!.listen((Socket clientSocket) {
        _socket = clientSocket;
        onConnected?.call();
        _listenToSocket();
      });

      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
      return "IP_BULUNAMADI";
    } catch (e) {
      return "HATA: $e";
    }
  }

  Future<bool> joinGame(String ipAddress, {int port = 4040}) async {
    try {
      _socket = await Socket.connect(ipAddress, port, timeout: const Duration(seconds: 5));
      onConnected?.call();
      _listenToSocket();
      return true;
    } catch (e) {
      return false;
    }
  }

  void _listenToSocket() {
    _socket!.listen(
      (List<int> data) {
        String decoded = utf8.decode(data);
        try {
          Map<String, dynamic> payload = jsonDecode(decoded);
          onDataReceived?.call(payload);
        } catch (e) {}
      },
      onDone: _cleanup,
      onError: (error) => _cleanup(),
    );
  }

  void sendPayload(Map<String, dynamic> data) {
    if (_socket != null) {
      String jsonStr = jsonEncode(data);
      _socket!.add(utf8.encode(jsonStr));
    }
  }

  void _cleanup() {
    _socket?.close();
    _serverSocket?.close();
    _socket = null;
    _serverSocket = null;
    onDisconnected?.call();
  }
}

// ==========================================
// LOBİ EKRANI (HOST/CLIENT BAĞLANTISI)
// ==========================================
class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final LocalP2PManager _p2pManager = LocalP2PManager();
  final TextEditingController _ipController = TextEditingController();

  String _hostIp = "";
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _p2pManager.onConnected = () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PingPongScreen(p2pManager: _p2pManager, isHost: _hostIp.isNotEmpty),
          ),
        );
      }
    };
  }

  void _startHosting() async {
    setState(() => _isConnecting = true);
    String ip = await _p2pManager.hostGame();
    setState(() { _hostIp = ip; _isConnecting = false; });
  }

  void _joinHost() async {
    if (_ipController.text.isEmpty) return;
    setState(() => _isConnecting = true);
    bool success = await _p2pManager.joinGame(_ipController.text.trim());
    if (!success && mounted) {
      setState(() => _isConnecting = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bağlantı Başarısız!")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LAN Çok Oyunculu Lobi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_hostIp.isNotEmpty) ...[
                const Text("Bağlantı Bekleniyor...", style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                Text("IP Adresin: $_hostIp", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                const SizedBox(height: 30),
                const CircularProgressIndicator(),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _startHosting,
                  icon: const Icon(Icons.router),
                  label: const Text("Oyun Kur (Host)"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const Padding(padding: EdgeInsets.symmetric(vertical: 24.0), child: Text("VEYA")),
                TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(labelText: "Kurucunun IP Adresi (Örn: 192.168.1.5)"),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _joinHost,
                  icon: const Icon(Icons.login),
                  label: const Text("Oyuna Katıl (Client)"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blueGrey),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// PING-PONG P2P OYUN EKRANI
// ==========================================
enum PingPongState { WAITING, WATCHING_OPPONENT, REPEATING, ADDING_NEW_STEP }

class PingPongScreen extends StatefulWidget {
  final LocalP2PManager p2pManager;
  final bool isHost;

  const PingPongScreen({super.key, required this.p2pManager, required this.isHost});

  @override
  State<PingPongScreen> createState() => _PingPongScreenState();
}

class _PingPongScreenState extends State<PingPongScreen> {
  PingPongState _currentState = PingPongState.WAITING;
  List<int> _currentSequence = [];
  int _userValidationIndex = 0;
  int _activeButtonIndex = -1;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<Color> _colors = [Colors.redAccent, Colors.blueAccent, Colors.greenAccent, Colors.amberAccent];
  final List<double> _freqs = [262.0, 294.0, 392.0, 440.0];

  @override
  void initState() {
    super.initState();
    widget.p2pManager.onDataReceived = _handleNetworkData;
    widget.p2pManager.onDisconnected = () {
      if (mounted) _showEndDialog("Bağlantı Koptu!");
    };

    if (widget.isHost) {
      _currentState = PingPongState.ADDING_NEW_STEP;
    } else {
      _currentState = PingPongState.WATCHING_OPPONENT;
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _handleNetworkData(Map<String, dynamic> payload) {
    if (payload['type'] == 'TURN') {
      _currentSequence = List<int>.from(payload['sequence']);
      _playOpponentSequence();
    } else if (payload['type'] == 'GAMEOVER') {
      _showEndDialog("KAZANDIN! Rakip yanlış butona bastı.");
    }
  }

  Future<void> _playLocalBuzzer(double freq, int durationMs) async {
    final Uint8List wavBytes = _generateWav(freq, durationMs);
    await _audioPlayer.stop();
    await _audioPlayer.play(BytesSource(wavBytes));
  }

  Future<void> _playOpponentSequence() async {
    setState(() { _currentState = PingPongState.WATCHING_OPPONENT; _userValidationIndex = 0; });
    await Future.delayed(const Duration(milliseconds: 800));

    for (int index in _currentSequence) {
      if (!mounted) return;
      setState(() => _activeButtonIndex = index);
      await _playLocalBuzzer(_freqs[index], 400);
      await Future.delayed(const Duration(milliseconds: 400));
      setState(() => _activeButtonIndex = -1);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    setState(() => _currentState = PingPongState.REPEATING);
  }

  void _handleUserTapStart(int index) {
    if (_currentState == PingPongState.WATCHING_OPPONENT || _currentState == PingPongState.WAITING) return;
    setState(() => _activeButtonIndex = index);
    _playLocalBuzzer(_freqs[index], 2000);
  }

  void _handleUserTapEnd(int index) {
    if (_currentState == PingPongState.WATCHING_OPPONENT || _currentState == PingPongState.WAITING) return;

    setState(() => _activeButtonIndex = -1);
    Future.delayed(const Duration(milliseconds: 50), () => _audioPlayer.stop());

    if (_currentState == PingPongState.REPEATING) {
      if (index == _currentSequence[_userValidationIndex]) {
        _userValidationIndex++;
        if (_userValidationIndex == _currentSequence.length) {
          setState(() => _currentState = PingPongState.ADDING_NEW_STEP);
        }
      } else {
        widget.p2pManager.sendPayload({"type": "GAMEOVER"});
        _showEndDialog("KAYBETTİN! Yanlış notaya bastın.");
      }
    } else if (_currentState == PingPongState.ADDING_NEW_STEP) {
      _currentSequence.add(index);
      widget.p2pManager.sendPayload({"type": "TURN", "sequence": _currentSequence});
      setState(() => _currentState = PingPongState.WATCHING_OPPONENT);
    }
  }

  void _showEndDialog(String msg) {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Oyun Bitti", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Lobiye Dön")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    String status = "";
    switch (_currentState) {
      case PingPongState.WAITING: status = "Bağlantı Kuruluyor..."; break;
      case PingPongState.WATCHING_OPPONENT: status = "Rakip Oynuyor..."; break;
      case PingPongState.REPEATING: status = "Diziyi Tekrarla (${_userValidationIndex}/${_currentSequence.length})"; break;
      case PingPongState.ADDING_NEW_STEP: status = "Diziye 1 Adım Ekle!"; break;
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.isHost ? "Host (Kurucu)" : "Client (Katılımcı)")),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blueGrey.withOpacity(0.2),
            child: Center(
              child: Text(status, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
            ),
          ),
          Expanded(s
            child: GridView.builder(
              padding: const EdgeInsets.all(32),
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 20, mainAxisSpacing: 20
              ),
              itemCount: 4,
              itemBuilder: (context, index) {
                bool isLit = _activeButtonIndex == index;
                return GestureDetector(
                  onTapDown: (_) => _handleUserTapStart(index),
                  onTapUp: (_) => _handleUserTapEnd(index),
                  onTapCancel: () => _handleUserTapEnd(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    decoration: BoxDecoration(
                      color: isLit ? _colors[index] : _colors[index].withOpacity(0.25),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isLit ? Colors.white : Colors.transparent, width: 3),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
