[Türkçe](README.tr.md) | **English**

# Blockly — Real-Time Cryptocurrency Tracker

A high-performance Flutter application that monitors real-time prices for **1500+ coins** via the Binance API.

The initial snapshot is fetched using a REST API, followed by real-time price updates via WebSockets. All JSON parsing operations are performed in **background isolates**, ensuring the UI thread is never blocked.

---

## Architecture Overview

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
                   │  _tickerMap (snapshot)  │
                   │  + real-time merge      │
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

## Folder Structure

```text
lib/
├── main.dart                          # App entry point
├── core/
│   ├── extensions/
│   │   ├── context_extension.dart     # Theme shortcuts (colorScheme, textTheme)
│   │   └── num_extension.dart         # Percentage-based screen size calculation
│   └── logging/
│       ├── custom_logger.dart         # Module-based logger wrapper
│       ├── log_manager.dart           # Root logger configuration
│       └── zone_manager.dart          # Global error handling (runZonedGuarded)
├── feature/
│   ├── const/
│   │   └── url_const.dart             # API endpoint constants
│   ├── enums/
│   │   └── socket_status_enum.dart    # WebSocket connection states
│   ├── env/
│   │   └── env.dart                   # Obfuscated environment variables (envied)
│   ├── init/
│   │   ├── dependency_container.dart  # GetIt DI configuration
│   │   └── dependency_instances.dart  # DI access facade
│   ├── managers/
│   │   ├── market_manager.dart        # REST + WebSocket data orchestrator
│   │   └── market_state.dart          # Immutable state object (Equatable)
│   ├── models/
│   │   ├── coin_ticker.dart           # 24h ticker model (21 fields)
│   │   └── mini_ticker.dart           # WebSocket mini ticker model
│   └── services/
│       ├── json_parser/
│       │   ├── json_stream_parser.dart         # REST response isolate parser
│       │   └── websocket_isolate_parser.dart   # WebSocket isolate parser
│       ├── network/
│       │   ├── dio_config.dart         # Dio instance configuration
│       │   └── dio_service.dart        # HTTP client (streaming support)
│       └── web_socket/
│           └── web_socket_service.dart # WebSocket lifecycle management
└── views/
    ├── home/
    │   ├── view/
    │   │   └── home_view.dart          # Main screen (search + coin list)
    │   ├── view_model/
    │   │   └── home_view_model.dart    # Main screen state management
    │   └── widgets/
    │       └── smart_coin_row.dart     # Row widget subscribed to its own stream
    └── coin_detail/
        ├── view/
        │   └── coin_detail_view.dart   # Detail screen
        ├── view_model/
        │   └── coin_detail_view_model.dart  # Detail state management
        └── widgets/
            ├── detail_card.dart        # Individual info card
            ├── detail_grid.dart        # 2-column stats grid
            └── price_section.dart      # Price and change percentage

```

---

## Layer Details

### 1. Data Layer — Services

#### DioService

* `request<T>()` — Standard JSON-parsed HTTP requests.
* `requestStreaming<T>()` — Fetches large JSON responses as `ResponseType.plain` and parses them in chunks using **`JsonStreamParser`** in a background isolate. Loads the 1500+ coin snapshot without blocking the main thread.

#### WebSocketService<T>

* **Generic** design — compatible with any model type.
* **Constructor injection** — `parser` and `manuellyRetry` parameters injected via constructor.
* **Isolate parsing** — With `useIsolate: true`, messages are routed to `WebSocketIsolateParser`.
* **Exponential backoff** — Reconnects with increasing delays (1s, 4s, 9s... up to 60s) upon disconnection.
* **Heartbeat** — If no data is received for 5 seconds, the connection is considered dead and a reconnect is initiated.
* **Manual retry mode** — When `manuellyRetry: true`, automatic reconnection is disabled and must be triggered by the user.
* **Status stream** — Emits `connecting → connected → disconnected → reconnecting` states.

#### WebSocketIsolateParser<T>

* Long-lived background **Dart isolate**.
* **Character-by-character JSON scanning** for arrays — parses items one by one without loading the entire array into memory.
* Configurable chunk size (default: 100 items/batch).
* Communicates with the main thread using the `SendPort`/`ReceivePort` handshake pattern.

### 2. Domain Layer — Manager

#### MarketManager

