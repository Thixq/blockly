/// This file defines constant URL paths used for API requests in the application.
final class UrlConst {
  /// The URL path for the 24hr ticker stream, which provides detailed ticker information for all trading pairs.
  static const String ticker24hr = '/ticker/24hr';

  /// The URL path for the mini ticker stream, which provides simplified ticker information.
  static const String miniTicker = '/!miniTicker@arr';
}
