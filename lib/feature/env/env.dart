import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: 'assets/env/.env', obfuscate: true)
/// The [Env] class provides access to environment variables defined in the .env file.
abstract class Env {
  /// The Binance API endpoint for fetching 24-hour ticker data, retrieved from the .env file.
  @EnviedField(varName: 'BINANCE_TICKER_24H_URL')
  static final String binanceTicker24hUrl = _Env.binanceTicker24hUrl;

  /// The Binance WebSocket endpoint for receiving real-time price updates, retrieved from the .env file.
  @EnviedField(varName: 'BINANCE_PRICE_SOCKET_URL')
  static final String binancePriceSocketUrl = _Env.binancePriceSocketUrl;
}
