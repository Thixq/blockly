**Türkçe** | [English](README.md)

# Blockly — Real-Time Cryptocurrency Tracker

Binance API üzerinden **1500+ coin**'in anlık fiyatlarını izleyen, yüksek performanslı Flutter uygulaması.

REST API ile ilk snapshot alınır, ardından WebSocket üzerinden gerçek zamanlı fiyat güncellemeleri gelir. Tüm JSON parsing işlemleri **background isolate**'larda yapılır; UI thread hiçbir zaman bloklanmaz.

---

## Mimari Genel Bakış

``` text
.env (Env) ──► DioConfig ──► Dio
                                │
                    DependencyContainer (GetIt)
                   ┌────────────┴────────────┐
                   ▼                         ▼
              DioService              WebSocketService<MiniTicker>
                   │                         │
                   │ REST /ticker/24hr       │ WSS !miniTicker@arr
                   │ (JsonStreamParser       │ (WebSocketIsolateParser
                   │  in isolate)            │  in isolate)
                   └──────────┬──────────────┘
                              ▼
                        MarketManager
                   ┌──── (throttle 1s) ─────┐
                   │  _tickerMap (snapshot) │
                   │  + real-time merge     │
                   └─────────┬──────────────┘
                             ▼
                    Stream<MarketState>
                   ┌─────────┴──────────┐
                   ▼                    ▼
            HomeViewModel        CoinDetailViewModel
             (Provider)            (Provider)
                   │                    │
          ┌────────┴─────┐              ▼
          ▼              ▼        CoinDetailView
       HomeView    SmartCoinRow    ├─ PriceSection
      (search)   (per-coin stream) ├─ DetailGrid
                                   └─ DetailCard
```

---

## Klasör Yapısı

``` text
lib/
├── main.dart                          # Uygulama giriş noktası
├── core/
│   ├── extensions/
│   │   ├── context_extension.dart     # Theme shortcut'ları (colorScheme, textTheme)
│   │   └── num_extension.dart         # Yüzdelik ekran boyutu hesaplama
│   └── logging/
│       ├── custom_logger.dart         # Modül bazlı logger wrapper
│       ├── log_manager.dart           # Root logger konfigürasyonu
│       └── zone_manager.dart          # Global hata yakalama (runZonedGuarded)
├── feature/
│   ├── const/
│   │   └── url_const.dart             # API endpoint sabitleri
│   ├── enums/
│   │   └── socket_status_enum.dart    # WebSocket bağlantı durumları
│   ├── env/
│   │   └── env.dart                   # Obfuscated ortam değişkenleri (envied)
│   ├── init/
│   │   ├── dependency_container.dart  # GetIt DI konfigürasyonu
│   │   └── dependency_instances.dart  # DI erişim facade'ı
│   ├── managers/
│   │   ├── market_manager.dart        # REST + WebSocket veri orkestratörü
│   │   └── market_state.dart          # Immutable state nesnesi (Equatable)
│   ├── models/
│   │   ├── coin_ticker.dart           # 24h ticker modeli (21 alan)
│   │   └── mini_ticker.dart           # WebSocket mini ticker modeli
│   └── services/
│       ├── json_parser/
│       │   ├── json_stream_parser.dart         # REST response isolate parser
│       │   └── websocket_isolate_parser.dart   # WebSocket isolate parser
│       ├── network/
│       │   ├── dio_config.dart         # Dio instance konfigürasyonu
│       │   └── dio_service.dart        # HTTP istemci (streaming destekli)
│       └── web_socket/
│           └── web_socket_service.dart # WebSocket yaşam döngüsü yönetimi
└── views/
    ├── home/
    │   ├── view/
    │   │   └── home_view.dart          # Ana ekran (arama + coin listesi)
    │   ├── view_model/
    │   │   └── home_view_model.dart    # Ana ekran state yönetimi
    │   └── widgets/
    │       └── smart_coin_row.dart     # Kendi stream'ine abone satır widget'ı
    └── coin_detail/
        ├── view/
        │   └── coin_detail_view.dart   # Detay ekranı
        ├── view_model/
        │   └── coin_detail_view_model.dart  # Detay state yönetimi
        └── widgets/
            ├── detail_card.dart        # Tekil bilgi kartı
            ├── detail_grid.dart        # 2 sütunlu istatistik grid'i
            └── price_section.dart      # Fiyat ve değişim yüzdesi
```

