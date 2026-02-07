// ignore_for_file: avoid_catches_without_on_clauses, document_ignores

import 'dart:async';
import 'dart:convert';

import 'dart:isolate'; // Isolate için gerekli

import 'package:blockly/core/logging/custom_logger.dart';
import 'package:blockly/feature/enums/socket_status_enum.dart';
import 'package:meta/meta.dart'; // For @visibleForTesting
import 'package:web_socket_channel/status.dart' as status;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Kanal oluşturucu fonksiyon tipi (Test edilebilirlik için)
typedef WebSocketChannelFactory = WebSocketChannel Function(Uri uri);

/// Gelen veriyi modele çeviren fonksiyon tipi
typedef Parser<T> = T Function(Map<String, dynamic> json);

/// WebSocketService, WebSocket bağlantılarını yönetmek için tasarlanmış generic bir servis sınıfıdır.
/// [T] tipi, socket üzerinden gelecek veri modelini temsil eder.
class WebSocketService<T> {
  /// Factory Constructor: İstenen T tipi için daha önce üretilmiş bir servis varsa onu döner,
  /// yoksa yenisini üretip havuza ekler ve onu döner.
  factory WebSocketService() {
    return _instances.putIfAbsent(T, WebSocketService<T>._internal)
        as WebSocketService<T>;
  }

  /// Private Constructor
  WebSocketService._internal();
  // --- Managed Pool (Multiton Pattern) ---
  static final Map<Type, WebSocketService<dynamic>> _instances = {};

  /// Test amaçlı instance sıfırlama metodu (Test tarafında kullanılıyor)
  @visibleForTesting
  static void resetInstance() {
    for (final instance in _instances.values) {
      // Disconnect tetikle
      instance.disconnect();
    }
    _instances.clear();
  }

  /// Gelen veriyi işleyecek parser
  Parser<T>? _parser;

  /// Parser'ı dışarıdan set etmek için kullanılan metot.
  /// Bağlantı öncesi mutlaka çağrılmalıdır.
  void setParser(Parser<T> parser) {
    _parser = parser;
  }

  /// Testlerde kullanılmak üzere mock kanal üreticisi
  @visibleForTesting
  WebSocketChannelFactory? channelFactory;

  final _logger = CustomLogger('WebSocketService');
  WebSocketChannel? _channel;
  SocketStatus _status = SocketStatus.disconnected;
  String? _lastUrl;

  // Yeniden bağlanma için üstel geri çekilme değişkenleri
  int _retryCount = 0;
  final int _maxRetryDelaySeconds = 60;
  Timer? _reconnectTimer; // Timer referansını tutuyoruz

  // Heartbeat (Kalp Atışı) yönetimi
  Timer? _heartbeatTimer;

  static const Duration _heartbeatInterval = Duration(
    seconds: 30,
  ); // 5 dakikalık zaman aşımını önlemek için idealdir.

  // UI'ın bağlantı durumunu dinleyebilmesi için StreamController
  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  /// Bağlantı durumunu dinleyebileceğiniz akış. UI, bu akışı dinleyerek bağlantı durumuna göre tepki verebilir (örneğin, yeniden bağlanma göstergesi).
  Stream<SocketStatus> get statusStream => _statusController.stream;

  // Gelen mesajların dinlenebileceği ana akış
  final StreamController<T> _messageController =
      StreamController<T>.broadcast();

  /// Gelen mesajların dinlenebileceği ana akış
  Stream<T> get messages => _messageController.stream;

  // Stream subscription referansı
  StreamSubscription<dynamic>? _subscription;

