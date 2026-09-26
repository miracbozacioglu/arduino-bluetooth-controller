import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ekranı yatay (landscape) kullanıma zorluyoruz
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arduino BT Kumanda',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1E1E2C),
        primaryColor: Colors.blueAccent,
      ),
      debugShowCheckedModeBanner: false,
      home: const BluetoothKumandaEkrani(),
    );
  }
}

class BluetoothKumandaEkrani extends StatefulWidget {
  const BluetoothKumandaEkrani({super.key});

  @override
  State<BluetoothKumandaEkrani> createState() => _BluetoothKumandaEkraniState();
}

class _BluetoothKumandaEkraniState extends State<BluetoothKumandaEkrani> {
  // Varsayılan komut harfleri
  String cmdF = 'F'; // İleri
  String cmdB = 'B'; // Geri
  String cmdL = 'L'; // Sol
  String cmdR = 'R'; // Sağ
  String cmdS = 'S'; // Dur

  BluetoothConnection? connection;
  BluetoothDevice? selectedDevice;
  bool isConnected = false;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    _izinleriAl();
  }

  // Android için gerekli donanım izinlerini talep et
  Future<void> _izinleriAl() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  // Eşleşmiş cihazları listele ve seçim menüsü (Dialog) göster
  void _cihazSecimMenusuAc() async {
    List<BluetoothDevice> devices = [];
    try {
      devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint("Cihaz listesi alınamadı: $e");
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Eşleşmiş Cihazlar"),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: devices.length,
              itemBuilder: (context, index) {
                BluetoothDevice device = devices[index];
                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(device.name ?? device.address),
                  subtitle: Text(device.address),
                  onTap: () {
                    Navigator.pop(context);
                    _baglan(device);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
          ],
        );
      },
    );
  }

  // Seçilen cihaza (Arduino) bağlan
  void _baglan(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
    });

    try {
      BluetoothConnection conn = await BluetoothConnection.toAddress(device.address);
      setState(() {
        connection = conn;
        isConnected = true;
        selectedDevice = device;
        isConnecting = false;
      });
      _mesajGoster("${device.name} başarıyla bağlandı!");
    } catch (e) {
      setState(() {
        isConnecting = false;
      });
      _mesajGoster("Bağlantı hatası: Modülün açık olduğundan emin olun.");
    }
  }

  // Bluetooth üzerinden karakter gönder
  void _komutGonder(String komut) async {
    if (connection != null && connection!.isConnected) {
      connection!.output.add(Uint8List.fromList(utf8.encode(komut)));
      await connection!.output.allSent;
      debugPrint("Gönderilen: $komut");
    } else {
      _mesajGoster("Önce cihaza bağlanmalısınız!");
    }
  }

  // Bağlantıyı kes
  void _baglantiyiKes() {
    connection?.dispose();
    setState(() {
      connection = null;
      isConnected = false;
      selectedDevice = null;
    });
    _mesajGoster("Bağlantı kesildi.");
  }

  // Bildirim gösterme aracı
  void _mesajGoster(String mesaj) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mesaj), duration: const Duration(seconds: 2)),
    );
  }

  // Komutları düzenleme ekranı
  void _ayarlarMenusuAc() {
    TextEditingController fCtrl = TextEditingController(text: cmdF);
    TextEditingController bCtrl = TextEditingController(text: cmdB);
    TextEditingController lCtrl = TextEditingController(text: cmdL);
    TextEditingController rCtrl = TextEditingController(text: cmdR);
    TextEditingController sCtrl = TextEditingController(text: cmdS);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Sinyal Harflerini Değiştir"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: fCtrl, decoration: const InputDecoration(labelText: "İleri (Forward)")),
                TextField(controller: bCtrl, decoration: const InputDecoration(labelText: "Geri (Backward)")),
                TextField(controller: lCtrl, decoration: const InputDecoration(labelText: "Sol (Left)")),
                TextField(controller: rCtrl, decoration: const InputDecoration(labelText: "Sağ (Right)")),
                TextField(controller: sCtrl, decoration: const InputDecoration(labelText: "Dur (Stop)")),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  cmdF = fCtrl.text.isNotEmpty ? fCtrl.text : cmdF;
                  cmdB = bCtrl.text.isNotEmpty ? bCtrl.text : cmdB;
                  cmdL = lCtrl.text.isNotEmpty ? lCtrl.text : cmdL;
                  cmdR = rCtrl.text.isNotEmpty ? rCtrl.text : cmdR;
                  cmdS = sCtrl.text.isNotEmpty ? sCtrl.text : cmdS;
                });
                Navigator.pop(context);
                _mesajGoster("Komut harfleri güncellendi.");
              },
              child: const Text("Kaydet"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    connection?.dispose();
    super.dispose();
  }

  // Yön tuşlarını üreten şablon
  Widget _yonTusuOlustur(IconData icon, String komut) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ElevatedButton(
        onPressed: () => _komutGonder(komut),
        style: ElevatedButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(24),
          backgroundColor: const Color(0xFF2B2B40),
          foregroundColor: Colors.white,
          elevation: 5,
        ),
        child: Icon(icon, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // 1. SOL TARAF: YÖN TUŞLARI (D-PAD)
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _yonTusuOlustur(Icons.keyboard_arrow_up, cmdF), // İleri
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _yonTusuOlustur(Icons.keyboard_arrow_left, cmdL), // Sol
                      const SizedBox(width: 60), // Ortayı boş bırak
                      _yonTusuOlustur(Icons.keyboard_arrow_right, cmdR), // Sağ
                    ],
                  ),
                  _yonTusuOlustur(Icons.keyboard_arrow_down, cmdB), // Geri
                ],
              ),
            ),

            // 2. ORTA KISIM: BLUETOOTH VE AYARLAR
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF252538),
                  borderRadius: BorderRadius.circular(20),
                ),
                margin: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.greenAccent : Colors.grey,
                      size: 60,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isConnected ? (selectedDevice?.name ?? "Bağlı") : "Bağlantı Yok",
                      style: TextStyle(
                        fontSize: 18,
                        color: isConnected ? Colors.greenAccent : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (isConnecting)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.cable),
                        label: Text(isConnected ? "Bağlantıyı Kes" : "Cihaza Bağlan"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isConnected ? Colors.redAccent : Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onPressed: isConnected ? _baglantiyiKes : _cihazSecimMenusuAc,
                      ),
                    const SizedBox(height: 20),
                    IconButton(
                      icon: const Icon(Icons.settings, size: 30),
                      color: Colors.white70,
                      tooltip: "Sinyal Harflerini Ayarla",
                      onPressed: _ayarlarMenusuAc,
                    )
                  ],
                ),
              ),
            ),

            // 3. SAĞ TARAF: BÜYÜK DUR BUTONU
            Expanded(
              flex: 2,
              child: Center(
                child: InkWell(
                  onTap: () => _komutGonder(cmdS),
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red[700],
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        "DUR",
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}