import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/portfolio.dart';
import '../services/portfolio_service.dart';
import '../services/notification_rule_service.dart';
import '../services/portfolio_monitor_service.dart';
import '../services/stock_service.dart';

/// 持倉跟蹤頁面
class PortfolioPage extends StatefulWidget {
  const PortfolioPage({super.key});

  @override
  State<PortfolioPage> createState() => _PortfolioPageState();
}

class _PortfolioPageState extends State<PortfolioPage> {
  late PortfolioService _portfolioService;
  late NotificationRuleService _notificationRuleService;
  late StockService _stockService;
  final _monitorService = PortfolioMonitorService();

  List<PortfolioPosition> _positions = [];
  Map<String, double> _currentPrices = {};
  bool _isLoading = true;
  bool _isPriceSyncing = false;
  String? _error;
  String? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _portfolioService = PortfolioService(prefs);
      _notificationRuleService = NotificationRuleService(
        prefs,
        portfolioService: _portfolioService,
      );
      _stockService = StockService();

      // 初始化監測服務
      await _monitorService.initialize();

      await _loadPositions();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '初始化失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    // 不自動停止監測，讓用戶控制
    super.dispose();
  }

  Future<void> _loadPositions() async {
    try {
      final positions = await _portfolioService.getPositions();
      await _fetchCurrentPrices();

      if (mounted) {
        setState(() {
          _positions = positions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入持倉失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// 自動獲取所有持倉股票的當前股價
  Future<void> _fetchCurrentPrices() async {
    try {
      setState(() {
        _isPriceSyncing = true;
      });

      final stocks = await _stockService.fetchAllStocks();
      final prices = <String, double>{};

      for (final stock in stocks) {
        prices[stock.code] = stock.closePrice;
      }

      if (mounted) {
        setState(() {
          _currentPrices = prices;
          _lastSyncTime =
              DateTime.now().toString().split('.')[0]; // HH:MM:SS
          _isPriceSyncing = false;
        });
      }

      print(
        '[PortfolioPage] Synced ${prices.length} stock prices',
      );
    } catch (e) {
      print('[PortfolioPage] Error fetching prices: $e');
      if (mounted) {
        setState(() {
          _isPriceSyncing = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('同步股價失敗: $e')),
      );
    }
  }

  Future<void> _addPosition() async {
    showDialog(
      context: context,
      builder: (context) => _AddPositionDialog(
        onAdd: (position) async {
          await _portfolioService.addPosition(position);
          await _loadPositions();
        },
      ),
    );
  }

  Future<void> _deletePosition(String code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('刪除持倉'),
            content: Text('確定要刪除 $code 的持倉嗎？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('刪除'),
              ),
            ],
          ),
    );

    if (confirmed ?? false) {
      await _portfolioService.removePosition(code);
      await _loadPositions();
    }
  }

  void _toggleMonitoring() {
    setState(() {
      if (_monitorService.isMonitoring) {
        _monitorService.stopMonitoring();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已停止持倉監測')),
        );
      } else {
        _monitorService.startMonitoring();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已啟動持倉監測（每 5 分鐘檢查一次）'),
          ),
        );
      }
    });
  }

  void _setPriceForCode(String code) {
    final priceController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$code 現價'),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: '輸入現價',
            hintText: '0.00',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              if (price != null && price > 0) {
                setState(() {
                  _currentPrices[code] = price;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('確定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的持倉')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的持倉')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('錯誤: $_error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadPositions,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final totalMarketValue =
        _positions.fold<double>(
      0,
      (sum, pos) {
        final price = _currentPrices[pos.code] ?? 0;
        return sum + pos.calculateMarketValue(price);
      },
    );

    final totalCost =
        _positions.fold<double>(
      0,
      (sum, pos) => sum + (pos.entryPrice * pos.shares),
    );

    final totalPnl = totalMarketValue - totalCost;
    final totalPnlPercent =
        totalCost > 0 ? (totalPnl / totalCost) * 100 : 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('我的持倉'),
            if (_lastSyncTime != null)
              Text(
                '更新於 $_lastSyncTime',
                style: Theme.of(context).textTheme.labelSmall,
              ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _toggleMonitoring,
            icon: Icon(
              _monitorService.isMonitoring
                  ? Icons.notifications_active
                  : Icons.notifications_off,
            ),
            tooltip: _monitorService.isMonitoring ? '停止監測' : '啟動監測',
          ),
          IconButton(
            onPressed: _isPriceSyncing ? null : _loadPositions,
            icon: _isPriceSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: '重新同步股價',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadPositions,
        child: _positions.isEmpty
            ? ListView(
          children: [
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.card_giftcard,
                    size: 64,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暫無持倉',
                    style: Theme
                        .of(context)
                        .textTheme
                        .headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '點擊下方按鈕添加持倉',
                    style: Theme
                        .of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        )
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 摘要卡片
              Padding(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '組合摘要',
                          style:
                              Theme
                                  .of(context)
                                  .textTheme
                                  .titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '市值',
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                                Text(
                                  '\$${totalMarketValue
                                      .toStringAsFixed(0)}',
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .headlineSmall,
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '損益',
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .bodySmall,
                                ),
                                Text(
                                  '${totalPnl >= 0 ? '+' : ''}\$${totalPnl
                                      .toStringAsFixed(0)} (${totalPnlPercent
                                      .toStringAsFixed(2)}%)',
                                  style: (Theme
                                      .of(context)
                                      .textTheme
                                      .headlineSmall ??
                                      const TextStyle())
                                      .copyWith(
                                        color: totalPnl >= 0
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // 持倉列表
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '持倉詳情 (${_positions.length})',
                  style: Theme
                      .of(context)
                      .textTheme
                      .titleMedium,
                ),
              ),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _positions.length,
                itemBuilder: (context, index) {
                  final pos = _positions[index];
                  final currentPrice = _currentPrices[pos.code] ?? 0;
                  final pnl = pos.calculatePnl(currentPrice);
                  final marketValue = pos.calculateMarketValue(
                    currentPrice,
                  );

                  return Card(
                    child: ListTile(
                      title: Text('${pos.code}｜${pos.name}'),
                      subtitle: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            '進價: \$${pos.entryPrice
                                .toStringAsFixed(2)} × ${pos.shares} 股',
                          ),
                          if (currentPrice > 0)
                            Text(
                              '現價: \$${currentPrice
                                  .toStringAsFixed(2)}',
                            )
                          else
                            GestureDetector(
                              onTap: () => _setPriceForCode(pos.code),
                              child: Text(
                                '點擊輸入現價',
                                style: TextStyle(
                                  color: Theme
                                      .of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ),
                          if (pos.targetPrice != null)
                            Text(
                              '目標: \$${pos.targetPrice
                                  ?.toStringAsFixed(2)}',
                            ),
                          if (pos.strategyName != null)
                            Text(
                              '策略: ${pos.strategyName}',
                              style: TextStyle(
                                color: Theme
                                    .of(context)
                                    .colorScheme
                                    .primary,
                              ),
                            ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${marketValue
                                .toStringAsFixed(0)}',
                            style: Theme
                                .of(context)
                                .textTheme
                                .bodyLarge,
                          ),
                          if (currentPrice > 0)
                            Text(
                              '${pnl >= 0 ? '+' : ''}${pnl
                                  .toStringAsFixed(2)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: pnl >= 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                        ],
                      ),
                      onLongPress: () =>
                          _showPositionMenu(context, pos),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addPosition,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showPositionMenu(
    BuildContext context,
    PortfolioPosition position,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) =>
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('編輯'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: 實現編輯功能
                },
              ),
              ListTile(
                leading: Icon(
                  position.enableNotification
                      ? Icons.notifications_active
                      : Icons.notifications_off,
                ),
                title: Text(
                  position.enableNotification ? '關閉通知' : '啟用通知',
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final updated = position.updateNotificationState(
                    enableNotification: !position.enableNotification,
                  );
                  await _portfolioService.updatePosition(
                    position.code,
                    updated,
                  );
                  await _loadPositions();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        position.enableNotification ? '已關閉通知' : '已啟用通知',
                      ),
                    ),
                  );
                },
              ),
              if (position.targetPrice != null)
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: Text(
                    '重置目標價通知${position.targetNotificationSent ? '✓' : ''}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _notificationRuleService.resetTargetPriceNotification(
                      position.code,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已重置目標價通知')),
                    );
                  },
                ),
              if (position.stopLossPrice != null)
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: Text(
                    '重置停損通知${position.stopLossNotificationSent ? '✓' : ''}',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _notificationRuleService.resetStopLossNotification(
                      position.code,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已重置停損通知')),
                    );
                  },
                ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('交易記錄'),
                onTap: () async {
                  Navigator.pop(context);
                  // TODO: 顯示該股票的交易記錄
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('刪除'),
                onTap: () {
                  Navigator.pop(context);
                  _deletePosition(position.code);
                },
              ),
            ],
          ),
    );
  }
}