  /// WebSocket sunucusuna bağlanır. Bağlantı durumunu yönetir ve mesajları işler.
  Future<void> connect(String url) async {
    _lastUrl = url;

    if (_parser == null) {
      _logger.error('Parser not set! Call setParser() before connecting.');
      throw StateError(
        'Parser not set. You must call setParser() before connecting.',
      );
    }

    if (_status == SocketStatus.connected ||
        _status == SocketStatus.connecting) {
      _logger.warning('Already connected or connecting to $url');
      return;
    }

    _updateStatus(SocketStatus.connecting);
    _logger.info('Connecting to $url');

    try {
      // Platform bağımsız bağlantı (Mobile/Web uyumlu)
      // Test edilebilirlik için factory kullanıyoruz
      if (channelFactory != null) {
        _channel = channelFactory!(Uri.parse(url));
      } else {
        _channel = WebSocketChannel.connect(Uri.parse(url));
      }

      // Bağlantı hazır olduğunda dinlemeye başla
      await _channel!.ready
          .then((_) {
            _onConnected();
          })
          .catchError((Object? e) {
            _logger.error('Failed to establish connection', error: e);
            _handleDisconnect();
          });

      // Eski subscription varsa iptal et
      await _subscription?.cancel();
      _subscription = _channel!.stream.listen(
        _onMessageReceived,
        onDone: _handleDisconnect,
        onError: (Object? error) {
          _logger.error('Stream error occurred', error: error);
          _handleDisconnect();
        },
      );
    } catch (e, s) {
      _logger.error(
        'Unexpected error during connection',
        error: e,
        stackTrace: s,
      );
      _handleDisconnect();
    }
  }

  void _onConnected() {
    _logger.info('Connection established successfully');
    _updateStatus(SocketStatus.connected);
    _retryCount = 0; // Başarılı bağlantıda sayacı sıfırla
    _startHeartbeat(); // Aktif tutma mekanizmasını başlat
  }

  // Uygulama seviyesinde ping (Web ve Proxy zaman aşımları için kritik) [5, 9]
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      send(jsonEncode({'type': 'ping'}));
    });
  }

  Future<void> _onMessageReceived(dynamic message) async {
    if (_messageController.isClosed) return;

    try {
      // Gelen veriyi işle (String veya byte listesi olabilir)
      String payload;
      if (message is String) {
        payload = message;
      } else if (message is List<int>) {
        payload = utf8.decode(message);
      } else {
        return;
      }

      // Isolate.run kullanarak parse işlemini arka planda yap
      // Bu, UI thread'ini bloklamadan büyük JSON'ları işlemeyi sağlar.
      final jsonMap = await Isolate.run(() {
        final decoded = jsonDecode(payload);
        return decoded;
      });

      if (_messageController.isClosed) return;

      if (jsonMap is Map && jsonMap['type'] == 'pong') {
        return;
      }

      // Parser fonksiyonu ile veriyi işle
      // Not: Parser hafifse UI thread'de çalışabilir.
      // Eğer çok ağır bir mapping işlemi varsa bunu da Isolate'e taşımak gerekebilir,
      // ancak closure kısıtlamaları yüzünden dikkatli olunmalı.
      if (_parser != null) {
        final data = _parser!(jsonMap as Map<String, dynamic>);
        _messageController.add(data);
      }
    } catch (e, s) {
      if (_messageController.isClosed) return;
      _logger.error('Error parsing incoming message', error: e, stackTrace: s);
    }
  }

  /// WebSocket üzerinden mesaj gönderir. Bağlantı durumunu kontrol eder ve uygun şekilde loglar.
  void send(dynamic message) {
    if (_status == SocketStatus.connected) {
      _channel?.sink.add(message);
    } else {
      _logger.warning('Attempted to send message while disconnected');
    }
  }

  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _updateStatus(SocketStatus.disconnected);
    _scheduleReconnect();
  }

  // Üstel Geri Çekilme Algoritması (Exponential Backoff)
  void _scheduleReconnect() {
    _updateStatus(SocketStatus.reconnecting);
    _retryCount++;

    // Gecikme süresi: 1s, 2s, 4s, 8s... (max 60s)
    final delay = (_retryCount * _retryCount).clamp(1, _maxRetryDelaySeconds);

    _logger.info('Reconnecting in $delay seconds...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (_lastUrl != null) {
        unawaited(connect(_lastUrl!));
      }
    });
  }

  void _updateStatus(SocketStatus newStatus) {
    if (_statusController.isClosed) return;
    _status = newStatus;
    _statusController.add(_status);
  }

  /// Bağlantıyı manuel olarak kapatır (Reconnect tetiklenmez).
  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    // onDone tetiklenmemesi için önce dinlemeyi durduruyoruz.
    await _subscription?.cancel();
    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
    _updateStatus(SocketStatus.disconnected);
    _logger.info('Disconnected manually');
  }

  /// Servisi tamamen kapatır ve kaynakları temizler (Streamler kapanır).
  void dispose() {
    // Havuzdan bu tipi çıkar
    _instances.remove(T);
    unawaited(disconnect());
    unawaited(_statusController.close());
    unawaited(_messageController.close());
  }
}
