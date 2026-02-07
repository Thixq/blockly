/// WebSocketService, WebSocket bağlantılarını yönetmek için tasarlanmış bir servis sınıfıdır.
/// Bağlantı durumunu izler, mesajları işler ve otomatik yeniden bağlanma mekanizması sağlar.
enum SocketStatus {
  /// Bağlantı kuruluyor
  connecting,

  /// Bağlantı başarılı
  connected,

  /// Bağlantı kesildi
  disconnected,

  /// Yeniden bağlanma sürecinde
  reconnecting,
}
