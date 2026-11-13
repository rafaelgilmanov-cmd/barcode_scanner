import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Сканер кодов',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class ScanEntry {
  final String value;
  final String type;
  final DateTime time;

  ScanEntry({required this.value, required this.type, DateTime? time}) : time = time ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'value': value,
        'type': type,
        'time': time.toIso8601String(),
      };

  factory ScanEntry.fromJson(Map<String, dynamic> j) => ScanEntry(
        value: j['value'] as String,
        type: j['type'] as String,
        time: DateTime.parse(j['time'] as String),
      );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<ScanEntry> _history = [];
  String _searchQuery = '';
  static const String _prefsKey = 'scan_history';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    setState(() {
      _history
        ..clear()
        ..addAll(list.map((e) => ScanEntry.fromJson(e as Map<String, dynamic>)));
    });
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_history.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, raw);
  }

  Future<void> _addEntry(String value, String type) async {
    setState(() {
      _history.insert(0, ScanEntry(value: value, type: type));
    });
    await _saveHistory();
  }

  Future<void> _clearHistory() async {
    setState(() => _history.clear());
    await _saveHistory();
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<ScanEntry>(
      MaterialPageRoute(builder: (_) => const ScannerPage()),
    );
    if (result != null) {
      await _addEntry(result.value, result.type);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Код добавлен в историю')),
      );
    }
  }

  Future<void> _openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  bool _isUrl(String text) {
    final uri = Uri.tryParse(text);
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  // Окно с деталями кода
  void _showDetails(ScanEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isUrl = _isUrl(entry.value);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Детали кода', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SelectableText(
                entry.value, 
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text('Тип: ${entry.type}', style: const TextStyle(color: Colors.grey)),
              Text('Время: ${_formatTime(entry.time)}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              
              if (isUrl)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Открыть ссылку в браузере'),
                  onPressed: () {
                    Navigator.pop(context);
                    _openLink(entry.value);
                  },
                ),
              if (isUrl) const SizedBox(height: 12),
              
              FilledButton.tonalIcon(
                icon: const Icon(Icons.copy),
                label: const Text('Скопировать'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: entry.value));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Скопировано')),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredHistory = _history
        .where((e) => e.value.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Сканер кодов'),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Очистить историю',
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск по истории...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
              ),
            ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner,
                            size: 96, color: Colors.indigo.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                          _history.isEmpty ? 'История пуста' : 'Ничего не найдено',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredHistory.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final e = filteredHistory[i];
                      final isUrl = _isUrl(e.value);
                      
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          onTap: () => _showDetails(e), // Нажатие на карточку
                          leading: CircleAvatar(
                            backgroundColor: Colors.indigo.withValues(alpha: 0.1),
                            child: Icon(
                              isUrl ? Icons.link : Icons.qr_code, 
                              color: Colors.indigo
                            ),
                          ),
                          title: Text(e.value, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('${e.type} · ${_formatTime(e.time)}'),
                          trailing: IconButton(
                            icon: const Icon(Icons.copy),
                            tooltip: 'Копировать',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: e.value));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Скопировано')),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Сканировать'),
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.day)}.${two(t.month)}.${t.year} ${two(t.hour)}:${two(t.minute)}';
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first;
    final raw = code.rawValue;
    if (raw == null || raw.isEmpty) return;
    _handled = true;
    Navigator.of(context).pop(
      ScanEntry(value: raw, type: code.format.name.toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Наведите на код'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}