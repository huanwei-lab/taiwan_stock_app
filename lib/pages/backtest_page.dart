import 'package:flutter/material.dart';

import '../models/backtest_result.dart';
import '../services/backtest_service.dart';

class BacktestTuningResult {
  const BacktestTuningResult({
    required this.stopLossPercent,
    required this.takeProfitPercent,
    this.applyStopLoss = true,
    this.applyTakeProfit = true,
  });

  final int stopLossPercent;
  final int takeProfitPercent;
  final bool applyStopLoss;
  final bool applyTakeProfit;
}

class BacktestPage extends StatefulWidget {
  const BacktestPage({
    super.key,
    this.initialStockCode,
    this.initialMonths,
    this.initialMinVolume,
    this.initialMinTradeValue,
    this.initialStopLoss,
    this.initialTakeProfit,
    this.initialEnableTrailingStop,
    this.initialTrailingPullback,
  });

  final String? initialStockCode;
  final int? initialMonths;
  final int? initialMinVolume;
  final int? initialMinTradeValue;
  final int? initialStopLoss;
  final int? initialTakeProfit;
  final bool? initialEnableTrailingStop;
  final int? initialTrailingPullback;

  @override
  State<BacktestPage> createState() => _BacktestPageState();
}

class _BacktestPageState extends State<BacktestPage> {
  late final TextEditingController _stockCodeController;
  late final TextEditingController _monthsController;
  late final TextEditingController _minVolumeController;
  late final TextEditingController _minTradeValueController;
  late final TextEditingController _stopLossController;
  late final TextEditingController _takeProfitController;
  late final TextEditingController _stopLossGridController;
  late final TextEditingController _takeProfitGridController;
  late final TextEditingController _trailingPullbackController;
  late final TextEditingController _atrTakeProfitMultiplierController;
  late final TextEditingController _feeBpsController;
  late final TextEditingController _slippageBpsController;
  late final TextEditingController _walkForwardTrainMonthsController;
  late final TextEditingController _walkForwardValidationMonthsController;

  final _service = BacktestService();

  BacktestResult? _result;
  List<BacktestGridItem> _gridResults = const <BacktestGridItem>[];
  WalkForwardResult? _walkForwardResult;
  bool _isLoading = false;
  bool _isGridLoading = false;
  bool _isWalkForwardLoading = false;
  bool _skipTop1ConfirmForSession = false;
  bool _enableTrailingStop = true;
  bool _enableAdaptiveAtr = true;
  String? _error;
  String? _gridError;

  @override
  void initState() {
    super.initState();
    _stockCodeController = TextEditingController(
      text: widget.initialStockCode ?? '2330',
    );
    _monthsController = TextEditingController(
      text: (widget.initialMonths ?? 6).toString(),
    );
    _minVolumeController = TextEditingController(
      text: (widget.initialMinVolume ?? 10000000).toString(),
    );
    _minTradeValueController = TextEditingController(
      text: (widget.initialMinTradeValue ?? 1000000000).toString(),
    );
    _stopLossController = TextEditingController(
      text: (widget.initialStopLoss ?? 5).toString(),
    );
    _takeProfitController = TextEditingController(
      text: (widget.initialTakeProfit ?? 10).toString(),
    );
    _stopLossGridController = TextEditingController(text: '4,5,6');
    _takeProfitGridController = TextEditingController(text: '8,10,12');
    _trailingPullbackController = TextEditingController(
      text: (widget.initialTrailingPullback ?? 3).toString(),
    );
    _atrTakeProfitMultiplierController = TextEditingController(text: '2');
    _feeBpsController = TextEditingController(text: '14');
    _slippageBpsController = TextEditingController(text: '10');
    _walkForwardTrainMonthsController = TextEditingController(text: '4');
    _walkForwardValidationMonthsController = TextEditingController(text: '2');
    _enableTrailingStop = widget.initialEnableTrailingStop ?? true;
  }

