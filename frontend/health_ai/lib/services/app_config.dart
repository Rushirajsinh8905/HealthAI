// ============================================================
// APP CONFIG — single place to change backend URL
// ============================================================
//
// Android Emulator  → http://10.0.2.2:8000
// iOS Simulator     → http://127.0.0.1:8000
// Real Device (APK) → http://<YOUR_WIFI_IP>:8000
//                     Find your Mac's IP:
//                       Mac: System Preferences → Wi-Fi → Details, or run:
//                            ifconfig | grep "inet " | grep -v 127
//                       Windows: ipconfig | find "IPv4"
//
// ⚠️  IMPORTANT: When building APK for a real phone, set this to your
//     Mac's LOCAL Wi-Fi IP (e.g. http://192.168.1.5:8000).
//     The emulator IP 10.0.2.2 does NOT work on real devices!
// ============================================================

// Example: const String kApiBaseUrl = 'http://192.168.1.5:8000';
const String kApiBaseUrl =
    'http://10.31.224.28:8000'; // Your Mac's Wi-Fi IP — works on real device
