import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/strategy_config.dart';
import '../services/strategy_service.dart';

/// 多策略對比頁面
class StrategyComparisonPage extends StatefulWidget {
  const StrategyComparisonPage({super.key});

  @override
  State<StrategyComparisonPage> createState() =>
      _StrategyComparisonPageState();
}

class _StrategyComparisonPageState
    extends State<StrategyComparisonPage> {
  late StrategyService _strategyService;

  List<StrategyConfig> _strategies = [];
  StrategyConfig? _activeStrategy;
  bool _isLoading = true;
  String? _error;
  String _sortBy = 'winRate'; // winRate, profitFactor, maxDrawdown

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _strategyService = StrategyService(prefs);
      await _loadStrategies();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '初始化失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadStrategies() async {
    try {
      final strategies = await _strategyService.getStrategies();
      final active = await _strategyService.getActiveStrategy();

      if (mounted) {
        setState(() {
          _strategies = strategies;
          _activeStrategy = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '載入策略失敗: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setActive(String strategyId) async {
    await _strategyService.setActiveStrategy(strategyId);
    await _loadStrategies();
  }

  Future<void> _deleteStrategy(String strategyId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('刪除策略'),
            content: const Text('確定要刪除此策略嗎？'),
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
      await _strategyService.deleteStrategy(strategyId);
      await _loadStrategies();
    }
  }

  List<StrategyConfig> _getSortedStrategies() {
    final sorted = List<StrategyConfig>.from(_strategies);

    switch (_sortBy) {
      case 'winRate':
        sorted.sort((a, b) =>
            (b.winRate ?? 0).compareTo(a.winRate ?? 0));
        break;
      case 'profitFactor':
        sorted.sort((a, b) =>
            (b.profitFactor ?? 0)
                .compareTo(a.profitFactor ?? 0));
        break;
      case 'maxDrawdown':
        // 較小的drawdown更好 (即負數較小)
        sorted.sort((a, b) =>
            (a.maxDrawdown ?? 0)
                .compareTo(b.maxDrawdown ?? 0));
        break;
    }

    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('策略對比')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('策略對比')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('錯誤: $_error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadStrategies,
                child: const Text('重試'),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = _getSortedStrategies();

    return Scaffold(
      appBar: AppBar(
        title: const Text('策略對比'),
        actions: [
          IconButton(
            onPressed: _loadStrategies,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadStrategies,
        child: sorted.isEmpty
            ? ListView(
          children: [
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.assessment,
                    size: 64,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暫無策略',
                    style: Theme
                        .of(context)
                        .textTheme
                        .headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '請先執行回測以創建策略',
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
            children: [
              // 排序選項
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '排序:',
                      style: Theme
                          .of(context)
                          .textTheme
                          .bodyMedium,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'winRate',
                            label: Text('勝率'),
                          ),
                          ButtonSegment(
                            value: 'profitFactor',
                            label: Text('獲利因子'),
                          ),
                          ButtonSegment(
                            value: 'maxDrawdown',
                            label: Text('最大回徹'),
                          ),
                        ],
                        selected: {_sortBy},
                        onSelectionChanged: (selection) {
                          setState(() {
                            _sortBy = selection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // 策略列表
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: sorted.length,
                itemBuilder: (context, index) {
                  final strategy = sorted[index];
                  final isActive = _activeStrategy?.id == strategy.id;

                  return Card(
                    elevation: isActive ? 4 : 0,
                    color: isActive
                        ? Theme
                            .of(context)
                            .colorScheme
                            .primaryContainer
                        : null,
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strategy.name,
                                  style: Theme
                                      .of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                if (isActive)
                                  Padding(
                                    padding:
                                        const EdgeInsets.only(
                                          top: 4,
                                        ),
                                    child: Chip(
                                      label: const Text('活躍'),
                                      visualDensity:
                                          VisualDensity
                                              .compact,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _MetricBadge(
                            label: '勝率',
                            value:
                                '${(strategy.winRate ?? 0)
                                    .toStringAsFixed(1)}%',
                          ),
                        ],
                      ),
                      subtitle: Row(
                        mainAxisAlignment:
                            MainAxisAlignment
                                .spaceBetween,
                        children: [
                          Text(
                            '因子: ${(strategy.profitFactor ?? 0)
                                .toStringAsFixed(2)}',
                          ),
                          Text(
                            '回徹: ${(strategy.maxDrawdown ?? 0)
                                .toStringAsFixed(2)}%',
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              _buildMetricRow(
                                context,
                                '描述',
                                strategy.description,
                              ),
                              const Divider(),
                              _buildMetricRow(
                                context,
                                '交易筆數',
                                '${strategy.totalTrades ?? 0}',
                              ),
                              _buildMetricRow(
                                context,
                                '勝率',
                                '${(strategy.winRate ?? 0)
                                    .toStringAsFixed(2)}%',
                              ),
                              _buildMetricRow(
                                context,
                                '獲利因子',
                                '${(strategy.profitFactor ?? 0)
                                    .toStringAsFixed(2)}',
                              ),
                              _buildMetricRow(
                                context,
                                '最大回徹',
                                '${(strategy.maxDrawdown ?? 0)
                                    .toStringAsFixed(2)}%',
                              ),
                              const Divider(),
                              // 參數
                              Text(
                                '參數',
                                style: Theme
                                    .of(context)
                                    .textTheme
                                    .titleSmall,
                              ),
                              const SizedBox(height: 8),
                              ...strategy.parameters
                                  .entries
                                  .map((e) =>
                                      Padding(
                                        padding: const EdgeInsets
                                            .symmetric(
                                          vertical: 4,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              e.key,
                                              style: Theme
                                                  .of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                            Text(
                                              '${e.value}',
                                              style: Theme
                                                  .of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    fontWeight:
                                                        FontWeight
                                                            .bold,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ))
                                  .toList(),
                              const SizedBox(height: 16),
                              // 操作按鈕
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  if (!isActive)
                                    FilledButton(
                                      onPressed: () =>
                                          _setActive(
                                            strategy
                                                .id,
                                          ),
                                      child: const Text(
                                        '設為活躍',
                                      ),
                                    ),
                                  if (isActive)
                                    const Chip(
                                      label: Text(
                                        '當前活躍策略',
                                      ),
                                    ),
                                  TextButton(
                                    onPressed: () =>
                                        _deleteStrategy(
                                          strategy
                                              .id,
                                        ),
                                    child: const Text(
                                      '刪除',
                                      style: TextStyle(
                                        color: Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium,
          ),
          Text(
            value,
            style: Theme
                .of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// 指標徽章組件
class _MetricBadge extends StatelessWidget {
  final String label;
  final String value;

  const _MetricBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: Theme
                .of(context)
                .textTheme
                .bodySmall,
          ),
          Text(
            value,
            style: Theme
                .of(context)
                .textTheme
                .titleSmall
                ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