---

## Katman Detayları

### 1. Data Layer — Servisler

#### DioService

- `request<T>()` — Standart JSON-parsed HTTP istekleri.
- `requestStreaming<T>()` — Büyük JSON yanıtlarını `ResponseType.plain` olarak alır, **`JsonStreamParser`** ile background isolate'da chunk'lar halinde parse eder. 1500+ coin'lik snapshot'u main thread'i bloklamadan yükler.

#### WebSocketService\<T\>

- **Generic** tasarım — herhangi bir model tipiyle kullanılabilir.
- **Constructor injection** — `parser` ve `manuellyRetry` parametreleri constructor'da alınır.
- **Isolate parsing** — `useIsolate: true` ile mesajlar `WebSocketIsolateParser`'a yönlendirilir.
- **Exponential backoff** — Bağlantı koptuğunda 1s, 4s, 9s... şeklinde artan gecikmelerle yeniden bağlanır (max 60s).
- **Heartbeat** — 5 saniye veri gelmezse bağlantıyı ölü kabul eder ve reconnect başlatır.
- **Manuel retry modu** — `manuellyRetry: true` iken otomatik reconnect devre dışı, kullanıcı tetikler.
- **Status stream** — `connecting → connected → disconnected → reconnecting` durumlarını yayınlar.

#### WebSocketIsolateParser\<T\>

- Uzun ömürlü background **Dart isolate**.
- JSON array'ler için **karakter-karakter tarama** — tüm array'i belleğe almadan item'ları tek tek parse eder.
- Configurable chunk size (varsayılan 100 item/batch).
- `SendPort`/`ReceivePort` handshake pattern ile main thread ile haberleşir.

### 2. Domain Layer — Manager

#### MarketManager

- **Veri akışı orkestratörü** — REST snapshot + WebSocket real-time güncellemeleri birleştirir.
- **Throttle mekanizması** — WebSocket güncellemelerini `_pendingUpdates` map'inde biriktirir, **1 saniyede bir** toplu olarak `_tickerMap`'e merge eder.
- **`marketStream`** — `Stream<MarketState>` yayınlar. `MarketState` hem tüm ticker listesini hem de son batch'te değişen symbol'leri içerir.
- **`getCoinStream(symbol)`** — Belirli bir coin için filtrelenmiş stream. `.distinct()` ile gereksiz emission'lar engellenir.
- **`socketStatusStream`** — WebSocket bağlantı durumunu UI'a expose eder.
- **`copyWithMiniTicker()`** — Mini ticker verisini ana ticker'a merge ederken `priceChange` ve `priceChangePercent` değerlerini **yeniden hesaplar**, tutarsızlığı önler.

### 3. Presentation Layer — MVVM + Provider

#### HomeViewModel

- `HomeViewState` enum: `loading → loaded → disconnected → error`
- `marketStream`'i dinler, sadece **snapshot emission** veya **state değişikliğinde** `notifyListeners()` çağırır.
- Fiyat güncellemeleri `SmartCoinRow` tarafından doğrudan handle edilir — ViewModel'i tetiklemez.
- Socket status stream'ini dinleyerek bağlantı kopması durumunda `disconnected` state'ine geçer.
- `updateSearchText()` ile filtreleme (varsayılan: `"TRY"`).

#### SmartCoinRow