/// 添加持倉對話框
class _AddPositionDialog extends StatefulWidget {
  final Function(PortfolioPosition) onAdd;

  const _AddPositionDialog({required this.onAdd});

  @override
  State<_AddPositionDialog> createState() => _AddPositionDialogState();
}

class _AddPositionDialogState extends State<_AddPositionDialog> {
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _sharesController;
  late TextEditingController _priceController;
  late TextEditingController _targetController;
  late TextEditingController _stopLossController;
  late TextEditingController _strategyController;
  bool _enableNotification = true;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _nameController = TextEditingController();
    _sharesController = TextEditingController();
    _priceController = TextEditingController();
    _targetController = TextEditingController();
    _stopLossController = TextEditingController();
    _strategyController = TextEditingController();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _sharesController.dispose();
    _priceController.dispose();
    _targetController.dispose();
    _stopLossController.dispose();
    _strategyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加持倉'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(labelText: '股票代號'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '股票名稱'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sharesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '股數'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '進價'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _targetController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '目標價 (可選)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _stopLossController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '停損價 (可選)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _strategyController,
              decoration: const InputDecoration(labelText: '策略名稱 (可選)'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('啟用通知'),
              subtitle: const Text('當股價達到目標或停損時通知'),
              value: _enableNotification,
              onChanged: (value) {
                setState(() {
                  _enableNotification = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final code = _codeController.text.trim();
            final name = _nameController.text.trim();
            final shares = int.tryParse(_sharesController.text.trim());
            final price =
                double.tryParse(_priceController.text.trim());
            final target =
                double.tryParse(_targetController.text.trim());
            final stopLoss =
                double.tryParse(_stopLossController.text.trim());

            if (code.isEmpty || name.isEmpty || shares == null ||
                price == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('請填入所有必須欄位')),
              );
              return;
            }

            final position = PortfolioPosition(
              code: code,
              name: name,
              shares: shares,
              entryPrice: price,
              entryDate: DateTime.now(),
              targetPrice: target,
              stopLossPrice: stopLoss,
              strategyName:
                  _strategyController.text.isNotEmpty
                      ? _strategyController.text
                      : null,
              enableNotification: _enableNotification,
            );

            widget.onAdd(position);
            Navigator.pop(context);
          },
          child: const Text('添加'),
        ),
      ],
    );
  }
}
