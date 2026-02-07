import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mini_ticker.g.dart';

/// MiniTicker is a data model representing a simplified ticker information from a financial API.
@JsonSerializable(createToJson: false, checked: true)
class MiniTicker extends Equatable {
  /// Constructs a MiniTicker with all required fields.
  const MiniTicker({
    required this.e,
    required this.s,
    required this.c,
    required this.o,
    required this.h,
    required this.l,
    required this.v,
    required this.q,
  });

  /// Factory constructor for creating a MiniTicker instance from a JSON map.
  factory MiniTicker.fromJson(Map<String, dynamic> json) =>
      _$MiniTickerFromJson(json);

  /// The event time in milliseconds since epoch.
  @JsonKey(name: 'E')
  final int? e;

  /// The symbol of the trading pair (e.g. "BTCUSDT").
  final String? s;

  /// The last price of the ticker.
  final String? c;

  /// The open price of the ticker.
  final String? o;

  /// The high price of the ticker.
  final String? h;

  /// The low price of the ticker.
  final String? l;

  /// The total traded base asset volume.
  final String? v;

  /// The total traded quote asset volume.
  final String? q;

  @override
  List<Object?> get props => [
    e,
    s,
    o,
    h,
    l,
    v,
    q,
  ];
}
