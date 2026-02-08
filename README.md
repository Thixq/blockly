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