  Future<void> _runBacktest() async {
    final stockCode = _stockCodeController.text.trim();
    final months = int.tryParse(_monthsController.text.trim());
    final minVolume = int.tryParse(_minVolumeController.text.trim());
    final minTradeValue = int.tryParse(_minTradeValueController.text.trim());
    final stopLoss = int.tryParse(_stopLossController.text.trim());
    final takeProfit = int.tryParse(_takeProfitController.text.trim());
    final trailingPullback = int.tryParse(_trailingPullbackController.text.trim());
    final atrTakeProfitMultiplier =
      int.tryParse(_atrTakeProfitMultiplierController.text.trim());
    final feeBps = int.tryParse(_feeBpsController.text.trim());
    final slippageBps = int.tryParse(_slippageBpsController.text.trim());

    if (stockCode.isEmpty ||
        months == null ||
        minVolume == null ||
        minTradeValue == null ||
        stopLoss == null ||
        takeProfit == null ||
      trailingPullback == null ||
        atrTakeProfitMultiplier == null ||
        feeBps == null ||
        slippageBps == null) {
      setState(() {
        _error = '請完整輸入正確參數';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _result = null;
      _gridError = null;
    });

    try {
      final result = await _service.runSimpleBacktest(
        stockCode: stockCode,
        months: months,
        minVolume: minVolume,
        minTradeValue: minTradeValue,
        stopLossPercent: stopLoss,
        takeProfitPercent: takeProfit,
        enableTrailingStop: _enableTrailingStop,
        trailingPullbackPercent: trailingPullback,
        enableAdaptiveAtr: _enableAdaptiveAtr,
        atrTakeProfitMultiplier: atrTakeProfitMultiplier,
        feeBps: feeBps,
        slippageBps: slippageBps,
      );

      setState(() {
        _result = result;
      });
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<int>? _parseGridCandidates(String raw) {
    final parts = raw
        .split(',')
        .map((text) => int.tryParse(text.trim()))
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    if (parts.isEmpty) {
      return null;
    }
    return parts;
  }

  Future<void> _runGridScan() async {
    final stockCode = _stockCodeController.text.trim();
    final months = int.tryParse(_monthsController.text.trim());
    final minVolume = int.tryParse(_minVolumeController.text.trim());
    final minTradeValue = int.tryParse(_minTradeValueController.text.trim());
    final stopLossCandidates =
        _parseGridCandidates(_stopLossGridController.text.trim());
    final takeProfitCandidates =
        _parseGridCandidates(_takeProfitGridController.text.trim());
    final trailingPullback = int.tryParse(_trailingPullbackController.text.trim());
    final atrTakeProfitMultiplier =
      int.tryParse(_atrTakeProfitMultiplierController.text.trim());
    final feeBps = int.tryParse(_feeBpsController.text.trim());
    final slippageBps = int.tryParse(_slippageBpsController.text.trim());

    if (stockCode.isEmpty ||
        months == null ||
        minVolume == null ||
        minTradeValue == null ||
        stopLossCandidates == null ||
        takeProfitCandidates == null ||
        trailingPullback == null ||
        atrTakeProfitMultiplier == null ||
        feeBps == null ||
        slippageBps == null) {
      setState(() {
        _gridError = '請輸入正確參數組合（例如停損 4,5,6）';
      });
      return;
    }

    setState(() {
      _isGridLoading = true;
      _gridError = null;
      _gridResults = const <BacktestGridItem>[];
    });

    try {
      final results = await _service.runParameterGrid(
        stockCode: stockCode,
        months: months,
        minVolume: minVolume,
        minTradeValue: minTradeValue,
        stopLossCandidates: stopLossCandidates,
        takeProfitCandidates: takeProfitCandidates,
        enableTrailingStop: _enableTrailingStop,
        trailingPullbackPercent: trailingPullback,
        enableAdaptiveAtr: _enableAdaptiveAtr,
        atrTakeProfitMultiplier: atrTakeProfitMultiplier,
        feeBps: feeBps,
        slippageBps: slippageBps,
      );

      setState(() {
        _gridResults = results;
      });
    } catch (error) {
      setState(() {
        _gridError = error.toString();
      });
    } finally {
      setState(() {
        _isGridLoading = false;
      });
    }
  }

  Future<void> _runWalkForward() async {
    final stockCode = _stockCodeController.text.trim();
    final months = int.tryParse(_monthsController.text.trim());
    final minVolume = int.tryParse(_minVolumeController.text.trim());
    final minTradeValue = int.tryParse(_minTradeValueController.text.trim());
    final stopLossCandidates =
        _parseGridCandidates(_stopLossGridController.text.trim());
    final takeProfitCandidates =
        _parseGridCandidates(_takeProfitGridController.text.trim());
    final trailingPullback = int.tryParse(_trailingPullbackController.text.trim());
    final atrTakeProfitMultiplier =
      int.tryParse(_atrTakeProfitMultiplierController.text.trim());
    final feeBps = int.tryParse(_feeBpsController.text.trim());
    final slippageBps = int.tryParse(_slippageBpsController.text.trim());
    final trainMonths =
        int.tryParse(_walkForwardTrainMonthsController.text.trim());
    final validationMonths =
        int.tryParse(_walkForwardValidationMonthsController.text.trim());

    if (stockCode.isEmpty ||
        months == null ||
        minVolume == null ||
        minTradeValue == null ||
        stopLossCandidates == null ||
        takeProfitCandidates == null ||
        trailingPullback == null ||
        atrTakeProfitMultiplier == null ||
        feeBps == null ||
        slippageBps == null ||
        trainMonths == null ||
        validationMonths == null) {
      setState(() {
        _gridError = 'Walk-forward 參數錯誤，請確認輸入。';
      });
      return;
    }

    setState(() {
      _isWalkForwardLoading = true;
      _gridError = null;
      _walkForwardResult = null;
    });

    try {
      final result = await _service.runWalkForwardBacktest(
        stockCode: stockCode,
        months: months,
        minVolume: minVolume,
        minTradeValue: minTradeValue,
        stopLossCandidates: stopLossCandidates,
        takeProfitCandidates: takeProfitCandidates,
        enableTrailingStop: _enableTrailingStop,
        trailingPullbackPercent: trailingPullback,
        enableAdaptiveAtr: _enableAdaptiveAtr,
        atrTakeProfitMultiplier: atrTakeProfitMultiplier,
        feeBps: feeBps,
        slippageBps: slippageBps,
        trainMonths: trainMonths,
        validationMonths: validationMonths,
      );

      setState(() {
        _walkForwardResult = result;
      });
    } catch (error) {
      setState(() {
        _gridError = error.toString();
      });
    } finally {
      setState(() {
        _isWalkForwardLoading = false;
      });
    }
  }

  Future<void> _applyTopGridToMain() async {
    if (_gridResults.isEmpty) {
      return;
    }

    final top = _gridResults.first;
    final currentStopLoss =
        int.tryParse(_stopLossController.text.trim()) ?? (widget.initialStopLoss ?? 5);
    final currentTakeProfit =
        int.tryParse(_takeProfitController.text.trim()) ?? (widget.initialTakeProfit ?? 10);
    final stopLossChanged = currentStopLoss != top.stopLossPercent;
    final takeProfitChanged = currentTakeProfit != top.takeProfitPercent;
    final noValueChanged = !stopLossChanged && !takeProfitChanged;

    if (_skipTop1ConfirmForSession) {
      if (noValueChanged) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Top1 與目前設定相同，無需套用')),
        );
        return;
      }

      Navigator.of(context).pop(
        BacktestTuningResult(
          stopLossPercent: top.stopLossPercent,
          takeProfitPercent: top.takeProfitPercent,
          applyStopLoss: true,
          applyTakeProfit: true,
        ),
      );
      return;
    }

    var applyStopLoss = true;
    var applyTakeProfit = true;
    var skipConfirmThisSession = _skipTop1ConfirmForSession;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('套用 Top1 到主策略'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top1 參數：停損 -${top.stopLossPercent}% / 停利 +${top.takeProfitPercent}%'),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        stopLossChanged ? Icons.trending_up : Icons.check,
                        size: 16,
                        color: stopLossChanged
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          stopLossChanged
                              ? '停損：目前 -$currentStopLoss% → 新 -${top.stopLossPercent}%'
                              : '停損：-$currentStopLoss%（不變）',
                          style: stopLossChanged
                              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                              : Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        takeProfitChanged ? Icons.trending_up : Icons.check,
                        size: 16,
                        color: takeProfitChanged
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          takeProfitChanged
                              ? '停利：目前 +$currentTakeProfit% → 新 +${top.takeProfitPercent}%'
                              : '停利：+$currentTakeProfit%（不變）',
                          style: takeProfitChanged
                              ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  )
                              : Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('套用停損%'),
                    value: applyStopLoss,
                    onChanged: (value) {
                      setDialogState(() {
                        applyStopLoss = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('套用停利%'),
                    value: applyTakeProfit,
                    onChanged: (value) {
                      setDialogState(() {
                        applyTakeProfit = value ?? false;
                      });
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('本次略過確認（同頁有效）'),
                    value: skipConfirmThisSession,
                    onChanged: (value) {
                      setDialogState(() {
                        skipConfirmThisSession = value ?? false;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                if (!noValueChanged)
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('取消'),
                  ),
                FilledButton(
                  onPressed: noValueChanged
                      ? () => Navigator.of(dialogContext).pop(false)
                      : (applyStopLoss || applyTakeProfit)
                          ? () => Navigator.of(dialogContext).pop(true)
                          : null,
                  child: Text(noValueChanged ? '返回' : '確認套用'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (skipConfirmThisSession != _skipTop1ConfirmForSession) {
      setState(() {
        _skipTop1ConfirmForSession = skipConfirmThisSession;
      });
    }

    Navigator.of(context).pop(
      BacktestTuningResult(
        stopLossPercent: top.stopLossPercent,
        takeProfitPercent: top.takeProfitPercent,
        applyStopLoss: applyStopLoss,
        applyTakeProfit: applyTakeProfit,
      ),
    );
  }

  @override
  void dispose() {
    _stockCodeController.dispose();
    _monthsController.dispose();
    _minVolumeController.dispose();
    _minTradeValueController.dispose();
    _stopLossController.dispose();
    _takeProfitController.dispose();
    _stopLossGridController.dispose();
    _takeProfitGridController.dispose();
    _trailingPullbackController.dispose();
    _atrTakeProfitMultiplierController.dispose();
    _feeBpsController.dispose();
    _slippageBpsController.dispose();
    _walkForwardTrainMonthsController.dispose();
    _walkForwardValidationMonthsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('回測 MVP'),
            if (_skipTop1ConfirmForSession) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '快速模式',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: _skipTop1ConfirmForSession ? '關閉快速模式' : '開啟快速模式',
            onPressed: () {
              setState(() {
                _skipTop1ConfirmForSession = !_skipTop1ConfirmForSession;
              });
            },
            icon: Icon(
              _skipTop1ConfirmForSession
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _stockCodeController,
            decoration: const InputDecoration(labelText: '股票代號（例：2330）'),
          ),
          TextField(
            controller: _monthsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '回測月數（例：6）'),
          ),
          TextField(
            controller: _minVolumeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '成交量門檻'),
          ),
          TextField(
            controller: _minTradeValueController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '成交值門檻'),
          ),
          TextField(
            controller: _stopLossController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '停損%'),
          ),
          TextField(
            controller: _takeProfitController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '停利%'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enableTrailingStop,
            title: const Text('啟用移動停利（達停利後改回撤出場）'),
            onChanged: (value) {
              setState(() {
                _enableTrailingStop = value;
              });
            },
          ),
          TextField(
            controller: _trailingPullbackController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '移動停利回撤%（例：3）'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _enableAdaptiveAtr,
            title: const Text('啟用 ATR 自適應停利'),
            onChanged: (value) {
              setState(() {
                _enableAdaptiveAtr = value;
              });
            },
          ),
          TextField(
            controller: _atrTakeProfitMultiplierController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'ATR 停利倍數（例：2）'),
          ),
          TextField(
            controller: _feeBpsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '手續費+稅（bps，例：14）'),
          ),
          TextField(
            controller: _slippageBpsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '滑價（bps，例：10）'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _stopLossGridController,
            decoration: const InputDecoration(
              labelText: '停損候選（逗號分隔，如 4,5,6）',
            ),
          ),
          TextField(
            controller: _takeProfitGridController,
            decoration: const InputDecoration(
              labelText: '停利候選（逗號分隔，如 8,10,12）',
            ),
          ),
          TextField(
            controller: _walkForwardTrainMonthsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Walk-forward 訓練月數（例：4）'),
          ),
          TextField(
            controller: _walkForwardValidationMonthsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Walk-forward 驗證月數（例：2）'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isLoading ? null : _runBacktest,
            icon: const Icon(Icons.analytics),
            label: Text(_isLoading ? '回測中...' : '執行回測'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isGridLoading ? null : _runGridScan,
            icon: const Icon(Icons.grid_view_rounded),
            label: Text(_isGridLoading ? '掃描中...' : '多參數掃描'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isWalkForwardLoading ? null : _runWalkForward,
            icon: const Icon(Icons.timeline),
            label: Text(_isWalkForwardLoading ? 'Walk-forward 中...' : 'Walk-forward 回測'),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_gridError != null)
            Text(
              _gridError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            _SummaryCard(result: _result!),
            const SizedBox(height: 12),
            Text('交易明細', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._result!.trades.map(
              (trade) => Card(
                child: ListTile(
                  title: Text(
                    '${trade.entryDate.toString().split(' ').first} → ${trade.exitDate.toString().split(' ').first}',
                  ),
                  subtitle: Text(
                    '進 ${trade.entryPrice.toStringAsFixed(2)} / 出 ${trade.exitPrice.toStringAsFixed(2)}',
                  ),
                  trailing: Text(
                    '${trade.pnlPercent >= 0 ? '+' : ''}${trade.pnlPercent.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: trade.pnlPercent >= 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_gridResults.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('多參數掃描（Top 5）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_skipTop1ConfirmForSession)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _skipTop1ConfirmForSession = false;
                    });
                  },
                  icon: const Icon(Icons.undo, size: 18),
                  label: const Text('已啟用快速模式，點此恢復確認'),
                ),
              ),
            FilledButton.tonalIcon(
              onPressed: _applyTopGridToMain,
              icon: const Icon(Icons.auto_fix_high),
              label: Text(
                '${_skipTop1ConfirmForSession ? '快速套用 Top1' : '套用 Top1 到主策略'}（停損 -${_gridResults.first.stopLossPercent}% / 停利 +${_gridResults.first.takeProfitPercent}%）',
              ),
            ),
            const SizedBox(height: 8),
            ..._gridResults.take(5).map(
              (item) => Card(
                child: ListTile(
                  title: Text(
                    '停損 -${item.stopLossPercent}% / 停利 +${item.takeProfitPercent}%',
                  ),
                  subtitle: Text(
                    '總報酬 ${item.result.totalPnlPercent.toStringAsFixed(2)}%｜勝率 ${item.result.winRate.toStringAsFixed(1)}%｜回撤 ${item.result.maxDrawdownPercent.toStringAsFixed(2)}%｜PF ${item.result.profitFactor.toStringAsFixed(2)}｜連虧 ${item.result.maxConsecutiveLosses}',
                  ),
                  trailing: Text(
                    '${(item.result.totalPnlPercent - item.result.maxDrawdownPercent * 0.5 - item.result.maxConsecutiveLosses * 2).toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
          ],
          if (_walkForwardResult != null) ...[
            const SizedBox(height: 16),
            Text('Walk-forward 結果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                title: Text('${_walkForwardResult!.stockCode}｜窗口 ${_walkForwardResult!.windows.length} 段'),
                subtitle: Text(
                  '總報酬 ${_walkForwardResult!.totalPnlPercent.toStringAsFixed(2)}%｜平均每段 ${_walkForwardResult!.averagePnlPercent.toStringAsFixed(2)}%',
                ),
              ),
            ),
            ..._walkForwardResult!.windows.map(
              (window) => Card(
                child: ListTile(
                  title: Text('窗口 ${window.windowIndex}：停損 -${window.stopLossPercent}% / 停利 +${window.takeProfitPercent}%'),
                  subtitle: Text(
                    '報酬 ${window.result.totalPnlPercent.toStringAsFixed(2)}%｜勝率 ${window.result.winRate.toStringAsFixed(1)}%｜回撤 ${window.result.maxDrawdownPercent.toStringAsFixed(2)}%',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result});

  final BacktestResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('股票 ${result.stockCode}', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('總交易次數：${result.totalTrades}'),
            Text('勝率：${result.winRate.toStringAsFixed(2)}%'),
            Text('平均盈虧：${result.averagePnlPercent.toStringAsFixed(2)}%'),
            Text('總報酬：${result.totalPnlPercent.toStringAsFixed(2)}%'),
            Text('最大回撤：${result.maxDrawdownPercent.toStringAsFixed(2)}%'),
            Text('Profit Factor：${result.profitFactor.toStringAsFixed(2)}'),
            Text('最大連續虧損：${result.maxConsecutiveLosses} 筆'),
          ],
        ),
      ),
    );
  }
}