* **Data flow orchestrator** — Merges REST snapshots with real-time WebSocket updates.
* **Throttle mechanism** — Collects WebSocket updates in a `_pendingUpdates` map and merges them into `_tickerMap` in batches **every 1 second**.
* **`marketStream`** — Broadcasts `Stream<MarketState>`. `MarketState` contains both the full ticker list and the symbols that changed in the last batch.
* **`getCoinStream(symbol)`** — Filtered stream for a specific coin. Uses `.distinct()` to prevent redundant emissions.
* **`socketStatusStream`** — Exposes WebSocket connection status to the UI.
* **`copyWithMiniTicker()`** — Recalculates `priceChange` and `priceChangePercent` while merging mini ticker data into the main ticker to prevent data inconsistency.

### 3. Presentation Layer — MVVM + Provider

#### HomeViewModel

* `HomeViewState` enum: `loading → loaded → disconnected → error`
* Listens to `marketStream`, calls `notifyListeners()` only on **snapshot emission** or **state changes**.
* Price updates are handled directly by `SmartCoinRow` — they do not trigger the ViewModel.
* Monitors the socket status stream to transition to the `disconnected` state if the connection drops.
* Filtering via `updateSearchText()` (default: `"TRY"`).

#### SmartCoinRow

* **Per-widget stream subscription** — Listens only to updates for its specific coin via `MarketManager.getCoinStream(symbol)`.
* Operates independently of the parent ViewModel. Only the relevant row rebuilds.
* Tick-based color comparison (green/red).

#### DetailGrid

* Uses a separate `Selector<CoinDetailViewModel, String?>` for each card.
* Rebuilds only the specific field (highPrice, lowPrice, volume, etc.) that has changed out of the 7 available fields.

### 4. Dependency Injection

#### DependencyContainer

* A singleton wrapper built on **GetIt**.
* `read<T>()` — Retrieves the registered dependency.
* `readOrCreate<T>()` — Registers as a lazy singleton if not already registered and returns it. Used for generic services at runtime.

#### DependencyInstances

* Clean facade: `DependencyInstances.service.dioService`, `.manager.marketManager`
* Decouples the project from a direct dependency on GetIt.

---

## Performance Optimizations

| Technique | Impact |
| --- | --- |
| **Isolate JSON parsing** | REST and WebSocket messages are parsed in a background thread, keeping the UI thread free |
| **Char-by-char JSON scanning** | Item-by-item processing for large arrays without memory overhead |
| **1s throttle** | Batches hundreds of WebSocket updates per second into a single update |
| **Per-widget stream** | `SmartCoinRow` only rebuilds when its specific coin changes |
| **Selector + shouldRebuild** | Lists rebuild only when length changes, not on price fluctuations |
| **`distinct()` on streams** | Prevents emitting the same data multiple times using Equatable |
| **`resizeToAvoidBottomInset: false`** | Prevents list rebuilds when the keyboard is opened |

---

## Tech Stack & Packages

| Package | Usage |
| --- | --- |
| `provider` | State management (ChangeNotifier + Selector) |
| `dio` | REST API HTTP client |
| `web_socket_channel` | WebSocket connections |
| `get_it` | Service locator / DI container |
| `json_annotation` + `json_serializable` | JSON model code generation |
| `envied` + `envied_generator` | Obfuscated .env variable access |
| `equatable` | Value equality for models and states |
| `logging` | Structured logging |
| `mockito` | Test mocking |
| `very_good_analysis` | Lint rules |

---

## Installation

```bash
# 1. Install dependencies
flutter pub get

# 2. Create the .env file
# Add Binance API URLs to assets/env/.env:
# BINANCE_TICKER_24H_URL=[https://api.binance.com/api/v3](https://api.binance.com/api/v3)
# BINANCE_PRICE_SOCKET_URL=wss://[stream.binance.com:9443/ws](https://stream.binance.com:9443/ws)

# 3. Run code generation
dart run build_runner build --delete-conflicting-outputs

# 4. Start the application
flutter run

```

## Testing

```bash
# Run all tests
flutter test

# Run specific test files
flutter test test/web_socket_service_test.dart
flutter test test/market_manager_test.dart
flutter test test/websocket_isolate_parser_test.dart
flutter test test/dio_service_test.dart
flutter test test/json_stream_parser_test.dart

```

### Test Coverage

| Test File | Scope |
| --- | --- |
| `web_socket_service_test.dart` | Connection, message parsing, reconnect, heartbeat, manual retry |
| `market_manager_test.dart` | Snapshot loading, WebSocket merge, throttling, getCoinStream |
| `websocket_isolate_parser_test.dart` | Single object, array, large batches, error scenarios |
| `dio_service_test.dart` | HTTP requests, streaming response |
| `json_stream_parser_test.dart` | Incremental JSON parsing |