- **Per-widget stream subscription** — `MarketManager.getCoinStream(symbol)` ile sadece kendi coin'inin güncellemelerini dinler.
- Parent ViewModel'den bağımsız çalışır. Sadece ilgili satır rebuild olur.
- Tick-bazlı renk karşılaştırması (yeşil/kırmızı).

#### DetailGrid

- Her bir kart için ayrı `Selector<CoinDetailViewModel, String?>` kullanır.
- 7 alandan sadece değişeni rebuild eder (highPrice, lowPrice, volume, vb.).

### 4. Dependency Injection

#### DependencyContainer

- **GetIt** üzerine singleton wrapper.
- `read<T>()` — Kayıtlı dependency'yi getirir.
- `readOrCreate<T>()` — Kayıtlı değilse lazy singleton olarak register eder ve döner. Runtime'da generic service'ler için kullanılır.

#### DependencyInstances

- Clean facade: `DependencyInstances.service.dioService`, `.manager.marketManager`
- GetIt'e doğrudan bağımlılığı ortadan kaldırır.

---

## Performans Optimizasyonları

| Teknik | Etki |
|---|---|
| **Isolate JSON parsing** | REST ve WebSocket mesajları background thread'de parse edilir, UI thread serbest kalır |
| **Karakter-karakter JSON tarama** | Büyük array'ler için tüm listeyi belleğe almadan item-by-item işleme |
| **1s throttle** | WebSocket'ten saniyede yüzlerce gelen güncelleme toplu olarak batch'lenir |
| **Per-widget stream** | `SmartCoinRow` sadece kendi coin'i değiştiğinde rebuild olur |
| **Selector + shouldRebuild** | Liste sadece uzunluk değiştiğinde rebuild olur, fiyat değişikliklerinde değil |
| **`distinct()` on streams** | Equatable ile aynı veriyi tekrar emit etmez |
| **`resizeToAvoidBottomInset: false`** | Klavye açıldığında liste rebuild olmaz |

---

## Teknoloji ve Paketler

| Paket | Kullanım |
|---|---|
| `provider` | State management (ChangeNotifier + Selector) |
| `dio` | REST API HTTP istemcisi |
| `web_socket_channel` | WebSocket bağlantıları |
| `get_it` | Service locator / DI container |
| `json_annotation` + `json_serializable` | JSON model code generation |
| `envied` + `envied_generator` | Obfuscated .env değişken erişimi |
| `equatable` | Model ve state value equality |
| `logging` | Yapılandırılmış loglama |
| `mockito` | Test mock'lama |
| `very_good_analysis` | Lint kuralları |

---

## Kurulum

```bash
# 1. Bağımlılıkları yükle
flutter pub get

# 2. .env dosyasını oluştur
# assets/env/.env dosyasına Binance API URL'lerini ekle:
# BINANCE_TICKER_24H_URL=https://api.binance.com/api/v3
# BINANCE_PRICE_SOCKET_URL=wss://stream.binance.com:9443/ws

# 3. Code generation çalıştır
dart run build_runner build --delete-conflicting-outputs

# 4. Uygulamayı başlat
flutter run
```

## Testler

```bash
# Tüm testleri çalıştır
flutter test

# Belirli bir test dosyasını çalıştır
flutter test test/web_socket_service_test.dart
flutter test test/market_manager_test.dart
flutter test test/websocket_isolate_parser_test.dart
flutter test test/dio_service_test.dart
flutter test test/json_stream_parser_test.dart
```

### Test Kapsamı

| Test Dosyası | Kapsam |
|---|---|
| `web_socket_service_test.dart` | Bağlantı, mesaj parse, reconnect, heartbeat, manuel retry |
| `market_manager_test.dart` | Snapshot yükleme, WebSocket merge, throttle, getCoinStream |
| `websocket_isolate_parser_test.dart` | Tekil obje, array, büyük batch, hata senaryoları |
| `dio_service_test.dart` | HTTP istekleri, streaming response |
| `json_stream_parser_test.dart` | Incremental JSON parsing |
