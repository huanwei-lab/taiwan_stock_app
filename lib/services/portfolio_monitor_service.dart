import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/stock_model.dart';
import 'notification_rule_service.dart';
import 'portfolio_service.dart';
import 'stock_service.dart';

/// 持倉價格監測服務 - 定期檢查持倉價格並發送通知
class PortfolioMonitorService {
  static final PortfolioMonitorService _instance =
      PortfolioMonitorService._internal();

  Timer? _monitorTimer;
  bool _isMonitoring = false;
  final int _checkIntervalMinutes = 5; // 每 5 分鐘檢查一次

  late SharedPreferences _prefs;
  late PortfolioService portfolioService;
  late NotificationRuleService notificationRuleService;
  late StockService stockService;

  factory PortfolioMonitorService() {
    return _instance;
  }

  PortfolioMonitorService._internal();

  /// 初始化監測服務
  Future<void> initialize() async {
    if (_isMonitoring) return;

    try {
      _prefs = await SharedPreferences.getInstance();
      portfolioService = PortfolioService(_prefs);
      notificationRuleService = NotificationRuleService(
        _prefs,
        portfolioService: portfolioService,
      );
      stockService = StockService();

      print('[PortfolioMonitorService] Initialized successfully');
    } catch (e) {
      print('[PortfolioMonitorService] Error during initialization: $e');
    }
  }

  /// 啟動持倉監測
  void startMonitoring() {
    if (_isMonitoring) {
      print('[PortfolioMonitorService] Already monitoring');
      return;
    }

    _isMonitoring = true;
    print('[PortfolioMonitorService] Starting portfolio monitoring');

    // 立即執行一次檢查
    _checkPortfolioPositions();

    // 設置定期檢查
    _monitorTimer = Timer.periodic(
      Duration(minutes: _checkIntervalMinutes),
      (_) => _checkPortfolioPositions(),
    );
  }

  /// 停止持倉監測
  void stopMonitoring() {
    if (!_isMonitoring) return;

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;

    print('[PortfolioMonitorService] Stopped portfolio monitoring');
  }

  /// 檢查持倉位置並發送通知
  Future<void> _checkPortfolioPositions() async {
    if (!_isMonitoring) return;

    try {
      print('[PortfolioMonitorService] Checking portfolio positions...');

      // 獲取所有持倉
      final positions = await portfolioService.getPositions();
      if (positions.isEmpty) {
        print('[PortfolioMonitorService] No positions to monitor');
        return;
      }

      // 獲取當前股價
      final currentPrices = <String, double>{};
      try {
        final stocks = await stockService.fetchAllStocks();
        for (final stock in stocks) {
          currentPrices[stock.code] = stock.closePrice;
        }
        print('[PortfolioMonitorService] Retrieved ${currentPrices.length} stock prices');
      } catch (e) {
        print('[PortfolioMonitorService] Error fetching stock prices: $e');
        return;
      }

      // 檢查並發送通知
      final sentNotifications =
          await notificationRuleService.checkAndNotifyPositions(currentPrices);

      if (sentNotifications > 0) {
        print(
          '[PortfolioMonitorService] Check completed - '
          'Sent $sentNotifications notifications',
        );
      }
    } catch (e) {
      print('[PortfolioMonitorService] Error checking positions: $e');
    }
  }

  /// 手動檢查（用高於檢查間隔的價格）
  Future<void> manualCheckNow() async {
    try {
      print('[PortfolioMonitorService] Manual check triggered');
      await _checkPortfolioPositions();
    } catch (e) {
      print('[PortfolioMonitorService] Error in manual check: $e');
    }
  }

  /// 獲取監測狀態
  bool get isMonitoring => _isMonitoring;

  /// 獲取檢查間隔（分鐘）
  int get checkIntervalMinutes => _checkIntervalMinutes;

  /// 獲取下次檢查時間（預估）
  DateTime? getNextCheckTime() {
    if (!_isMonitoring || _monitorTimer == null) return null;
    return DateTime.now().add(Duration(minutes: _checkIntervalMinutes));
  }
}
