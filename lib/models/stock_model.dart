class StockModel {
  const StockModel({
    required this.code,
    required this.name,
    required this.closePrice,
    required this.volume,
    required this.tradeValue,
    required this.change,
    this.chipConcentration = 0.0, // 0-100 %, optional
    this.foreignNet = 0,
    this.trustNet = 0,
    this.dealerNet = 0,
    this.marginBalanceDiff = 0,
  });

  final String code;
  final String name;
  final double closePrice;
  final int volume;
  final int tradeValue;
  final double change;
  final double chipConcentration;
  // 三大法人買賣超；資料由 stock_service 填充，若無則為 0。
  final int foreignNet;
  final int trustNet;
  final int dealerNet;
  // 融資餘額變動（今日減昨日），正值表示融資增加
  final int marginBalanceDiff;

  factory StockModel.fromJson(Map<String, dynamic> json) {
    final code = _readString(
      json,
      ['Code', '證券代號', '代號'],
    );

    final name = _readString(
      json,
      ['Name', '證券名稱', '名稱'],
    );

    final closePrice = _readDouble(
      json,
      ['ClosingPrice', '收盤價'],
    );

    final volume = _readInt(
      json,
      ['TradeVolume', '成交股數', '成交量'],
    );

    final tradeValue = _readInt(
      json,
      ['TradeValue', '成交金額'],
    );

    final changeDiff = _readDouble(
      json,
      ['Change', '漲跌價差'],
    );
    final changePercent = _toChangePercent(closePrice, changeDiff);
    final chipConcentration = _readDouble(
      json,
      ['ChipConcentration', '籌碼集中度'],
    );

    final foreignNet = _readInt(
      json,
      ['ForeignNet', '外資買賣超', '三大法人-外資'],
    );
    final trustNet = _readInt(
      json,
      ['TrustNet', '投信買賣超', '三大法人-投信'],
    );
    final dealerNet = _readInt(
      json,
      ['DealerNet', '自營商買賣超', '三大法人-自營'],
    );
    final marginBalanceDiff = _readInt(
      json,
      ['MarginBalanceDiff', '融資餘額變動'],
    );

    return StockModel(
      code: code,
      name: name,
      closePrice: closePrice,
      volume: volume,
      tradeValue: tradeValue,
      change: changePercent,
      chipConcentration: chipConcentration,
      foreignNet: foreignNet,
      trustNet: trustNet,
      dealerNet: dealerNet,
      marginBalanceDiff: marginBalanceDiff,
    );
  }

  static double _toChangePercent(double closePrice, double changeDiff) {
    if (closePrice <= 0) {
      return 0;
    }

    final previousClose = closePrice - changeDiff;
    if (previousClose <= 0) {
      return 0;
    }

    return (changeDiff / previousClose) * 100;
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static double _readDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _parseDouble(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  static int _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _parseInt(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) {
      return null;
    }

    final cleaned = value.toString().replaceAll(',', '').trim();
    if (cleaned.isEmpty || cleaned == '--' || cleaned == '-') {
      return null;
    }

    return double.tryParse(cleaned);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    final cleaned = value.toString().replaceAll(',', '').trim();
    if (cleaned.isEmpty || cleaned == '--' || cleaned == '-') {
      return null;
    }

    return int.tryParse(cleaned);
  }
}
