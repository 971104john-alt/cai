import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MedBoxApp extends StatelessWidget {
  const MedBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 智慧藥盒',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ESP32 IP 位址（支援 STA 模式區域網路 IP 或 AP 模式預設 IP 如 192.168.4.1）
  final TextEditingController _ipController = TextEditingController(text: '192.168.4.1');
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isBoxOpen = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 8, minute: 0);

  // 1. 測試 ESP32 連線狀態
// 1. 測試 ESP32 連線狀態（改成呼叫根目錄 /）
  Future<void> _checkConnection() async {
    setState(() => _isConnecting = true);
    final ip = _ipController.text.trim();
    
    try {
      final response = await http
          .get(Uri.parse('http://$ip/')) // 呼叫 ESP32 的根目錄
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() => _isConnected = true);
        _showSnackBar('成功連線至 ESP32 藥盒！', isError: false);
      } else {
        setState(() => _isConnected = false);
        _showSnackBar('無法連線：HTTP ${response.statusCode}', isError: true);
      }
    } catch (e) {
      setState(() => _isConnected = false);
      _showSnackBar('連線失敗，請檢查 IP 或 Wi-Fi 連線', isError: true);
    } finally {
      setState(() => _isConnecting = false);
    }
  }
  // 2. 開關藥盒指令
  Future<void> _toggleBox(bool open) async {
    final ip = _ipController.text.trim();
    final action = open ? 'open' : 'close';
    
    try {
      final response = await http
          .get(Uri.parse('http://$ip/box?action=$action'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() => _isBoxOpen = open);
        _showSnackBar(open ? '已開啟藥盒' : '已關閉藥盒', isError: false);
      } else {
        _showSnackBar('指令傳送失敗', isError: true);
      }
    } catch (e) {
      _showSnackBar('傳送失敗，請確認與 ESP32 的連線', isError: true);
    }
  }

  // 3. 設定服藥提醒時間
  Future<void> _setAlarmTime() async {
    final ip = _ipController.text.trim();
    final hour = _selectedTime.hour.toString().padLeft(2, '0');
    final minute = _selectedTime.minute.toString().padLeft(2, '0');

    try {
      final response = await http
          .get(Uri.parse('http://$ip/set_alarm?time=$hour:$minute'))
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _showSnackBar('服藥提醒時間已成功設定為 $hour:$minute', isError: false);
      } else {
        _showSnackBar('設定失敗', isError: true);
      }
    } catch (e) {
      _showSnackBar('傳送時間設定失敗，請檢查連線', isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.teal,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ESP32 智慧藥盒控制台', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 連線設定卡片 ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.wifi_sharp : Icons.wifi_off_sharp,
                          color: _isConnected ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isConnected ? '連線狀態：已連線' : '連線狀態：未連線',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _isConnected ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ipController,
                      decoration: const InputDecoration(
                        labelText: 'ESP32 IP 位址 / 熱點網址',
                        hintText: '例如：192.168.4.1',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.router),
                      ),
                      keyboardType: TextInputType.datetime,
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isConnecting ? null : _checkConnection,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: _isConnecting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(_isConnecting ? '連線測試中...' : '測試連線'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- 藥盒控制卡片 ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '藥盒手動控制',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleBox(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade100,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.lock_open, color: Colors.teal),
                            label: const Text('開啟藥盒', style: TextStyle(color: Colors.teal)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _toggleBox(false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.lock, color: Colors.black87),
                            label: const Text('關閉藥盒', style: TextStyle(color: Colors.black87)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- 服藥時間提醒卡片 ---
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '服藥提醒設定',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      leading: const Icon(Icons.alarm, color: Colors.teal, size: 32),
                      title: const Text('預設服藥時間'),
                      subtitle: Text(
                        _selectedTime.format(context),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      trailing: TextButton(
                        onPressed: () async {
                          final TimeOfDay? newTime = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (newTime != null) {
                            setState(() => _selectedTime = newTime);
                          }
                        },
                        child: const Text('選擇時間'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _setAlarmTime,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.send),
                      label: const Text('同步時間設定至 ESP32'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}