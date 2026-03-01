// ignore_for_file: use_build_context_synchronously, prefer_const_constructors, prefer_const_declarations, unnecessary_brace_in_string_interps, prefer_interpolation_to_compose_strings, deprecated_member_use

import 'dart:convert';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/market_news.dart';
import 'models/stock_model.dart';
import 'pages/backtest_page.dart';
import 'services/backtest_service.dart';
import 'services/breakout_filter_service.dart';
import 'services/google_drive_backup_service.dart';
import 'services/news_service.dart';
import 'services/notification_service.dart';
import 'services/persistence_service.dart';
import 'services/stock_alert_scheduler.dart';
import 'services/stock_service.dart';
import 'strategy_utils.dart';
import 'services/intraday_controller.dart';
import 'debug/diagnostics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StockAlertScheduler.initialize();
  runApp(const StockCheckerApp());
}

class StockCheckerApp extends StatelessWidget {
  const StockCheckerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '?�股飆股?��?',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const StockListPage(),
    );
  }
}

class StockListPage extends StatefulWidget {
  const StockListPage({
    super.key,
    StockService? stockService,
  }) : _stockService = stockService;

  final StockService? _stockService;

  @override
  State<StockListPage> createState() => _StockListPageState();
}

class _StockListPageState extends State<StockListPage> {
  static const String _favoritesKey = 'favorites.codes';
  static const String _enableStrategyFilterKey = 'filter.enabled';
  static const String _onlyRisingKey = 'filter.onlyRising';
  static const String _showOnlyFavoritesKey = 'filter.showOnlyFavorites';
  static const String _showOnlyHoldingsKey = 'filter.showOnlyHoldings';
  static const String _showStrongOnlyKey = 'filter.showStrongOnly';
  static const String _sortHoldingsByRiskKey = 'holding.sortByRisk';
  static const String _showOnlyHighRiskHoldingsKey = 'holding.showOnlyHighRisk';
  static const String _holdingNotifyIncludeCautionKey =
      'notify.holding.includeCaution';
  static const String _warLooseBackupMinScoreKey = 'warLoose.backup.minScore';
  static const String _warLooseBackupMinTradeValueKey =
      'warLoose.backup.minTradeValue';
  static const String _warLooseBackupMaxChaseKey = 'warLoose.backup.maxChase';
  static const String _eventTuneBackupStopLossKey = 'eventTune.backup.stopLoss';
  static const String _eventTuneBackupTakeProfitKey =
      'eventTune.backup.takeProfit';
  static const String _eventTuneBackupRiskBudgetKey =
      'eventTune.backup.riskBudget';
  static const String _eventTuneActiveTemplateIdKey =
      'eventTune.activeTemplateId';
  static const String _maxPriceThresholdKey = 'filter.maxPriceThreshold';
  static const String _surgeVolumeThresholdKey = 'filter.surgeVolumeThreshold';
  static const String _minTradeValueThresholdKey =
      'filter.minTradeValueThreshold';
  static const String _enableScoringKey = 'filter.enableScoring';
  static const String _minScoreKey = 'filter.minScore';
  static const String _volumeWeightKey = 'filter.volumeWeight';
  static const String _changeWeightKey = 'filter.changeWeight';
  static const String _priceWeightKey = 'filter.priceWeight';
  static const String _limitTopCandidatesKey = 'filter.limitTopCandidates';
  static const String _excludeOverheatedKey = 'filter.excludeOverheated';
  static const String _maxChaseChangePercentKey =
      'filter.maxChaseChangePercent';
  static const String _enableExitSignalKey = 'exit.enableSignal';
  static const String _stopLossPercentKey = 'exit.stopLossPercent';
  static const String _takeProfitPercentKey = 'exit.takeProfitPercent';
  static const String _entryPricesKey = 'position.entryPrices';
  static const String _positionLotsKey = 'position.lots';
  static const String _holdingModeTagFingerprintByCodeKey =
      'position.modeTagFingerprintByCode';
  static const String _riskBudgetKey = 'risk.budgetPerTrade';
  static const String _autoRefreshEnabledKey = 'scan.autoRefreshEnabled';
  static const String _autoRefreshMinutesKey = 'scan.autoRefreshMinutes';
  static const String _autoApplyRecommendedModeKey =
      'scan.autoApplyRecommendedMode';
  static const String _autoApplyOnlyTradingMorningKey =
      'scan.autoApplyOnlyTradingMorning';
  static const String _expandAggressiveEstimateByDefaultKey =
      'ui.expandAggressiveEstimateByDefault';
  static const String _expandCardDetailsByDefaultKey =
      'ui.expandCardDetailsByDefault';
  static const String _mobileUiDensityKey = 'ui.mobileDensity';
  static const String _mobileTextScaleKey = 'ui.mobileTextScale';
  static const String _candidateDriftHistoryKey =
      'diagnostic.candidateDriftHistory';
  static const String _dailyCandidateArchiveKey =
      'diagnostic.dailyCandidateArchive';
    static const String _dailyPredictionArchiveKey =
      'diagnostic.dailyPredictionArchive';
    static const String _dailyContextArchiveKey =
      'diagnostic.dailyContextArchive';
  static const String _dailyFilterStatsKey =
      'diagnostic.dailyFilterStats';
    static const String _parameterChangeAuditHistoryKey =
      'diagnostic.parameterChangeAuditHistory';
  // 三大法人?��?資篩?�設�?
  static const String _enableForeignFlowFilterKey =
      'filter.foreign.enabled';
  static const String _minForeignNetKey =
      'filter.foreign.minNet';
  static const String _enableTrustFlowFilterKey =
      'filter.trust.enabled';
  static const String _minTrustNetKey =
      'filter.trust.minNet';
  static const String _enableDealerFlowFilterKey =
      'filter.dealer.enabled';
  static const String _minDealerNetKey =
      'filter.dealer.minNet';
  static const String _enableMarginDiffFilterKey =
      'filter.marginDiff.enabled';
  static const String _minMarginBalanceDiffKey =
      'filter.marginDiff.minDiff';
    static const String _lastCoreSelectionParamsSnapshotKey =
      'diagnostic.lastCoreSelectionParamsSnapshot';
  static const String _lastCandidateFilterContextKey =
      'diagnostic.lastCandidateFilterContext';
    static const String _lastCandidateFilterContextBeforeResetKey =
      'diagnostic.lastCandidateFilterContextBeforeReset';
  static const String _lastLimitedCandidateCodesKey =
      'diagnostic.lastLimitedCandidateCodes';
      static const String _lockSelectionParametersKey =
        'diagnostic.lockSelectionParameters';
  static const String _enableAutoRiskAdjustmentKey =
      'risk.autoAdjustment.enabled';
  static const String _autoRiskAdjustmentStrengthKey =
      'risk.autoAdjustment.strength';
  static const String _riskScoreHistoryKey = 'risk.autoAdjustment.history';
  static const String _signalTrackEntriesKey = 'signal.track.entries';
  static const String _googleBackupEnabledKey = 'backup.google.enabled';
  static const String _googleBackupLastAtKey = 'backup.google.lastAt';
  static const String _googleBackupEmailKey = 'backup.google.email';
  static const String _lastAutoModeAppliedAtKey = 'scan.lastAutoModeAppliedAt';
  static const String _requireOpenConfirmKey = 'scan.requireOpenConfirm';
  static const String _autoDefensiveOnHighNewsRiskKey =
      'news.autoDefensiveOnHighRisk';
  static const String _autoApplyNewsEventTemplateKey =
      'news.autoApplyEventTemplate';
  static const String _eventTemplateRestoreArmedKey =
      'news.eventTemplate.restoreArmed';
  static const String _autoRestoreNewsEventTemplateAfterDaysKey =
      'news.autoRestoreEventTemplate.afterDays';
  static const String _lastNewsEventTemplateHitAtKey =
      'news.eventTemplate.lastHitAt';
  static const String _lastTopNewsTopicTagKey = 'news.topic.lastTopTag';
  static const String _lastTopNewsTopicNotifyDayKey =
      'news.topic.lastNotifyDay';
  static const String _useRelativeVolumeFilterKey = 'filter.useRelativeVolume';
  static const String _relativeVolumePercentKey =
      'filter.relativeVolumePercent';
  static const String _manualLossStreakKey = 'risk.manualLossStreak';
  static const String _enableTrailingStopKey = 'exit.enableTrailingStop';
  static const String _trailingPullbackPercentKey =
      'exit.trailingPullbackPercent';
  static const String _tradeJournalKey = 'journal.trades';
  static const String _autoRegimeEnabledKey = 'regime.autoEnabled';
  static const String _timeSegmentTuningEnabledKey = 'timing.segmentEnabled';
  static const String _enableAdaptiveAtrExitKey = 'exit.enableAdaptiveAtr';
  static const String _atrTakeProfitMultiplierKey =
      'exit.atrTakeProfitMultiplier';
  static const String _breakoutQualityEnabledKey =
      'filter.breakoutQuality.enabled';
  static const String _breakoutMinVolumeRatioKey =
      'filter.breakoutQuality.minVolumeRatio';
  static const String _enableChipConcentrationFilterKey =
      'filter.chipConcentration.enabled';
  static const String _minChipConcentrationPercentKey =
      'filter.chipConcentration.minPercent';
  static const String _concentrationWeightKey =
      'filter.chipConcentration.weight';
  static const String _tradeValueWeightKey =
      'filter.chipConcentration.tradeValueWeight';
  static const String _enableMasterTrapFilterKey =
      'filter.masterTrap.enabled';
  static const String _masterTrapDropPercentKey =
      'filter.masterTrap.dropPercent';
  static const String _riskRewardPrefilterEnabledKey =
      'filter.riskReward.enabled';
  static const String _minRiskRewardRatioKey = 'filter.riskReward.minRatioX100';
  static const String _weeklyAutoTuneEnabledKey =
      'walkForward.weeklyAutoTune.enabled';
  static const String _weeklyAutoTuneLastAtKey =
      'walkForward.weeklyAutoTune.lastAt';
  static const String _enableMultiDayBreakoutKey =
      'filter.multiDayBreakout.enabled';
  static const String _minBreakoutStreakDaysKey =
      'filter.multiDayBreakout.minDays';
  static const String _enableFalseBreakoutProtectionKey =
      'filter.falseBreakoutProtection.enabled';
  static const String _enableMarketBreadthFilterKey =
      'filter.marketBreadth.enabled';
  static const String _minMarketBreadthRatioX100Key =
      'filter.marketBreadth.minRatioX100';
  static const String _enableEventRiskExclusionKey =
      'filter.eventRiskExclusion.enabled';
  static const String _enableEventCalendarWindowKey =
      'filter.eventCalendarWindow.enabled';
  static const String _eventCalendarGuardDaysKey =
      'filter.eventCalendarWindow.guardDays';
  static const String _enableRevenueMomentumFilterKey =
      'filter.revenueMomentum.enabled';
  static const String _minRevenueMomentumScoreKey =
      'filter.revenueMomentum.minScore';
  static const String _enableEarningsSurpriseFilterKey =
      'filter.earningsSurprise.enabled';
  static const String _minEarningsSurpriseScoreKey =
      'filter.earningsSurprise.minScore';
  static const String _enableOvernightGapRiskGuardKey =
      'filter.overnightGapRiskGuard.enabled';
  static const String _enableSectorExposureCapKey =
      'filter.sectorExposureCap.enabled';
  static const String _maxHoldingPerSectorKey =
      'filter.sectorExposureCap.maxPerSector';
  static const String BreakoutModeKey = 'filter.breakoutStageMode';
  static const String _breakoutStreakByCodeKey = 'filter.breakoutStreakByCode';
  static const String _breakoutStreakUpdatedAtKey =
      'filter.breakoutStreakUpdatedAt';
  static const String _cooldownDaysKey = 'risk.cooldownDays';
  static const String _enableScoreTierSizingKey = 'risk.enableScoreTierSizing';
  static const String _enableSectorRotationBoostKey =
      'regime.enableSectorRotationBoost';
  static const String _sectorRulesTextKey = 'regime.sectorRulesText';
  static const String _defaultSectorRulesText = '11-17=食�?/塑�?\n'
      '20-24=?�鐵/?��?\n'
      '25-29=?��?/?��?體\n'
      '58-59=?��?';

  static const int _minPrice = 5;
  static const int _maxPrice = 100;
  static const int _priceStep = 1;
  static const int _minVolume = 1000000;
  static const int _maxVolume = 50000000;
  static const int _volumeStep = 1000000;
  static const int _minTradeValue = 100000000;
  static const int _maxTradeValue = 5000000000;
  static const int _tradeValueStep = 100000000;
  static const int _minScore = 0;
  static const int _maxScore = 100;
  static const int _topCandidateLimit = 20;

  late final StockService _stockService;
  late final NewsService _newsService;
  late final BacktestService _backtestService;
  late final GoogleDriveBackupService _googleDriveBackupService;
  late Future<List<StockModel>> _stocksFuture;
  MarketNewsSnapshot? _marketNewsSnapshot;
  bool _isLoadingNews = true;
  String? _newsError;
  bool _enableStrategyFilter = false;
  bool _onlyRising = true;
  bool _showOnlyFavorites = false;
  bool _showOnlyHoldings = false;
  bool _sortHoldingsByRisk = true;
  bool _showOnlyHighRiskHoldings = false;
  bool _holdingNotifyIncludeCaution = true;
  bool _enableScoring = true;
  bool _limitTopCandidates = true;
  bool _excludeOverheated = true;
  bool _enableExitSignal = true;
  bool _showStrongOnly = false;
  bool _expandAggressiveEstimateByDefault = false;
  bool _expandCardDetailsByDefault = false;
  _MobileUiDensity _mobileUiDensity = _MobileUiDensity.comfortable;
  _MobileTextScale _mobileTextScale = _MobileTextScale.medium;
  bool _enableAutoRiskAdjustment = true;
  bool _enableGoogleDailyBackup = false;
  bool _isGoogleBackupBusy = false;
  int _autoRiskAdjustmentStrength = 50;
  bool _autoRefreshEnabled = true;
  bool _autoApplyRecommendedMode = false;
  bool _autoApplyOnlyTradingMorning = true;
  bool _requireOpenConfirm = true;
  bool _autoDefensiveOnHighNewsRisk = true;
  bool _autoApplyNewsEventTemplate = false;
  bool _eventTemplateRestoreArmed = false;
  int _autoRestoreNewsEventTemplateAfterDays = 3;
  bool _useRelativeVolumeFilter = true;
  bool _enableTrailingStop = true;
  bool _autoRegimeEnabled = true;
  bool _timeSegmentTuningEnabled = true;
  bool _enableAdaptiveAtrExit = true;
  bool _enableBreakoutQuality = true;
  bool _enableChipConcentrationFilter = false;
  double _minChipConcentrationPercent = 70.0; // percent
  int _concentrationWeight = 0;
  int _tradeValueWeight = 0;
  bool _enableMasterTrapFilter = false;
  double _masterTrapDropPercent = 10.0;
  bool _enableRiskRewardPrefilter = true;
  // new filters based on fund flow / margin
  bool _enableForeignFlowFilter = false;
  int _minForeignNet = 0;
  bool _enableTrustFlowFilter = false;
  int _minTrustNet = 0;
  bool _enableDealerFlowFilter = false;
  int _minDealerNet = 0;
  bool _enableMarginDiffFilter = false;
  int _minMarginBalanceDiff = 0;
  bool _enableWeeklyWalkForwardAutoTune = true;
  bool _enableMultiDayBreakout = true;
  bool _enableFalseBreakoutProtection = true;
  bool _enableMarketBreadthFilter = true;
  bool _enableEventRiskExclusion = true;
  bool _enableOvernightGapRiskGuard = true;
  bool _enableEventCalendarWindow = true;
  int _eventCalendarGuardDays = 1;
  bool _enableRevenueMomentumFilter = true;
  int _minRevenueMomentumScore = -1;
  bool _enableEarningsSurpriseFilter = true;
  int _minEarningsSurpriseScore = -1;
  bool _enableSectorExposureCap = true;
  bool _enableScoreTierSizing = true;
  bool _enableSectorRotationBoost = true;
  bool _lockSelectionParameters = false;
  bool _isHighNewsRiskDefenseActive = false;
  NewsRiskLevel? _lastHandledNewsRiskLevel;
  _MarketRegime _currentRegime = _MarketRegime.range;
  final Map<String, _MarketRegime> _sectorRegimeByGroup =
      <String, _MarketRegime>{};
  final Map<String, double> _sectorStrengthByGroup = <String, double>{};
  String _sectorRulesText = _defaultSectorRulesText;
  final List<_SectorRule> _sectorRules = <_SectorRule>[
    const _SectorRule(start: 11, end: 17, group: '食�?/塑�?'),
    const _SectorRule(start: 20, end: 24, group: '?�鐵/?��?'),
    const _SectorRule(start: 25, end: 29, group: '?��?/?��?�?),
    const _SectorRule(start: 58, end: 59, group: '?��?'),
  ];
  int _maxPriceThreshold = 50;
  int _surgeVolumeThreshold = 10000000;
  int _relativeVolumePercent = 120;
  int _minTradeValueThreshold = 1000000000;
  int _minScoreThreshold = 60;
  int _maxChaseChangePercent = 6;
  int _stopLossPercent = 5;
  int _takeProfitPercent = 10;
  int _volumeWeight = 40;
  int _changeWeight = 35;
  int _priceWeight = 25;
  int _autoRefreshMinutes = 15;
  int _manualLossStreak = 0;
  int _trailingPullbackPercent = 3;
  int _atrTakeProfitMultiplier = 2;
  int _breakoutMinVolumeRatioPercent = 130;
  int _minRiskRewardRatioX100 = 180;
  int _minBreakoutStreakDays = 2;
  int _minMarketBreadthRatioX100 = 110;
  int _maxHoldingPerSector = 2;
  int? _warLooseBackupMinScore;
  int? _warLooseBackupMinTradeValue;
  int? _warLooseBackupMaxChase;
  int? _eventTuneBackupStopLoss;
  int? _eventTuneBackupTakeProfit;
  int? _eventTuneBackupRiskBudget;
  String? _activeNewsEventTemplateId;
  DateTime? _lastNewsEventTemplateHitAt;
  BreakoutMode BreakoutMode = BreakoutMode.early;
  int _cooldownDays = 3;
  DateTime? _lastWeeklyAutoTuneAt;
  DateTime? _lastAutoModeAppliedAt;
  DateTime? _lastGoogleBackupAt;
  DateTime? _lastBreakoutStreakUpdatedAt;
  String? _lastTopNewsTopicTag;
  String? _lastTopNewsTopicNotifyDay;
  final Map<String, int> _breakoutStreakByCode = <String, int>{};
  double _latestMarketBreadthRatio = 1.0;
  String _searchKeyword = '';
  final List<String> _recentDiagnosticQueries = <String>[];
  final Set<String> _favoriteStockCodes = <String>{};
  final List<_TradeJournalEntry> _tradeJournalEntries = <_TradeJournalEntry>[];
  final List<_RiskScorePoint> _riskScoreHistory = <_RiskScorePoint>[];
  final List<_SignalTrackEntry> _signalTrackEntries = <_SignalTrackEntry>[];
  final Map<String, double> _entryPriceByCode = <String, double>{};
  final Map<String, double> _positionLotsByCode = <String, double>{};
  final Map<String, _EntrySignalType> _entrySignalTypeByCode =
      <String, _EntrySignalType>{};
  final Map<String, int> _entrySignalPendingCountByCode = <String, int>{};
  final Map<String, String> _holdingModeTagFingerprintByCode =
      <String, String>{};
  final Map<String, String> _holdingExitAlertFingerprintByCode =
      <String, String>{};
  // additional state for chip concentration & master-trap features
  final Map<String, double> _previousChipConcentrationByCode =
      <String, double>{};
  final Map<String, bool> _masterTrapAlertedByCode = <String, bool>{};
  Set<String> _lastLimitedCandidateCodes = <String>{};
  bool _hasLimitedCandidateSnapshot = false;
  Map<String, String> _lastCandidateFilterContext = <String, String>{};
  Map<String, String> _lastCandidateFilterContextBeforeReset =
      <String, String>{};
  final Map<String, List<String>> _lastDropReasonsByCodeSnapshot =
      <String, List<String>>{};
  final List<_CandidateDriftRecord> _candidateDriftHistory =
      <_CandidateDriftRecord>[];
  final List<_DailyCandidateSnapshot> _dailyCandidateArchive =
      <_DailyCandidateSnapshot>[];
  final List<_DailyFilterStats> _dailyFilterStats = <_DailyFilterStats>[];
    final List<_DailyPredictionSnapshot> _dailyPredictionArchive =
      <_DailyPredictionSnapshot>[];
    final List<_DailyContextSnapshot> _dailyContextArchive =
      <_DailyContextSnapshot>[];
    final List<_ParameterChangeAuditEntry> _parameterChangeAuditHistory =
      <_ParameterChangeAuditEntry>[];
    Map<String, String> _lastCoreSelectionParamsSnapshot = <String, String>{};
    String? _nextPreferenceSaveSource;
  bool _diagnosticSnapshotPersistScheduled = false;
  int _riskBudgetPerTrade = 3000;
  double _latestVolumeReference = 10000000;
  // keep last fetched stock list for weight optimization
  List<StockModel> _latestStocks = <StockModel>[];

  DateTime? _lockedMarketAverageVolumeDate;
  int? _lockedMarketAverageVolume;
  final Map<String, double> _peakPnlPercentByCode = <String, double>{};
  Timer? _autoRefreshTimer;
  String? _googleBackupEmail;

  static const _StrategyPreset _conservativePreset = _StrategyPreset(
    id: 'conservative',
    label: '保�?',
    description: '高�??��?高�??�檻�?訊�?較�?但相對穩?��?,
    onlyRising: true,
    maxPrice: 45,
    minVolume: 20000000,
    minTradeValue: 2000000000,
    enableScoring: true,
    minScore: 70,
    volumeWeight: 50,
    changeWeight: 30,
    priceWeight: 20,
  );

  static const _StrategyPreset _balancedPreset = _StrategyPreset(
    id: 'balanced',
    label: '平衡',
    description: '?�能?�漲幅兼顧�??��?大�??�日常�??��?,
    onlyRising: true,
    maxPrice: 50,
    minVolume: 10000000,
    minTradeValue: 1000000000,
    enableScoring: true,
    minScore: 60,
    volumeWeight: 40,
    changeWeight: 35,
    priceWeight: 25,
  );

  static const _StrategyPreset _aggressivePreset = _StrategyPreset(
    id: 'aggressive',
    label: '積極',
    description: '?�寬條件?�早?��?，�?波�?風險較�???,
    onlyRising: false,
    maxPrice: 60,
    minVolume: 5000000,
    minTradeValue: 500000000,
    enableScoring: true,
    minScore: 50,
    volumeWeight: 30,
    changeWeight: 45,
    priceWeight: 25,
  );

  static const List<_StrategyPreset> _presets = <_StrategyPreset>[
    _conservativePreset,
    _balancedPreset,
    _aggressivePreset,
  ];

  static const List<_NewsEventTemplate> _newsEventTemplates =
      <_NewsEventTemplate>[
    _NewsEventTemplate(
      id: 'war_conflict',
      label: '?�爭/?�緣衝�?模�?',
      adjustmentSummary: '?�寬?�股但�?低單筆風?��??��??�面空�?',
      minScore: 50,
      minTradeValue: 700000000,
      maxChase: 9,
      stopLoss: 6,
      takeProfit: 12,
      riskBudget: 2500,
      triggerKeywords: <String>[
        '?�爭',
        '衝�?',
        '空襲',
        '?�戰',
        '飛�?',
        '封�?',
        '?�緣',
        '以色??,
        '伊�?',
        '中東',
      ],
    ),
    _NewsEventTemplate(
      id: 'pandemic',
      label: '?��??�溫模�?',
      adjustmentSummary: '?��??�質?�檻�?縮�?追價?��??�空??,
      minScore: 72,
      minTradeValue: 1600000000,
      maxChase: 4,
      stopLoss: 4,
      takeProfit: 8,
      riskBudget: 2200,
      triggerKeywords: <String>[
        '?��?',
        '確診',
        '?��?',
        '?��?',
        '封�?',
        '流�?',
        '?��?',
        'COVID',
      ],
    ),
    _NewsEventTemplate(
      id: 'drug_approval',
      label: '?�藥?�可模�?',
      adjustmentSummary: '?�許題�??�波?��??�大?�利並�??�風??,
      minScore: 55,
      minTradeValue: 600000000,
      maxChase: 10,
      stopLoss: 6,
      takeProfit: 15,
      riskBudget: 2800,
      triggerKeywords: <String>[
        '?�藥',
        '?�可',
        '?��?',
        '?��?',
        '三�?',
        '?��?',
        'FDA',
        'EUA',
      ],
    ),
    _NewsEventTemplate(
      id: 'policy_stimulus',
      label: '?��??��?模�?',
      adjustmentSummary: '?�度?��?追價容�?，�??��??�共?��?�?,
      minScore: 52,
      minTradeValue: 800000000,
      maxChase: 9,
      stopLoss: 5,
      takeProfit: 13,
      riskBudget: 3000,
      triggerKeywords: <String>[
        '補助',
        '?��?',
        '?�息',
        '寬�?',
        '?��?',
        '?�建',
        '?��?',
      ],
    ),
    _NewsEventTemplate(
      id: 'rate_hike_inflation',
      label: '?�息/?�膨壓�?模�?',
      adjustmentSummary: '轉為?��?，抬高�??��??�交?��?�?,
      minScore: 68,
      minTradeValue: 1400000000,
      maxChase: 5,
      stopLoss: 4,
      takeProfit: 9,
      riskBudget: 2400,
      triggerKeywords: <String>[
        '?�息',
        '?�膨',
        'CPI',
        '?��?',
        '緊縮',
        '殖利??,
      ],
    ),
    _NewsEventTemplate(
      id: 'supply_chain_shock',
      label: '供�??�中?�模�?,
      adjustmentSummary: '?�度?��?，優?�大?��?流�??��???,
      minScore: 64,
      minTradeValue: 1200000000,
      maxChase: 6,
      stopLoss: 5,
      takeProfit: 10,
      riskBudget: 2500,
      triggerKeywords: <String>[
        '?��?',
        '缺貨',
        '?�工',
        '罷工',
        '?��?',
        '塞港',
        '?��?',
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _stockService = widget._stockService ?? StockService();
    _newsService = NewsService();
    _backtestService = BacktestService();
    _googleDriveBackupService = GoogleDriveBackupService();
    _stocksFuture = _stockService.fetchAllStocks();
    _refreshNews();
    _loadSavedPreferences();
    _refreshGoogleBackupAccount();
    _initIntradayController();
  }

  IntradayController? _intradayController;
  bool _intradayEnabled = false;

  Future<void> _initIntradayController() async {
    try {
      final c = await IntradayController.create();
      if (!mounted) return;
      setState(() {
        _intradayController = c;
        _intradayEnabled = c.enabled;
      });
    } catch (_) {
      // ignore initialization failures
    }
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Initialize PersistenceService for background writes
    await PersistenceService.instance.init(prefs);

    if (!mounted) {
      return;
    }

    setState(() {
      _favoriteStockCodes
        ..clear()
        ..addAll(prefs.getStringList(_favoritesKey) ?? const <String>[]);
      _tradeJournalEntries.clear();
      _replaceSectorRulesFromText(
        prefs.getString(_sectorRulesTextKey) ?? _defaultSectorRulesText,
      );
      _breakoutStreakByCode.clear();
      final rawBreakoutStreak = prefs.getString(_breakoutStreakByCodeKey);
      if (rawBreakoutStreak != null && rawBreakoutStreak.isNotEmpty) {
        final decoded = jsonDecode(rawBreakoutStreak);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            final parsed = int.tryParse(value.toString());
            if (parsed != null && parsed >= 0) {
              _breakoutStreakByCode[key] = parsed;
            }
          });
        }
      }
      final rawBreakoutUpdatedAt = prefs.getString(_breakoutStreakUpdatedAtKey);
      _lastBreakoutStreakUpdatedAt = rawBreakoutUpdatedAt == null
          ? null
          : DateTime.tryParse(rawBreakoutUpdatedAt);
      final rawTradeJournal = prefs.getString(_tradeJournalKey);
      if (rawTradeJournal != null && rawTradeJournal.isNotEmpty) {
        final decoded = jsonDecode(rawTradeJournal);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _TradeJournalEntry.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _tradeJournalEntries.add(parsed);
              }
            }
          }
        }
      }
      _riskScoreHistory.clear();
      final rawRiskHistory = prefs.getString(_riskScoreHistoryKey);
      if (rawRiskHistory != null && rawRiskHistory.isNotEmpty) {
        final decoded = jsonDecode(rawRiskHistory);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final point =
                  _RiskScorePoint.fromJson(Map<String, dynamic>.from(item));
              if (point != null) {
                _riskScoreHistory.add(point);
              }
            }
          }
          _riskScoreHistory.sort((a, b) => a.date.compareTo(b.date));
        }
      }
      _signalTrackEntries.clear();
      final rawSignalTrack = prefs.getString(_signalTrackEntriesKey);
      if (rawSignalTrack != null && rawSignalTrack.isNotEmpty) {
        final decoded = jsonDecode(rawSignalTrack);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _SignalTrackEntry.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _signalTrackEntries.add(parsed);
              }
            }
          }
        }
      }
      _candidateDriftHistory.clear();
      final rawCandidateDriftHistory =
          prefs.getString(_candidateDriftHistoryKey);
      if (rawCandidateDriftHistory != null && rawCandidateDriftHistory.isNotEmpty) {
        final decoded = jsonDecode(rawCandidateDriftHistory);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _CandidateDriftRecord.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _candidateDriftHistory.add(parsed);
              }
            }
          }
        }
      }
      _dailyCandidateArchive.clear();
      final rawDailyCandidateArchive =
          prefs.getString(_dailyCandidateArchiveKey);
      if (rawDailyCandidateArchive != null && rawDailyCandidateArchive.isNotEmpty) {
        final decoded = jsonDecode(rawDailyCandidateArchive);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _DailyCandidateSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _dailyCandidateArchive.add(parsed);
              }
            }
          }
          _dailyCandidateArchive.sort(
            (a, b) => b.dateKey.compareTo(a.dateKey),
          );
        }
      }
      // load filter stats
      final rawDailyFilterStats = prefs.getString(_dailyFilterStatsKey);
      if (rawDailyFilterStats != null && rawDailyFilterStats.isNotEmpty) {
        final decoded = jsonDecode(rawDailyFilterStats);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _DailyFilterStats.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _dailyFilterStats.add(parsed);
              }
            }
          }
          _dailyFilterStats.sort(
            (a, b) => b.dateKey.compareTo(a.dateKey),
          );
        }
      }
      _dailyPredictionArchive.clear();
      final rawDailyPredictionArchive =
          prefs.getString(_dailyPredictionArchiveKey);
      if (rawDailyPredictionArchive != null &&
          rawDailyPredictionArchive.isNotEmpty) {
        final decoded = jsonDecode(rawDailyPredictionArchive);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _DailyPredictionSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _dailyPredictionArchive.add(parsed);
              }
            }
          }
          _dailyPredictionArchive.sort((a, b) => b.dateKey.compareTo(a.dateKey));
        }
      }
      _dailyContextArchive.clear();
      final rawDailyContextArchive = prefs.getString(_dailyContextArchiveKey);
      if (rawDailyContextArchive != null && rawDailyContextArchive.isNotEmpty) {
        final decoded = jsonDecode(rawDailyContextArchive);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _DailyContextSnapshot.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _dailyContextArchive.add(parsed);
              }
            }
          }
          _dailyContextArchive.sort((a, b) => b.dateKey.compareTo(a.dateKey));
        }
      }
      _parameterChangeAuditHistory.clear();
      final rawParameterChangeAuditHistory =
          prefs.getString(_parameterChangeAuditHistoryKey);
      if (rawParameterChangeAuditHistory != null &&
          rawParameterChangeAuditHistory.isNotEmpty) {
        final decoded = jsonDecode(rawParameterChangeAuditHistory);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              final parsed = _ParameterChangeAuditEntry.fromJson(
                Map<String, dynamic>.from(item),
              );
              if (parsed != null) {
                _parameterChangeAuditHistory.add(parsed);
              }
            }
          }
        }
      }
      final rawCoreParamSnapshot =
          prefs.getString(_lastCoreSelectionParamsSnapshotKey);
      _lastCoreSelectionParamsSnapshot = <String, String>{};
      if (rawCoreParamSnapshot != null && rawCoreParamSnapshot.isNotEmpty) {
        final decoded = jsonDecode(rawCoreParamSnapshot);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            _lastCoreSelectionParamsSnapshot[key] = value.toString();
          });
        }
      }
      final rawCandidateContext =
          prefs.getString(_lastCandidateFilterContextKey);
      _lastCandidateFilterContext = <String, String>{};
      if (rawCandidateContext != null && rawCandidateContext.isNotEmpty) {
        final decoded = jsonDecode(rawCandidateContext);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            _lastCandidateFilterContext[key] = value.toString();
          });
        }
      }
      final rawCandidateContextBeforeReset =
          prefs.getString(_lastCandidateFilterContextBeforeResetKey);
      _lastCandidateFilterContextBeforeReset = <String, String>{};
      if (rawCandidateContextBeforeReset != null &&
          rawCandidateContextBeforeReset.isNotEmpty) {
        final decoded = jsonDecode(rawCandidateContextBeforeReset);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            _lastCandidateFilterContextBeforeReset[key] = value.toString();
          });
        }
      }
      final savedCandidateCodes =
          prefs.getStringList(_lastLimitedCandidateCodesKey);
      _lastLimitedCandidateCodes = savedCandidateCodes == null
          ? <String>{}
          : savedCandidateCodes.toSet();
      _hasLimitedCandidateSnapshot =
          savedCandidateCodes != null && _lastCandidateFilterContext.isNotEmpty;
        _lockSelectionParameters =
          prefs.getBool(_lockSelectionParametersKey) ?? _lockSelectionParameters;
      _enableStrategyFilter =
          prefs.getBool(_enableStrategyFilterKey) ?? _enableStrategyFilter;
      _onlyRising = prefs.getBool(_onlyRisingKey) ?? _onlyRising;
      _showOnlyFavorites =
          prefs.getBool(_showOnlyFavoritesKey) ?? _showOnlyFavorites;
      _showOnlyHoldings =
          prefs.getBool(_showOnlyHoldingsKey) ?? _showOnlyHoldings;
      _showStrongOnly = prefs.getBool(_showStrongOnlyKey) ?? _showStrongOnly;
      _sortHoldingsByRisk =
          prefs.getBool(_sortHoldingsByRiskKey) ?? _sortHoldingsByRisk;
      _showOnlyHighRiskHoldings = prefs.getBool(_showOnlyHighRiskHoldingsKey) ??
          _showOnlyHighRiskHoldings;
      _holdingNotifyIncludeCaution =
          prefs.getBool(_holdingNotifyIncludeCautionKey) ??
              _holdingNotifyIncludeCaution;
      if (_showOnlyFavorites && _showOnlyHoldings) {
        _showOnlyFavorites = false;
      }
      _maxPriceThreshold =
          prefs.getInt(_maxPriceThresholdKey) ?? _maxPriceThreshold;
      _surgeVolumeThreshold =
          prefs.getInt(_surgeVolumeThresholdKey) ?? _surgeVolumeThreshold;
      _relativeVolumePercent =
          prefs.getInt(_relativeVolumePercentKey) ?? _relativeVolumePercent;
      _minTradeValueThreshold =
          prefs.getInt(_minTradeValueThresholdKey) ?? _minTradeValueThreshold;
      _enableScoring = prefs.getBool(_enableScoringKey) ?? _enableScoring;
      _minScoreThreshold = prefs.getInt(_minScoreKey) ?? _minScoreThreshold;
      _volumeWeight = prefs.getInt(_volumeWeightKey) ?? _volumeWeight;
      _changeWeight = prefs.getInt(_changeWeightKey) ?? _changeWeight;
      _priceWeight = prefs.getInt(_priceWeightKey) ?? _priceWeight;
      _limitTopCandidates =
          prefs.getBool(_limitTopCandidatesKey) ?? _limitTopCandidates;
      _excludeOverheated =
          prefs.getBool(_excludeOverheatedKey) ?? _excludeOverheated;
      _maxChaseChangePercent =
          prefs.getInt(_maxChaseChangePercentKey) ?? _maxChaseChangePercent;
      _enableExitSignal =
          prefs.getBool(_enableExitSignalKey) ?? _enableExitSignal;
      _stopLossPercent = prefs.getInt(_stopLossPercentKey) ?? _stopLossPercent;
      _takeProfitPercent =
          prefs.getInt(_takeProfitPercentKey) ?? _takeProfitPercent;

      // fund?�flow / margin filters
      _enableForeignFlowFilter =
          prefs.getBool(_enableForeignFlowFilterKey) ?? _enableForeignFlowFilter;
      _minForeignNet = prefs.getInt(_minForeignNetKey) ?? _minForeignNet;
      _enableTrustFlowFilter =
          prefs.getBool(_enableTrustFlowFilterKey) ?? _enableTrustFlowFilter;
      _minTrustNet = prefs.getInt(_minTrustNetKey) ?? _minTrustNet;
      _enableDealerFlowFilter =
          prefs.getBool(_enableDealerFlowFilterKey) ?? _enableDealerFlowFilter;
      _minDealerNet = prefs.getInt(_minDealerNetKey) ?? _minDealerNet;
      _enableMarginDiffFilter =
          prefs.getBool(_enableMarginDiffFilterKey) ?? _enableMarginDiffFilter;
      _minMarginBalanceDiff =
          prefs.getInt(_minMarginBalanceDiffKey) ?? _minMarginBalanceDiff;

      final savedEntryPrices = prefs.getString(_entryPricesKey);
      _entryPriceByCode.clear();
      if (savedEntryPrices != null && savedEntryPrices.isNotEmpty) {
        final decoded = jsonDecode(savedEntryPrices);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            final parsed = double.tryParse(value.toString());
            if (parsed != null && parsed > 0) {
              _entryPriceByCode[key] = parsed;
            }
          });
        }
      }

      final savedLots = prefs.getString(_positionLotsKey);
      _positionLotsByCode.clear();
      if (savedLots != null && savedLots.isNotEmpty) {
        final decoded = jsonDecode(savedLots);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            final parsed = double.tryParse(value.toString());
            if (parsed != null && parsed > 0) {
              _positionLotsByCode[key] = parsed;
            }
          });
        }
      }

      _riskBudgetPerTrade = prefs.getInt(_riskBudgetKey) ?? _riskBudgetPerTrade;
      _autoRefreshEnabled =
          prefs.getBool(_autoRefreshEnabledKey) ?? _autoRefreshEnabled;
      _autoApplyRecommendedMode = prefs.getBool(_autoApplyRecommendedModeKey) ??
          _autoApplyRecommendedMode;
      _autoApplyOnlyTradingMorning =
          prefs.getBool(_autoApplyOnlyTradingMorningKey) ??
              _autoApplyOnlyTradingMorning;
      _expandAggressiveEstimateByDefault =
          prefs.getBool(_expandAggressiveEstimateByDefaultKey) ??
              _expandAggressiveEstimateByDefault;
      _expandCardDetailsByDefault =
          prefs.getBool(_expandCardDetailsByDefaultKey) ??
              _expandCardDetailsByDefault;
      _mobileUiDensity = _mobileUiDensityFromStorage(
        prefs.getString(_mobileUiDensityKey),
      );
      _mobileTextScale = _mobileTextScaleFromStorage(
        prefs.getString(_mobileTextScaleKey),
      );
      _enableGoogleDailyBackup =
          prefs.getBool(_googleBackupEnabledKey) ?? _enableGoogleDailyBackup;
      _googleBackupEmail = prefs.getString(_googleBackupEmailKey);
      final rawGoogleBackupAt = prefs.getString(_googleBackupLastAtKey);
      _lastGoogleBackupAt = rawGoogleBackupAt == null
          ? null
          : DateTime.tryParse(rawGoogleBackupAt);
      _enableAutoRiskAdjustment = prefs.getBool(_enableAutoRiskAdjustmentKey) ??
          _enableAutoRiskAdjustment;
      _autoRiskAdjustmentStrength =
          (prefs.getInt(_autoRiskAdjustmentStrengthKey) ??
                  _autoRiskAdjustmentStrength)
              .clamp(0, 100);
      final rawAutoModeAt = prefs.getString(_lastAutoModeAppliedAtKey);
      _lastAutoModeAppliedAt =
          rawAutoModeAt == null ? null : DateTime.tryParse(rawAutoModeAt);
      _autoRefreshMinutes =
          prefs.getInt(_autoRefreshMinutesKey) ?? _autoRefreshMinutes;
      _requireOpenConfirm =
          prefs.getBool(_requireOpenConfirmKey) ?? _requireOpenConfirm;
      _autoDefensiveOnHighNewsRisk =
          prefs.getBool(_autoDefensiveOnHighNewsRiskKey) ??
              _autoDefensiveOnHighNewsRisk;
      _autoApplyNewsEventTemplate =
          prefs.getBool(_autoApplyNewsEventTemplateKey) ??
              _autoApplyNewsEventTemplate;
      _eventTemplateRestoreArmed =
          prefs.getBool(_eventTemplateRestoreArmedKey) ??
              _eventTemplateRestoreArmed;
      _autoRestoreNewsEventTemplateAfterDays =
          (prefs.getInt(_autoRestoreNewsEventTemplateAfterDaysKey) ??
                  _autoRestoreNewsEventTemplateAfterDays)
              .clamp(1, 14);
      final rawLastEventTemplateHitAt =
          prefs.getString(_lastNewsEventTemplateHitAtKey);
      _lastNewsEventTemplateHitAt = rawLastEventTemplateHitAt == null
          ? null
          : DateTime.tryParse(rawLastEventTemplateHitAt);
      _lastTopNewsTopicTag = prefs.getString(_lastTopNewsTopicTagKey);
      _lastTopNewsTopicNotifyDay =
          prefs.getString(_lastTopNewsTopicNotifyDayKey);
      _useRelativeVolumeFilter = prefs.getBool(_useRelativeVolumeFilterKey) ??
          _useRelativeVolumeFilter;
      _manualLossStreak =
          prefs.getInt(_manualLossStreakKey) ?? _manualLossStreak;
      _enableTrailingStop =
          prefs.getBool(_enableTrailingStopKey) ?? _enableTrailingStop;
      _trailingPullbackPercent =
          prefs.getInt(_trailingPullbackPercentKey) ?? _trailingPullbackPercent;
      _autoRegimeEnabled =
          prefs.getBool(_autoRegimeEnabledKey) ?? _autoRegimeEnabled;
      _timeSegmentTuningEnabled = prefs.getBool(_timeSegmentTuningEnabledKey) ??
          _timeSegmentTuningEnabled;
      _enableAdaptiveAtrExit =
          prefs.getBool(_enableAdaptiveAtrExitKey) ?? _enableAdaptiveAtrExit;
      _atrTakeProfitMultiplier =
          prefs.getInt(_atrTakeProfitMultiplierKey) ?? _atrTakeProfitMultiplier;
      _enableBreakoutQuality =
          prefs.getBool(_breakoutQualityEnabledKey) ?? _enableBreakoutQuality;
      _enableChipConcentrationFilter =
          prefs.getBool(_enableChipConcentrationFilterKey) ?? _enableChipConcentrationFilter;
      _minChipConcentrationPercent =
          prefs.getDouble(_minChipConcentrationPercentKey) ?? _minChipConcentrationPercent;
      _concentrationWeight = prefs.getInt(_concentrationWeightKey) ?? _concentrationWeight;
      _tradeValueWeight = prefs.getInt(_tradeValueWeightKey) ?? _tradeValueWeight;
      _enableMasterTrapFilter =
          prefs.getBool(_enableMasterTrapFilterKey) ?? _enableMasterTrapFilter;
      _masterTrapDropPercent =
          prefs.getDouble(_masterTrapDropPercentKey) ?? _masterTrapDropPercent;
      _breakoutMinVolumeRatioPercent =
          prefs.getInt(_breakoutMinVolumeRatioKey) ??
              _breakoutMinVolumeRatioPercent;
      _enableRiskRewardPrefilter =
          prefs.getBool(_riskRewardPrefilterEnabledKey) ??
              _enableRiskRewardPrefilter;
      _minRiskRewardRatioX100 =
          prefs.getInt(_minRiskRewardRatioKey) ?? _minRiskRewardRatioX100;
      _warLooseBackupMinScore = prefs.getInt(_warLooseBackupMinScoreKey);
      _warLooseBackupMinTradeValue =
          prefs.getInt(_warLooseBackupMinTradeValueKey);
      _warLooseBackupMaxChase = prefs.getInt(_warLooseBackupMaxChaseKey);
      _eventTuneBackupStopLoss = prefs.getInt(_eventTuneBackupStopLossKey);
      _eventTuneBackupTakeProfit = prefs.getInt(_eventTuneBackupTakeProfitKey);
      _eventTuneBackupRiskBudget = prefs.getInt(_eventTuneBackupRiskBudgetKey);
      _activeNewsEventTemplateId =
          prefs.getString(_eventTuneActiveTemplateIdKey);
      _enableWeeklyWalkForwardAutoTune =
          prefs.getBool(_weeklyAutoTuneEnabledKey) ??
              _enableWeeklyWalkForwardAutoTune;
      final lastAutoTuneRaw = prefs.getString(_weeklyAutoTuneLastAtKey);
      _lastWeeklyAutoTuneAt =
          lastAutoTuneRaw == null ? null : DateTime.tryParse(lastAutoTuneRaw);
      _enableMultiDayBreakout =
          prefs.getBool(_enableMultiDayBreakoutKey) ?? _enableMultiDayBreakout;
      _minBreakoutStreakDays =
          prefs.getInt(_minBreakoutStreakDaysKey) ?? _minBreakoutStreakDays;
      _enableFalseBreakoutProtection =
          prefs.getBool(_enableFalseBreakoutProtectionKey) ??
              _enableFalseBreakoutProtection;
      _enableMarketBreadthFilter =
          prefs.getBool(_enableMarketBreadthFilterKey) ??
              _enableMarketBreadthFilter;
      _minMarketBreadthRatioX100 =
          prefs.getInt(_minMarketBreadthRatioX100Key) ??
              _minMarketBreadthRatioX100;
      _enableEventRiskExclusion = prefs.getBool(_enableEventRiskExclusionKey) ??
          _enableEventRiskExclusion;
      _enableEventCalendarWindow =
          prefs.getBool(_enableEventCalendarWindowKey) ??
              _enableEventCalendarWindow;
      _eventCalendarGuardDays =
          (prefs.getInt(_eventCalendarGuardDaysKey) ?? _eventCalendarGuardDays)
              .clamp(0, 3);
      _enableRevenueMomentumFilter =
          prefs.getBool(_enableRevenueMomentumFilterKey) ??
              _enableRevenueMomentumFilter;
      _minRevenueMomentumScore = (prefs.getInt(_minRevenueMomentumScoreKey) ??
              _minRevenueMomentumScore)
          .clamp(-3, 3);
      _enableEarningsSurpriseFilter =
          prefs.getBool(_enableEarningsSurpriseFilterKey) ??
              _enableEarningsSurpriseFilter;
      _minEarningsSurpriseScore = (prefs.getInt(_minEarningsSurpriseScoreKey) ??
              _minEarningsSurpriseScore)
          .clamp(-3, 3);
      _enableOvernightGapRiskGuard =
          prefs.getBool(_enableOvernightGapRiskGuardKey) ??
              _enableOvernightGapRiskGuard;
      _enableSectorExposureCap = prefs.getBool(_enableSectorExposureCapKey) ??
          _enableSectorExposureCap;
      _maxHoldingPerSector =
          (prefs.getInt(_maxHoldingPerSectorKey) ?? _maxHoldingPerSector)
              .clamp(1, 6);
      final breakoutStageRaw = prefs.getString(BreakoutModeKey);
      BreakoutMode = BreakoutModeFromStorage(breakoutStageRaw);
      _cooldownDays = prefs.getInt(_cooldownDaysKey) ?? _cooldownDays;
      _enableScoreTierSizing =
          prefs.getBool(_enableScoreTierSizingKey) ?? _enableScoreTierSizing;
      _enableSectorRotationBoost =
          prefs.getBool(_enableSectorRotationBoostKey) ??
              _enableSectorRotationBoost;
      final savedModeTagFingerprintByCode =
          prefs.getString(_holdingModeTagFingerprintByCodeKey);
      _holdingModeTagFingerprintByCode.clear();
      if (savedModeTagFingerprintByCode != null &&
          savedModeTagFingerprintByCode.isNotEmpty) {
        final decoded = jsonDecode(savedModeTagFingerprintByCode);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            final text = value.toString().trim();
            if (text.isNotEmpty) {
              _holdingModeTagFingerprintByCode[key] = text;
            }
          });
        }
      }
      if (_lastCoreSelectionParamsSnapshot.isEmpty) {
        _lastCoreSelectionParamsSnapshot =
            _buildCoreSelectionParamsSnapshot();
      }
    });

    _configureAutoRefreshTimer();
  }

  Future<void> _savePreferences() async {
    _recordCoreParameterAuditIfChanged(
      source: _consumePreferenceSaveSource(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, _favoriteStockCodes.toList());
    await prefs.setBool(_enableStrategyFilterKey, _enableStrategyFilter);
    await prefs.setBool(_onlyRisingKey, _onlyRising);
    await prefs.setBool(_showOnlyFavoritesKey, _showOnlyFavorites);
    await prefs.setBool(_showOnlyHoldingsKey, _showOnlyHoldings);
    await prefs.setBool(_showStrongOnlyKey, _showStrongOnly);
    await prefs.setBool(_sortHoldingsByRiskKey, _sortHoldingsByRisk);
    await prefs.setBool(
      _showOnlyHighRiskHoldingsKey,
      _showOnlyHighRiskHoldings,
    );
    await prefs.setBool(
      _holdingNotifyIncludeCautionKey,
      _holdingNotifyIncludeCaution,
    );
    await prefs.setInt(_maxPriceThresholdKey, _maxPriceThreshold);
    await prefs.setInt(_surgeVolumeThresholdKey, _surgeVolumeThreshold);
    await prefs.setInt(_relativeVolumePercentKey, _relativeVolumePercent);
    await prefs.setInt(_minTradeValueThresholdKey, _minTradeValueThreshold);
    await prefs.setBool(_enableScoringKey, _enableScoring);
    await prefs.setInt(_minScoreKey, _minScoreThreshold);
    await prefs.setInt(_volumeWeightKey, _volumeWeight);
    await prefs.setInt(_changeWeightKey, _changeWeight);
    await prefs.setInt(_priceWeightKey, _priceWeight);
    await prefs.setBool(_limitTopCandidatesKey, _limitTopCandidates);
    await prefs.setBool(_excludeOverheatedKey, _excludeOverheated);
    await prefs.setInt(_maxChaseChangePercentKey, _maxChaseChangePercent);
    await prefs.setBool(_enableExitSignalKey, _enableExitSignal);
    await prefs.setInt(_stopLossPercentKey, _stopLossPercent);
    await prefs.setInt(_takeProfitPercentKey, _takeProfitPercent);
    // fund?�flow / margin filters
    await prefs.setBool(_enableForeignFlowFilterKey, _enableForeignFlowFilter);
    await prefs.setInt(_minForeignNetKey, _minForeignNet);
    await prefs.setBool(_enableTrustFlowFilterKey, _enableTrustFlowFilter);
    await prefs.setInt(_minTrustNetKey, _minTrustNet);
    await prefs.setBool(_enableDealerFlowFilterKey, _enableDealerFlowFilter);
    await prefs.setInt(_minDealerNetKey, _minDealerNet);
    await prefs.setBool(_enableMarginDiffFilterKey, _enableMarginDiffFilter);
    await prefs.setInt(_minMarginBalanceDiffKey, _minMarginBalanceDiff);
    await prefs.setString(_entryPricesKey, jsonEncode(_entryPriceByCode));
    await prefs.setString(_positionLotsKey, jsonEncode(_positionLotsByCode));
    await prefs.setString(
      _holdingModeTagFingerprintByCodeKey,
      jsonEncode(_holdingModeTagFingerprintByCode),
    );
    await prefs.setInt(_riskBudgetKey, _riskBudgetPerTrade);
    await prefs.setBool(_autoRefreshEnabledKey, _autoRefreshEnabled);
    await prefs.setBool(
        _autoApplyRecommendedModeKey, _autoApplyRecommendedMode);
    await prefs.setBool(
      _autoApplyOnlyTradingMorningKey,
      _autoApplyOnlyTradingMorning,
    );
    await prefs.setBool(
      _expandAggressiveEstimateByDefaultKey,
      _expandAggressiveEstimateByDefault,
    );
    await prefs.setBool(
      _expandCardDetailsByDefaultKey,
      _expandCardDetailsByDefault,
    );
    await prefs.setString(_mobileUiDensityKey, _mobileUiDensity.name);
    await prefs.setString(_mobileTextScaleKey, _mobileTextScale.name);
    await prefs.setBool(_googleBackupEnabledKey, _enableGoogleDailyBackup);
    if (_googleBackupEmail != null && _googleBackupEmail!.isNotEmpty) {
      await prefs.setString(_googleBackupEmailKey, _googleBackupEmail!);
    } else {
      await prefs.remove(_googleBackupEmailKey);
    }
    if (_lastGoogleBackupAt != null) {
      await prefs.setString(
          _googleBackupLastAtKey, _lastGoogleBackupAt!.toIso8601String());
    } else {
      await prefs.remove(_googleBackupLastAtKey);
    }
    await prefs.setBool(
        _enableAutoRiskAdjustmentKey, _enableAutoRiskAdjustment);
    await prefs.setInt(
      _autoRiskAdjustmentStrengthKey,
      _autoRiskAdjustmentStrength,
    );
    if (_lastAutoModeAppliedAt != null) {
      await prefs.setString(
        _lastAutoModeAppliedAtKey,
        _lastAutoModeAppliedAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_lastAutoModeAppliedAtKey);
    }
    await prefs.setInt(_autoRefreshMinutesKey, _autoRefreshMinutes);
    await prefs.setBool(_requireOpenConfirmKey, _requireOpenConfirm);
    await prefs.setBool(
      _autoDefensiveOnHighNewsRiskKey,
      _autoDefensiveOnHighNewsRisk,
    );
    await prefs.setBool(
      _autoApplyNewsEventTemplateKey,
      _autoApplyNewsEventTemplate,
    );
    await prefs.setBool(
      _eventTemplateRestoreArmedKey,
      _eventTemplateRestoreArmed,
    );
    await prefs.setInt(
      _autoRestoreNewsEventTemplateAfterDaysKey,
      _autoRestoreNewsEventTemplateAfterDays,
    );
    if (_lastNewsEventTemplateHitAt != null) {
      await prefs.setString(
        _lastNewsEventTemplateHitAtKey,
        _lastNewsEventTemplateHitAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_lastNewsEventTemplateHitAtKey);
    }
    if (_lastTopNewsTopicTag != null && _lastTopNewsTopicTag!.isNotEmpty) {
      await prefs.setString(_lastTopNewsTopicTagKey, _lastTopNewsTopicTag!);
    } else {
      await prefs.remove(_lastTopNewsTopicTagKey);
    }
    if (_lastTopNewsTopicNotifyDay != null &&
        _lastTopNewsTopicNotifyDay!.isNotEmpty) {
      await prefs.setString(
        _lastTopNewsTopicNotifyDayKey,
        _lastTopNewsTopicNotifyDay!,
      );
    } else {
      await prefs.remove(_lastTopNewsTopicNotifyDayKey);
    }
    await prefs.setBool(_useRelativeVolumeFilterKey, _useRelativeVolumeFilter);
    await prefs.setInt(_manualLossStreakKey, _manualLossStreak);
    await prefs.setBool(_enableTrailingStopKey, _enableTrailingStop);
    await prefs.setInt(_trailingPullbackPercentKey, _trailingPullbackPercent);
    await prefs.setBool(_autoRegimeEnabledKey, _autoRegimeEnabled);
    await prefs.setBool(
        _timeSegmentTuningEnabledKey, _timeSegmentTuningEnabled);
    await prefs.setBool(_enableAdaptiveAtrExitKey, _enableAdaptiveAtrExit);
    await prefs.setInt(_atrTakeProfitMultiplierKey, _atrTakeProfitMultiplier);
    await prefs.setBool(_breakoutQualityEnabledKey, _enableBreakoutQuality);
    await prefs.setBool(_enableChipConcentrationFilterKey, _enableChipConcentrationFilter);
    await prefs.setDouble(_minChipConcentrationPercentKey, _minChipConcentrationPercent);
    await prefs.setInt(_concentrationWeightKey, _concentrationWeight);
    await prefs.setInt(_tradeValueWeightKey, _tradeValueWeight);
    await prefs.setBool(_enableMasterTrapFilterKey, _enableMasterTrapFilter);
    await prefs.setDouble(_masterTrapDropPercentKey, _masterTrapDropPercent);
    await prefs.setInt(
        _breakoutMinVolumeRatioKey, _breakoutMinVolumeRatioPercent);
    await prefs.setBool(
        _riskRewardPrefilterEnabledKey, _enableRiskRewardPrefilter);
    await prefs.setInt(_minRiskRewardRatioKey, _minRiskRewardRatioX100);
    if (_warLooseBackupMinScore != null) {
      await prefs.setInt(_warLooseBackupMinScoreKey, _warLooseBackupMinScore!);
    } else {
      await prefs.remove(_warLooseBackupMinScoreKey);
    }
    if (_warLooseBackupMinTradeValue != null) {
      await prefs.setInt(
        _warLooseBackupMinTradeValueKey,
        _warLooseBackupMinTradeValue!,
      );
    } else {
      await prefs.remove(_warLooseBackupMinTradeValueKey);
    }
    if (_warLooseBackupMaxChase != null) {
      await prefs.setInt(_warLooseBackupMaxChaseKey, _warLooseBackupMaxChase!);
    } else {
      await prefs.remove(_warLooseBackupMaxChaseKey);
    }
    if (_eventTuneBackupStopLoss != null) {
      await prefs.setInt(
          _eventTuneBackupStopLossKey, _eventTuneBackupStopLoss!);
    } else {
      await prefs.remove(_eventTuneBackupStopLossKey);
    }
    if (_eventTuneBackupTakeProfit != null) {
      await prefs.setInt(
        _eventTuneBackupTakeProfitKey,
        _eventTuneBackupTakeProfit!,
      );
    } else {
      await prefs.remove(_eventTuneBackupTakeProfitKey);
    }
    if (_eventTuneBackupRiskBudget != null) {
      await prefs.setInt(
          _eventTuneBackupRiskBudgetKey, _eventTuneBackupRiskBudget!);
    } else {
      await prefs.remove(_eventTuneBackupRiskBudgetKey);
    }
    if (_activeNewsEventTemplateId != null &&
        _activeNewsEventTemplateId!.isNotEmpty) {
      await prefs.setString(
        _eventTuneActiveTemplateIdKey,
        _activeNewsEventTemplateId!,
      );
    } else {
      await prefs.remove(_eventTuneActiveTemplateIdKey);
    }
    await prefs.setBool(
        _weeklyAutoTuneEnabledKey, _enableWeeklyWalkForwardAutoTune);
    if (_lastWeeklyAutoTuneAt != null) {
      await prefs.setString(
          _weeklyAutoTuneLastAtKey, _lastWeeklyAutoTuneAt!.toIso8601String());
    } else {
      await prefs.remove(_weeklyAutoTuneLastAtKey);
    }
    await prefs.setInt(_cooldownDaysKey, _cooldownDays);
    await prefs.setBool(_enableMultiDayBreakoutKey, _enableMultiDayBreakout);
    await prefs.setInt(_minBreakoutStreakDaysKey, _minBreakoutStreakDays);
    await prefs.setBool(
      _enableFalseBreakoutProtectionKey,
      _enableFalseBreakoutProtection,
    );
    await prefs.setBool(
        _enableMarketBreadthFilterKey, _enableMarketBreadthFilter);
    await prefs.setInt(
        _minMarketBreadthRatioX100Key, _minMarketBreadthRatioX100);
    await prefs.setBool(
        _enableEventRiskExclusionKey, _enableEventRiskExclusion);
    await prefs.setBool(
      _enableEventCalendarWindowKey,
      _enableEventCalendarWindow,
    );
    await prefs.setInt(_eventCalendarGuardDaysKey, _eventCalendarGuardDays);
    await prefs.setBool(
      _enableRevenueMomentumFilterKey,
      _enableRevenueMomentumFilter,
    );
    await prefs.setInt(_minRevenueMomentumScoreKey, _minRevenueMomentumScore);
    await prefs.setBool(
      _enableEarningsSurpriseFilterKey,
      _enableEarningsSurpriseFilter,
    );
    await prefs.setInt(
      _minEarningsSurpriseScoreKey,
      _minEarningsSurpriseScore,
    );
    await prefs.setBool(
      _enableOvernightGapRiskGuardKey,
      _enableOvernightGapRiskGuard,
    );
    await prefs.setBool(_enableSectorExposureCapKey, _enableSectorExposureCap);
    await prefs.setInt(_maxHoldingPerSectorKey, _maxHoldingPerSector);
    await prefs.setString(BreakoutModeKey, BreakoutMode.name);
    await prefs.setString(
        _breakoutStreakByCodeKey, jsonEncode(_breakoutStreakByCode));
    if (_lastBreakoutStreakUpdatedAt != null) {
      await prefs.setString(
        _breakoutStreakUpdatedAtKey,
        _lastBreakoutStreakUpdatedAt!.toIso8601String(),
      );
    } else {
      await prefs.remove(_breakoutStreakUpdatedAtKey);
    }
    await prefs.setBool(_enableScoreTierSizingKey, _enableScoreTierSizing);
    await prefs.setBool(
        _enableSectorRotationBoostKey, _enableSectorRotationBoost);
    await prefs.setString(_sectorRulesTextKey, _sectorRulesText);
    await prefs.setString(
      _tradeJournalKey,
      jsonEncode(_tradeJournalEntries.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _riskScoreHistoryKey,
      jsonEncode(_riskScoreHistory.map((point) => point.toJson()).toList()),
    );
    await prefs.setString(
      _signalTrackEntriesKey,
      jsonEncode(_signalTrackEntries.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _candidateDriftHistoryKey,
      jsonEncode(_candidateDriftHistory.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _dailyCandidateArchiveKey,
      jsonEncode(_dailyCandidateArchive.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _dailyFilterStatsKey,
      jsonEncode(_dailyFilterStats.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _dailyPredictionArchiveKey,
      jsonEncode(_dailyPredictionArchive.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _dailyContextArchiveKey,
      jsonEncode(_dailyContextArchive.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _parameterChangeAuditHistoryKey,
      jsonEncode(_parameterChangeAuditHistory.map((entry) => entry.toJson()).toList()),
    );
    await prefs.setString(
      _lastCoreSelectionParamsSnapshotKey,
      jsonEncode(_lastCoreSelectionParamsSnapshot),
    );
    await prefs.setString(
      _lastCandidateFilterContextKey,
      jsonEncode(_lastCandidateFilterContext),
    );
    await prefs.setString(
      _lastCandidateFilterContextBeforeResetKey,
      jsonEncode(_lastCandidateFilterContextBeforeReset),
    );
    await prefs.setStringList(
      _lastLimitedCandidateCodesKey,
      _lastLimitedCandidateCodes.toList(),
    );
    await prefs.setBool(
      _lockSelectionParametersKey,
      _lockSelectionParameters,
    );
  }

  Future<void> _savePreferencesTagged(String source) async {
    final normalized = source.trim().isEmpty ? 'system' : source.trim();
    _nextPreferenceSaveSource = normalized;
    try {
      await _savePreferences();
    } finally {
      _nextPreferenceSaveSource = null;
    }
  }

  String _consumePreferenceSaveSource() {
    final source = _nextPreferenceSaveSource;
    _nextPreferenceSaveSource = null;
    if (source == null || source.trim().isEmpty) {
      return 'system';
    }
    return source.trim();
  }

  Map<String, String> _buildCoreSelectionParamsSnapshot() {
    return <String, String>{
      'strategy': _enableStrategyFilter ? '1' : '0',
      'onlyRising': _onlyRising ? '1' : '0',
      'maxPrice': _maxPriceThreshold.toString(),
      'minVolume': _surgeVolumeThreshold.toString(),
      'minTradeValue': _minTradeValueThreshold.toString(),
      'enableScoring': _enableScoring ? '1' : '0',
      'minScore': _minScoreThreshold.toString(),
      'excludeOverheated': _excludeOverheated ? '1' : '0',
      'maxChase': _maxChaseChangePercent.toString(),
      'breakoutMode': BreakoutMode.name,
      'eventWindowEnabled': _enableEventCalendarWindow ? '1' : '0',
      'eventWindowDays': _eventCalendarGuardDays.toString(),
      'revenueEnabled': _enableRevenueMomentumFilter ? '1' : '0',
      'revenueMin': _minRevenueMomentumScore.toString(),
      'earningsEnabled': _enableEarningsSurpriseFilter ? '1' : '0',
      'earningsMin': _minEarningsSurpriseScore.toString(),
      'riskRewardEnabled': _enableRiskRewardPrefilter ? '1' : '0',
      'riskRewardMin': _minRiskRewardRatioX100.toString(),
      'breadthEnabled': _enableMarketBreadthFilter ? '1' : '0',
      'breadthMin': _minMarketBreadthRatioX100.toString(),
      'sectorCapEnabled': _enableSectorExposureCap ? '1' : '0',
      'sectorCap': _maxHoldingPerSector.toString(),
      'stopLoss': _stopLossPercent.toString(),
      'takeProfit': _takeProfitPercent.toString(),
      'riskBudget': _riskBudgetPerTrade.toString(),
      'cooldownDays': _cooldownDays.toString(),
      'foreignEnabled': _enableForeignFlowFilter ? '1' : '0',
      'foreignMin': _minForeignNet.toString(),
      'trustEnabled': _enableTrustFlowFilter ? '1' : '0',
      'trustMin': _minTrustNet.toString(),
      'dealerEnabled': _enableDealerFlowFilter ? '1' : '0',
      'dealerMin': _minDealerNet.toString(),
      'marginDiffEnabled': _enableMarginDiffFilter ? '1' : '0',
      'marginMin': _minMarginBalanceDiff.toString(),
    };
  }

  String? _coreSelectionParamLabel(String key) {
    return switch (key) {
      'strategy' => '?�用策略篩選',
      'onlyRising' => '?��?上漲',
      'maxPrice' => '?�價上�?',
      'minVolume' => '?�能?��?,
      'minTradeValue' => '?�交?��?�?,
      'enableScoring' => '?�用?��?',
      'minScore' => '?�低�???,
      'excludeOverheated' => '?�除追�?風險',
      'maxChase' => '追�?漲�?上�?',
      'breakoutMode' => '飆股模�?',
      'eventWindowEnabled' => '事件窗�?�?,
      'eventWindowDays' => '事件窗天??,
      'revenueEnabled' => '?�收?�能?�濾',
      'revenueMin' => '?�收?�能?��?,
      'earningsEnabled' => '財報驚�??�濾',
      'earningsMin' => '財報驚�??��?,
      'riskRewardEnabled' => '風險?�酬?�濾',
      'riskRewardMin' => '風險?�酬比�?�?,
      'breadthEnabled' => '市場寬度?�濾',
      'breadthMin' => '市場寬度?��?,
      'sectorCapEnabled' => '?�業?�中度�???,
      'sectorCap' => '?��??�業上�?',
      'stopLoss' => '?��?(%)',
      'takeProfit' => '?�利(%)',
      'riskBudget' => '?��?風險額度',
      'cooldownDays' => '?��??�卻天數',
      'foreignEnabled' => '外�?淨買�?,
      'foreignMin' => '外�??��?,
      'trustEnabled' => '?�信淨買�?,
      'trustMin' => '?�信?��?,
      'dealerEnabled' => '?��??�淨買�?',
      'dealerMin' => '?��??��?�?,
      'marginDiffEnabled' => '?��?餘�?變�?',
      'marginMin' => '?��??��?,
      _ => null,
    };
  }

  String _coreSelectionParamValueLabel(String key, String value) {
    switch (key) {
      case 'strategy':
      case 'onlyRising':
      case 'enableScoring':
      case 'excludeOverheated':
      case 'eventWindowEnabled':
      case 'revenueEnabled':
      case 'earningsEnabled':
      case 'riskRewardEnabled':
      case 'breadthEnabled':
      case 'sectorCapEnabled':
        return value == '1' ? '?? : '??;
      case 'breakoutMode':
        return BreakoutModeLabel(BreakoutModeFromStorage(value));
      default:
        return value;
    }
  }

  List<String> _buildCoreSelectionParamChangeDetails({
    required Map<String, String> previous,
    required Map<String, String> current,
  }) {
    final labels = <String>[];
    for (final entry in current.entries) {
      final before = previous[entry.key];
      if (before == null || before == entry.value) {
        continue;
      }
      final label = _coreSelectionParamLabel(entry.key);
      if (label == null) {
        continue;
      }
      final beforeText = _coreSelectionParamValueLabel(entry.key, before);
      final afterText = _coreSelectionParamValueLabel(entry.key, entry.value);
      labels.add('$label $beforeText??afterText');
    }
    return labels;
  }

  void _recordCoreParameterAuditIfChanged({required String source}) {
    final current = _buildCoreSelectionParamsSnapshot();
    if (_lastCoreSelectionParamsSnapshot.isEmpty) {
      _lastCoreSelectionParamsSnapshot = Map<String, String>.from(current);
      return;
    }

    final changes = _buildCoreSelectionParamChangeDetails(
      previous: _lastCoreSelectionParamsSnapshot,
      current: current,
    );
    _lastCoreSelectionParamsSnapshot = Map<String, String>.from(current);
    if (changes.isEmpty) {
      return;
    }

    _parameterChangeAuditHistory.insert(
      0,
      _ParameterChangeAuditEntry(
        timestamp: DateTime.now(),
        source: source,
        changes: changes,
      ),
    );
    if (_parameterChangeAuditHistory.length > 30) {
      _parameterChangeAuditHistory.removeRange(30, _parameterChangeAuditHistory.length);
    }
  }

  String _parameterAuditSourceLabel(String source) {
    return switch (source) {
      'filter_sheet_apply' => '?��?套用策略',
      'morning_scan' => '?�盤?��?',
      'news_template_apply' => '事件模板套用',
      'news_template_restore' => '事件模板?��?',
      'auto_mode_rotation' => '?��?模�??��?',
      'auto_tune_suggestion_apply' => '?�中?�自?�調??,
      _ => source,
    };
  }

  String _parameterAuditHistoryLabel(_ParameterChangeAuditEntry entry) {
    final changesPreview = entry.changes.take(2).join('??);
    final more = entry.changes.length > 2 ? ' +${entry.changes.length - 2}' : '';
    return '${_formatTimeHHmm(entry.timestamp)} ${_parameterAuditSourceLabel(entry.source)}�?changesPreview$more';
  }

  String _calendarDayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _upsertDailyCandidateArchive({
    required Set<String> coreCandidateCodes,
    required Set<String> limitedCodes,
    required Set<String> strongOnlyCodes,
  }) {
    final now = DateTime.now();
    final dateKey = _calendarDayKey(now);
    final core = coreCandidateCodes.toList()..sort();
    final limited = limitedCodes.toList()..sort();
    final strong = strongOnlyCodes.toList()..sort();

    final next = _DailyCandidateSnapshot(
      dateKey: dateKey,
      capturedAt: now,
      coreCandidateCodes: core,
      limitedCandidateCodes: limited,
      strongOnlyCodes: strong,
    );

    final index = _dailyCandidateArchive.indexWhere((item) => item.dateKey == dateKey);
    if (index >= 0) {
      final prev = _dailyCandidateArchive[index];
      if (listEquals(prev.coreCandidateCodes, next.coreCandidateCodes) &&
          listEquals(prev.limitedCandidateCodes, next.limitedCandidateCodes) &&
          listEquals(prev.strongOnlyCodes, next.strongOnlyCodes)) {
        return;
      }
      _dailyCandidateArchive[index] = next;
    } else {
      _dailyCandidateArchive.insert(0, next);
    }

    _dailyCandidateArchive.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    if (_dailyCandidateArchive.length > 45) {
      _dailyCandidateArchive.removeRange(45, _dailyCandidateArchive.length);
    }
    _scheduleDiagnosticsSnapshotPersist();
  }

  String _stableFilterContextHash(Map<String, String> context) {
    final keys = context.keys.toList()..sort();
    var checksum = 0;
    for (final key in keys) {
      final text = '$key=${context[key] ?? ''};';
      for (final unit in text.codeUnits) {
        checksum = ((checksum * 131) + unit) % 1000000007;
      }
    }
    return checksum.toRadixString(16).padLeft(8, '0');
  }

  /// Record or update today?�s filter?�drop statistics.  We replace the entry
  /// for the current date if it already exists and only persist when it
  /// actually changes (to avoid thrashing the prefs file).
  void _upsertDailyFilterStats(Map<String, int> counts) {
    if (counts.isEmpty) return;

    final now = DateTime.now();
    final dateKey = _calendarDayKey(now);
    final next = _DailyFilterStats(
      dateKey: dateKey,
      reasonCounts: Map<String, int>.from(counts),
    );

    final index = _dailyFilterStats.indexWhere((e) => e.dateKey == dateKey);
    if (index >= 0) {
      final prev = _dailyFilterStats[index];
      if (mapEquals(prev.reasonCounts, next.reasonCounts)) {
        return; // nothing changed
      }
      _dailyFilterStats[index] = next;
    } else {
      _dailyFilterStats.insert(0, next);
    }

    _dailyFilterStats.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    if (_dailyFilterStats.length > 45) {
      _dailyFilterStats.removeRange(45, _dailyFilterStats.length);
    }
    _scheduleDiagnosticsSnapshotPersist();
  }

  /// Aggregate reason counts across the most recent [lookbackDays].
  Map<String, int> _aggregateRecentFilterReasons(int lookbackDays) {
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(days: lookbackDays));
    final result = <String, int>{};
    for (final entry in _dailyFilterStats) {
      final date = DateTime.tryParse(entry.dateKey);
      if (date == null) continue;
      if (date.isBefore(cutoff)) break; // list is sorted descending
      entry.reasonCounts.forEach((k, v) {
        result.update(k, (old) => old + v, ifAbsent: () => v);
      });
    }
    return result;
  }

  void _upsertDailyPredictionArchive({
    required List<_ScoredStock> limitedCandidateStocks,
    required Set<String> coreCandidateCodes,
    required Set<String> strongOnlyCodes,
    required _EntrySignal Function(StockModel stock, int score) resolveEntrySignal,
  }) {
    final now = DateTime.now();
    final dateKey = _calendarDayKey(now);
    final rows = <_DailyPredictionRow>[];

    for (var index = 0; index < limitedCandidateStocks.length; index++) {
      final item = limitedCandidateStocks[index];
      final signal = resolveEntrySignal(item.stock, item.score);
      rows.add(
        _DailyPredictionRow(
          code: item.stock.code,
          stockName: item.stock.name,
          signalType: signal.type.name,
          rank: index + 1,
          score: item.score,
          inCore: coreCandidateCodes.contains(item.stock.code),
          inTop20: true,
          inStrong: strongOnlyCodes.contains(item.stock.code),
        ),
      );
    }

    final next = _DailyPredictionSnapshot(
      dateKey: dateKey,
      capturedAt: now,
      rows: rows,
    );

    final index = _dailyPredictionArchive.indexWhere((item) => item.dateKey == dateKey);
    if (index >= 0) {
      final prev = _dailyPredictionArchive[index];
      if (listEquals(prev.rows.map((e) => e.toCsvKey()).toList(),
          next.rows.map((e) => e.toCsvKey()).toList())) {
        return;
      }
      _dailyPredictionArchive[index] = next;
    } else {
      _dailyPredictionArchive.insert(0, next);
    }

    _dailyPredictionArchive.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    if (_dailyPredictionArchive.length > 45) {
      _dailyPredictionArchive.removeRange(45, _dailyPredictionArchive.length);
    }
    _scheduleDiagnosticsSnapshotPersist();
  }

  void _upsertDailyContextArchive({
    required double marketBreadthRatio,
    required _MarketRegime marketRegime,
    required Map<String, String> filterContext,
  }) {
    final now = DateTime.now();
    final dateKey = _calendarDayKey(now);
    final newsRisk = _marketNewsSnapshot?.level.name ?? 'unknown';
    final next = _DailyContextSnapshot(
      dateKey: dateKey,
      capturedAt: now,
      marketBreadthRatio: marketBreadthRatio,
      newsRiskLevel: newsRisk,
      breakoutMode: BreakoutMode.name,
      marketRegime: marketRegime.name,
      keyParamsHash: _stableFilterContextHash(filterContext),
    );

    final index = _dailyContextArchive.indexWhere((item) => item.dateKey == dateKey);
    if (index >= 0) {
      final prev = _dailyContextArchive[index];
      if (prev.marketBreadthRatio.toStringAsFixed(4) ==
              next.marketBreadthRatio.toStringAsFixed(4) &&
          prev.newsRiskLevel == next.newsRiskLevel &&
          prev.breakoutMode == next.breakoutMode &&
          prev.marketRegime == next.marketRegime &&
          prev.keyParamsHash == next.keyParamsHash) {
        return;
      }
      _dailyContextArchive[index] = next;
    } else {
      _dailyContextArchive.insert(0, next);
    }

    _dailyContextArchive.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    if (_dailyContextArchive.length > 90) {
      _dailyContextArchive.removeRange(90, _dailyContextArchive.length);
    }
    _scheduleDiagnosticsSnapshotPersist();
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  String _buildPredictionsCsv({required int lookbackDays}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final lines = <String>[
      'date,code,stock_name,signal_type,rank,score,in_core,in_top20,in_strong',
    ];

    final snapshots = _dailyPredictionArchive
        .where((snapshot) {
          final date = DateTime.tryParse(snapshot.dateKey);
          if (date == null) {
            return false;
          }
          return !date.isBefore(start);
        })
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    for (final snapshot in snapshots) {
      for (final row in snapshot.rows) {
        lines.add([
          _csvCell(snapshot.dateKey),
          _csvCell(row.code),
          _csvCell(row.stockName),
          _csvCell(row.signalType),
          row.rank.toString(),
          row.score.toString(),
          row.inCore ? '1' : '0',
          row.inTop20 ? '1' : '0',
          row.inStrong ? '1' : '0',
        ].join(','));
      }
    }
    return lines.join('\n');
  }

  String _buildOutcomesCsv({required int lookbackDays}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final rows = _signalTrackEntries.where((entry) => !entry.date.isBefore(start)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final lines = <String>[
      'date,code,stock_name,signal_type,entry_price,ret_1d,ret_3d,ret_5d,max_up_5d,max_dd_5d',
    ];
    for (final row in rows) {
      lines.add([
        _csvCell(_calendarDayKey(row.date)),
        _csvCell(row.stockCode),
        _csvCell(row.stockName),
        _csvCell(row.signalType.name),
        row.entryPrice.toStringAsFixed(2),
        row.return1Day?.toStringAsFixed(4) ?? '',
        row.return3Day?.toStringAsFixed(4) ?? '',
        row.return5Day?.toStringAsFixed(4) ?? '',
        '',
        '',
      ].join(','));
    }
    return lines.join('\n');
  }

  String _buildContextCsv({required int lookbackDays}) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final rows = _dailyContextArchive
        .where((entry) {
          final date = DateTime.tryParse(entry.dateKey);
          if (date == null) {
            return false;
          }
          return !date.isBefore(start);
        })
        .toList()
      ..sort((a, b) => a.dateKey.compareTo(b.dateKey));

    final lines = <String>[
      'date,market_breadth,news_risk,breakout_mode,market_regime,key_params_hash',
    ];
    for (final row in rows) {
      lines.add([
        _csvCell(row.dateKey),
        row.marketBreadthRatio.toStringAsFixed(4),
        _csvCell(row.newsRiskLevel),
        _csvCell(row.breakoutMode),
        _csvCell(row.marketRegime),
        _csvCell(row.keyParamsHash),
      ].join(','));
    }
    return lines.join('\n');
  }

  String _buildWeeklyHitRateSummaryText() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 7));
    final rows = _signalTrackEntries.where((entry) => !entry.date.isBefore(start)).toList();

    int countBy(_EntrySignalType type) =>
        rows.where((entry) => entry.signalType == type).length;

    ({int total, int win, double avg}) scoreBy(
      _EntrySignalType type,
      double? Function(_SignalTrackEntry e) getter,
    ) {
      final values = rows
          .where((entry) => entry.signalType == type)
          .map(getter)
          .whereType<double>()
          .toList();
      if (values.isEmpty) {
        return (total: 0, win: 0, avg: 0);
      }
      final win = values.where((v) => v > 0).length;
      final avg = values.fold<double>(0, (sum, value) => sum + value) / values.length;
      return (total: values.length, win: win, avg: avg);
    }

    final strong1 = scoreBy(_EntrySignalType.strong, (e) => e.return1Day);
    final watch1 = scoreBy(_EntrySignalType.watch, (e) => e.return1Day);
    final dailyPred = _dailyPredictionArchive
        .where((entry) {
          final date = DateTime.tryParse(entry.dateKey);
          if (date == null) {
            return false;
          }
          return !date.isBefore(start);
        })
        .toList();
    final avgPredPerDay = dailyPred.isEmpty
        ? 0.0
        : dailyPred
                .map((entry) => entry.rows.length)
                .fold<int>(0, (sum, value) => sum + value) /
            dailyPred.length;

    String winRateText(int win, int total) {
      if (total == 0) {
        return '0.0%';
      }
      return (win * 100 / total).toStringAsFixed(1) + '%';
    }

    return '?��?天命中�?要�?強勢訊�? ${countBy(_EntrySignalType.strong)} 筆�?1D ?��? ${winRateText(strong1.win, strong1.total)} / 平�? ${strong1.avg.toStringAsFixed(2)}%�?
        '｜�?察�???${countBy(_EntrySignalType.watch)} 筆�?1D ?��? ${winRateText(watch1.win, watch1.total)} / 平�? ${watch1.avg.toStringAsFixed(2)}%�?
        '｜平?��??�候選 ${avgPredPerDay.toStringAsFixed(1)} �?;
  }

  List<_AutoTuneSuggestion> _buildAutoTuneSuggestions({
    int lookbackDays = 30,
  }) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: lookbackDays));
    final signalRows = _signalTrackEntries
        .where((entry) => !entry.date.isBefore(start))
        .toList();
    final predictionDays = _dailyPredictionArchive
        .where((entry) {
          final date = DateTime.tryParse(entry.dateKey);
          if (date == null) {
            return false;
          }
          return !date.isBefore(start);
        })
        .toList();

    List<double> returnsOf(_EntrySignalType type) {
      return signalRows
          .where((entry) => entry.signalType == type)
          .map((entry) => entry.return1Day)
          .whereType<double>()
          .toList();
    }

    double avgOf(List<double> values) {
      if (values.isEmpty) {
        return 0;
      }
      return values.fold<double>(0, (sum, value) => sum + value) /
          values.length;
    }

    double winRateOf(List<double> values) {
      if (values.isEmpty) {
        return 0;
      }
      final wins = values.where((value) => value > 0).length;
      return (wins * 100) / values.length;
    }

    final strong = returnsOf(_EntrySignalType.strong);
    final watch = returnsOf(_EntrySignalType.watch);
    final strongAvg = avgOf(strong);
    final watchAvg = avgOf(watch);
    final strongWinRate = winRateOf(strong);
    final watchWinRate = winRateOf(watch);
    final avgCandidatesPerDay = predictionDays.isEmpty
        ? 0.0
        : predictionDays
                .map((entry) => entry.rows.length)
                .fold<int>(0, (sum, value) => sum + value) /
            predictionDays.length;

    final suggestions = <_AutoTuneSuggestion>[];

    void addSuggestion(_AutoTuneSuggestion suggestion) {
      final duplicated = suggestions.any((item) =>
          item.minScore == suggestion.minScore &&
          item.maxChaseChangePercent == suggestion.maxChaseChangePercent &&
          item.minTradeValue == suggestion.minTradeValue);
      if (!duplicated) {
        suggestions.add(suggestion);
      }
    }

    if ((strong.length + watch.length) < 12 || predictionDays.length < 5) {
      addSuggestion(
        _AutoTuneSuggestion(
          id: 'conservative_bootstrap',
          title: '�?��不足：�??��?守微�?,
          summary:
              '�?0天樣?��??��?，�??��??�數?��?交值�??��??�早?�寬導致?��?增�???,
          minScore: (_minScoreThreshold + 2).clamp(40, 90),
          maxChaseChangePercent: (_maxChaseChangePercent - 1).clamp(3, 12),
          minTradeValue:
              (_minTradeValueThreshold * 1.1).round().clamp(_minTradeValue, _maxTradeValue),
        ),
      );
      addSuggestion(
        _AutoTuneSuggestion(
          id: 'balanced_bootstrap',
          title: '�?��不足：維?�平�?,
          summary: '維�??��??�檻�??�累積更�?outcomes ?��??��?步自?�調?��?,
          minScore: _minScoreThreshold,
          maxChaseChangePercent: _maxChaseChangePercent,
          minTradeValue: _minTradeValueThreshold,
        ),
      );
      return suggestions;
    }

    final needTighten =
        avgCandidatesPerDay > 16 || watchWinRate < 42 || (strongAvg < 0 && watchAvg < 0);
    if (needTighten) {
      addSuggestion(
        _AutoTuneSuggestion(
          id: 'tighten_noise',
          title: '?��?訊�??��?守�?',
          summary:
              '?�選?��?多�? 1D ?��??��?，建議�?高�????�交?�並?��?追�?上�???,
          minScore: (_minScoreThreshold + 3).clamp(40, 90),
          maxChaseChangePercent: (_maxChaseChangePercent - 1).clamp(3, 12),
          minTradeValue:
              (_minTradeValueThreshold * 1.15).round().clamp(_minTradeValue, _maxTradeValue),
        ),
      );
    }

    final canLoosen =
        avgCandidatesPerDay < 9 && strongWinRate >= 55 && strongAvg > 0.4;
    if (canLoosen) {
      addSuggestion(
        _AutoTuneSuggestion(
          id: 'capture_more',
          title: '?��??��??��?極�?',
          summary:
              '?�選?��?少�?強勢表現穩�?，可微放寬�?檻�??�「�?一天�??�」�??��???,
          minScore: (_minScoreThreshold - 2).clamp(35, 90),
          maxChaseChangePercent: (_maxChaseChangePercent + 1).clamp(3, 12),
          minTradeValue:
              (_minTradeValueThreshold * 0.9).round().clamp(_minTradeValue, _maxTradeValue),
        ),
      );
    }

    addSuggestion(
      _AutoTuneSuggestion(
        id: 'balanced_default',
        title: '平衡微調（�?設�?',
        summary:
            '?��??��??��??��??�衷，適?��??��??��?察�?決�??�否?�為?��?�?積極??,
        minScore: (_minScoreThreshold + (needTighten ? 2 : 0) - (canLoosen ? 1 : 0))
            .clamp(35, 90),
        maxChaseChangePercent:
            (_maxChaseChangePercent - (needTighten ? 1 : 0)).clamp(3, 12),
        minTradeValue: (_minTradeValueThreshold * (needTighten ? 1.1 : 1.0))
            .round()
            .clamp(_minTradeValue, _maxTradeValue),
      ),
    );

    return suggestions.take(3).toList();
  }

  Future<void> _applyAutoTuneSuggestion(_AutoTuneSuggestion suggestion) async {
    if (_lockSelectionParameters) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已�?定選?��??��??��?套用?��?調�?建議')),
        );
      }
      return;
    }

    final prevMinScore = _minScoreThreshold;
    final prevMaxChase = _maxChaseChangePercent;
    final prevMinTradeValue = _minTradeValueThreshold;

    setState(() {
      _enableStrategyFilter = true;
      _enableScoring = true;
      _excludeOverheated = true;
      _minScoreThreshold = suggestion.minScore;
      _maxChaseChangePercent = suggestion.maxChaseChangePercent;
      _minTradeValueThreshold = suggestion.minTradeValue;
      if (!_enableScoring) {
        _showStrongOnly = false;
      }
    });
    await _savePreferencesTagged('auto_tune_suggestion_apply');

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已�??��?{suggestion.title}?��??�數 $prevMinScore??_minScoreThreshold?�追�?$prevMaxChase%??_maxChaseChangePercent%?��?交�?${_formatWithThousandsSeparator(prevMinTradeValue)}??{_formatWithThousandsSeparator(_minTradeValueThreshold)}',
        ),
      ),
    );
  }

  Future<void> _openAutoTuneSuggestionDialog() async {
    final suggestions = _buildAutoTuneSuggestions(lookbackDays: 30);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('?�中?�自?�調?�建議�??��?30 天�?'),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buildWeeklyHitRateSummaryText(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                ...suggestions.map(
                  (item) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.summary}\n?�數 >= ${item.minScore}｜追�?<= ${item.maxChaseChangePercent}%｜�?交�?>= ${_formatWithThousandsSeparator(item.minTradeValue)}',
                      ),
                      isThreeLine: true,
                      trailing: FilledButton.tonal(
                        onPressed: () async {
                          await _applyAutoTuneSuggestion(item);
                          if (mounted) {
                            Navigator.of(dialogContext).pop();
                          }
                        },
                        child: const Text('套用'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('?��?'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openAnalyticsExportDialog() async {
    final lookbackController = TextEditingController(text: '30');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String status = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> copy(String name, String content) async {
                await Clipboard.setData(ClipboardData(text: content));
                if (!mounted) {
                  return;
                }
                setDialogState(() {
                  status = '已�?�?$name�?{content.split('\n').length - 1} 筆�?';
                });
              }

              int lookbackDays() {
                final raw = int.tryParse(lookbackController.text.trim()) ?? 30;
                return raw.clamp(7, 120);
              }

              return AlertDialog(
                title: const Text('?�出?�中?��??��?CSV�?),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: lookbackController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '?�出天數�?~120�?,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _buildWeeklyHitRateSummaryText(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(status, style: Theme.of(context).textTheme.labelSmall),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('?��?'),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      copy('predictions.csv', _buildPredictionsCsv(lookbackDays: lookbackDays()));
                    },
                    child: const Text('複製 predictions.csv'),
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      copy('outcomes.csv', _buildOutcomesCsv(lookbackDays: lookbackDays()));
                    },
                    child: const Text('複製 outcomes.csv'),
                  ),
                  FilledButton(
                    onPressed: () {
                      copy('context.csv', _buildContextCsv(lookbackDays: lookbackDays()));
                    },
                    child: const Text('複製 context.csv'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      lookbackController.dispose();
    }
  }

  Future<void> _openBullRunReplayDialog() async {
    final codeController = TextEditingController();
    final daysController = TextEditingController(text: '7');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String report = _dailyCandidateArchive.isEmpty
              ? '尚無每日?�選快照，�??�至少更??1 ?�交?�日??
              : '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void runReplay() {
                if (_dailyCandidateArchive.isEmpty) {
                  setDialogState(() {
                    report = '尚無每日?�選快照，�??�至少更??1 ?�交?�日??;
                  });
                  return;
                }

                final rawCodes = codeController.text
                    .split(RegExp(r'[\s,�?；]+'))
                    .map((text) => text.trim().toUpperCase())
                    .where((text) => text.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final days = int.tryParse(daysController.text.trim()) ?? 7;
                final lookbackDays = days.clamp(3, 45);

                if (rawCodes.isEmpty) {
                  setDialogState(() {
                    report = '請輸?��??��??��??�代?��??��?檔�?以逗�??��?�?;
                  });
                  return;
                }

                final now = DateTime.now();
                final start = now.subtract(Duration(days: lookbackDays));
                final selectedSnapshots = _dailyCandidateArchive
                    .where((entry) {
                      final date = DateTime.tryParse(entry.dateKey);
                      if (date == null) {
                        return false;
                      }
                      return !date.isBefore(start);
                    })
                    .toList()
                  ..sort((a, b) => b.dateKey.compareTo(a.dateKey));

                if (selectedSnapshots.isEmpty) {
                  setDialogState(() {
                    report = '?��?$lookbackDays 天�??�可?�快?��?;
                  });
                  return;
                }

                final lines = <String>[
                  '?��??�?��??��?$lookbackDays 天�?${selectedSnapshots.length} 筆快?��?',
                  '輸入�??�?{rawCodes.join('??)}',
                ];

                var hitAnyCore = 0;
                var hitAnyStrong = 0;
                for (final code in rawCodes) {
                  var coreHits = 0;
                  var limitedHits = 0;
                  var strongHits = 0;
                  String? latestCoreDate;
                  String? latestStrongDate;

                  for (final entry in selectedSnapshots) {
                    if (entry.coreCandidateCodes.contains(code)) {
                      coreHits += 1;
                      latestCoreDate ??= entry.dateKey;
                    }
                    if (entry.limitedCandidateCodes.contains(code)) {
                      limitedHits += 1;
                    }
                    if (entry.strongOnlyCodes.contains(code)) {
                      strongHits += 1;
                      latestStrongDate ??= entry.dateKey;
                    }
                  }

                  if (coreHits > 0) {
                    hitAnyCore += 1;
                  }
                  if (strongHits > 0) {
                    hitAnyStrong += 1;
                  }

                  lines.add(
                    '$code：核�?$coreHits/${selectedSnapshots.length} 天、�?$_topCandidateLimit $limitedHits 天、強??$strongHits �?
                    '${latestCoreDate == null ? '' : '｜�?近核心命�?$latestCoreDate'}'
                    '${latestStrongDate == null ? '' : '｜�?近強?�命�?$latestStrongDate'}',
                  );
                }

                lines.add(
                  '?��?覆�?：核心命�?$hitAnyCore/${rawCodes.length} 檔、強?�命�?$hitAnyStrong/${rawCodes.length} �?,
                );
                lines.add('註�?此�??�檢?�「是?�曾?�選?��?不代表�??��?漲�?);

                setDialogState(() {
                  report = lines.join('\n');
                });
              }

              return AlertDialog(
                title: const Text('上週�??��??��??��??�是?��??��?'),
                content: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: '飆股�??（逗�??��?�?,
                          hintText: '例�? 3017, 2382, 3450',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: daysController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '?��?天數�?~45�?,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (report.isNotEmpty)
                        Text(
                          report,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('?��?'),
                  ),
                  FilledButton(
                    onPressed: runReplay,
                    child: const Text('?��?'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      codeController.dispose();
      daysController.dispose();
    }
  }

  List<_SectorRule> _parseSectorRulesText(String raw) {
    final lines = raw
        .split(RegExp(r'[\n;]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final parsed = <_SectorRule>[];
    for (final line in lines) {
      final pair = line.split('=');
      if (pair.length != 2) {
        continue;
      }

      final rangeText = pair[0].trim();
      final group = pair[1].trim();
      if (group.isEmpty) {
        continue;
      }

      final rangeParts =
          rangeText.split('-').map((part) => part.trim()).toList();
      if (rangeParts.isEmpty || rangeParts.length > 2) {
        continue;
      }

      final start = int.tryParse(rangeParts.first);
      final end = int.tryParse(
          rangeParts.length == 2 ? rangeParts.last : rangeParts.first);
      if (start == null || end == null || start > end) {
        continue;
      }

      parsed.add(_SectorRule(start: start, end: end, group: group));
    }

    return parsed;
  }

  void _replaceSectorRulesFromText(String raw) {
    final trimmed = raw.trim();
    final source = trimmed.isEmpty ? _defaultSectorRulesText : raw;
    final parsed = _parseSectorRulesText(source);
    _sectorRules
      ..clear()
      ..addAll(
        parsed.isEmpty
            ? const <_SectorRule>[
                _SectorRule(start: 11, end: 17, group: '食�?/塑�?'),
                _SectorRule(start: 20, end: 24, group: '?�鐵/?��?'),
                _SectorRule(start: 25, end: 29, group: '?��?/?��?�?),
                _SectorRule(start: 58, end: 59, group: '?��?'),
              ]
            : parsed,
      );
    _sectorRulesText = source;
  }

  void _retryFetch() {
    _refreshStocks();
  }

  Future<void> _refreshNews({bool showFeedback = false}) async {
    try {
      final snapshot = await _newsService.fetchMarketSnapshot(
        keyword: null,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _marketNewsSnapshot = snapshot;
        _isLoadingNews = false;
        _newsError = null;
      });

      await _handleNewsRiskAutomation(snapshot);
      _handleNewsEventTemplateAutomation(snapshot);
      await _maybeNotifyTopicRotation(snapshot);

      if (showFeedback) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('?��??��?已更??)),
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingNews = false;
        _newsError = '?��?載入失�?�?error';
      });
    }
  }

  void _applyPreset(_StrategyPreset preset) {
    _enableStrategyFilter = true;
    _onlyRising = preset.onlyRising;
    _maxPriceThreshold = preset.maxPrice;
    _surgeVolumeThreshold = preset.minVolume;
    _minTradeValueThreshold = preset.minTradeValue;
    _enableScoring = preset.enableScoring;
    _minScoreThreshold = preset.minScore;
    _volumeWeight = preset.volumeWeight;
    _changeWeight = preset.changeWeight;
    _priceWeight = preset.priceWeight;
  }

  Future<void> _handleNewsRiskAutomation(MarketNewsSnapshot snapshot) async {
    if (_lockSelectionParameters) {
      _lastHandledNewsRiskLevel = snapshot.level;
      if (_isHighNewsRiskDefenseActive && mounted) {
        setState(() {
          _isHighNewsRiskDefenseActive = false;
        });
      }
      return;
    }

    if (_isEventTemplateLayerActive()) {
      _lastHandledNewsRiskLevel = snapshot.level;
      if (_isHighNewsRiskDefenseActive && mounted) {
        setState(() {
          _isHighNewsRiskDefenseActive = false;
        });
      }
      return;
    }

    if (!_autoDefensiveOnHighNewsRisk) {
      _lastHandledNewsRiskLevel = snapshot.level;
      if (_isHighNewsRiskDefenseActive && mounted) {
        setState(() {
          _isHighNewsRiskDefenseActive = false;
        });
      }
      return;
    }

    final wasHigh = _lastHandledNewsRiskLevel == NewsRiskLevel.high;
    final isHigh = snapshot.level == NewsRiskLevel.high;

    if (isHigh && !wasHigh && mounted) {
      setState(() {
        _applyPreset(_conservativePreset);
        _excludeOverheated = true;
        _requireOpenConfirm = true;
        _isHighNewsRiskDefenseActive = true;
      });
      _configureAutoRefreshTimer();
      await _savePreferences();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('?�大事件模�?：新?�風?��?高�?已自?��??��?守�???),
        ),
      );
    }

    if (!isHigh && _isHighNewsRiskDefenseActive && mounted) {
      setState(() {
        _isHighNewsRiskDefenseActive = false;
      });
    }

    _lastHandledNewsRiskLevel = snapshot.level;
  }

  void _handleNewsEventTemplateAutomation(MarketNewsSnapshot snapshot) {
    if (_lockSelectionParameters) {
      return;
    }

    if (!_autoApplyNewsEventTemplate) {
      return;
    }

    final now = DateTime.now();
    final suggested = _suggestNewsEventTemplate(snapshot);
    if (suggested != null) {
      _lastNewsEventTemplateHitAt = now;
      _eventTemplateRestoreArmed = false;
      if (_activeNewsEventTemplateId == suggested.id &&
          _hasNewsEventTuneBackup()) {
        _savePreferences();
        return;
      }

      _applyNewsEventTemplate(suggested);
      return;
    }

    if (!_hasNewsEventTuneBackup()) {
      return;
    }

    final lastHit = _lastNewsEventTemplateHitAt;
    if (lastHit == null) {
      return;
    }

    final quietDays = now.difference(lastHit).inDays;
    if (quietDays < _autoRestoreNewsEventTemplateAfterDays) {
      return;
    }

    if (!_eventTemplateRestoreArmed) {
      _eventTemplateRestoreArmed = true;
      _savePreferences();
      return;
    }

    if (quietDays >= (_autoRestoreNewsEventTemplateAfterDays + 1)) {
      _restoreNewsEventTemplate();
    }
  }

  List<({String tag, int score})> _buildTopicStrengths(
    List<MarketNewsItem> items,
  ) {
    if (items.isEmpty) {
      return const <({String tag, int score})>[];
    }

    final rules = <String, List<String>>{
      'AI': <String>['AI', '人工?�慧', '伺�???, '?��?', '算�?'],
      '低�?衛�?': <String>['低�?', '衛�?', '太空', 'Starlink'],
      '?��?': <String>['?��??�溫', '?��?', '確診', '?��?', '封�?', '流�?'],
      '?�藥?��?': <String>['?�藥?�可', '?�藥', '?��?', 'FDA', 'EUA', '?��?'],
      '軍工?�緣': <String>['軍�?衝�?', '?�爭', '衝�?', '飛�?', '?�緣'],
      '?��??�物??: <String>['油價', '天然�?, '?�油', '??, '?�物??],
      '供�???: <String>['供�??�中??, '?��?', '塞港', '缺貨', '?�工'],
      '?��??��?': <String>['?��?寬�?', '?��?緊縮', '?�息', '?�息', '?�膨壓�?'],
    };

    final scoreByTag = <String, int>{};
    final topItems = items.take(8).toList();
    for (var i = 0; i < topItems.length; i++) {
      final item = topItems[i];
      final recencyWeight = i == 0
          ? 4
          : (i <= 2)
              ? 3
              : (i <= 5)
                  ? 2
                  : 1;
      final text = '${item.title} ${item.matchedKeywords.join(' ')}';
      rules.forEach((tag, keywords) {
        if (keywords.any((keyword) => text.contains(keyword))) {
          scoreByTag[tag] = (scoreByTag[tag] ?? 0) + (10 * recencyWeight);
        }
      });
    }

    return scoreByTag.entries
        .map((entry) => (tag: entry.key, score: entry.value.clamp(0, 100)))
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));
  }

  List<String> _topicBeneficiaryHints(
      List<({String tag, int score})> strengths) {
    final map = <String, String>{
      'AI': '?�優?��?注�?伺�??�、散?�、電源、�??�傳�?PCB',
      '低�?衛�?': '?�優?��?注�?衛�??��??�天線、網?�設?�、地?��?供�???,
      '?��?': '?�優?��?注�??�疫?��??�檢測、�??�製藥?�醫?�通路',
      '?�藥?��?': '?�優?��?注�??�藥?��??�CDMO?�臨床�?託�???,
      '軍工?�緣': '?�優?��?注�?軍工?��?件、�??�、�?安、能源替�?,
      '?��??�物??: '?�優?��?注�?油氣/?��?設�??��??��?上游?��???,
      '供�???: '?�優?��?注�??�代供�??�、在?��??�產?�物流航??,
      '?��??��?': '?�優?��?注�??��??��?補助?�群?��?負債?�長?�、�???,
    };

    return strengths
        .where((item) => item.score >= 30)
        .take(3)
        .map((item) =>
            '${item.tag}�?{item.score}）�?${map[item.tag] ?? '?��??�價?��?碼�?�?}')
        .toList();
  }

  Future<void> _maybeNotifyTopicRotation(MarketNewsSnapshot snapshot) async {
    final strengths = _buildTopicStrengths(snapshot.items);
    if (strengths.isEmpty) {
      return;
    }

    final top = strengths.first;
    if (top.score < 30) {
      return;
    }

    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final previousTag = _lastTopNewsTopicTag;
    final alreadyNotifiedToday = _lastTopNewsTopicNotifyDay == dayKey;

    var changed = false;
    if (previousTag != top.tag) {
      _lastTopNewsTopicTag = top.tag;
      changed = true;
    }

    if (previousTag != null &&
        previousTag != top.tag &&
        !alreadyNotifiedToday) {
      await NotificationService.showAlert(
        id: 4801,
        title: '議�?輪�??��?',
        body: '市場主�???$previousTag ?��???${top.tag}（強�?${top.score}�?,
      );
      _lastTopNewsTopicNotifyDay = dayKey;
      changed = true;
    }

    if (changed) {
      await _savePreferences();
    }
  }

  bool _isEventTemplateLayerActive() {
    return _activeNewsEventTemplateId != null && _hasNewsEventTuneBackup();
  }

  bool _isAutoRiskAdjustmentSuppressed() {
    return _isEventTemplateLayerActive() || _isHighNewsRiskDefenseActive;
  }

  String? _autoRiskAdjustmentSuppressedReason() {
    if (_isEventTemplateLayerActive()) {
      return '事件模板?�管中�??��??�新?��?守�??��?微調�?;
    }
    if (_isHighNewsRiskDefenseActive) {
      return '?��?高風?��?守模式接管中（優?�於?��?微調�?;
    }
    return null;
  }

  String _currentControlLayerLabel() {
    if (_isEventTemplateLayerActive()) {
      return '?�制層�?事件模板';
    }
    if (_isHighNewsRiskDefenseActive) {
      return '?�制層�??��?保�?';
    }
    if (_enableAutoRiskAdjustment) {
      return '?�制層�??��?微調';
    }
    return '?�制層�??��??�數';
  }

  IconData _currentControlLayerIcon() {
    if (_isEventTemplateLayerActive()) {
      return Icons.rule;
    }
    if (_isHighNewsRiskDefenseActive) {
      return Icons.shield;
    }
    if (_enableAutoRiskAdjustment) {
      return Icons.auto_awesome;
    }
    return Icons.tune;
  }

  void _configureAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (!_autoRefreshEnabled) {
      return;
    }

    _autoRefreshTimer = Timer.periodic(
      Duration(minutes: _autoRefreshMinutes),
      (_) {
        if (!mounted) {
          return;
        }
        _refreshStocks(showFeedback: false);
      },
    );
  }

  bool _shouldNotifyForExitSignal(_ExitSignalType type) {
    return type == _ExitSignalType.danger ||
        type == _ExitSignalType.profit ||
        (_holdingNotifyIncludeCaution && type == _ExitSignalType.caution);
  }

  Future<void> _notifyHoldingExitSignals(List<StockModel> stocks) async {
    if (_positionLotsByCode.isEmpty || _entryPriceByCode.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final dayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final stockByCode = <String, StockModel>{
      for (final stock in stocks) stock.code: stock,
    };

    for (final code in _positionLotsByCode.keys) {
      final lots = _positionLotsByCode[code];
      final entryPrice = _entryPriceByCode[code];
      if (lots == null || lots <= 0 || entryPrice == null || entryPrice <= 0) {
        continue;
      }

      final stock = stockByCode[code];
      if (stock == null) {
        continue;
      }

      final signal = _evaluateExitSignal(stock, _calculateStockScore(stock));
      if (!_shouldNotifyForExitSignal(signal.type)) {
        _holdingExitAlertFingerprintByCode.remove(code);
        continue;
      }

      final fingerprint = '$dayKey|${signal.type.name}|${signal.label}';
      final prevFingerprint = _holdingExitAlertFingerprintByCode[code];
      if (prevFingerprint == fingerprint) {
        continue;
      }

      final pnlPercent = _calculatePnlPercent(stock, entryPrice);
      final pnlText = pnlPercent == null
          ? ''
          : '｜�???${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%';
      await NotificationService.showAlert(
        id: 3000 + code.hashCode.abs() % 900,
        title: '?�股?�場?��? ${stock.code} ${stock.name}',
        body:
            '${signal.label}｜現??${stock.closePrice.toStringAsFixed(2)}$pnlText',
      );
      _holdingExitAlertFingerprintByCode[code] = fingerprint;
    }
  }

  Future<void> _notifyHoldingModeTagChanges(List<StockModel> stocks) async {
    if (_positionLotsByCode.isEmpty) {
      return;
    }

    final stockByCode = <String, StockModel>{
      for (final stock in stocks) stock.code: stock,
    };
    var changed = false;
    final activeCodes = <String>{};

    for (final code in _positionLotsByCode.keys) {
      final lots = _positionLotsByCode[code];
      if (lots == null || lots <= 0) {
        continue;
      }
      final stock = stockByCode[code];
      if (stock == null) {
        continue;
      }

      activeCodes.add(code);
      final score = _calculateStockScore(stock);
      final modes = _matchedBreakoutModesForStock(stock, score);
      final labels = modes.map(BreakoutModeLabel).toList()..sort();
      final currentState = _modeStrengthStateFromModes(modes);
      final current = '$currentState|${labels.join('|')}';
      final previous = _holdingModeTagFingerprintByCode[code];
      final previousState = _modeStrengthStateFromFingerprint(previous);

      if (previous != null &&
          previous != current &&
          previousState == 'strong' &&
          currentState != 'strong') {
        final nextText = labels.isEmpty ? '?�命�? : labels.take(3).join('??);
        final previousLabels = _labelsFromFingerprint(previous);
        final previousText =
            previousLabels.isEmpty ? '?�命�? : previousLabels.join('??);
        await NotificationService.showAlert(
          id: 4200 + code.hashCode.abs() % 700,
          title: '?�股模�?標籤變更 ${stock.code} ${stock.name}',
          body: '??$previousText ??$nextText',
        );
      }

      if (previous != current) {
        changed = true;
      }
      _holdingModeTagFingerprintByCode[code] = current;
    }

    final staleCodes = _holdingModeTagFingerprintByCode.keys
        .where((code) => !activeCodes.contains(code))
        .toList();
    for (final code in staleCodes) {
      _holdingModeTagFingerprintByCode.remove(code);
      changed = true;
    }

    if (changed) {
      await _savePreferences();
    }
  }

  String _modeStrengthStateFromModes(List<BreakoutMode> modes) {
    if (modes.contains(BreakoutMode.confirmed) ||
        modes.contains(BreakoutMode.pullbackRebreak) ||
        modes.contains(BreakoutMode.early)) {
      return 'strong';
    }
    if (modes.contains(BreakoutMode.lowBaseTheme) ||
        modes.contains(BreakoutMode.preEventPosition)) {
      return 'neutral';
    }
    if (modes.contains(BreakoutMode.squeezeSetup)) {
      return 'weak';
    }
    return 'weak';
  }

  String _modeStrengthStateFromFingerprint(String? fingerprint) {
    if (fingerprint == null || fingerprint.isEmpty) {
      return 'weak';
    }
    final splitIndex = fingerprint.indexOf('|');
    if (splitIndex <= 0) {
      return 'weak';
    }
    return fingerprint.substring(0, splitIndex);
  }

  List<String> _labelsFromFingerprint(String? fingerprint) {
    if (fingerprint == null || fingerprint.isEmpty) {
      return const <String>[];
    }
    final splitIndex = fingerprint.indexOf('|');
    final payload =
        splitIndex <= 0 ? fingerprint : fingerprint.substring(splitIndex + 1);
    if (payload.isEmpty) {
      return const <String>[];
    }
    return payload.split('|').where((item) => item.trim().isNotEmpty).toList();
  }

  Future<void> _refreshStocks({bool showFeedback = true}) async {
    final future = _stockService.fetchAllStocks();
    setState(() {
      _stocksFuture = future;
      _isLoadingNews = true;
    });

    final newsFuture = _refreshNews();

    try {
      final stocks = await future;
      // store for later diagnostics/optimization
      _latestStocks = stocks;
      await newsFuture;
      await _recordDailyRiskScore(stocks);
      _updateBreakoutStreakForCurrentFilters(stocks);
      _trimEntrySignalCaches(stocks);
      await _notifyHoldingExitSignals(stocks);
      await _notifyHoldingModeTagChanges(stocks);
      await _notifyMasterTrap(stocks);
      await _maybeAutoBackupToGoogle(showFeedback: false);
      await _maybeAutoApplyRecommendedMode(stocks, showFeedback: showFeedback);
      await _maybeRunWeeklyAutoTune(stocks);
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?�股資�?已更??)),
      );
    } catch (_) {
      if (!mounted || !showFeedback) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?�新失�?，�?稍�??�試')),
      );
    }
  }

  Future<void> _refreshGoogleBackupAccount() async {
    final email = await _googleDriveBackupService.getSignedInEmail();
    if (!mounted) {
      return;
    }
    if (email == _googleBackupEmail) {
      return;
    }
    setState(() {
      _googleBackupEmail = email;
    });
    _savePreferences();
  }

  Future<Map<String, dynamic>> _buildGoogleBackupPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    final data = <String, dynamic>{};
    for (final key in keys) {
      data[key] = prefs.get(key);
    }
    return <String, dynamic>{
      'schema': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'prefs': data,
    };
  }

  String _googleWebSignInHintText(String? rawError) {
    final error = (rawError ?? '').toLowerCase();
    if (error.contains('origin_mismatch')) {
      return 'Google ?�入失�?：origin_mismatch?��???OAuth Web Client ??Authorized JavaScript origins ?�入 http://localhost:7357 ??http://127.0.0.1:7357';
    }
    if (error.contains('access_denied') ||
        error.contains('unauthorized') ||
        error.contains('invalid_client')) {
      return 'Google ?�入被�??��?確�? OAuth ?��??�面已�??�、目?�帳?�在測試使用?��??�內，�?使用�?��??Web Client ID';
    }
    if (error.contains('popup')) {
      return 'Google ?�入視�?被瀏覽?�阻?�。�??�許彈出視�?後�?試�?�?;
    }
    return 'Google ?�入?��??�。�?確�?已�???Drive API，�? OAuth Web Client 已設�?localhost/127.0.0.1 網�?';
  }

  void _showGoogleSignInNullFeedback({
    required String fallback,
    required bool showFeedback,
  }) {
    if (!mounted || !showFeedback) {
      return;
    }
    final authError = _googleDriveBackupService.consumeLastAuthError();
    final message = kIsWeb ? _googleWebSignInHintText(authError) : fallback;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<bool> _backupNowToGoogle({bool showFeedback = true}) async {
    if (_isGoogleBackupBusy) {
      return false;
    }
    if (!_googleDriveBackupService.isSupportedPlatform()) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('?��??�支??Android / Chrome(Web) Google ?�份')),
        );
      }
      return false;
    }
    if (!_googleDriveBackupService.isWebClientIdReady()) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Web 尚未設�? GOOGLE_WEB_CLIENT_ID，�??��? --dart-define=GOOGLE_WEB_CLIENT_ID=...')),
        );
      }
      return false;
    }

    setState(() {
      _isGoogleBackupBusy = true;
    });
    try {
      final email = await _googleDriveBackupService.signInAndGetEmail();
      if (email == null) {
        _showGoogleSignInNullFeedback(
          fallback: 'Google ?�入?��?，未完�??�份',
          showFeedback: showFeedback,
        );
        return false;
      }
      final payload = await _buildGoogleBackupPayload();
      final success = await _googleDriveBackupService.backupJson(payload);
      if (!success) {
        if (showFeedback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google 驗�?失�?，�??�新?�入')),
          );
        }
        return false;
      }
      setState(() {
        _googleBackupEmail = email;
        _lastGoogleBackupAt = DateTime.now();
      });
      await _savePreferences();
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已�?份到 Google�?email�?)),
        );
      }
      return true;
    } catch (error) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('?�份失�?�?error')),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleBackupBusy = false;
        });
      }
    }
  }

  Future<void> _restoreFromGoogleBackup() async {
    if (_isGoogleBackupBusy) {
      return;
    }
    if (!_googleDriveBackupService.isSupportedPlatform()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('?��??�支??Android / Chrome(Web) Google ?��?')),
        );
      }
      return;
    }
    if (!_googleDriveBackupService.isWebClientIdReady()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Web 尚未設�? GOOGLE_WEB_CLIENT_ID，�??��? --dart-define=GOOGLE_WEB_CLIENT_ID=...')),
        );
      }
      return;
    }

    setState(() {
      _isGoogleBackupBusy = true;
    });
    try {
      final email = await _googleDriveBackupService.signInAndGetEmail();
      if (email == null) {
        _showGoogleSignInNullFeedback(
          fallback: 'Google ?�入?��?，未?��?資�?',
          showFeedback: true,
        );
        return;
      }
      final payload = await _googleDriveBackupService.restoreJson();
      if (payload == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Google ?�端尚無?�份�?)),
          );
        }
        return;
      }
      final prefsMap = payload['prefs'];
      if (prefsMap is! Map) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('?�份檔格式錯�?)),
          );
        }
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      for (final entry in prefsMap.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is List) {
          final list = value.map((item) => item.toString()).toList();
          await prefs.setStringList(key, list);
        }
      }

      setState(() {
        _googleBackupEmail = email;
      });
      await _loadSavedPreferences();
      await _refreshStocks(showFeedback: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已�? Google ?��?資�?�?email�?)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('?��?失�?�?error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleBackupBusy = false;
        });
      }
    }
  }

  Future<void> _maybeAutoBackupToGoogle({required bool showFeedback}) async {
    if (!_enableGoogleDailyBackup) {
      return;
    }
    final now = DateTime.now();
    if (_lastGoogleBackupAt != null &&
        _isSameCalendarDay(_lastGoogleBackupAt!, now)) {
      return;
    }
    await _backupNowToGoogle(showFeedback: showFeedback);
  }

  Future<void> _maybeAutoApplyRecommendedMode(
    List<StockModel> stocks, {
    required bool showFeedback,
  }) async {
    if (_lockSelectionParameters) {
      return;
    }

    if (!_autoApplyRecommendedMode || stocks.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_autoApplyOnlyTradingMorning && !_isTradingDayMorningWindow(now)) {
      return;
    }

    if (_lastAutoModeAppliedAt != null &&
        _isSameCalendarDay(_lastAutoModeAppliedAt!, now)) {
      return;
    }

    final regime =
        _autoRegimeEnabled ? _detectMarketRegime(stocks) : _currentRegime;
    final breadth = _marketBreadthRatio(stocks);
    final recommendation = _buildModeRecommendationForContext(
      regime: regime,
      breadth: breadth,
      newsLevel: _marketNewsSnapshot?.level,
      isNightSession: _isPostMarketOrNight(now),
    );

    final changed = recommendation.mode != BreakoutMode;
    setState(() {
      _currentRegime = regime;
      _latestMarketBreadthRatio = breadth;
      BreakoutMode = recommendation.mode;
      _lastAutoModeAppliedAt = now;
    });
    await _savePreferencesTagged('auto_mode_rotation');

    if (changed && mounted && showFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('已自?��??�建議模式�?${BreakoutModeLabel(recommendation.mode)}'),
        ),
      );
    }
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.showAlert(
      id: 2001,
      title: '?�股?��?測試',
      body: '?�知?�能�?��，�?後�??��??�送�????�利訊�???,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已送出測試?��?，�??��??�知??)),
    );
  }

  Future<void> _runMorningScan() async {
    if (_lockSelectionParameters) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已�?定選?��??��??�盤?��?不�??��??��?條件')),
        );
      }
      await _refreshStocks();
      return;
    }

    setState(() {
      _enableStrategyFilter = true;
      _onlyRising = true;
      _enableScoring = true;
      _excludeOverheated = true;
      _showStrongOnly = true;
      _searchKeyword = '';
    });
    await _savePreferencesTagged('morning_scan');
    await _refreshStocks();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?�盤?��?完�?：已套用強勢?�選模�?')),
    );
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    // Flush any pending persistence writes before disposing
    unawaited(PersistenceService.instance.flushNow());
    PersistenceService.instance.dispose();
    super.dispose();
  }

  Future<void> _openNewsLink(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      return;
    }

    bool opened = false;
    try {
      opened = await launchUrl(
        uri,
        mode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
    } catch (_) {
      opened = false;
    }

    if (opened || !mounted) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?��??�接?��?，已複製?��?????�剪貼簿')),
    );
  }

  Future<void> _applyBacktestTuningResult(BacktestTuningResult? tuning) async {
    if (tuning == null) {
      return;
    }

    if (!tuning.applyStopLoss && !tuning.applyTakeProfit) {
      return;
    }

    setState(() {
      if (tuning.applyStopLoss) {
        _stopLossPercent = tuning.stopLossPercent;
      }
      if (tuning.applyTakeProfit) {
        _takeProfitPercent = tuning.takeProfitPercent;
      }
    });
    await _savePreferences();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已�??��?�?Top1�?{tuning.applyStopLoss ? '?��? -${tuning.stopLossPercent}%' : ''}${(tuning.applyStopLoss && tuning.applyTakeProfit) ? ' / ' : ''}${tuning.applyTakeProfit ? '?�利 +${tuning.takeProfitPercent}%' : ''}',
        ),
      ),
    );
  }

  Future<void> _openBacktestForStock(StockModel stock) async {
    final tuning = await Navigator.of(context).push<BacktestTuningResult>(
      MaterialPageRoute(
        builder: (_) => BacktestPage(
          initialStockCode: stock.code,
          initialMonths: 6,
          initialMinVolume: _surgeVolumeThreshold,
          initialMinTradeValue: _minTradeValueThreshold,
          initialStopLoss: _stopLossPercent,
          initialTakeProfit: _takeProfitPercent,
          initialEnableTrailingStop: _enableTrailingStop,
          initialTrailingPullback: _trailingPullbackPercent,
        ),
      ),
    );

    await _applyBacktestTuningResult(tuning);
  }

  Map<_EntrySignalType, int> _buildCandidateTagCounts(
    List<_ScoredStock> stocks,
    _EntrySignal Function(StockModel stock, int score)? signalResolver,
  ) {
    final counts = <_EntrySignalType, int>{};
    final resolve = signalResolver ?? _evaluateEntrySignal;
    for (final item in stocks) {
      final signal = resolve(item.stock, item.score);
      counts.update(signal.type, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<void> _saveSignalTrackEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _signalTrackEntriesKey,
      jsonEncode(_signalTrackEntries.map((entry) => entry.toJson()).toList()),
    );
  }

  void _updateSignalTracking(
    List<StockModel> stocks,
    List<_ScoredStock> candidates,
    _EntrySignal Function(StockModel stock, int score)? signalResolver,
  ) {
    if (stocks.isEmpty) {
      return;
    }

    final now = DateTime.now();
    var changed = false;
    final latestPriceByCode = <String, double>{
      for (final stock in stocks) stock.code: stock.closePrice,
    };

    for (final item in _signalTrackEntries) {
      final latest = latestPriceByCode[item.stockCode];
      if (latest == null || latest <= 0) {
        continue;
      }
      final dayDiff = calendarDayDiff(item.date, now);

      if (item.return1Day == null && dayDiff >= 1) {
        item.return1Day = computeForwardReturnPercent(
          entryPrice: item.entryPrice,
          latestPrice: latest,
        );
        changed = true;
      }
      if (item.return3Day == null && dayDiff >= 3) {
        item.return3Day = computeForwardReturnPercent(
          entryPrice: item.entryPrice,
          latestPrice: latest,
        );
        changed = true;
      }
      if (item.return5Day == null && dayDiff >= 5) {
        item.return5Day = computeForwardReturnPercent(
          entryPrice: item.entryPrice,
          latestPrice: latest,
        );
        changed = true;
      }
    }

    final resolve = signalResolver ?? _evaluateEntrySignal;

    for (final item in candidates.take(25)) {
      final signal = resolve(item.stock, item.score);
      if (signal.type != _EntrySignalType.strong &&
          signal.type != _EntrySignalType.watch) {
        continue;
      }

      final existsToday = _signalTrackEntries.any(
        (entry) =>
            entry.stockCode == item.stock.code &&
            entry.signalType == signal.type &&
            _isSameCalendarDay(entry.date, now),
      );
      if (existsToday) {
        continue;
      }

      _signalTrackEntries.add(
        _SignalTrackEntry(
          date: now,
          stockCode: item.stock.code,
          stockName: item.stock.name,
          signalType: signal.type,
          entryPrice: item.stock.closePrice,
        ),
      );
      changed = true;
    }

    if (_signalTrackEntries.length > 600) {
      _signalTrackEntries.sort((a, b) => a.date.compareTo(b.date));
      _signalTrackEntries.removeRange(0, _signalTrackEntries.length - 600);
      changed = true;
    }

    if (changed) {
      _saveSignalTrackEntries();
    }
  }

  _SignalPerformanceSummary _buildSignalPerformanceSummary(
    _EntrySignalType signalType,
  ) {
    final rows = _signalTrackEntries
        .where((entry) => entry.signalType == signalType)
        .toList();
    if (rows.isEmpty) {
      return const _SignalPerformanceSummary.empty();
    }

    double avgOf(List<double> values) {
      if (values.isEmpty) {
        return 0;
      }
      return values.reduce((a, b) => a + b) / values.length;
    }

    double winRateOf(List<double> values) {
      if (values.isEmpty) {
        return 0;
      }
      final wins = values.where((value) => value > 0).length;
      return (wins / values.length) * 100;
    }

    double maxDrawdownOf(List<double> values) {
      if (values.isEmpty) {
        return 0;
      }
      final worst = values.reduce((a, b) => a < b ? a : b);
      return worst < 0 ? worst : 0;
    }

    final day1 =
        rows.map((entry) => entry.return1Day).whereType<double>().toList();
    final day3 =
        rows.map((entry) => entry.return3Day).whereType<double>().toList();
    final day5 =
        rows.map((entry) => entry.return5Day).whereType<double>().toList();
    return _SignalPerformanceSummary(
      sampleSize: rows.length,
      day1Count: day1.length,
      day3Count: day3.length,
      day5Count: day5.length,
      day1Avg: avgOf(day1),
      day3Avg: avgOf(day3),
      day5Avg: avgOf(day5),
      day1WinRate: winRateOf(day1),
      day3WinRate: winRateOf(day3),
      day5WinRate: winRateOf(day5),
      day1MaxDrawdown: maxDrawdownOf(day1),
      day3MaxDrawdown: maxDrawdownOf(day3),
      day5MaxDrawdown: maxDrawdownOf(day5),
    );
  }

  List<String> _buildStrategyConsistencyWarnings() {
    final warnings = <String>[];

    if (_lockSelectionParameters) {
      warnings.add('?��??�用?�股?�數?��?：自?�調?�已?��?，�??��?�???��?變更?��?條件??);
    }
    if (_marketNewsSnapshot == null) {
      warnings.add('?��?快照尚未建�?：�?�?風險?��?條件?�能?��?保�??�中?�判讀??);
    }

    if (_maxPriceThreshold > 70) {
      warnings.add('?�價上�??��?，可?��??��?資�??��??��?);
    }
    if (_minTradeValueThreshold < 500000000) {
      warnings.add('?�交?��?檻�?低�?流�??�風?��??��?);
    }
    if (!_excludeOverheated) {
      warnings.add('已�??�追高�?濾�??��?波�?風險?��???);
    }
    if (!_onlyRising) {
      warnings.add('?��??�當?��?漲�??�場?��??�能下�???);
    }
    if (_stopLossPercent > 8) {
      warnings.add('?��??�寬，單筆�??�可?��?大�?);
    }
    if (!_requireOpenConfirm) {
      warnings.add('?��??��???0?��?確�?，追?�風?��?高�?);
    }
    if (_autoRefreshEnabled && _autoRefreshMinutes > 20) {
      warnings.add('?��??�新?��??�長，可?�錯?�盤中�??��?);
    }
    if (!_autoDefensiveOnHighNewsRisk) {
      warnings.add('?�大事件模�?已�??��?突發消息下�??��?調整策略??);
    }
    if (!_useRelativeVolumeFilter) {
      warnings.add('?��??�相對�??��?檻�?行�?轉弱?�可?�誤?��?訊�?);
    }
    if (!_enableTrailingStop) {
      warnings.add('?��??�移?��??��?強勢?��??��?護�?弱�?);
    }
    if (_autoLossStreakFromJournal() >= 3) {
      warnings.add('?��???��?��?，系統�??��??�倉�?);
    }
    if (!_autoRegimeEnabled) {
      warnings.add('?��???Regime ?��??��?，�??��??�隨?�勢調整??);
    }
    if (!_timeSegmentTuningEnabled) {
      warnings.add('?��??��?段�??��??��??�盤?��??�防護�?弱�?);
    }
    if (!_enableAdaptiveAtrExit) {
      warnings.add('?��???ATR ?�適?��??��??�利?�檻�?波�??��?較僵硬�?);
    }
    if (!_enableBreakoutQuality) {
      warnings.add('?��??��??��?質�?濾�??��??��??�可?��??��?);
    }
    if (_breakoutMinVolumeRatioPercent < 120) {
      warnings.add('突破?�能?��??��?，建議至�?120% 以�???);
    }
    if (_enableChipConcentrationFilter && _minChipConcentrationPercent > 0) {
      warnings.add('已�??��?碼�?中度?�濾，�???${_minChipConcentrationPercent.toInt()}% ?��?顯示??);
    }
    if (_enableMasterTrapFilter) {
      warnings.add('主�?誘�??�濾?��?，�?�?${_masterTrapDropPercent.toInt()}% ?�為誘�?');
    }
    if (!_enableRiskRewardPrefilter) {
      warnings.add('?��??�風?�報?��?置�?濾�?低報?��?交�??�能增�???);
    }
    if (_minRiskRewardRatioX100 < 150) {
      warnings.add('?�低風?�報?��??��?，建議至�?1.50??);
    }
    switch (BreakoutMode) {
      case BreakoutMode.confirmed:
        if (!_enableMultiDayBreakout) {
          warnings.add('確�?突破模�?下�??��??突破確�?，建議�??�以?��??��???);
        }
        if (_minBreakoutStreakDays < 2) {
          warnings.add('???突破天數?��?，建議至�?2 天�?);
        }
        break;
      case BreakoutMode.lowBaseTheme:
        warnings.add('?��??��??��?題�?模�?，�??��?事件風險?��??�控管�?);
        break;
      case BreakoutMode.pullbackRebreak:
        warnings.add('?��??��?檔�??�模式�?建議?��?觀察�??�是?��?步放大�?);
        break;
      case BreakoutMode.squeezeSetup:
        warnings.add('?��??��?縮整?��??�模式�?訊�??�早但�?訊可?��??��?);
        break;
      case BreakoutMode.preEventPosition:
        warnings.add('?��??��?件�??��?模�?，�?必控?�單筆風?��??��???);
        break;
      case BreakoutMode.early:
        break;
    }
    if (!_enableFalseBreakoutProtection) {
      warnings.add('?��??��?突破?�護，追高風?�可?��??��?);
    }
    if (!_enableMarketBreadthFilter) {
      warnings.add('?��??��??�寬度�?濾�?弱�?中誤?�場機�??��???);
    }
    if ((_minMarketBreadthRatioX100 / 100) < 1.0) {
      warnings.add('市場寬度?�檻�?低�?建議?��? 1.00??);
    }
    if (!_enableEventRiskExclusion) {
      warnings.add('?��??��?件風?��??��?財報/?��??��?後波?��??��?管�???);
    }
    if (!_enableWeeklyWalkForwardAutoTune) {
      warnings.add('?��??��???walk-forward 微調，�??�適?�盤?�速度?��??��?);
    }
    if (_cooldownDays <= 0) {
      warnings.add('?��??�卻?�為 0 天�?????��?風險?�能上�???);
    }
    if (!_enableSectorRotationBoost) {
      warnings.add('?��??�板塊輪?��?權�??��??�能忽略?��?強板塊�?);
    }

    return warnings;
  }

  bool _hasNewsEventTuneBackup() {
    return _warLooseBackupMinScore != null &&
        _warLooseBackupMinTradeValue != null &&
        _warLooseBackupMaxChase != null &&
        _eventTuneBackupStopLoss != null &&
        _eventTuneBackupTakeProfit != null &&
        _eventTuneBackupRiskBudget != null;
  }

  _NewsEventTemplate? _templateById(String? id) {
    if (id == null || id.isEmpty) {
      return null;
    }
    for (final template in _newsEventTemplates) {
      if (template.id == id) {
        return template;
      }
    }
    return null;
  }

  _NewsEventTemplate? _suggestNewsEventTemplate(MarketNewsSnapshot? snapshot) {
    if (snapshot == null || snapshot.items.isEmpty) {
      return null;
    }

    final scores = <String, int>{
      for (final template in _newsEventTemplates) template.id: 0,
    };
    final headlines = snapshot.items.take(6).map((item) => item.title).toList();

    for (var index = 0; index < headlines.length; index++) {
      final title = headlines[index];
      final weight = index <= 2 ? 3 : 1;
      for (final template in _newsEventTemplates) {
        final hit =
            template.triggerKeywords.any((keyword) => title.contains(keyword));
        if (hit) {
          scores[template.id] = (scores[template.id] ?? 0) + weight;
        }
      }
    }

    _NewsEventTemplate? best;
    var bestScore = 0;
    for (final template in _newsEventTemplates) {
      final score = scores[template.id] ?? 0;
      if (score > bestScore) {
        best = template;
        bestScore = score;
      }
    }

    if (bestScore >= 3) {
      return best;
    }

    if (snapshot.level == NewsRiskLevel.high) {
      return _newsEventTemplates.first;
    }

    return null;
  }

  void _applyNewsEventTemplate(
    _NewsEventTemplate template, {
    bool showFeedback = true,
  }) {
    if (_lockSelectionParameters) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已�?定選?��??��??��?套用事件模板')),
        );
      }
      return;
    }

    if (!_hasNewsEventTuneBackup()) {
      _warLooseBackupMinScore = _minScoreThreshold;
      _warLooseBackupMinTradeValue = _minTradeValueThreshold;
      _warLooseBackupMaxChase = _maxChaseChangePercent;
      _eventTuneBackupStopLoss = _stopLossPercent;
      _eventTuneBackupTakeProfit = _takeProfitPercent;
      _eventTuneBackupRiskBudget = _riskBudgetPerTrade;
    }

    final prevMinScore = _minScoreThreshold;
    final prevMinTradeValue = _minTradeValueThreshold;
    final prevMaxChase = _maxChaseChangePercent;
    final prevStopLoss = _stopLossPercent;
    final prevTakeProfit = _takeProfitPercent;
    final prevRiskBudget = _riskBudgetPerTrade;

    setState(() {
      _minScoreThreshold = template.minScore.clamp(_minScore, _maxScore);
      _minTradeValueThreshold = template.minTradeValue.clamp(
        _minTradeValue,
        _maxTradeValue,
      );
      _maxChaseChangePercent = template.maxChase.clamp(3, 12);
      _stopLossPercent = template.stopLoss.clamp(3, 10);
      _takeProfitPercent = template.takeProfit.clamp(6, 18);
      _riskBudgetPerTrade = template.riskBudget.clamp(1000, 100000);
      _activeNewsEventTemplateId = template.id;
      _enableStrategyFilter = true;
      _enableScoring = true;
      _excludeOverheated = true;
      _requireOpenConfirm = true;
      _lastNewsEventTemplateHitAt = DateTime.now();
      _eventTemplateRestoreArmed = false;
    });
    _savePreferencesTagged('news_template_apply');

    if (!showFeedback || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已�???{template.label}：�???${prevMinScore}??_minScoreThreshold?��?交�?${_formatWithThousandsSeparator(prevMinTradeValue)}??{_formatWithThousandsSeparator(_minTradeValueThreshold)}?�追�?${prevMaxChase}%??_maxChaseChangePercent%?��???${prevStopLoss}%??_stopLossPercent%?��???${prevTakeProfit}%??_takeProfitPercent%?�單筆風??${_formatCurrency(prevRiskBudget.toDouble())}??{_formatCurrency(_riskBudgetPerTrade.toDouble())}',
        ),
      ),
    );
  }

  void _restoreNewsEventTemplate({bool showFeedback = true}) {
    if (_lockSelectionParameters) {
      if (showFeedback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已�?定選?��??��??��??��?事件模板?�數')),
        );
      }
      return;
    }

    if (!_hasNewsEventTuneBackup()) {
      return;
    }

    final backupMinScore = _warLooseBackupMinScore!;
    final backupMinTradeValue = _warLooseBackupMinTradeValue!;
    final backupMaxChase = _warLooseBackupMaxChase!;
    final backupStopLoss = _eventTuneBackupStopLoss!;
    final backupTakeProfit = _eventTuneBackupTakeProfit!;
    final backupRiskBudget = _eventTuneBackupRiskBudget!;

    setState(() {
      _minScoreThreshold = backupMinScore;
      _minTradeValueThreshold = backupMinTradeValue;
      _maxChaseChangePercent = backupMaxChase;
      _stopLossPercent = backupStopLoss;
      _takeProfitPercent = backupTakeProfit;
      _riskBudgetPerTrade = backupRiskBudget;
      _warLooseBackupMinScore = null;
      _warLooseBackupMinTradeValue = null;
      _warLooseBackupMaxChase = null;
      _eventTuneBackupStopLoss = null;
      _eventTuneBackupTakeProfit = null;
      _eventTuneBackupRiskBudget = null;
      _activeNewsEventTemplateId = null;
      _lastNewsEventTemplateHitAt = null;
      _eventTemplateRestoreArmed = false;
    });
    _savePreferencesTagged('news_template_restore');

    if (!showFeedback || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已�??��?件�??�數：�???$_minScoreThreshold?��?交�?${_formatWithThousandsSeparator(_minTradeValueThreshold)}?�追高�???$_maxChaseChangePercent%?��???$_stopLossPercent%?��???$_takeProfitPercent%?�單筆風??${_formatCurrency(_riskBudgetPerTrade.toDouble())}',
        ),
      ),
    );
  }

  Future<void> _openKLineChart(StockModel stock) async {
    final uris = <Uri>[
      Uri.parse('https://www.cmoney.tw/forum/stock/${stock.code}'),
      Uri.parse('https://tw.stock.yahoo.com/quote/${stock.code}.TW'),
      Uri.parse('https://www.google.com/finance/quote/${stock.code}:TPE'),
      Uri.parse(
          'https://goodinfo.tw/tw/StockKChart.asp?STOCK_ID=${stock.code}'),
    ];

    await _openExternalUrisWithFallback(
      uris: uris,
      webClipboardHint: '?�覽?�阻?�新?��?，已複製 CMoney ????�剪貼簿',
      fallbackClipboardHint: '?��??�接?��?，已複製 CMoney ?�援????�剪貼簿',
    );
  }

  Future<void> _openCMoneyDiscussion(StockModel stock) async {
    final uris = <Uri>[
      Uri.parse('https://www.cmoney.tw/forum/stock/${stock.code}'),
      Uri.parse('https://tw.stock.yahoo.com/quote/${stock.code}.TW'),
    ];

    await _openExternalUrisWithFallback(
      uris: uris,
      webClipboardHint: '?�覽?�阻?�新?��?，已複製 CMoney 討�?????�剪貼簿',
      fallbackClipboardHint: '?��??�接?��?，已複製 CMoney 討�?????�剪貼簿',
    );
  }

  Future<void> _openExternalUrisWithFallback({
    required List<Uri> uris,
    required String webClipboardHint,
    required String fallbackClipboardHint,
  }) async {
    if (uris.isEmpty) {
      return;
    }

    bool opened = false;

    if (kIsWeb) {
      final webUri = uris.first;
      try {
        opened = await launchUrl(
          webUri,
          mode: LaunchMode.platformDefault,
          webOnlyWindowName: '_blank',
        );
      } catch (_) {
        opened = false;
      }

      if (opened || !mounted) {
        return;
      }

      await Clipboard.setData(ClipboardData(text: webUri.toString()));
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(webClipboardHint)),
      );
      return;
    }

    for (final uri in uris) {
      try {
        opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!opened) {
          opened = await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
            webOnlyWindowName: '_blank',
          );
        }
      } catch (_) {
        opened = false;
      }

      if (opened) {
        break;
      }
    }

    if (opened || !mounted) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: uris.first.toString()));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fallbackClipboardHint)),
    );
  }

  void _toggleFavorite(String stockCode) {
    setState(() {
      if (_favoriteStockCodes.contains(stockCode)) {
        _favoriteStockCodes.remove(stockCode);
      } else {
        _favoriteStockCodes.add(stockCode);
      }
    });
    _savePreferences();
  }

  void _saveCandidatesToFavorites(List<StockModel> stocks) {
    final before = _favoriteStockCodes.length;
    setState(() {
      for (final stock in stocks) {
        _favoriteStockCodes.add(stock.code);
      }
    });
    _savePreferences();
    final added = _favoriteStockCodes.length - before;
    final message = added > 0 ? '已新�?$added 檔到?��??�單' : '?�選?�都已在?��??�單�?;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportFavoritesText(List<_ScoredStock> rankedStocks) async {
    final favorites = rankedStocks
        .where((item) => _favoriteStockCodes.contains(item.stock.code))
        .toList();

    if (favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?��?沒�??�匯?��??��??�票')),
      );
      return;
    }

    final now = DateTime.now();
    final dateText =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final lines = <String>[
      '?? ?�股?��??�選清單',
      '?? ?�出?��?�?dateText',
      '?? 檔數�?{favorites.length}',
      '------------------------------',
    ];

    for (var i = 0; i < favorites.length; i++) {
      final item = favorites[i];
      final stock = item.stock;
      final isUp = stock.change >= 0;
      final changePrefix = isUp ? '+' : '';
      final changeEmoji = isUp ? '?��' : '?��';
      final scoreEmoji = item.score >= 80
          ? '??'
          : item.score >= 65
              ? '??
              : '?��?';
      final entryPrice = _entryPriceByCode[stock.code];
      final lots = _positionLotsByCode[stock.code];
      final pnlPercent = _calculatePnlPercent(stock, entryPrice);
      final pnlAmount = _calculatePnlAmount(stock, entryPrice, lots);
      lines.add(
        '${i + 1}. ${stock.code} ${stock.name} $scoreEmoji',
      );
      lines.add(
          '   ?�� ${stock.closePrice.toStringAsFixed(2)}  $changeEmoji $changePrefix${stock.change.toStringAsFixed(2)}');
      lines.add(
        '   ?�� ??${_formatWithThousandsSeparator(stock.volume)}  ?�� ??${item.score}${entryPrice == null || pnlPercent == null ? '' : '  ?�� ?�本 ${entryPrice.toStringAsFixed(2)}'}${lots == null ? '' : '  張數 ${lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2)}'}${pnlPercent == null ? '' : '  ?��? ${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%'}${pnlAmount == null ? '' : '  (${pnlAmount >= 0 ? '+' : ''}${_formatCurrency(pnlAmount)})'}',
      );
      lines.add('');
    }

    lines.add('?��? ?��??�究?�考�?請自行控管風?��?);

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('?��?清單已�?製到?�貼�?)),
    );
  }

  Future<void> _openFilterSheet() async {
    bool localEnableStrategyFilter = _enableStrategyFilter;
    bool localOnlyRising = _onlyRising;
    double localMaxPrice = _maxPriceThreshold.toDouble();
    double localVolumeThreshold = _surgeVolumeThreshold.toDouble();
    double localTradeValueThreshold = _minTradeValueThreshold.toDouble();
    bool localEnableScoring = _enableScoring;
    bool localLimitTopCandidates = _limitTopCandidates;
    bool localExcludeOverheated = _excludeOverheated;
    bool localEnableExitSignal = _enableExitSignal;
    bool localHoldingNotifyIncludeCaution = _holdingNotifyIncludeCaution;
    bool localExpandAggressiveEstimateByDefault =
        _expandAggressiveEstimateByDefault;
    bool localExpandCardDetailsByDefault = _expandCardDetailsByDefault;
    _MobileUiDensity localMobileUiDensity = _mobileUiDensity;
    _MobileTextScale localMobileTextScale = _mobileTextScale;
    bool localEnableAutoRiskAdjustment = _enableAutoRiskAdjustment;
    double localAutoRiskAdjustmentStrength =
        _autoRiskAdjustmentStrength.toDouble();
    bool localAutoRefreshEnabled = _autoRefreshEnabled;
    bool localAutoApplyRecommendedMode = _autoApplyRecommendedMode;
    bool localLockSelectionParameters = _lockSelectionParameters;
    bool localAutoApplyOnlyTradingMorning = _autoApplyOnlyTradingMorning;
    bool localRequireOpenConfirm = _requireOpenConfirm;
    bool localAutoDefensiveOnHighNewsRisk = _autoDefensiveOnHighNewsRisk;
    bool localAutoApplyNewsEventTemplate = _autoApplyNewsEventTemplate;
    double localAutoRestoreNewsEventTemplateAfterDays =
        _autoRestoreNewsEventTemplateAfterDays.toDouble();
    bool localAutoRegimeEnabled = _autoRegimeEnabled;
    bool localTimeSegmentTuningEnabled = _timeSegmentTuningEnabled;
    bool localUseRelativeVolumeFilter = _useRelativeVolumeFilter;
    bool localEnableTrailingStop = _enableTrailingStop;
    bool localEnableAdaptiveAtrExit = _enableAdaptiveAtrExit;
    bool localEnableBreakoutQuality = _enableBreakoutQuality;
    bool localEnableChipConcentrationFilter = _enableChipConcentrationFilter;
    double localMinChipConcentrationPercent = _minChipConcentrationPercent.toDouble();
    bool localEnableRiskRewardPrefilter = _enableRiskRewardPrefilter;
    bool localEnableMultiDayBreakout = _enableMultiDayBreakout;
    bool localEnableFalseBreakoutProtection = _enableFalseBreakoutProtection;
    bool localEnableMarketBreadthFilter = _enableMarketBreadthFilter;
    bool localEnableEventRiskExclusion = _enableEventRiskExclusion;
    bool localEnableEventCalendarWindow = _enableEventCalendarWindow;
    bool localEnableRevenueMomentumFilter = _enableRevenueMomentumFilter;
    bool localEnableEarningsSurpriseFilter = _enableEarningsSurpriseFilter;
    bool localEnableOvernightGapRiskGuard = _enableOvernightGapRiskGuard;
    bool localEnableSectorExposureCap = _enableSectorExposureCap;
    bool localEnableWeeklyWalkForwardAutoTune =
        _enableWeeklyWalkForwardAutoTune;
    bool localEnableScoreTierSizing = _enableScoreTierSizing;
    bool localEnableSectorRotationBoost = _enableSectorRotationBoost;
    BreakoutMode localBreakoutStageMode = BreakoutMode;
    double localMinScore = _minScoreThreshold.toDouble();
    double localAutoRefreshMinutes = _autoRefreshMinutes.toDouble();
    double localRelativeVolumePercent = _relativeVolumePercent.toDouble();
    double localManualLossStreak = _manualLossStreak.toDouble();
    double localTrailingPullbackPercent = _trailingPullbackPercent.toDouble();
    double localAtrTakeProfitMultiplier = _atrTakeProfitMultiplier.toDouble();
    double localBreakoutMinVolumeRatio =
        _breakoutMinVolumeRatioPercent.toDouble();
    double localMinRiskRewardRatio = _minRiskRewardRatioX100 / 100;
    double localMinBreakoutStreakDays = _minBreakoutStreakDays.toDouble();
    double localMinMarketBreadthRatio = _minMarketBreadthRatioX100 / 100;
    double localEventCalendarGuardDays = _eventCalendarGuardDays.toDouble();
    double localMinRevenueMomentumScore = _minRevenueMomentumScore.toDouble();
    double localMinEarningsSurpriseScore = _minEarningsSurpriseScore.toDouble();
    double localMaxHoldingPerSector = _maxHoldingPerSector.toDouble();
    double localCooldownDays = _cooldownDays.toDouble();
    double localMaxChaseChangePercent = _maxChaseChangePercent.toDouble();
    double localStopLossPercent = _stopLossPercent.toDouble();
    double localTakeProfitPercent = _takeProfitPercent.toDouble();
    double localVolumeWeight = _volumeWeight.toDouble();
    double localChangeWeight = _changeWeight.toDouble();
    double localPriceWeight = _priceWeight.toDouble();
    double localConcentrationWeight = _concentrationWeight.toDouble();
    double localTradeValueWeight = _tradeValueWeight.toDouble();
    // fund?�flow / margin filter locals
    bool localEnableForeignFlowFilter = _enableForeignFlowFilter;
    double localMinForeignNet = _minForeignNet.toDouble();
    bool localEnableTrustFlowFilter = _enableTrustFlowFilter;
    double localMinTrustNet = _minTrustNet.toDouble();
    bool localEnableDealerFlowFilter = _enableDealerFlowFilter;
    double localMinDealerNet = _minDealerNet.toDouble();
    bool localEnableMarginDiffFilter = _enableMarginDiffFilter;
    double localMinMarginBalanceDiff = _minMarginBalanceDiff.toDouble();
    bool localEnableMasterTrapFilter = _enableMasterTrapFilter;
    double localMasterTrapDropPercent = _masterTrapDropPercent.toDouble();
    String localSectorRulesText = _sectorRulesText;
    String? selectedPresetId;
    String? selectedMvpPresetId;

    final result = await showModalBottomSheet<_FilterState>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final safeBottom = MediaQuery.of(context).padding.bottom;
            final sheetWidth = MediaQuery.of(context).size.width;
            final sheetHorizontalPadding = sheetWidth < 390 ? 14.0 : 20.0;
            return SafeArea(
              top: false,
              child: FractionallySizedBox(
                heightFactor: 0.94,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      sheetHorizontalPadding,
                      8,
                      sheetHorizontalPadding,
                      20 + bottomInset + safeBottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '篩選飆股設�?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '?��?介面密度�?{_mobileUiDensityLabel(localMobileUiDensity)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('?�適'),
                              selected: localMobileUiDensity ==
                                  _MobileUiDensity.comfortable,
                              onSelected: (_) {
                                setLocalState(() {
                                  localMobileUiDensity =
                                      _MobileUiDensity.comfortable;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('緊�?'),
                              selected: localMobileUiDensity ==
                                  _MobileUiDensity.compact,
                              onSelected: (_) {
                                setLocalState(() {
                                  localMobileUiDensity =
                                      _MobileUiDensity.compact;
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          '?�示：�?湊�??��?機寬度�??��?< 600）�?,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localExpandCardDetailsByDefault,
                          title: const Text('?�設展�??��?詳細說�?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localExpandCardDetailsByDefault = value;
                            });
                          },
                        ),
                        Text(
                          '?��?字�?�?{_mobileTextScaleLabel(localMobileTextScale)}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('�?),
                              selected:
                                  localMobileTextScale == _MobileTextScale.small,
                              onSelected: (_) {
                                setLocalState(() {
                                  localMobileTextScale = _MobileTextScale.small;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('�?),
                              selected: localMobileTextScale ==
                                  _MobileTextScale.medium,
                              onSelected: (_) {
                                setLocalState(() {
                                  localMobileTextScale =
                                      _MobileTextScale.medium;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('�?),
                              selected:
                                  localMobileTextScale == _MobileTextScale.large,
                              onSelected: (_) {
                                setLocalState(() {
                                  localMobileTextScale = _MobileTextScale.large;
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          '?�示：�??��?機寬度�??��?< 600）�?,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableStrategyFilter,
                          title: const Text('?�用策略篩選'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableStrategyFilter = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoRefreshEnabled,
                          title: const Text('?��?定�??�新'),
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoRefreshEnabled = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _intradayEnabled,
                          title: const Text('?�用?�中?��??�測（�?5?��?�?),
                          subtitle: const Text('App ?��??��?�??��?輪詢 TWSE ?�中資�?並�?算�???),
                          onChanged: (value) async {
                            if (_intradayController != null) {
                              if (value) {
                                await _intradayController!.enable();
                              } else {
                                await _intradayController!.disable();
                              }
                              if (!mounted) return;
                              setState(() {
                                _intradayEnabled = value;
                              });
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localLockSelectionParameters,
                          title: const Text('?��??�股?�數（防?��?漂移�?),
                          subtitle: const Text('?�用後�??�自?��??��???事件模板/高風?�自?��?�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localLockSelectionParameters = value;
                              if (value) {
                                localAutoApplyRecommendedMode = false;
                                localAutoDefensiveOnHighNewsRisk = false;
                                localAutoApplyNewsEventTemplate = false;
                              }
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoApplyRecommendedMode,
                          title: const Text('?��??��?建議模�?（�??��?次�?'),
                          onChanged: localLockSelectionParameters
                              ? null
                              : (value) {
                                  setLocalState(() {
                                    localAutoApplyRecommendedMode = value;
                                  });
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoApplyOnlyTradingMorning,
                          title: const Text('?�在交�??�早上自?��???),
                          subtitle: const Text('?��??�週�? 08:00-10:30 ?��??��?套用建議'),
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoApplyOnlyTradingMorning = value;
                            });
                          },
                        ),
                        Text('?��??�新?��?�?{localAutoRefreshMinutes.toInt()} ?��?'),
                        Slider(
                          value: localAutoRefreshMinutes,
                          min: 5,
                          max: 30,
                          divisions: 5,
                          label: '${localAutoRefreshMinutes.toInt()}m',
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoRefreshMinutes = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localRequireOpenConfirm,
                          title: const Text('?�盤30?��?確�??�場'),
                          onChanged: (value) {
                            setLocalState(() {
                              localRequireOpenConfirm = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoDefensiveOnHighNewsRisk,
                          title: const Text('?�大事件模�?（新?��?風險?��?保�?�?),
                          onChanged: localLockSelectionParameters
                              ? null
                              : (value) {
                                  setLocalState(() {
                                    localAutoDefensiveOnHighNewsRisk = value;
                                  });
                                },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoApplyNewsEventTemplate,
                          title: const Text('事件模板?��?套用'),
                          subtitle: const Text('?�測?�戰???��?/?�藥等�?件�?，自?��??��??��???),
                          onChanged: localLockSelectionParameters
                              ? null
                              : (value) {
                                  setLocalState(() {
                                    localAutoApplyNewsEventTemplate = value;
                                  });
                                },
                        ),
                        Text(
                          '事件模板?��??��?天數�?{localAutoRestoreNewsEventTemplateAfterDays.toInt()} 天�?????��?件命中�??��?�?,
                        ),
                        Slider(
                          value: localAutoRestoreNewsEventTemplateAfterDays,
                          min: 1,
                          max: 14,
                          divisions: 13,
                          label:
                              '${localAutoRestoreNewsEventTemplateAfterDays.toInt()}�?,
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoRestoreNewsEventTemplateAfterDays =
                                  value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localAutoRegimeEnabled,
                          title: const Text('Regime ?��??��?（�????�整/?��?�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoRegimeEnabled = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localTimeSegmentTuningEnabled,
                          title: const Text('?�段?��??�數（�??��?守�?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localTimeSegmentTuningEnabled = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          minLines: 3,
                          maxLines: 5,
                          initialValue: localSectorRulesText,
                          decoration: const InputDecoration(
                            labelText: '?��??��?規�?（格式�?11-17=食�?/塑�?�?,
                            helperText: '?��?行�?例�?25-29=?��?/?��?�?,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            localSectorRulesText = value;
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          children: _presets
                              .map(
                                (preset) => ChoiceChip(
                                  label: Text(preset.label),
                                  selected: selectedPresetId == preset.id,
                                  onSelected: (_) {
                                    setLocalState(() {
                                      selectedPresetId = preset.id;
                                      localEnableStrategyFilter = true;
                                      localOnlyRising = preset.onlyRising;
                                      localMaxPrice =
                                          preset.maxPrice.toDouble();
                                      localVolumeThreshold =
                                          preset.minVolume.toDouble();
                                      localTradeValueThreshold =
                                          preset.minTradeValue.toDouble();
                                      localEnableScoring = preset.enableScoring;
                                      localMinScore =
                                          preset.minScore.toDouble();
                                      localVolumeWeight =
                                          preset.volumeWeight.toDouble();
                                      localChangeWeight =
                                          preset.changeWeight.toDouble();
                                      localPriceWeight =
                                          preset.priceWeight.toDouble();
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 10),
                        ..._presets.map(
                          (preset) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.info_outline),
                              title: Text('${preset.label}?�設'),
                              subtitle: Text(preset.description),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localOnlyRising,
                          title: const Text('?��??�日上漲'),
                          onChanged: (value) {
                            setLocalState(() {
                              localOnlyRising = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '?�價上�?�?{_formatWithThousandsSeparator(localMaxPrice.toInt())}',
                        ),
                        Slider(
                          value: localMaxPrice,
                          min: _minPrice.toDouble(),
                          max: _maxPrice.toDouble(),
                          divisions: (_maxPrice - _minPrice) ~/ _priceStep,
                          label: localMaxPrice.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localMaxPrice = value;
                            });
                          },
                        ),
                        Text(
                          '?�交?��?檻�?${_formatWithThousandsSeparator(localVolumeThreshold.toInt())}',
                        ),
                        Slider(
                          value: localVolumeThreshold,
                          min: _minVolume.toDouble(),
                          max: _maxVolume.toDouble(),
                          divisions: (_maxVolume - _minVolume) ~/ _volumeStep,
                          label: localVolumeThreshold.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localVolumeThreshold = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localUseRelativeVolumeFilter,
                          title: const Text('?�用?��??�能?��?),
                          onChanged: (value) {
                            setLocalState(() {
                              localUseRelativeVolumeFilter = value;
                            });
                          },
                        ),
                        Text(
                            '?��??�能?�檻�?${localRelativeVolumePercent.toInt()}%（相對大?�平?��?�?),
                        Slider(
                          value: localRelativeVolumePercent,
                          min: 100,
                          max: 220,
                          divisions: 12,
                          label: '${localRelativeVolumePercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localRelativeVolumePercent = value;
                            });
                          },
                        ),
                        Text(
                          '?�交?��?檻�?${_formatCurrency(localTradeValueThreshold)}',
                        ),
                        Slider(
                          value: localTradeValueThreshold,
                          min: _minTradeValue.toDouble(),
                          max: _maxTradeValue.toDouble(),
                          divisions: (_maxTradeValue - _minTradeValue) ~/
                              _tradeValueStep,
                          label: _formatCurrency(localTradeValueThreshold),
                          onChanged: (value) {
                            setLocalState(() {
                              localTradeValueThreshold = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableForeignFlowFilter,
                          title: const Text('外�?淨買超篩??),
                          subtitle: Text('?�檻�?${_formatWithThousandsSeparator(localMinForeignNet.toInt())}'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableForeignFlowFilter = value;
                            });
                          },
                        ),
                        if (localEnableForeignFlowFilter) ...[
                          Slider(
                            value: localMinForeignNet,
                            min: -50000000,
                            max: 50000000,
                            divisions: 100,
                            label: _formatWithThousandsSeparator(localMinForeignNet.toInt()),
                            onChanged: (value) {
                              setLocalState(() {
                                localMinForeignNet = value;
                              });
                            },
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableTrustFlowFilter,
                          title: const Text('?�信淨買超篩??),
                          subtitle: Text('?�檻�?${_formatWithThousandsSeparator(localMinTrustNet.toInt())}'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableTrustFlowFilter = value;
                            });
                          },
                        ),
                        if (localEnableTrustFlowFilter) ...[
                          Slider(
                            value: localMinTrustNet,
                            min: -50000000,
                            max: 50000000,
                            divisions: 100,
                            label: _formatWithThousandsSeparator(localMinTrustNet.toInt()),
                            onChanged: (value) {
                              setLocalState(() {
                                localMinTrustNet = value;
                              });
                            },
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableDealerFlowFilter,
                          title: const Text('?��??�淨買�?篩選'),
                          subtitle: Text('?�檻�?${_formatWithThousandsSeparator(localMinDealerNet.toInt())}'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableDealerFlowFilter = value;
                            });
                          },
                        ),
                        if (localEnableDealerFlowFilter) ...[
                          Slider(
                            value: localMinDealerNet,
                            min: -50000000,
                            max: 50000000,
                            divisions: 100,
                            label: _formatWithThousandsSeparator(localMinDealerNet.toInt()),
                            onChanged: (value) {
                              setLocalState(() {
                                localMinDealerNet = value;
                              });
                            },
                          ),
                        ],
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableMarginDiffFilter,
                          title: const Text('?��?餘�?變�?篩選'),
                          subtitle: Text('?�檻�?${_formatWithThousandsSeparator(localMinMarginBalanceDiff.toInt())}'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableMarginDiffFilter = value;
                            });
                          },
                        ),
                        if (localEnableMarginDiffFilter) ...[
                          Slider(
                            value: localMinMarginBalanceDiff,
                            min: -100000000,
                            max: 100000000,
                            divisions: 200,
                            label: _formatWithThousandsSeparator(localMinMarginBalanceDiff.toInt()),
                            onChanged: (value) {
                              setLocalState(() {
                                localMinMarginBalanceDiff = value;
                              });
                            },
                          ),
                        ],
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableScoring,
                          title: const Text('?�用?��??��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableScoring = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localExcludeOverheated,
                          title: const Text('?�除追�?風險（�??��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localExcludeOverheated = value;
                            });
                          },
                        ),
                        Text('?�熱漲�?上�?�?{localMaxChaseChangePercent.toInt()}%'),
                        Slider(
                          value: localMaxChaseChangePercent,
                          min: 3,
                          max: 10,
                          divisions: 7,
                          label: '${localMaxChaseChangePercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localMaxChaseChangePercent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localLimitTopCandidates,
                          title: const Text('?�顯示�?20�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localLimitTopCandidates = value;
                            });
                          },
                        ),
                        const Divider(height: 24),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableExitSignal,
                          title: const Text('?�用?�場訊�?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableExitSignal = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localHoldingNotifyIncludeCaution,
                          title: const Text('庫�??��??�含警�?訊�?'),
                          subtitle: const Text('?��?後�??�知?��?/?�利（�?少通知�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localHoldingNotifyIncludeCaution = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableAutoRiskAdjustment,
                          title: const Text('?�用?��?調�?（風?��??��?'),
                          subtitle: const Text('依新???�勢/寬度/??��?��?調整?�數?��??��??�利?��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableAutoRiskAdjustment = value;
                            });
                          },
                        ),
                        Text(
                          '?��?調�?強度�?{localAutoRiskAdjustmentStrength.toInt()}�?{_riskAdjustmentIntensityLabel(localAutoRiskAdjustmentStrength.toInt())}�?,
                        ),
                        Slider(
                          value: localAutoRiskAdjustmentStrength,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label:
                              '${localAutoRiskAdjustmentStrength.toInt()} ${_riskAdjustmentIntensityLabel(localAutoRiskAdjustmentStrength.toInt())}',
                          onChanged: (value) {
                            setLocalState(() {
                              localAutoRiskAdjustmentStrength = value;
                            });
                          },
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Tooltip(
                              message: '?�格?�濾：�??�更少、�??��???,
                              child: ChoiceChip(
                                label: const Text('保�? 25'),
                                selected:
                                    localAutoRiskAdjustmentStrength.toInt() ==
                                        25,
                                onSelected: (_) {
                                  setLocalState(() {
                                    localAutoRiskAdjustmentStrength = 25;
                                  });
                                },
                              ),
                            ),
                            Tooltip(
                              message: '標�?設�?：進攻?�風?�平衡�?,
                              child: ChoiceChip(
                                label: const Text('平衡 50'),
                                selected:
                                    localAutoRiskAdjustmentStrength.toInt() ==
                                        50,
                                onSelected: (_) {
                                  setLocalState(() {
                                    localAutoRiskAdjustmentStrength = 50;
                                  });
                                },
                              ),
                            ),
                            Tooltip(
                              message: '快速�??��?調�??��??��?,
                              child: ChoiceChip(
                                label: const Text('積極 75'),
                                selected:
                                    localAutoRiskAdjustmentStrength.toInt() ==
                                        75,
                                onSelected: (_) {
                                  setLocalState(() {
                                    localAutoRiskAdjustmentStrength = 75;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localExpandAggressiveEstimateByDefault,
                          title: const Text('?�設展�?積極估�?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localExpandAggressiveEstimateByDefault = value;
                            });
                          },
                        ),
                        Text('?��?警示�?${localStopLossPercent.toInt()}%'),
                        Slider(
                          value: localStopLossPercent,
                          min: 3,
                          max: 10,
                          divisions: 7,
                          label: '-${localStopLossPercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localStopLossPercent = value;
                            });
                          },
                        ),
                        Text('?�利警示�?${localTakeProfitPercent.toInt()}%'),
                        Slider(
                          value: localTakeProfitPercent,
                          min: 5,
                          max: 20,
                          divisions: 15,
                          label: '+${localTakeProfitPercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localTakeProfitPercent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableTrailingStop,
                          title: const Text('?�用移�??�利'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableTrailingStop = value;
                            });
                          },
                        ),
                        const Divider(height: 24),
                        Text('權�?設�?�?＝忽?��?'),
                        Text('?�交?��??��?${localVolumeWeight.toInt()}'),
                        Slider(
                          value: localVolumeWeight.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${localVolumeWeight.toInt()}',
                          onChanged: (value) {
                            setLocalState(() {
                              localVolumeWeight = value;
                            });
                          },
                        ),
                        Text('漲�??��?比�??��?${localChangeWeight.toInt()}'),
                        Slider(
                          value: localChangeWeight.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${localChangeWeight.toInt()}',
                          onChanged: (value) {
                            setLocalState(() {
                              localChangeWeight = value;
                            });
                          },
                        ),
                        Text('?�價距離權�?�?{localPriceWeight.toInt()}'),
                        Slider(
                          value: localPriceWeight.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${localPriceWeight.toInt()}',
                          onChanged: (value) {
                            setLocalState(() {
                              localPriceWeight = value;
                            });
                          },
                        ),
                        Text('籌碼?�中度�??��?${localConcentrationWeight.toInt()}'),
                        Slider(
                          value: localConcentrationWeight.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${localConcentrationWeight.toInt()}',
                          onChanged: (value) {
                            setLocalState(() {
                              localConcentrationWeight = value;
                            });
                          },
                        ),
                        Text('?�交?��??��?${localTradeValueWeight.toInt()}'),
                        Slider(
                          value: localTradeValueWeight.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: '${localTradeValueWeight.toInt()}',
                          onChanged: (value) {
                            setLocalState(() {
                              localTradeValueWeight = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        // auto weight search button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('?��??��?權�?'),
                            onPressed: _latestStocks.isEmpty
                                ? null
                                : () {
                                    // run helper to get best weights from current stocks
                                    final best = autoSearchWeights(
                                        _latestStocks,
                                        _latestVolumeReference,
                                        _maxPriceThreshold.toDouble(),
                                      );
                                    setLocalState(() {
                                      localVolumeWeight = best[0].toDouble();
                                      localChangeWeight = best[1].toDouble();
                                      localPriceWeight = best[2].toDouble();
                                      localConcentrationWeight = best[3].toDouble();
                                      localTradeValueWeight = best[4].toDouble();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              const Text('權�?已根?��??�表?�自?�調??)),
                                    );
                                  },
                          ),
                        ),
                        Text('移�??�利?�撤�?{localTrailingPullbackPercent.toInt()}%'),
                        Slider(
                          value: localTrailingPullbackPercent,
                          min: 2,
                          max: 8,
                          divisions: 6,
                          label: '${localTrailingPullbackPercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localTrailingPullbackPercent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableAdaptiveAtrExit,
                          title: const Text('?�用 ATR ?�適?��???),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableAdaptiveAtrExit = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableScoreTierSizing,
                          title: const Text('?�數?�層?��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableScoreTierSizing = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableBreakoutQuality,
                          title: const Text('突破?�質?�濾'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableBreakoutQuality = value;
                            });
                          },
                        ),
                        Text(
                            '突破?�能?��??�檻�?${localBreakoutMinVolumeRatio.toInt()}%'),
                        Slider(
                          value: localBreakoutMinVolumeRatio,
                          min: 100,
                          max: 200,
                          divisions: 10,
                          label: '${localBreakoutMinVolumeRatio.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localBreakoutMinVolumeRatio = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableChipConcentrationFilter,
                          title: const Text('籌碼?�中度�?�?),
                          subtitle: Text('?�顯示�?中度 ??${localMinChipConcentrationPercent.toInt()}% ?�個股'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableChipConcentrationFilter = value;
                            });
                          },
                        ),
                        Text('?�低�?碼�?中度�?{localMinChipConcentrationPercent.toInt()}%'),
                        Slider(
                          value: localMinChipConcentrationPercent,
                          min: 0,
                          max: 100,
                          divisions: 20,
                          label: '${localMinChipConcentrationPercent.toInt()}%',
                          onChanged: (value) {
                            setLocalState(() {
                              localMinChipConcentrationPercent = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableRiskRewardPrefilter,
                          title: const Text('風險?�酬?�置?�濾'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableRiskRewardPrefilter = value;
                            });
                          },
                        ),
                        Text(
                            '?�低風?�報?��?�?{localMinRiskRewardRatio.toStringAsFixed(2)}'),
                        Slider(
                          value: localMinRiskRewardRatio,
                          min: 1.0,
                          max: 3.0,
                          divisions: 20,
                          label: localMinRiskRewardRatio.toStringAsFixed(2),
                          onChanged: (value) {
                            setLocalState(() {
                              localMinRiskRewardRatio = value;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<BreakoutMode>(
                          initialValue: localBreakoutStageMode,
                          decoration: const InputDecoration(
                            labelText: '飆股篩選模�?',
                            border: OutlineInputBorder(),
                          ),
                          items: BreakoutMode.values
                              .map(
                                (mode) => DropdownMenuItem<BreakoutMode>(
                                  value: mode,
                                  child: Text(BreakoutModeLabel(mode)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setLocalState(() {
                              localBreakoutStageMode = value;
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '?��???確�?突破/低基?��????��??�攻/?�縮待噴/事件?�卡位�??��??�勢快速�??��?,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableMultiDayBreakout,
                          title: const Text('???突破確�?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableMultiDayBreakout = value;
                            });
                          },
                        ),
                        Text(
                            '?�低�??突破天數�?{localMinBreakoutStreakDays.toInt()} �?),
                        Slider(
                          value: localMinBreakoutStreakDays,
                          min: 1,
                          max: 5,
                          divisions: 4,
                          label: '${localMinBreakoutStreakDays.toInt()}�?,
                          onChanged: (value) {
                            setLocalState(() {
                              localMinBreakoutStreakDays = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableFalseBreakoutProtection,
                          title: const Text('?��??�防�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableFalseBreakoutProtection = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableMarketBreadthFilter,
                          title: const Text('市場寬度?�濾（漲跌家?��?�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableMarketBreadthFilter = value;
                            });
                          },
                        ),
                        Text(
                            '?�低�??�寬度�?�?{localMinMarketBreadthRatio.toStringAsFixed(2)}'),
                        Slider(
                          value: localMinMarketBreadthRatio,
                          min: 0.8,
                          max: 2.0,
                          divisions: 12,
                          label: localMinMarketBreadthRatio.toStringAsFixed(2),
                          onChanged: (value) {
                            setLocalState(() {
                              localMinMarketBreadthRatio = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableEventRiskExclusion,
                          title: const Text('事件風險?�除（財???��?�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableEventRiskExclusion = value;
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '三�?子快?��?設�?MVP�?,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('保�?'),
                              selected: selectedMvpPresetId == 'mvp_conservative',
                              onSelected: (_) {
                                setLocalState(() {
                                  selectedMvpPresetId = 'mvp_conservative';
                                  localEnableEventCalendarWindow = true;
                                  localEventCalendarGuardDays = 2;
                                  localEnableRevenueMomentumFilter = true;
                                  localMinRevenueMomentumScore = 1;
                                  localEnableEarningsSurpriseFilter = true;
                                  localMinEarningsSurpriseScore = 1;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('平衡'),
                              selected: selectedMvpPresetId == 'mvp_balanced',
                              onSelected: (_) {
                                setLocalState(() {
                                  selectedMvpPresetId = 'mvp_balanced';
                                  localEnableEventCalendarWindow = true;
                                  localEventCalendarGuardDays = 1;
                                  localEnableRevenueMomentumFilter = true;
                                  localMinRevenueMomentumScore = 0;
                                  localEnableEarningsSurpriseFilter = true;
                                  localMinEarningsSurpriseScore = 0;
                                });
                              },
                            ),
                            ChoiceChip(
                              label: const Text('積極'),
                              selected: selectedMvpPresetId == 'mvp_aggressive',
                              onSelected: (_) {
                                setLocalState(() {
                                  selectedMvpPresetId = 'mvp_aggressive';
                                  localEnableEventCalendarWindow = false;
                                  localEventCalendarGuardDays = 0;
                                  localEnableRevenueMomentumFilter = true;
                                  localMinRevenueMomentumScore = -1;
                                  localEnableEarningsSurpriseFilter = true;
                                  localMinEarningsSurpriseScore = -1;
                                });
                              },
                            ),
                          ],
                        ),
                        Text(
                          '保�?：避?��?件�?且�?求�?高�??��?平衡：�?準�?檻�?積極：放寬�?件�??��??��?檻�?,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableEventCalendarWindow,
                          title: const Text('法說/財報事件窗�?濾�?MVP�?),
                          subtitle: const Text('事件?��?後天?�內?�避?��?事件?�卡位模式除�?),
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localEnableEventCalendarWindow = value;
                            });
                          },
                        ),
                        Text('事件窗天?��?±${localEventCalendarGuardDays.toInt()} �?),
                        Slider(
                          value: localEventCalendarGuardDays,
                          min: 0,
                          max: 3,
                          divisions: 3,
                          label: '±${localEventCalendarGuardDays.toInt()}�?,
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localEventCalendarGuardDays = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableRevenueMomentumFilter,
                          title: const Text('?��??��??��?濾�?MVP�?),
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localEnableRevenueMomentumFilter = value;
                            });
                          },
                        ),
                        Text(
                            '?�低�??��??��??��?${localMinRevenueMomentumScore.toInt()}�?3 ~ +3�?),
                        Slider(
                          value: localMinRevenueMomentumScore,
                          min: -3,
                          max: 3,
                          divisions: 6,
                          label:
                              localMinRevenueMomentumScore.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localMinRevenueMomentumScore = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableEarningsSurpriseFilter,
                          title: const Text('財報 surprise ?�濾（MVP�?),
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localEnableEarningsSurpriseFilter = value;
                            });
                          },
                        ),
                        Text(
                            '?�低財??surprise ?�數�?{localMinEarningsSurpriseScore.toInt()}�?3 ~ +3�?),
                        Slider(
                          value: localMinEarningsSurpriseScore,
                          min: -3,
                          max: 3,
                          divisions: 6,
                          label:
                              localMinEarningsSurpriseScore.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              selectedMvpPresetId = null;
                              localMinEarningsSurpriseScore = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableOvernightGapRiskGuard,
                          title: const Text('?�日跳空風險?�護（盤�?夜�?�?),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableOvernightGapRiskGuard = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableSectorExposureCap,
                          title: const Text('?�業?�中度�??��?依�??��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableSectorExposureCap = value;
                            });
                          },
                        ),
                        Text(
                            '?��??�業?�多�????�選�?{localMaxHoldingPerSector.toInt()} �?),
                        Slider(
                          value: localMaxHoldingPerSector,
                          min: 1,
                          max: 6,
                          divisions: 5,
                          label: '${localMaxHoldingPerSector.toInt()}�?,
                          onChanged: (value) {
                            setLocalState(() {
                              localMaxHoldingPerSector = value;
                            });
                          },
                        ),
                        Text('?��??�卻?��?${localCooldownDays.toInt()} �?),
                        Slider(
                          value: localCooldownDays,
                          min: 0,
                          max: 7,
                          divisions: 7,
                          label: '${localCooldownDays.toInt()}�?,
                          onChanged: (value) {
                            setLocalState(() {
                              localCooldownDays = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableSectorRotationBoost,
                          title: const Text('?��?輪�?強度?��?'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableSectorRotationBoost = value;
                            });
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: localEnableWeeklyWalkForwardAutoTune,
                          title: const Text('每週自??walk-forward 微調'),
                          onChanged: (value) {
                            setLocalState(() {
                              localEnableWeeklyWalkForwardAutoTune = value;
                            });
                          },
                        ),
                        Text(
                            'ATR ?�利?�數�?{localAtrTakeProfitMultiplier.toInt()}x'),
                        Slider(
                          value: localAtrTakeProfitMultiplier,
                          min: 1,
                          max: 4,
                          divisions: 3,
                          label: '${localAtrTakeProfitMultiplier.toInt()}x',
                          onChanged: (value) {
                            setLocalState(() {
                              localAtrTakeProfitMultiplier = value;
                            });
                          },
                        ),
                        Text('?��?????��?筆數�?{localManualLossStreak.toInt()}'),
                        Slider(
                          value: localManualLossStreak,
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: localManualLossStreak.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localManualLossStreak = value;
                            });
                          },
                        ),
                        Text('?�低�??�檻�?${localMinScore.toInt()}'),
                        Slider(
                          value: localMinScore,
                          min: _minScore.toDouble(),
                          max: _maxScore.toDouble(),
                          divisions: _maxScore - _minScore,
                          label: localMinScore.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localMinScore = value;
                            });
                          },
                        ),
                        Text('?�能權�?�?{localVolumeWeight.toInt()}'),
                        Slider(
                          value: localVolumeWeight,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: localVolumeWeight.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localVolumeWeight = value;
                            });
                          },
                        ),
                        Text('漲�?權�?�?{localChangeWeight.toInt()}'),
                        Slider(
                          value: localChangeWeight,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: localChangeWeight.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localChangeWeight = value;
                            });
                          },
                        ),
                        Text('低價權�?�?{localPriceWeight.toInt()}'),
                        Slider(
                          value: localPriceWeight,
                          min: 0,
                          max: 100,
                          divisions: 100,
                          label: localPriceWeight.toInt().toString(),
                          onChanged: (value) {
                            setLocalState(() {
                              localPriceWeight = value;
                            });
                          },
                        ),
                        Text(
                          '?�示：可?��??�設，�?微調?�數?��?轉判?��??�歷史資�?，目?�用?�能＋漲幅�?低價建�??�步?�數??,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).pop(
                                _FilterState(
                                  enabled: localEnableStrategyFilter,
                                  onlyRising: localOnlyRising,
                                  maxPrice: localMaxPrice.toInt(),
                                  minVolume: localVolumeThreshold.toInt(),
                                  useRelativeVolumeFilter:
                                      localUseRelativeVolumeFilter,
                                  relativeVolumePercent:
                                      localRelativeVolumePercent.toInt(),
                                  minTradeValue:
                                      localTradeValueThreshold.toInt(),
                                  enableScoring: localEnableScoring,
                                  limitTopCandidates: localLimitTopCandidates,
                                  autoRefreshEnabled: localAutoRefreshEnabled,
                                  autoApplyRecommendedMode:
                                      localAutoApplyRecommendedMode,
                                    lockSelectionParameters:
                                      localLockSelectionParameters,
                                  autoApplyOnlyTradingMorning:
                                      localAutoApplyOnlyTradingMorning,
                                  autoRefreshMinutes:
                                      localAutoRefreshMinutes.toInt(),
                                  requireOpenConfirm: localRequireOpenConfirm,
                                  autoDefensiveOnHighNewsRisk:
                                      localAutoDefensiveOnHighNewsRisk,
                                  autoApplyNewsEventTemplate:
                                      localAutoApplyNewsEventTemplate,
                                  autoRestoreNewsEventTemplateAfterDays:
                                      localAutoRestoreNewsEventTemplateAfterDays
                                          .toInt(),
                                  autoRegimeEnabled: localAutoRegimeEnabled,
                                  timeSegmentTuningEnabled:
                                      localTimeSegmentTuningEnabled,
                                  sectorRulesText: localSectorRulesText,
                                  excludeOverheated: localExcludeOverheated,
                                  maxChaseChangePercent:
                                      localMaxChaseChangePercent.toInt(),
                                  enableExitSignal: localEnableExitSignal,
                                  holdingNotifyIncludeCaution:
                                      localHoldingNotifyIncludeCaution,
                                  enableAutoRiskAdjustment:
                                      localEnableAutoRiskAdjustment,
                                  mobileUiDensity: localMobileUiDensity,
                                  autoRiskAdjustmentStrength:
                                      localAutoRiskAdjustmentStrength.toInt(),
                                  expandAggressiveEstimateByDefault:
                                      localExpandAggressiveEstimateByDefault,
                                    expandCardDetailsByDefault:
                                      localExpandCardDetailsByDefault,
                                    mobileTextScale: localMobileTextScale,
                                  stopLossPercent: localStopLossPercent.toInt(),
                                  takeProfitPercent:
                                      localTakeProfitPercent.toInt(),
                                  enableTrailingStop: localEnableTrailingStop,
                                  trailingPullbackPercent:
                                      localTrailingPullbackPercent.toInt(),
                                  enableAdaptiveAtrExit:
                                      localEnableAdaptiveAtrExit,
                                  atrTakeProfitMultiplier:
                                      localAtrTakeProfitMultiplier.toInt(),
                                  cooldownDays: localCooldownDays.toInt(),
                                  enableScoreTierSizing:
                                      localEnableScoreTierSizing,
                                  enableSectorRotationBoost:
                                      localEnableSectorRotationBoost,
                                  enableBreakoutQuality:
                                      localEnableBreakoutQuality,
                                  breakoutMinVolumeRatioPercent:
                                      localBreakoutMinVolumeRatio.toInt(),
                                  enableChipConcentrationFilter:
                                      localEnableChipConcentrationFilter,
                                  minChipConcentrationPercent:
                                      localMinChipConcentrationPercent,
                                  concentrationWeight:
                                      localConcentrationWeight.toInt(),
                                  tradeValueWeight:
                                      localTradeValueWeight.toInt(),
                                  enableMasterTrapFilter:
                                      localEnableMasterTrapFilter,
                                  masterTrapDropPercent:
                                      localMasterTrapDropPercent,
                                  enableRiskRewardPrefilter:
                                      localEnableRiskRewardPrefilter,
                                  minRiskRewardRatioX100:
                                      (localMinRiskRewardRatio * 100).round(),
                                  enableMultiDayBreakout:
                                      localEnableMultiDayBreakout,
                                  minBreakoutStreakDays:
                                      localMinBreakoutStreakDays.toInt(),
                                  enableFalseBreakoutProtection:
                                      localEnableFalseBreakoutProtection,
                                  enableMarketBreadthFilter:
                                      localEnableMarketBreadthFilter,
                                  minMarketBreadthRatioX100:
                                      (localMinMarketBreadthRatio * 100)
                                          .round(),
                                  enableEventRiskExclusion:
                                      localEnableEventRiskExclusion,
                                  enableEventCalendarWindow:
                                      localEnableEventCalendarWindow,
                                  eventCalendarGuardDays:
                                      localEventCalendarGuardDays.toInt(),
                                  enableRevenueMomentumFilter:
                                      localEnableRevenueMomentumFilter,
                                  minRevenueMomentumScore:
                                      localMinRevenueMomentumScore.toInt(),
                                  enableEarningsSurpriseFilter:
                                      localEnableEarningsSurpriseFilter,
                                  minEarningsSurpriseScore:
                                      localMinEarningsSurpriseScore.toInt(),
                                  enableOvernightGapRiskGuard:
                                      localEnableOvernightGapRiskGuard,
                                  enableSectorExposureCap:
                                      localEnableSectorExposureCap,
                                  maxHoldingPerSector:
                                      localMaxHoldingPerSector.toInt(),
                                  breakoutStageMode: localBreakoutStageMode,
                                  enableWeeklyWalkForwardAutoTune:
                                      localEnableWeeklyWalkForwardAutoTune,
                                  manualLossStreak:
                                      localManualLossStreak.toInt(),
                                  minScore: localMinScore.toInt(),
                                  volumeWeight: localVolumeWeight.toInt(),
                                  changeWeight: localChangeWeight.toInt(),
                                  priceWeight: localPriceWeight.toInt(),
                                  enableForeignFlowFilter: localEnableForeignFlowFilter,
                                  minForeignNet: localMinForeignNet.toInt(),
                                  enableTrustFlowFilter: localEnableTrustFlowFilter,
                                  minTrustNet: localMinTrustNet.toInt(),
                                  enableDealerFlowFilter: localEnableDealerFlowFilter,
                                  minDealerNet: localMinDealerNet.toInt(),
                                  enableMarginDiffFilter: localEnableMarginDiffFilter,
                                  minMarginBalanceDiff: localMinMarginBalanceDiff.toInt(),
                                ),
                              );
                            },
                            child: const Text('套用'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null) {
      return;
    }

    final lockKeepsCoreStable =
        _lockSelectionParameters && result.lockSelectionParameters;
    final coreBefore = (
      enableStrategyFilter: _enableStrategyFilter,
      onlyRising: _onlyRising,
      maxPriceThreshold: _maxPriceThreshold,
      surgeVolumeThreshold: _surgeVolumeThreshold,
      useRelativeVolumeFilter: _useRelativeVolumeFilter,
      relativeVolumePercent: _relativeVolumePercent,
      minTradeValueThreshold: _minTradeValueThreshold,
      enableScoring: _enableScoring,
      limitTopCandidates: _limitTopCandidates,
      excludeOverheated: _excludeOverheated,
      maxChaseChangePercent: _maxChaseChangePercent,
      enableBreakoutQuality: _enableBreakoutQuality,
      breakoutMinVolumeRatioPercent: _breakoutMinVolumeRatioPercent,
      enableRiskRewardPrefilter: _enableRiskRewardPrefilter,
      minRiskRewardRatioX100: _minRiskRewardRatioX100,
      enableMultiDayBreakout: _enableMultiDayBreakout,
      minBreakoutStreakDays: _minBreakoutStreakDays,
      enableFalseBreakoutProtection: _enableFalseBreakoutProtection,
      enableMarketBreadthFilter: _enableMarketBreadthFilter,
      minMarketBreadthRatioX100: _minMarketBreadthRatioX100,
      enableEventRiskExclusion: _enableEventRiskExclusion,
      enableEventCalendarWindow: _enableEventCalendarWindow,
      eventCalendarGuardDays: _eventCalendarGuardDays,
      enableRevenueMomentumFilter: _enableRevenueMomentumFilter,
      minRevenueMomentumScore: _minRevenueMomentumScore,
      enableEarningsSurpriseFilter: _enableEarningsSurpriseFilter,
      minEarningsSurpriseScore: _minEarningsSurpriseScore,
      enableOvernightGapRiskGuard: _enableOvernightGapRiskGuard,
      enableSectorExposureCap: _enableSectorExposureCap,
      maxHoldingPerSector: _maxHoldingPerSector,
      breakoutStageMode: BreakoutMode,
      minScoreThreshold: _minScoreThreshold,
      volumeWeight: _volumeWeight,
      changeWeight: _changeWeight,
      priceWeight: _priceWeight,
    );
    final attemptedCoreChange = lockKeepsCoreStable &&
        (result.enabled != coreBefore.enableStrategyFilter ||
            result.onlyRising != coreBefore.onlyRising ||
            result.maxPrice != coreBefore.maxPriceThreshold ||
            result.minVolume != coreBefore.surgeVolumeThreshold ||
        result.useRelativeVolumeFilter !=
          coreBefore.useRelativeVolumeFilter ||
        result.relativeVolumePercent !=
          coreBefore.relativeVolumePercent ||
            result.minTradeValue != coreBefore.minTradeValueThreshold ||
            result.enableScoring != coreBefore.enableScoring ||
        result.limitTopCandidates != coreBefore.limitTopCandidates ||
        result.excludeOverheated != coreBefore.excludeOverheated ||
        result.maxChaseChangePercent != coreBefore.maxChaseChangePercent ||
            result.minScore != coreBefore.minScoreThreshold ||
        result.volumeWeight != coreBefore.volumeWeight ||
        result.changeWeight != coreBefore.changeWeight ||
        result.priceWeight != coreBefore.priceWeight ||
            result.breakoutStageMode != coreBefore.breakoutStageMode ||
            result.enableEventCalendarWindow !=
                coreBefore.enableEventCalendarWindow ||
        result.eventCalendarGuardDays != coreBefore.eventCalendarGuardDays ||
        result.enableRevenueMomentumFilter !=
          coreBefore.enableRevenueMomentumFilter ||
            result.minRevenueMomentumScore !=
                coreBefore.minRevenueMomentumScore ||
        result.enableEarningsSurpriseFilter !=
          coreBefore.enableEarningsSurpriseFilter ||
            result.minEarningsSurpriseScore !=
          coreBefore.minEarningsSurpriseScore ||
        result.enableRiskRewardPrefilter !=
          coreBefore.enableRiskRewardPrefilter ||
        result.minRiskRewardRatioX100 != coreBefore.minRiskRewardRatioX100 ||
        result.enableMarketBreadthFilter !=
          coreBefore.enableMarketBreadthFilter ||
        result.minMarketBreadthRatioX100 !=
          coreBefore.minMarketBreadthRatioX100 ||
        result.enableSectorExposureCap !=
          coreBefore.enableSectorExposureCap ||
        result.maxHoldingPerSector != coreBefore.maxHoldingPerSector);

    setState(() {
      _enableStrategyFilter = result.enabled;
      _onlyRising = result.onlyRising;
      _maxPriceThreshold = result.maxPrice;
      _surgeVolumeThreshold = result.minVolume;
      _useRelativeVolumeFilter = result.useRelativeVolumeFilter;
      _relativeVolumePercent = result.relativeVolumePercent;
      _minTradeValueThreshold = result.minTradeValue;
      _enableScoring = result.enableScoring;
      if (!_enableScoring) {
        _showStrongOnly = false;
      }
      _limitTopCandidates = result.limitTopCandidates;
      _autoRefreshEnabled = result.autoRefreshEnabled;
      _lockSelectionParameters = result.lockSelectionParameters;
        _autoApplyRecommendedMode = _lockSelectionParameters
          ? false
          : result.autoApplyRecommendedMode;
      _autoApplyOnlyTradingMorning = result.autoApplyOnlyTradingMorning;
      _autoRefreshMinutes = result.autoRefreshMinutes;
      _requireOpenConfirm = result.requireOpenConfirm;
        _autoDefensiveOnHighNewsRisk = _lockSelectionParameters
          ? false
          : result.autoDefensiveOnHighNewsRisk;
        _autoApplyNewsEventTemplate = _lockSelectionParameters
          ? false
          : result.autoApplyNewsEventTemplate;
      _autoRestoreNewsEventTemplateAfterDays =
          result.autoRestoreNewsEventTemplateAfterDays;
      _autoRegimeEnabled = result.autoRegimeEnabled;
      _timeSegmentTuningEnabled = result.timeSegmentTuningEnabled;
      _replaceSectorRulesFromText(result.sectorRulesText);
      _excludeOverheated = result.excludeOverheated;
      _maxChaseChangePercent = result.maxChaseChangePercent;
      _enableExitSignal = result.enableExitSignal;
      _holdingNotifyIncludeCaution = result.holdingNotifyIncludeCaution;
      _enableAutoRiskAdjustment = result.enableAutoRiskAdjustment;
      _mobileUiDensity = result.mobileUiDensity;
        _mobileTextScale = result.mobileTextScale;
      _autoRiskAdjustmentStrength = result.autoRiskAdjustmentStrength;
      _expandAggressiveEstimateByDefault =
          result.expandAggressiveEstimateByDefault;
        _expandCardDetailsByDefault = result.expandCardDetailsByDefault;
      _stopLossPercent = result.stopLossPercent;
      _takeProfitPercent = result.takeProfitPercent;
      _enableTrailingStop = result.enableTrailingStop;
      _trailingPullbackPercent = result.trailingPullbackPercent;
      _enableAdaptiveAtrExit = result.enableAdaptiveAtrExit;
      _atrTakeProfitMultiplier = result.atrTakeProfitMultiplier;
      _cooldownDays = result.cooldownDays;
      _enableScoreTierSizing = result.enableScoreTierSizing;
      _enableSectorRotationBoost = result.enableSectorRotationBoost;
      _enableBreakoutQuality = result.enableBreakoutQuality;
      _breakoutMinVolumeRatioPercent = result.breakoutMinVolumeRatioPercent;
      _enableChipConcentrationFilter = result.enableChipConcentrationFilter;
      _minChipConcentrationPercent = result.minChipConcentrationPercent;
      _concentrationWeight = result.concentrationWeight;
      _tradeValueWeight = result.tradeValueWeight;
      _enableMasterTrapFilter = result.enableMasterTrapFilter;
      _masterTrapDropPercent = result.masterTrapDropPercent;
      _enableRiskRewardPrefilter = result.enableRiskRewardPrefilter;
      _minRiskRewardRatioX100 = result.minRiskRewardRatioX100;
      _enableMultiDayBreakout = result.enableMultiDayBreakout;
      _minBreakoutStreakDays = result.minBreakoutStreakDays;
      _enableFalseBreakoutProtection = result.enableFalseBreakoutProtection;
      _enableMarketBreadthFilter = result.enableMarketBreadthFilter;
      _minMarketBreadthRatioX100 = result.minMarketBreadthRatioX100;
      _enableEventRiskExclusion = result.enableEventRiskExclusion;
      _enableEventCalendarWindow = result.enableEventCalendarWindow;
      _eventCalendarGuardDays = result.eventCalendarGuardDays;
      _enableRevenueMomentumFilter = result.enableRevenueMomentumFilter;
      _minRevenueMomentumScore = result.minRevenueMomentumScore;
      _enableEarningsSurpriseFilter = result.enableEarningsSurpriseFilter;
      _minEarningsSurpriseScore = result.minEarningsSurpriseScore;
      _enableOvernightGapRiskGuard = result.enableOvernightGapRiskGuard;
      _enableSectorExposureCap = result.enableSectorExposureCap;
      _maxHoldingPerSector = result.maxHoldingPerSector;
      BreakoutMode = result.breakoutStageMode;
      _enableWeeklyWalkForwardAutoTune = result.enableWeeklyWalkForwardAutoTune;
      _manualLossStreak = result.manualLossStreak;
      _minScoreThreshold = result.minScore;
      _volumeWeight = result.volumeWeight;
      _changeWeight = result.changeWeight;
      _priceWeight = result.priceWeight;

      if (lockKeepsCoreStable) {
        _enableStrategyFilter = coreBefore.enableStrategyFilter;
        _onlyRising = coreBefore.onlyRising;
        _maxPriceThreshold = coreBefore.maxPriceThreshold;
        _surgeVolumeThreshold = coreBefore.surgeVolumeThreshold;
        _useRelativeVolumeFilter = coreBefore.useRelativeVolumeFilter;
        _relativeVolumePercent = coreBefore.relativeVolumePercent;
        _minTradeValueThreshold = coreBefore.minTradeValueThreshold;
        _enableScoring = coreBefore.enableScoring;
        _limitTopCandidates = coreBefore.limitTopCandidates;
        _excludeOverheated = coreBefore.excludeOverheated;
        _maxChaseChangePercent = coreBefore.maxChaseChangePercent;
        _enableBreakoutQuality = coreBefore.enableBreakoutQuality;
        _breakoutMinVolumeRatioPercent =
            coreBefore.breakoutMinVolumeRatioPercent;
        _enableRiskRewardPrefilter = coreBefore.enableRiskRewardPrefilter;
        _minRiskRewardRatioX100 = coreBefore.minRiskRewardRatioX100;
        _enableMultiDayBreakout = coreBefore.enableMultiDayBreakout;
        _minBreakoutStreakDays = coreBefore.minBreakoutStreakDays;
        _enableFalseBreakoutProtection =
            coreBefore.enableFalseBreakoutProtection;
        _enableMarketBreadthFilter = coreBefore.enableMarketBreadthFilter;
        _minMarketBreadthRatioX100 = coreBefore.minMarketBreadthRatioX100;
        _enableEventRiskExclusion = coreBefore.enableEventRiskExclusion;
        _enableEventCalendarWindow = coreBefore.enableEventCalendarWindow;
        _eventCalendarGuardDays = coreBefore.eventCalendarGuardDays;
        _enableRevenueMomentumFilter =
            coreBefore.enableRevenueMomentumFilter;
        _minRevenueMomentumScore = coreBefore.minRevenueMomentumScore;
        _enableEarningsSurpriseFilter =
            coreBefore.enableEarningsSurpriseFilter;
        _minEarningsSurpriseScore = coreBefore.minEarningsSurpriseScore;
        _enableOvernightGapRiskGuard = coreBefore.enableOvernightGapRiskGuard;
        _enableSectorExposureCap = coreBefore.enableSectorExposureCap;
        _maxHoldingPerSector = coreBefore.maxHoldingPerSector;
        BreakoutMode = coreBefore.breakoutStageMode;
        _minScoreThreshold = coreBefore.minScoreThreshold;
        _volumeWeight = coreBefore.volumeWeight;
        _changeWeight = coreBefore.changeWeight;
        _priceWeight = coreBefore.priceWeight;
      }

      if (!_enableScoring) {
        _showStrongOnly = false;
      }
    });
    _configureAutoRefreshTimer();
    _savePreferencesTagged('filter_sheet_apply');

    final message = _enableStrategyFilter
        ? '已�??��??��??�價 <= $_maxPriceThreshold，�? ${_useRelativeVolumeFilter ? '>= $_relativeVolumePercent%?��?�? : '>='} ${_formatWithThousandsSeparator(_surgeVolumeThreshold)}，�?>= ${_formatCurrency(_minTradeValueThreshold)}${_onlyRising ? '，只?��?�? : ''}'
        : '已顯示全?�股�?;
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          attemptedCoreChange ? '$message（已?��??��??�數，�?套用?�選?�設定�?' : message,
        ),
      ),
    );
  }

  int _calculateStockScore(StockModel stock) {
    final volumeReference = _latestVolumeReference <= 0
        ? _surgeVolumeThreshold.toDouble()
        : _latestVolumeReference;
    final normalizedTradeValue =
        normalizedTradeValueForFilter(stock.tradeValue).toDouble();
    int baseScore = computeScore(
      volume: stock.volume.toDouble(),
      volumeReference: volumeReference,
      changePercent: stock.change,
      price: stock.closePrice,
      maxPrice: _maxPriceThreshold.toDouble(),
      chipConcentration: stock.chipConcentration,
      normalizedTradeValue: normalizedTradeValue,
      volumeWeight: _volumeWeight,
      changeWeight: _changeWeight,
      priceWeight: _priceWeight,
      concentrationWeight: _concentrationWeight,
      tradeValueWeight: _tradeValueWeight,
    );
    // adjust by sector strength (if available), downscale scores from weak sectors
    final group = _sectorGroupForCode(stock.code);
    final strength = _sectorStrengthByGroup[group] ?? 1.0;
    if (strength < 1.0) {
      // linearly reduce score
      baseScore = (baseScore * strength).round();
    }
    return baseScore;
  }

  int _calculateMarketAverageVolume(List<StockModel> stocks) {
    if (stocks.isEmpty) {
      return _surgeVolumeThreshold;
    }
    final total = stocks.fold<int>(0, (sum, stock) => sum + stock.volume);
    final avg = (total / stocks.length).round();
    return avg <= 0 ? _surgeVolumeThreshold : avg;
  }

  int _stableMarketAverageVolume(List<StockModel> stocks) {
    final now = DateTime.now();
    final cachedDate = _lockedMarketAverageVolumeDate;
    final cachedVolume = _lockedMarketAverageVolume;
    if (cachedDate != null &&
        cachedVolume != null &&
        _isSameCalendarDay(cachedDate, now)) {
      return cachedVolume;
    }

    final current = _calculateMarketAverageVolume(stocks);
    _lockedMarketAverageVolumeDate = now;
    _lockedMarketAverageVolume = current;
    return current;
  }

  int _effectiveVolumeThresholdWithSnapshot(
    int marketAverageVolume, {
    _RiskSnapshot? riskSnapshot,
  }) {
    if (!_useRelativeVolumeFilter) {
      return _surgeVolumeThreshold;
    }
    final relativeThreshold =
        (marketAverageVolume * (_relativeVolumePercent / 100)).round();
    final baseThreshold = relativeThreshold > _surgeVolumeThreshold
        ? relativeThreshold
        : _surgeVolumeThreshold;
    return (baseThreshold *
            _timeSegmentVolumeMultiplier() *
            _riskVolumeMultiplier(riskSnapshot))
        .round();
  }

  int _effectiveMinScoreThreshold([StockModel? stock]) {
    return _effectiveMinScoreThresholdWithSnapshot(stock: stock);
  }

  int _effectiveMinScoreThresholdWithSnapshot({
    StockModel? stock,
    _RiskSnapshot? riskSnapshot,
    _MarketRegime? regime,
  }) {
    final effectiveRegime = regime ?? _currentRegime;
    var threshold = _minScoreThreshold +
        _regimeScoreBiasFor(effectiveRegime) +
        _timeSegmentScoreBias() +
        _riskScoreBias(riskSnapshot);
    if (stock != null) {
      threshold += _sectorRegimeScoreBias(_regimeForStock(stock));
    }
    // breadth-based adjustment: ?�貨寬度?�弱?��?高�?檻�?寬度強�??�寬
    if (_latestMarketBreadthRatio < 0.9) {
      threshold += 2;
    } else if (_latestMarketBreadthRatio > 1.1) {
      threshold -= 2;
    }
    return threshold.clamp(0, 100);
  }

  _RiskSnapshot _buildRiskSnapshot() {
    return _buildRiskSnapshotForContext(
      regime: _currentRegime,
      breadth: _latestMarketBreadthRatio,
    );
  }

  _RiskSnapshot _buildRiskSnapshotForContext({
    required _MarketRegime regime,
    required double breadth,
    DateTime? now,
  }) {
    final rawScore = _calculateGlobalRiskScore(
      regime: regime,
      breadth: breadth,
      newsLevel: _marketNewsSnapshot?.level,
      isNightSession: _isPostMarketOrNight(now),
      lossStreak: _autoLossStreakFromJournal(),
    );
    final score = _smoothedRiskScore(rawScore);

    final level = score >= 75
        ? '高風??
        : score >= 55
            ? '中性�?保�?'
            : '風險?�控';
    return _RiskSnapshot(score: score, level: level);
  }

  int _smoothedRiskScore(int rawScore) {
    final recent =
        _riskScoreHistory.reversed.take(2).map((item) => item.score).toList();
    if (recent.isEmpty) {
      return rawScore;
    }
    final avgRecent = recent.reduce((a, b) => a + b) / recent.length;
    final smoothed = (rawScore * 0.65) + (avgRecent * 0.35);
    return smoothed.round().clamp(0, 100);
  }

  Future<void> _recordDailyRiskScore(List<StockModel> stocks) async {
    if (stocks.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final regime =
        _autoRegimeEnabled ? _detectMarketRegime(stocks) : _currentRegime;
    final breadth = _marketBreadthRatio(stocks);
    final rawScore = _calculateGlobalRiskScore(
      regime: regime,
      breadth: breadth,
      newsLevel: _marketNewsSnapshot?.level,
      isNightSession: _isPostMarketOrNight(now),
      lossStreak: _autoLossStreakFromJournal(),
    );
    final score = _smoothedRiskScore(rawScore);

    final index = _riskScoreHistory
        .indexWhere((point) => _isSameCalendarDay(point.date, now));
    if (index >= 0) {
      _riskScoreHistory[index] = _RiskScorePoint(date: now, score: score);
    } else {
      _riskScoreHistory.add(_RiskScorePoint(date: now, score: score));
      _riskScoreHistory.sort((a, b) => a.date.compareTo(b.date));
      while (_riskScoreHistory.length > 30) {
        _riskScoreHistory.removeAt(0);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _riskScoreHistoryKey,
      jsonEncode(_riskScoreHistory.map((point) => point.toJson()).toList()),
    );
  }

  String _riskScoreTrendText() {
    final last = _riskScoreHistory.reversed.take(7).toList().reversed.toList();
    if (last.isEmpty) {
      return '-';
    }
    const bars = <String>['??, '??, '??, '??, '??, '??, '??, '??];
    return last
        .map((point) =>
            bars[(point.score / 13).floor().clamp(0, bars.length - 1)])
        .join();
  }

  int _calculateGlobalRiskScore({
    required _MarketRegime regime,
    required double breadth,
    required NewsRiskLevel? newsLevel,
    required bool isNightSession,
    required int lossStreak,
  }) {
    var score = 50;

    score += switch (newsLevel) {
      NewsRiskLevel.high => 25,
      NewsRiskLevel.medium => 10,
      NewsRiskLevel.low => -5,
      null => 0,
    };

    score += switch (regime) {
      _MarketRegime.defensive => 18,
      _MarketRegime.range => 5,
      _MarketRegime.bull => -8,
    };

    if (breadth < 0.9) {
      score += 18;
    } else if (breadth < 1.0) {
      score += 10;
    } else if (breadth < 1.1) {
      score += 4;
    } else if (breadth >= 1.3) {
      score -= 10;
    } else {
      score -= 4;
    }

    score += (lossStreak * 4).clamp(0, 12);
    if (isNightSession) {
      score += 4;
    }
    return score.clamp(0, 100);
  }

  int _riskScoreBias([_RiskSnapshot? riskSnapshot]) {
    if (!_enableAutoRiskAdjustment || _isAutoRiskAdjustmentSuppressed()) {
      return 0;
    }
    final score = (riskSnapshot ?? _buildRiskSnapshot()).score;
    int baseBias;
    if (score >= 80) {
      baseBias = 8;
    } else if (score >= 70) {
      baseBias = 5;
    } else if (score >= 60) {
      baseBias = 3;
    } else if (score <= 35) {
      baseBias = -4;
    } else if (score <= 45) {
      baseBias = -2;
    } else {
      baseBias = 0;
    }
    final factor = _riskAdjustmentIntensityFactor();
    final scaled = (baseBias * factor).round();
    if (baseBias > 0) {
      return scaled.clamp(1, 12);
    }
    if (baseBias < 0) {
      return scaled.clamp(-8, -1);
    }
    return 0;
  }

  double _riskVolumeMultiplier([_RiskSnapshot? riskSnapshot]) {
    if (!_enableAutoRiskAdjustment || _isAutoRiskAdjustmentSuppressed()) {
      return 1.0;
    }
    final score = (riskSnapshot ?? _buildRiskSnapshot()).score;
    double baseMultiplier;
    if (score >= 80) {
      baseMultiplier = 1.2;
    } else if (score >= 70) {
      baseMultiplier = 1.12;
    } else if (score >= 60) {
      baseMultiplier = 1.06;
    } else if (score <= 35) {
      baseMultiplier = 0.95;
    } else {
      baseMultiplier = 1.0;
    }
    final factor = _riskAdjustmentIntensityFactor();
    return (1 + ((baseMultiplier - 1) * factor)).clamp(0.9, 1.28);
  }

  double _riskTakeProfitMultiplier([_RiskSnapshot? riskSnapshot]) {
    if (!_enableAutoRiskAdjustment || _isAutoRiskAdjustmentSuppressed()) {
      return 1.0;
    }
    final score = (riskSnapshot ?? _buildRiskSnapshot()).score;
    double baseMultiplier;
    if (score >= 80) {
      baseMultiplier = 0.85;
    } else if (score >= 70) {
      baseMultiplier = 0.9;
    } else if (score >= 60) {
      baseMultiplier = 0.95;
    } else if (score <= 35) {
      baseMultiplier = 1.08;
    } else {
      baseMultiplier = 1.0;
    }
    final factor = _riskAdjustmentIntensityFactor();
    return (1 + ((baseMultiplier - 1) * factor)).clamp(0.8, 1.14);
  }

  double _effectiveTrailingPullbackPercent([_RiskSnapshot? riskSnapshot]) {
    if (!_enableAutoRiskAdjustment || _isAutoRiskAdjustmentSuppressed()) {
      return _trailingPullbackPercent.toDouble();
    }
    final score = (riskSnapshot ?? _buildRiskSnapshot()).score;
    double baseMultiplier;
    if (score >= 80) {
      baseMultiplier = 0.7;
    } else if (score >= 70) {
      baseMultiplier = 0.85;
    } else if (score <= 35) {
      baseMultiplier = 1.1;
    } else {
      baseMultiplier = 1.0;
    }
    final factor = _riskAdjustmentIntensityFactor();
    final scaledMultiplier = 1 + ((baseMultiplier - 1) * factor);
    return (_trailingPullbackPercent * scaledMultiplier).clamp(1.5, 8.0);
  }

  double _riskAdjustmentIntensityFactor() {
    final ratio = (_autoRiskAdjustmentStrength / 100).clamp(0.0, 1.0);
    return 0.6 + (ratio * 0.8);
  }

  String _riskAdjustmentIntensityLabel([int? strength]) {
    final value = (strength ?? _autoRiskAdjustmentStrength).clamp(0, 100);
    if (value <= 33) {
      return '保�?';
    }
    if (value <= 66) {
      return '平衡';
    }
    return '積極';
  }

  int _autoLossStreakFromJournal() {
    if (_tradeJournalEntries.isEmpty) {
      return _manualLossStreak;
    }

    final sorted = List<_TradeJournalEntry>.from(_tradeJournalEntries)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    var count = 0;
    for (var i = sorted.length - 1; i >= 0; i--) {
      if (sorted[i].pnlPercent < 0) {
        count += 1;
      } else {
        break;
      }
    }
    return count;
  }

  DateTime? _lastStopLossTime(String stockCode) {
    final matches = _tradeJournalEntries
        .where((entry) =>
            entry.stockCode == stockCode &&
            entry.pnlPercent <= -_stopLossPercent)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return matches.isEmpty ? null : matches.first.timestamp;
  }

  bool _isInStopLossCooldown(String stockCode) {
    if (_cooldownDays <= 0) {
      return false;
    }
    final lastStopLoss = _lastStopLossTime(stockCode);
    if (lastStopLoss == null) {
      return false;
    }
    final days = DateTime.now().difference(lastStopLoss).inDays;
    return days < _cooldownDays;
  }

  int _scoreTierSizingPercent(StockModel stock) {
    if (!_enableScoreTierSizing) {
      return 100;
    }
    final score = _calculateStockScore(stock);
    if (score >= 80) {
      return 120;
    }
    if (score >= 70) {
      return 100;
    }
    if (score >= 60) {
      return 80;
    }
    return 60;
  }

  _MarketRegime _detectMarketRegime(List<StockModel> stocks) {
    if (stocks.isEmpty) {
      return _MarketRegime.range;
    }

    final risingCount = stocks.where((stock) => stock.change > 0).length;
    final risingRatio = risingCount / stocks.length;
    final averageChange =
        stocks.fold<double>(0.0, (sum, stock) => sum + stock.change) /
            stocks.length;

    if ((_marketNewsSnapshot?.level == NewsRiskLevel.high) ||
        averageChange <= -0.5 ||
        risingRatio < 0.35) {
      return _MarketRegime.defensive;
    }

    if (averageChange >= 0.8 && risingRatio > 0.6) {
      return _MarketRegime.bull;
    }

    return _MarketRegime.range;
  }

  String _sectorGroupForCode(String code) {
    if (code.length < 2) {
      return '?��?';
    }
    final prefix = int.tryParse(code.substring(0, 2));
    if (prefix == null) {
      return '?��?';
    }
    for (final rule in _sectorRules) {
      if (prefix >= rule.start && prefix <= rule.end) {
        return rule.group;
      }
    }
    return '?��?';
  }

  void _rebuildSectorRegime(List<StockModel> stocks) {
    _sectorRegimeByGroup.clear();
    _sectorStrengthByGroup.clear();
    final grouped = <String, List<StockModel>>{};
    for (final stock in stocks) {
      final group = _sectorGroupForCode(stock.code);
      grouped.putIfAbsent(group, () => <StockModel>[]).add(stock);
    }
    grouped.forEach((group, list) {
      _sectorRegimeByGroup[group] = _detectMarketRegime(list);
      final avgChange = list.fold<double>(0.0, (sum, s) => sum + s.change) /
          (list.isEmpty ? 1 : list.length);
      final risingRatio = list.where((stock) => stock.change > 0).length /
          (list.isEmpty ? 1 : list.length);
      _sectorStrengthByGroup[group] = (avgChange * 10) + (risingRatio * 20);
    });
  }

  _MarketRegime _regimeForStock(StockModel stock) {
    final group = _sectorGroupForCode(stock.code);
    return _sectorRegimeByGroup[group] ?? _currentRegime;
  }

  int _sectorRegimeScoreBias(_MarketRegime regime) {
    if (!_autoRegimeEnabled) {
      return 0;
    }
    return switch (regime) {
      _MarketRegime.bull => -2,
      _MarketRegime.range => 0,
      _MarketRegime.defensive => 3,
    };
  }

  int _sectorRotationBonus(StockModel stock) {
    if (!_enableSectorRotationBoost) {
      return 0;
    }
    final group = _sectorGroupForCode(stock.code);
    final strength = _sectorStrengthByGroup[group] ?? 0.0;
    if (strength >= 20) {
      return 5;
    }
    if (strength >= 10) {
      return 3;
    }
    if (strength <= 0) {
      return -2;
    }
    return 0;
  }

  int _timeSegmentScoreBias() {
    if (!_timeSegmentTuningEnabled) {
      return 0;
    }
    final status = _buildMarketTimingStatus();
    return switch (status.type) {
      _MarketTimingType.premarket => 4,
      _MarketTimingType.openConfirm => 2,
      _MarketTimingType.tradable => 0,
      _MarketTimingType.closed => 0,
    };
  }

  double _timeSegmentVolumeMultiplier() {
    if (!_timeSegmentTuningEnabled) {
      return 1.0;
    }
    final status = _buildMarketTimingStatus();
    return switch (status.type) {
      _MarketTimingType.premarket => 1.15,
      _MarketTimingType.openConfirm => 1.08,
      _MarketTimingType.tradable => 1.0,
      _MarketTimingType.closed => 1.0,
    };
  }

  double _adaptiveTakeProfitThreshold(StockModel stock) {
    final adjustedBaseTakeProfit =
        (_takeProfitPercent * _riskTakeProfitMultiplier()).clamp(4.0, 20.0);
    if (!_enableAdaptiveAtrExit || stock.closePrice <= 0) {
      return adjustedBaseTakeProfit.toDouble();
    }
    final dailyVolatilityPercent = stock.change.abs();
    final adaptive = ((dailyVolatilityPercent * _atrTakeProfitMultiplier) *
            _riskTakeProfitMultiplier())
        .clamp(4.0, 20.0);
    return adaptive > adjustedBaseTakeProfit
        ? adaptive
        : adjustedBaseTakeProfit.toDouble();
  }

  double _regimeVolumeMultiplier() {
    return _regimeVolumeMultiplierFor(_currentRegime);
  }

  double _regimeVolumeMultiplierFor(_MarketRegime regime) {
    if (!_autoRegimeEnabled) {
      return 1.0;
    }
    return switch (regime) {
      _MarketRegime.bull => 0.95,
      _MarketRegime.range => 1.0,
      _MarketRegime.defensive => 1.15,
    };
  }

  int _regimeScoreBiasFor(_MarketRegime regime) {
    if (!_autoRegimeEnabled) {
      return 0;
    }
    return switch (regime) {
      _MarketRegime.bull => -3,
      _MarketRegime.range => 0,
      _MarketRegime.defensive => 5,
    };
  }

  String _regimeLabelOf(_MarketRegime regime) {
    return switch (regime) {
      _MarketRegime.bull => '多頭',
      _MarketRegime.range => '?�整',
      _MarketRegime.defensive => '?��?',
    };
  }

  double? _calculatePnlPercent(StockModel stock, double? entryPrice) {
    if (entryPrice == null || entryPrice <= 0) {
      return null;
    }
    return ((stock.closePrice - entryPrice) / entryPrice) * 100;
  }

  double? _calculatePnlAmount(
    StockModel stock,
    double? entryPrice,
    double? lots,
  ) {
    if (entryPrice == null || entryPrice <= 0 || lots == null || lots <= 0) {
      return null;
    }
    return (stock.closePrice - entryPrice) * lots * 1000;
  }

  Future<void> _openEntryPriceDialog(StockModel stock) async {
    final currentEntryPrice = _entryPriceByCode[stock.code];
    final currentLots = _positionLotsByCode[stock.code] ?? 1;
    final priceController = TextEditingController(
      text: (currentEntryPrice ?? stock.closePrice).toStringAsFixed(2),
    );
    final lotsController = TextEditingController(
      text: currentLots.toStringAsFixed(currentLots % 1 == 0 ? 0 : 2),
    );

    final result = await showDialog<_PositionInput?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('設�??�股 - ${stock.code} ${stock.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '買入?�本',
                  hintText: '例�? 48.50',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lotsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '?�股張數',
                  hintText: '例�? 1 ??0.5',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('?��?'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(
                const _PositionInput(clear: true),
              ),
              child: const Text('清除?�股'),
            ),
            TextButton(
              onPressed: () async {
                final defaultPrice =
                    double.tryParse(priceController.text.trim()) ??
                        currentEntryPrice ??
                        stock.closePrice;
                final defaultLots =
                    double.tryParse(lotsController.text.trim()) ?? currentLots;
                final result = await _openBatchCostCalculatorDialog(
                  defaultPrice: defaultPrice,
                  defaultLots: defaultLots,
                );
                if (result == null) {
                  return;
                }
                priceController.text = result.averagePrice.toStringAsFixed(2);
                lotsController.text = result.totalLots
                    .toStringAsFixed(result.totalLots % 1 == 0 ? 0 : 2);
              },
              child: const Text('?�批計�?'),
            ),
            FilledButton(
              onPressed: () {
                final entryPrice = double.tryParse(priceController.text.trim());
                final lots = double.tryParse(lotsController.text.trim());
                Navigator.of(context).pop(
                  _PositionInput(
                    entryPrice: entryPrice,
                    lots: lots,
                  ),
                );
              },
              child: const Text('?��?'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    if (result.clear) {
      setState(() {
        _entryPriceByCode.remove(stock.code);
        _positionLotsByCode.remove(stock.code);
      });
      await _savePreferences();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已�???${stock.code} ?�股設�?')),
      );
      return;
    }

    final entryPrice = result.entryPrice;
    final lots = result.lots;
    if (entryPrice == null || entryPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?�本必�?大於 0')),
      );
      return;
    }

    if (lots == null || lots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('張數必�?大於 0')),
      );
      return;
    }

    setState(() {
      _entryPriceByCode[stock.code] = entryPrice;
      _positionLotsByCode[stock.code] = lots;
    });
    await _savePreferences();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已儲�?${stock.code} ?�本 ${entryPrice.toStringAsFixed(2)} / 張數 ${lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2)}',
        ),
      ),
    );
  }

  Future<void> _openManualHoldingDialog() async {
    final codeController = TextEditingController();
    final priceController = TextEditingController();
    final lotsController = TextEditingController(text: '1');

    final result = await showDialog<(String, _PositionInput)?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('?��??��?/?�新庫�?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: '?�票�??',
                  hintText: '例�? 2324',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '買入?�本',
                  hintText: '例�? 39.25',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: lotsController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '?�股張數',
                  hintText: '例�? 1 ??0.5',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('?��?'),
            ),
            FilledButton(
              onPressed: () {
                final code = codeController.text.trim().toUpperCase();
                final entryPrice = double.tryParse(priceController.text.trim());
                final lots = double.tryParse(lotsController.text.trim());
                Navigator.of(context).pop((
                  code,
                  _PositionInput(entryPrice: entryPrice, lots: lots),
                ));
              },
              child: const Text('?��?'),
            ),
          ],
        );
      },
    );

    if (result == null) {
      return;
    }

    final code = result.$1;
    final payload = result.$2;
    if (code.isEmpty || !RegExp(r'^[0-9A-Z]+$').hasMatch(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?�票�???��??�誤')),
      );
      return;
    }

    final entryPrice = payload.entryPrice;
    final lots = payload.lots;
    if (entryPrice == null || entryPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?�本必�?大於 0')),
      );
      return;
    }
    if (lots == null || lots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('張數必�?大於 0')),
      );
      return;
    }

    setState(() {
      _entryPriceByCode[code] = entryPrice;
      _positionLotsByCode[code] = lots;
      _showOnlyHoldings = true;
      _showOnlyFavorites = false;
    });
    await _savePreferences();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已儲�?$code ?�本 ${entryPrice.toStringAsFixed(2)} / 張數 ${lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2)}',
        ),
      ),
    );
  }

  Future<void> _openTradeRecordDialog(
    StockModel stock, {
    required String exitLabel,
  }) async {
    final entryPrice = _entryPriceByCode[stock.code];
    final lots = _positionLotsByCode[stock.code];
    if (entryPrice == null || lots == null || lots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請�?設�??�股?�本?�張?��?記�?平�?)),
      );
      return;
    }

    final exitPriceController = TextEditingController(
      text: stock.closePrice.toStringAsFixed(2),
    );
    final lotsController = TextEditingController(
      text: lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2),
    );
    final reasonController = TextEditingController(text: exitLabel);
    String selectedStrategyTag = 'A';

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('記�?平�?- ${stock.code} ${stock.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('?�股?�本 ${entryPrice.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('策略標籤'),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: selectedStrategyTag,
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                        ],
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setDialogState(() {
                            selectedStrategyTag = value;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: exitPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '?�場??),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: lotsController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '平倉張??),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: '平倉�???),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('?��?'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('記�?'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) {
      return;
    }

    final exitPrice = double.tryParse(exitPriceController.text.trim());
    final closeLots = double.tryParse(lotsController.text.trim());
    final reason = reasonController.text.trim();
    if (exitPrice == null ||
        closeLots == null ||
        exitPrice <= 0 ||
        closeLots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('平倉�??�格式錯�?)),
      );
      return;
    }
    if (closeLots > lots) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '平倉張?��??�大?�目?��???${lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2)} �?)),
      );
      return;
    }

    final pnlPercent = ((exitPrice - entryPrice) / entryPrice) * 100;
    final pnlAmount = (exitPrice - entryPrice) * closeLots * 1000;

    setState(() {
      _tradeJournalEntries.add(
        _TradeJournalEntry(
          timestamp: DateTime.now(),
          stockCode: stock.code,
          stockName: stock.name,
          pnlPercent: pnlPercent,
          pnlAmount: pnlAmount,
          reason: reason.isEmpty ? exitLabel : reason,
          strategyTag: selectedStrategyTag,
        ),
      );
      if (_tradeJournalEntries.length > 300) {
        _tradeJournalEntries.removeAt(0);
      }

      if (closeLots >= lots) {
        _entryPriceByCode.remove(stock.code);
        _positionLotsByCode.remove(stock.code);
        _peakPnlPercentByCode.remove(stock.code);
      } else {
        _positionLotsByCode[stock.code] = lots - closeLots;
      }
    });
    await _savePreferences();

    if (!mounted) {
      return;
    }
    final autoStreak = _autoLossStreakFromJournal();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '已�??�平?��?${pnlPercent >= 0 ? '+' : ''}${pnlPercent.toStringAsFixed(2)}%（�?�� $autoStreak 筆�?',
        ),
      ),
    );
  }

  Future<void> _openTradeJournalPage() async {
    if (_tradeJournalEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?��?尚無交�??��?紀??)),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TradeJournalPage(
          entries: List<_TradeJournalEntry>.from(_tradeJournalEntries),
        ),
      ),
    );
  }

  Future<_BatchCostResult?> _openBatchCostCalculatorDialog({
    required double defaultPrice,
    required double defaultLots,
  }) async {
    final linesController = TextEditingController(
      text:
          '${defaultPrice.toStringAsFixed(2)},${defaultLots.toStringAsFixed(defaultLots % 1 == 0 ? 0 : 2)}',
    );
    String? errorText;

    return showDialog<_BatchCostResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('?�批買進�?�?),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('每�?一筆�??��?：價??張數'),
                  const SizedBox(height: 6),
                  const Text('例�?：\n48,1\n52,2\n50,0.5'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: linesController,
                    minLines: 4,
                    maxLines: 8,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: '?�格,張數',
                      errorText: errorText,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('?��?'),
                ),
                FilledButton(
                  onPressed: () {
                    final parseResult =
                        _parseBatchCostInput(linesController.text);
                    if (parseResult == null) {
                      setDialogState(() {
                        errorText = '?��??�誤，�?使用?�價??張數?��??�大??0';
                      });
                      return;
                    }
                    Navigator.of(context).pop(parseResult);
                  },
                  child: const Text('套用結�?'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  _BatchCostResult? _parseBatchCostInput(String rawText) {
    final lines = rawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }

    double totalLots = 0;
    double totalAmount = 0;

    for (final line in lines) {
      final parts = line
          .split(RegExp(r'[,\s]+'))
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList();

      if (parts.length < 2) {
        return null;
      }

      final price = double.tryParse(parts[0]);
      final lots = double.tryParse(parts[1]);
      if (price == null || lots == null || price <= 0 || lots <= 0) {
        return null;
      }

      totalLots += lots;
      totalAmount += price * lots;
    }

    if (totalLots <= 0) {
      return null;
    }

    return _BatchCostResult(
      averagePrice: totalAmount / totalLots,
      totalLots: totalLots,
    );
  }

  _ExitSignal _evaluateExitSignal(StockModel stock, int score) {
    if (!_enableExitSignal) {
      return const _ExitSignal(
        label: '?��??�出?��???,
        type: _ExitSignalType.neutral,
      );
    }

    final pnlPercent =
        _calculatePnlPercent(stock, _entryPriceByCode[stock.code]);

    if (pnlPercent == null) {
      _peakPnlPercentByCode.remove(stock.code);
    } else {
      final peak = _peakPnlPercentByCode[stock.code] ?? pnlPercent;
      if (pnlPercent > peak) {
        _peakPnlPercentByCode[stock.code] = pnlPercent;
      } else {
        _peakPnlPercentByCode[stock.code] = peak;
      }
    }

    if (pnlPercent != null && pnlPercent <= -_stopLossPercent) {
      return _ExitSignal(
        label: '?��?警示 ${pnlPercent.toStringAsFixed(1)}%',
        type: _ExitSignalType.danger,
      );
    }

    final adaptiveTakeProfit = _adaptiveTakeProfitThreshold(stock);
    if (pnlPercent != null && pnlPercent >= adaptiveTakeProfit) {
      if (_enableTrailingStop) {
        final effectivePullbackPercent = _effectiveTrailingPullbackPercent();
        final peak = _peakPnlPercentByCode[stock.code] ?? pnlPercent;
        final pullback = peak - pnlPercent;
        if (peak >= adaptiveTakeProfit &&
            pullback >= effectivePullbackPercent) {
          return _ExitSignal(
            label: '移�??�利?�場 ${pullback.toStringAsFixed(1)}%',
            type: _ExitSignalType.profit,
          );
        }
        return _ExitSignal(
          label: '移�??�利??�� 峰�?{peak.toStringAsFixed(1)}%',
          type: _ExitSignalType.hold,
        );
      }
      return _ExitSignal(
        label:
            '?�批?�利 +${pnlPercent.toStringAsFixed(1)}%（目�?${adaptiveTakeProfit.toStringAsFixed(1)}%�?,
        type: _ExitSignalType.profit,
      );
    }

    if (_excludeOverheated && stock.change >= _maxChaseChangePercent) {
      return const _ExitSignal(label: '追�?風險', type: _ExitSignalType.caution);
    }

    if (score < _effectiveMinScoreThreshold(stock)) {
      return const _ExitSignal(label: '轉弱觀�?, type: _ExitSignalType.caution);
    }

    if (pnlPercent == null) {
      return const _ExitSignal(
          label: '?��??��??�出?��?', type: _ExitSignalType.neutral);
    }

    return const _ExitSignal(label: '續抱觀�?, type: _ExitSignalType.hold);
  }

  _EntrySignal _evaluateEntrySignal(StockModel stock, int score) {
    if (!_enableStrategyFilter) {
      return _commitImmediateEntrySignal(
        stock.code,
        const _EntrySignal(
          label: '?��??�進場篩選',
          type: _EntrySignalType.neutral,
        ),
      );
    }

    if (_excludeOverheated && stock.change >= _maxChaseChangePercent) {
      return _commitImmediateEntrySignal(
        stock.code,
        const _EntrySignal(label: '?��?追�?', type: _EntrySignalType.avoid),
      );
    }

    if (_requireOpenConfirm && _isBeforeOpenConfirmTime()) {
      return _commitImmediateEntrySignal(
        stock.code,
        const _EntrySignal(
          label: '�?9:30後確�?,
          type: _EntrySignalType.wait,
        ),
      );
    }

    if (_isInStopLossCooldown(stock.code)) {
      final lastStopLoss = _lastStopLossTime(stock.code);
      final daysPassed = lastStopLoss == null
          ? 0
          : DateTime.now().difference(lastStopLoss).inDays;
      final remain = (_cooldownDays - daysPassed).clamp(1, _cooldownDays);
      return _commitImmediateEntrySignal(
        stock.code,
        _EntrySignal(
          label: '?��??�卻中�???$remain 天�?',
          type: _EntrySignalType.wait,
        ),
      );
    }

    if (!_passesBreakoutStage(stock, score)) {
      return _commitImmediateEntrySignal(
        stock.code,
        _EntrySignal(
          label: _breakoutStageRejectLabel(),
          type: _EntrySignalType.wait,
        ),
      );
    }

    if (!_passesRiskRewardPrefilter(stock)) {
      return _commitImmediateEntrySignal(
        stock.code,
        _EntrySignal(
          label:
              '風險?�酬不足�? ${(_minRiskRewardRatioX100 / 100).toStringAsFixed(2)}�?,
          type: _EntrySignalType.wait,
        ),
      );
    }

    if (!_passesMarketBreadthFilter()) {
      return _commitImmediateEntrySignal(
        stock.code,
        _EntrySignal(
          label:
              '市場寬度不足�? ${(_minMarketBreadthRatioX100 / 100).toStringAsFixed(2)}�?,
          type: _EntrySignalType.wait,
        ),
      );
    }

    if (_isLikelyFalseBreakout(stock, score)) {
      return _commitImmediateEntrySignal(
        stock.code,
        const _EntrySignal(
          label: '?�似?��???,
          type: _EntrySignalType.avoid,
        ),
      );
    }

    if (!_passesEventRiskExclusion(stock)) {
      return _commitImmediateEntrySignal(
        stock.code,
        const _EntrySignal(
          label: '事件風險?�除',
          type: _EntrySignalType.wait,
        ),
      );
    }

    final effectiveMinScore = _effectiveMinScoreThreshold(stock);
    final strongScoreThreshold =
        (effectiveMinScore + _strongScoreBuffer()).clamp(0, 100);
    final strongVolumeThreshold =
        (_latestVolumeReference * _strongVolumeMultiplier());
    final strongMinChange = _strongMinChangePercent();
    if (score >= strongScoreThreshold &&
        stock.change >= strongMinChange &&
        stock.volume >= strongVolumeThreshold) {
      return _applyEntrySignalHysteresis(
        stock.code,
        const _EntrySignal(label: '強勢?�場', type: _EntrySignalType.strong),
      );
    }

    if (score >= effectiveMinScore && stock.change > 0) {
      return _applyEntrySignalHysteresis(
        stock.code,
        const _EntrySignal(label: '觀察進場', type: _EntrySignalType.watch),
      );
    }

    return _applyEntrySignalHysteresis(
      stock.code,
      const _EntrySignal(label: '等�?訊�?', type: _EntrySignalType.wait),
    );
  }

  _EntrySignal _commitImmediateEntrySignal(String code, _EntrySignal signal) {
    _entrySignalTypeByCode[code] = signal.type;
    _entrySignalPendingCountByCode.remove(code);
    return signal;
  }

  _EntrySignal _applyEntrySignalHysteresis(
      String code, _EntrySignal nextSignal) {
    final previous = _entrySignalTypeByCode[code];
    if (previous == null) {
      return _commitImmediateEntrySignal(code, nextSignal);
    }

    if (previous == nextSignal.type) {
      _entrySignalPendingCountByCode.remove(code);
      return _commitImmediateEntrySignal(code, nextSignal);
    }

    const hysteresisTypes = <_EntrySignalType>{
      _EntrySignalType.strong,
      _EntrySignalType.watch,
      _EntrySignalType.wait,
    };
    if (!hysteresisTypes.contains(previous) ||
        !hysteresisTypes.contains(nextSignal.type)) {
      return _commitImmediateEntrySignal(code, nextSignal);
    }

    final pending = (_entrySignalPendingCountByCode[code] ?? 0) + 1;
    if (pending >= 2) {
      _entrySignalPendingCountByCode.remove(code);
      return _commitImmediateEntrySignal(code, nextSignal);
    }

    _entrySignalPendingCountByCode[code] = pending;
    return _EntrySignal(
      label: _entrySignalDefaultLabel(previous),
      type: previous,
    );
  }

  String _entrySignalDefaultLabel(_EntrySignalType type) {
    return switch (type) {
      _EntrySignalType.strong => '強勢?�場',
      _EntrySignalType.watch => '觀察進場',
      _EntrySignalType.wait => '等�?訊�?',
      _EntrySignalType.avoid => '?��?追�?',
      _EntrySignalType.neutral => '?��??�進場篩選',
    };
  }

  void _trimEntrySignalCaches(List<StockModel> stocks) {
    final activeCodes = stocks.map((item) => item.code).toSet();
    _entrySignalTypeByCode
        .removeWhere((code, _) => !activeCodes.contains(code));
    _entrySignalPendingCountByCode.removeWhere(
      (code, _) => !activeCodes.contains(code),
    );
  }

  void _syncRealtimeContextForRender({
    required List<StockModel> stocks,
    required double marketBreadthRatio,
    required _MarketRegime marketRegime,
    required int effectiveVolumeThreshold,
  }) {
    _latestMarketBreadthRatio = marketBreadthRatio;
    _currentRegime = marketRegime;
    _latestVolumeReference = effectiveVolumeThreshold.toDouble();

    if (_autoRegimeEnabled) {
      _rebuildSectorRegime(stocks);
    } else {
      _sectorRegimeByGroup.clear();
      _sectorStrengthByGroup.clear();
    }
  }

  int _strongScoreBuffer() {
    var buffer = switch (BreakoutMode) {
      BreakoutMode.confirmed => 12,
      BreakoutMode.early => 9,
      BreakoutMode.pullbackRebreak => 9,
      BreakoutMode.preEventPosition => 9,
      BreakoutMode.lowBaseTheme => 8,
      BreakoutMode.squeezeSetup => 7,
    };

    if (_currentRegime == _MarketRegime.bull) {
      buffer -= 2;
    } else if (_currentRegime == _MarketRegime.defensive) {
      buffer += 2;
    }

    if (_latestMarketBreadthRatio >= 1.25) {
      buffer -= 1;
    } else if (_latestMarketBreadthRatio < 1.0) {
      buffer += 1;
    }

    return buffer.clamp(5, 16);
  }

  double _strongVolumeMultiplier() {
    var multiplier = switch (BreakoutMode) {
      BreakoutMode.confirmed => 1.15,
      BreakoutMode.early => 1.05,
      BreakoutMode.pullbackRebreak => 1.05,
      BreakoutMode.preEventPosition => 1.0,
      BreakoutMode.lowBaseTheme => 0.95,
      BreakoutMode.squeezeSetup => 0.92,
    };

    if (_currentRegime == _MarketRegime.bull) {
      multiplier -= 0.05;
    } else if (_currentRegime == _MarketRegime.defensive) {
      multiplier += 0.05;
    }

    return multiplier.clamp(0.9, 1.2);
  }

  double _strongMinChangePercent() {
    return switch (BreakoutMode) {
      BreakoutMode.confirmed => 1.2,
      BreakoutMode.early => 0.8,
      BreakoutMode.pullbackRebreak => 0.6,
      BreakoutMode.preEventPosition => 0.5,
      BreakoutMode.lowBaseTheme => 0.3,
      BreakoutMode.squeezeSetup => 0.2,
    };
  }

  bool _isBeforeOpenConfirmTime() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes < (9 * 60 + 30);
  }



  
  _MarketTimingStatus _buildMarketTimingStatus() {
    final now = DateTime.now();
    final minutes = now.hour * 60 + now.minute;

    if (minutes < 9 * 60) {
      return const _MarketTimingStatus(
        label: '?��?觀�?,
        description: '尚未?�盤，�??�候選?�風?��??��?,
        type: _MarketTimingType.premarket,
      );
    }

    if (minutes < (9 * 60 + 30)) {
      if (_requireOpenConfirm) {
        return const _MarketTimingStatus(
          label: '?�盤確�???,
          description: '09:30 ?��?觀察�??��?追價??,
          type: _MarketTimingType.openConfirm,
        );
      }

      return const _MarketTimingStatus(
        label: '?�盤?�段',
        description: '已�???09:30 確�?，�??��?風險?��???,
        type: _MarketTimingType.openConfirm,
      );
    }

    if (minutes <= (13 * 60 + 30)) {
      return const _MarketTimingStatus(
        label: '?�確認進場',
        description: '?��?策略?�風?��?件確認進場??,
        type: _MarketTimingType.tradable,
      );
    }

    return const _MarketTimingStatus(
      label: '?�盤後檢�?,
      description: '?��??��?測�?調整?�日?�數??,
      type: _MarketTimingType.closed,
    );
  }

  _PremarketRisk _evaluatePremarketRisk(StockModel stock) {
    if (stock.change.abs() >= 7) {
      return const _PremarketRisk(
        label: '高波??,
        type: _PremarketRiskType.high,
      );
    }

    if (normalizedTradeValueForFilter(stock.tradeValue) <
        _minTradeValueThreshold) {
      return const _PremarketRisk(
        label: '?�能?�弱',
        type: _PremarketRiskType.medium,
      );
    }

    if (stock.change < -2) {
      return const _PremarketRisk(
        label: '?�弱?�盪',
        type: _PremarketRiskType.medium,
      );
    }

    return const _PremarketRisk(
      label: '風險?�控',
      type: _PremarketRiskType.low,
    );
  }

  bool _isLikelyOvernightGapRisk(StockModel stock) {
    if (!_enableOvernightGapRiskGuard) {
      return false;
    }
    if (!_isPostMarketOrNight()) {
      return false;
    }
    final risk = _evaluatePremarketRisk(stock);
    if (risk.type == _PremarketRiskType.high) {
      return true;
    }
    final hotMove = stock.change >= (_maxChaseChangePercent - 1);
    final weakLiquidity = normalizedTradeValueForFilter(stock.tradeValue) <
      (_minTradeValueThreshold * 1.1);
    return hotMove && weakLiquidity;
  }

  _EntryPlan _buildEntryPlan(StockModel stock, _EntrySignal signal) {
    final close = stock.closePrice;
    final conservativeFactor =
        signal.type == _EntrySignalType.strong ? 0.995 : 0.99;
    final aggressiveFactor =
        signal.type == _EntrySignalType.avoid ? 0.99 : 1.003;

    final conservativeEntry = close * conservativeFactor;
    final aggressiveEntry = close * aggressiveFactor;
    final avoidAbovePrice = close * (1 + (_maxChaseChangePercent / 100));
    final stopLossPrice = conservativeEntry * (1 - (_stopLossPercent / 100));
    final takeProfitPrice =
        conservativeEntry * (1 + (_takeProfitPercent / 100));

    return _EntryPlan(
      conservativeEntry: conservativeEntry,
      aggressiveEntry: aggressiveEntry,
      avoidAbovePrice: avoidAbovePrice,
      stopLossPrice: stopLossPrice,
      takeProfitPrice: takeProfitPrice,
    );
  }

  bool _passesBreakoutQuality(StockModel stock, int score) {
    if (!_enableBreakoutQuality) {
      return true;
    }
    if (!_passesChipConcentration(stock)) {
      return false;
    }
    final volumeRatio = _latestVolumeReference <= 0
        ? 0.0
        : stock.volume / _latestVolumeReference;
    final requiredRatio = _breakoutMinVolumeRatioPercent / 100;
    final secondaryRequiredRatio = computeSecondaryVolumeRatio(
      requiredRatio,
      strategyFilterEnabled: _enableStrategyFilter,
    );
    final passVolume = volumeRatio >= secondaryRequiredRatio;
    final passChange = stock.change >= 1.5;
    final passScore =
        score >= (_effectiveMinScoreThreshold(stock) + 3).clamp(0, 100);
    final passTradeValue =
      normalizedTradeValueForFilter(stock.tradeValue) >=
        _minTradeValueThreshold;
    return passVolume && passChange && passScore && passTradeValue;
  }

  double _marketBreadthRatio(List<StockModel> stocks) {
    if (stocks.isEmpty) {
      return 1.0;
    }
    final rising = stocks.where((stock) => stock.change > 0).length;
    final falling = stocks.where((stock) => stock.change < 0).length;
    if (falling == 0) {
      return rising > 0 ? 9.99 : 1.0;
    }
    return rising / falling;
  }

  bool _passesMarketBreadthFilter() {
    if (!_enableMarketBreadthFilter) {
      return true;
    }
    final minRatio = _minMarketBreadthRatioX100 / 100;
    return _latestMarketBreadthRatio >= minRatio;
  }

  bool _passesChipConcentration(StockModel stock) {
    if (!_enableChipConcentrationFilter) return true;
    return stock.chipConcentration >= _minChipConcentrationPercent;
  }

  bool _passesMasterTrap(StockModel stock) {
    if (!_enableMasterTrapFilter) return true;
    final prev = _previousChipConcentrationByCode[stock.code];
    if (prev == null) return true;
    return isMasterTrap(
      prevConcentration: prev,
      currConcentration: stock.chipConcentration,
      dropThresholdPercent: _masterTrapDropPercent,
    );
  }

  Future<void> _notifyMasterTrap(List<StockModel> stocks) async {
    if (!_enableMasterTrapFilter) return;
    for (final stock in stocks) {
      if (!_passesMasterTrap(stock)) {
        if (_masterTrapAlertedByCode[stock.code] == true) continue;
        await NotificationService.showAlert(
          id: 4000 + stock.code.hashCode.abs() % 900,
          title: '主�?誘�?警示 ${stock.code} ${stock.name}',
          body: '籌碼?�中度急�?，現??${stock.chipConcentration.toStringAsFixed(1)}%',
        );
        _masterTrapAlertedByCode[stock.code] = true;
      } else {
        _masterTrapAlertedByCode.remove(stock.code);
      }
    }
  }

  bool _isSameCalendarDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatCompactDateTime(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isGoogleBackupConnected() {
    return _googleBackupEmail != null && _googleBackupEmail!.isNotEmpty;
  }

  bool _isGoogleBackupFreshToday() {
    if (_lastGoogleBackupAt == null) {
      return false;
    }
    return _isSameCalendarDay(_lastGoogleBackupAt!, DateTime.now());
  }

  String _googleBackupStatusLabel() {
    if (!_isGoogleBackupConnected()) {
      return 'Google ?�份：未??��';
    }
    if (_lastGoogleBackupAt == null) {
      return 'Google ?�份：已??��，�??��?�?;
    }
    if (_isGoogleBackupFreshToday()) {
      return 'Google ?�份：�??�已?�份 ${_lastGoogleBackupAt!.hour.toString().padLeft(2, '0')}:${_lastGoogleBackupAt!.minute.toString().padLeft(2, '0')}';
    }
    return 'Google ?�份：�?�?${_formatCompactDateTime(_lastGoogleBackupAt!)}';
  }

  IconData _googleBackupStatusIcon() {
    if (!_isGoogleBackupConnected()) {
      return Icons.cloud_off;
    }
    if (_isGoogleBackupFreshToday()) {
      return Icons.cloud_done;
    }
    return Icons.cloud_sync;
  }

  void _refreshBreakoutStreakByCode(List<StockModel> stocks) {
    if (stocks.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastBreakoutStreakUpdatedAt != null &&
        _isSameCalendarDay(_lastBreakoutStreakUpdatedAt!, now)) {
      return;
    }

    // save previous concentrations before updating
    _previousChipConcentrationByCode.clear();
    for (final stock in stocks) {
      _previousChipConcentrationByCode[stock.code] = stock.chipConcentration;
    }

    final next = <String, int>{};
    for (final stock in stocks) {
      final score = _calculateStockScore(stock);
      final passToday = _passesBreakoutQuality(stock, score);
      final prev = _breakoutStreakByCode[stock.code] ?? 0;
      next[stock.code] = passToday ? prev + 1 : 0;
    }

    _breakoutStreakByCode
      ..clear()
      ..addAll(next);
    _lastBreakoutStreakUpdatedAt = now;
  }

  void _updateBreakoutStreakForCurrentFilters(List<StockModel> stocks) {
    if (stocks.isEmpty) {
      return;
    }

    _latestMarketBreadthRatio = _marketBreadthRatio(stocks);
    if (_autoRegimeEnabled) {
      _currentRegime = _detectMarketRegime(stocks);
      _rebuildSectorRegime(stocks);
    } else {
      _sectorRegimeByGroup.clear();
      _sectorStrengthByGroup.clear();
    }

    final riskSnapshot = _buildRiskSnapshot();
    final marketAverageVolume = _stableMarketAverageVolume(stocks);
    final effectiveVolumeThreshold = (_effectiveVolumeThresholdWithSnapshot(
              marketAverageVolume,
              riskSnapshot: riskSnapshot,
            ) *
            _regimeVolumeMultiplier())
        .round();
    _latestVolumeReference = effectiveVolumeThreshold.toDouble();

    _refreshBreakoutStreakByCode(stocks);
  }

  bool _passesMultiDayBreakout(StockModel stock, {int? score}) {
    if (!_enableMultiDayBreakout) {
      return true;
    }

    final streak = _breakoutStreakByCode[stock.code];
    if (streak == null) {
      if (_breakoutStreakByCode.isEmpty) {
        return true;
      }
      if (score != null) {
        return _passesBreakoutQuality(stock, score);
      }
      return true;
    }

    return streak >= _minBreakoutStreakDays;
  }

  BreakoutMode BreakoutModeFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return BreakoutMode.early;
    }
    return BreakoutMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => BreakoutMode.early,
    );
  }

  _MobileUiDensity _mobileUiDensityFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return _MobileUiDensity.comfortable;
    }
    return _MobileUiDensity.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => _MobileUiDensity.comfortable,
    );
  }

  String _mobileUiDensityLabel(_MobileUiDensity density) {
    return switch (density) {
      _MobileUiDensity.comfortable => '?�適',
      _MobileUiDensity.compact => '緊�?',
    };
  }

  _MobileTextScale _mobileTextScaleFromStorage(String? raw) {
    if (raw == null || raw.isEmpty) {
      return _MobileTextScale.medium;
    }
    return _MobileTextScale.values.firstWhere(
      (scale) => scale.name == raw,
      orElse: () => _MobileTextScale.medium,
    );
  }

  String _mobileTextScaleLabel(_MobileTextScale scale) {
    return switch (scale) {
      _MobileTextScale.small => '�?,
      _MobileTextScale.medium => '�?,
      _MobileTextScale.large => '�?,
    };
  }

  String _formatTimeHHmm(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  double _mobileTextScaleFactor(_MobileTextScale scale) {
    return switch (scale) {
      _MobileTextScale.small => 0.92,
      _MobileTextScale.medium => 1.0,
      _MobileTextScale.large => 1.1,
    };
  }

  Map<String, String> _buildCandidateFilterContextSnapshot() {
    return <String, String>{
      'strategy': _enableStrategyFilter ? '1' : '0',
      'score': _enableScoring ? '1' : '0',
      'onlyRising': _onlyRising ? '1' : '0',
      'excludeOverheated': _excludeOverheated ? '1' : '0',
      'maxChase': _maxChaseChangePercent.toString(),
      'minScore': _minScoreThreshold.toString(),
      'breakoutMode': BreakoutMode.name,
      'eventWindowEnabled': _enableEventCalendarWindow ? '1' : '0',
      'eventWindowDays': _eventCalendarGuardDays.toString(),
      'revenueEnabled': _enableRevenueMomentumFilter ? '1' : '0',
      'revenueMin': _minRevenueMomentumScore.toString(),
      'earningsEnabled': _enableEarningsSurpriseFilter ? '1' : '0',
      'earningsMin': _minEarningsSurpriseScore.toString(),
      'riskRewardEnabled': _enableRiskRewardPrefilter ? '1' : '0',
      'riskRewardMin': _minRiskRewardRatioX100.toString(),
      'breadthEnabled': _enableMarketBreadthFilter ? '1' : '0',
      'breadthMin': _minMarketBreadthRatioX100.toString(),
      'sectorCapEnabled': _enableSectorExposureCap ? '1' : '0',
      'sectorCap': _maxHoldingPerSector.toString(),
    };
  }

  List<String> _candidateFilterContextDiffLabels({
    required Map<String, String> previous,
    required Map<String, String> current,
  }) {
    String? labelFor(String key) {
      return switch (key) {
        'strategy' => '?�用策略篩選',
        'score' => '?�用?��??��?',
        'onlyRising' => '?��?上漲',
        'excludeOverheated' => '?�除追�?風險',
        'maxChase' => '追�?漲�?上�?',
        'minScore' => '?�低�??��?�?,
        'breakoutMode' => '飆股篩選模�?',
        'eventWindowEnabled' => '事件窗�?�?,
        'eventWindowDays' => '事件窗天??,
        'revenueEnabled' => '?�收?�能?�濾',
        'revenueMin' => '?�收?�能?�數?��?,
        'earningsEnabled' => '財報 surprise ?�濾',
        'earningsMin' => '財報 surprise ?�數?��?,
        'riskRewardEnabled' => '風險?�酬?�置?�濾',
        'riskRewardMin' => '風險?�酬比�?�?,
        'breadthEnabled' => '市場寬度?�濾',
        'breadthMin' => '市場寬度?��?,
        'sectorCapEnabled' => '?�業?�中度�???,
        'sectorCap' => '?��??�業上�?',
        'concentrationWeight' => '籌碼權�?',
        'tradeValueWeight' => '?�交?��???,
        'enableMasterTrapFilter' => '主�?誘�??�濾',
        'masterTrapDropPercent' => '誘�?跌�??��?,
        _ => null,
      };
    }

    final labels = <String>[];
    for (final entry in current.entries) {
      final before = previous[entry.key];
      if (before == null || before == entry.value) {
        continue;
      }
      final label = labelFor(entry.key);
      if (label != null) {
        labels.add(label);
      }
    }
    return labels;
  }

  void _appendCandidateDriftRecord({
    required String type,
    required int addedCount,
    required int removedCount,
    required List<String> changedFilters,
  }) {
    _candidateDriftHistory.insert(
      0,
      _CandidateDriftRecord(
        timestamp: DateTime.now(),
        type: type,
        addedCount: addedCount,
        removedCount: removedCount,
        changedFilters: changedFilters,
      ),
    );
    if (_candidateDriftHistory.length > 20) {
      _candidateDriftHistory.removeRange(20, _candidateDriftHistory.length);
    }
  }

  String _candidateDriftHistoryLabel(_CandidateDriftRecord record) {
    final base =
        '${_formatTimeHHmm(record.timestamp)} ${record.type == 'reset' ? '?��??�置' : '?�單變�? +${record.addedCount}/-${record.removedCount}'}';
    if (record.changedFilters.isEmpty) {
      return base;
    }
    final tags = record.changedFilters.take(3).join('??);
    final more = record.changedFilters.length > 3
        ? ' +${record.changedFilters.length - 3}'
        : '';
    return '$base�?tags$more�?;
  }

  void _scheduleDiagnosticsSnapshotPersist() {
    if (_diagnosticSnapshotPersistScheduled) {
      return;
    }
    _diagnosticSnapshotPersistScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _diagnosticSnapshotPersistScheduled = false;
      await _savePreferences();
    });
  }

  Future<void> _restorePreviousCandidateFilterSnapshot() async {
    if (_lastCandidateFilterContextBeforeReset.isEmpty) {
      return;
    }

    bool boolValue(String key, bool fallback) {
      return _lastCandidateFilterContextBeforeReset[key] == '1'
          ? true
          : (_lastCandidateFilterContextBeforeReset[key] == '0'
              ? false
              : fallback);
    }

    int intValue(String key, int fallback) {
      return int.tryParse(_lastCandidateFilterContextBeforeReset[key] ?? '') ??
          fallback;
    }

    final modeRaw = _lastCandidateFilterContextBeforeReset['breakoutMode'];
    final restoredMode = BreakoutMode.values.firstWhere(
      (mode) => mode.name == modeRaw,
      orElse: () => BreakoutMode,
    );

    setState(() {
      _enableStrategyFilter = boolValue('strategy', _enableStrategyFilter);
      _enableScoring = boolValue('score', _enableScoring);
      if (!_enableScoring) {
        _showStrongOnly = false;
      }
      _onlyRising = boolValue('onlyRising', _onlyRising);
      _excludeOverheated = boolValue('excludeOverheated', _excludeOverheated);
      _maxChaseChangePercent = intValue('maxChase', _maxChaseChangePercent)
          .clamp(3, 10);
      _minScoreThreshold = intValue('minScore', _minScoreThreshold)
          .clamp(_minScore, _maxScore);
      BreakoutMode = restoredMode;
      _enableEventCalendarWindow =
          boolValue('eventWindowEnabled', _enableEventCalendarWindow);
      _eventCalendarGuardDays =
          intValue('eventWindowDays', _eventCalendarGuardDays).clamp(0, 3);
      _enableRevenueMomentumFilter =
          boolValue('revenueEnabled', _enableRevenueMomentumFilter);
      _minRevenueMomentumScore =
          intValue('revenueMin', _minRevenueMomentumScore).clamp(-3, 3);
      _enableEarningsSurpriseFilter =
          boolValue('earningsEnabled', _enableEarningsSurpriseFilter);
      _minEarningsSurpriseScore =
          intValue('earningsMin', _minEarningsSurpriseScore).clamp(-3, 3);
      _enableRiskRewardPrefilter =
          boolValue('riskRewardEnabled', _enableRiskRewardPrefilter);
      _minRiskRewardRatioX100 =
          intValue('riskRewardMin', _minRiskRewardRatioX100).clamp(100, 300);
      _enableMarketBreadthFilter =
          boolValue('breadthEnabled', _enableMarketBreadthFilter);
      _minMarketBreadthRatioX100 =
          intValue('breadthMin', _minMarketBreadthRatioX100).clamp(80, 200);
      _enableSectorExposureCap =
          boolValue('sectorCapEnabled', _enableSectorExposureCap);
      _maxHoldingPerSector =
          intValue('sectorCap', _maxHoldingPerSector).clamp(1, 6);
    });

    await _savePreferences();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已�??��?次�?較�??�快??)),
    );
  }

  String BreakoutModeLabel(BreakoutMode mode) {
    return switch (mode) {
      BreakoutMode.early => '?��???,
      BreakoutMode.confirmed => '確�?突破',
      BreakoutMode.lowBaseTheme => '低基?��???,
      BreakoutMode.pullbackRebreak => '?��??�攻',
      BreakoutMode.squeezeSetup => '?�縮待噴',
      BreakoutMode.preEventPosition => '事件?�卡�?,
    };
  }

  IconData BreakoutModeIcon(BreakoutMode mode) {
    return switch (mode) {
      BreakoutMode.early => Icons.trending_up,
      BreakoutMode.confirmed => Icons.verified,
      BreakoutMode.lowBaseTheme => Icons.lightbulb,
      BreakoutMode.pullbackRebreak => Icons.replay,
      BreakoutMode.squeezeSetup => Icons.compress,
      BreakoutMode.preEventPosition => Icons.event,
    };
  }

  String _breakoutStageRejectLabel() {
    return switch (BreakoutMode) {
      BreakoutMode.early => '尚未?�入?��??��???,
      BreakoutMode.confirmed => '???突破不足�? $_minBreakoutStreakDays 天�?',
      BreakoutMode.lowBaseTheme => '?��?低基?��??��?�?,
      BreakoutMode.pullbackRebreak => '?��??��??�攻條件',
      BreakoutMode.squeezeSetup => '?��??�縮?��?待噴條件',
      BreakoutMode.preEventPosition => '?��?事件?�卡位�?�?,
    };
  }

  bool _hasThemeNewsSupport(StockModel stock) {
    final snapshot = _marketNewsSnapshot;
    if (snapshot == null || snapshot.items.isEmpty) {
      return false;
    }
    final keywords = <String>[
      '題�?',
      '?��?',
      '?��?',
      'AI',
      '?��?',
      '補助',
      '訂單',
      '轉單',
      '?�收',
      '法說'
    ];
    for (final item in snapshot.items.take(30)) {
      final title = item.title;
      final hitStock = title.contains(stock.code) || title.contains(stock.name);
      final hitTheme = keywords.any((keyword) => title.contains(keyword));
      if (hitStock && hitTheme) {
        return true;
      }
    }
    return false;
  }

  bool _hasEventCatalystNewsSupport(StockModel stock) {
    final snapshot = _marketNewsSnapshot;
    if (snapshot == null || snapshot.items.isEmpty) {
      return false;
    }
    final keywords = <String>['財報', '法說', '?�收', '?��?', '訂單', '轉單', '展�?', '?��?'];
    for (final item in snapshot.items.take(30)) {
      final title = item.title;
      final hitStock = title.contains(stock.code) || title.contains(stock.name);
      final hitKeyword = keywords.any((keyword) => title.contains(keyword));
      if (hitStock && hitKeyword) {
        return true;
      }
    }
    return false;
  }

  List<MarketNewsItem> _newsItemsForStock(
    StockModel stock, {
    int limit = 30,
  }) {
    final snapshot = _marketNewsSnapshot;
    if (snapshot == null || snapshot.items.isEmpty) {
      return const <MarketNewsItem>[];
    }

    return snapshot.items
        .where(
          (item) =>
              item.title.contains(stock.code) ||
              item.title.contains(stock.name),
        )
        .take(limit)
        .toList();
  }

  int? _daysToNearestEventWindow(StockModel stock) {
    if (!_enableEventCalendarWindow) {
      return null;
    }

    final eventKeywords = <String>['法說', '法說??, '財報', '法說?��?', '業績?�表'];
    final items = _newsItemsForStock(stock, limit: 25)
        .where((item) => eventKeywords.any((k) => item.title.contains(k)))
        .toList();
    if (items.isEmpty) {
      return null;
    }

    final now = DateTime.now();
    int? best;

    for (final item in items) {
      final title = item.title;
      final withYear =
          RegExp(r'(20\d{2})[\/-](\d{1,2})[\/-](\d{1,2})').firstMatch(title);
      final noYear = RegExp(r'(\d{1,2})[\/-](\d{1,2})').firstMatch(title);

      DateTime? eventDate;
      if (withYear != null) {
        final year = int.tryParse(withYear.group(1)!);
        final month = int.tryParse(withYear.group(2)!);
        final day = int.tryParse(withYear.group(3)!);
        if (year != null && month != null && day != null) {
          eventDate = DateTime(year, month, day);
        }
      } else if (noYear != null) {
        final month = int.tryParse(noYear.group(1)!);
        final day = int.tryParse(noYear.group(2)!);
        if (month != null && day != null) {
          var year = now.year;
          var candidate = DateTime(year, month, day);
          if (candidate.difference(now).inDays < -120) {
            candidate = DateTime(year + 1, month, day);
          }
          eventDate = candidate;
        }
      }

      if (eventDate == null) {
        final published = item.publishedAt;
        if (published != null) {
          final fallbackDays = now.difference(published).inDays;
          if (fallbackDays.abs() <= 3) {
            final days = -fallbackDays;
            if (best == null || days.abs() < best.abs()) {
              best = days;
            }
          }
        }
        continue;
      }

      final days =
          eventDate.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (best == null || days.abs() < best.abs()) {
        best = days;
      }
    }

    return best;
  }

  int _extractPercentSignal(String title, String prefix) {
    final direct =
        RegExp('$prefix\\s*([+-]?\\d+(?:\\.\\d+)?)%').firstMatch(title);
    if (direct != null) {
      final value = double.tryParse(direct.group(1) ?? '');
      if (value != null) {
        return value.round();
      }
    }
    return 0;
  }

  int _revenueMomentumScore(StockModel stock) {
    if (!_enableRevenueMomentumFilter) {
      return 0;
    }

    final items = _newsItemsForStock(stock, limit: 20)
        .where((item) => item.title.contains('?�收'))
        .toList();
    if (items.isEmpty) {
      return 0;
    }

    var score = 0;
    for (final item in items) {
      final title = item.title;
      if (title.contains('?��?') || title.contains('?��?')) {
        score += 2;
      }
      if (title.contains('年�?') || title.contains('?��?')) {
        score -= 1;
      }
      if (title.contains('衰退') || title.contains('下�?')) {
        score -= 2;
      }

      final yoy = _extractPercentSignal(title, '年�?');
      final mom = _extractPercentSignal(title, '?��?');
      score += yoy >= 15 ? 2 : (yoy > 0 ? 1 : 0);
      score += mom >= 10 ? 1 : (mom > 0 ? 1 : 0);
    }

    return score.clamp(-5, 5);
  }

  int _earningsSurpriseScore(StockModel stock) {
    if (!_enableEarningsSurpriseFilter) {
      return 0;
    }

    final items = _newsItemsForStock(stock, limit: 20)
        .where((item) =>
            item.title.contains('財報') ||
            item.title.contains('EPS') ||
            item.title.contains('每股?��?') ||
            item.title.contains('法說'))
        .toList();
    if (items.isEmpty) {
      return 0;
    }

    var score = 0;
    for (final item in items) {
      final title = item.title;
      if (title.contains('?�於?��?') ||
          title.contains('超�???) ||
          title.contains('上修') ||
          title.contains('轉�?')) {
        score += 2;
      }
      if (title.contains('低於?��?') ||
          title.contains('不�??��?') ||
          title.contains('下修') ||
          title.contains('轉虧') ||
          title.contains('?��?')) {
        score -= 2;
      }
    }

    return score.clamp(-5, 5);
  }

  bool _passesBreakoutStage(StockModel stock, int score) {
    // Evaluate using the unified BreakoutFilterService
    return BreakoutFilterService.evaluateAllModes(
      stock,
      score,
      latestVolumeReference: _latestVolumeReference,
      minTradeValueThreshold: _minTradeValueThreshold,
      minScoreThreshold: _minScoreThreshold,
      maxChaseChangePercent: _maxChaseChangePercent,
      minPriceThreshold: _maxPriceThreshold,
      enableBreakoutQuality: _enableBreakoutQuality,
      enableMultiDayBreakout: _enableMultiDayBreakout,
      breakoutStreakByCode: _breakoutStreakByCode,
      minBreakoutStreakDays: _minBreakoutStreakDays,
      hasThemeNewsSupport: _hasThemeNewsSupport,
      hasEventCatalystSupport: _hasEventCatalystNewsSupport,
      passesChipConcentration: _passesChipConcentration,
      breakoutMinVolumeRatioPercent: _breakoutMinVolumeRatioPercent,
      computeSecondaryVolumeRatio: computeSecondaryVolumeRatio,
      enableStrategyFilter: _enableStrategyFilter,
      normalizeTradeValue: normalizedTradeValueForFilter,
    )[BreakoutMode] ?? false;
  }

  bool _passesBreakoutStageByMode(
    BreakoutMode mode,
    StockModel stock,
    int score,
  ) {
    // Delegate to BreakoutFilterService
    return BreakoutFilterService.evaluateAllModes(
      stock,
      score,
      latestVolumeReference: _latestVolumeReference,
      minTradeValueThreshold: _minTradeValueThreshold,
      minScoreThreshold: _minScoreThreshold,
      maxChaseChangePercent: _maxChaseChangePercent,
      minPriceThreshold: _maxPriceThreshold,
      enableBreakoutQuality: _enableBreakoutQuality,
      enableMultiDayBreakout: _enableMultiDayBreakout,
      breakoutStreakByCode: _breakoutStreakByCode,
      minBreakoutStreakDays: _minBreakoutStreakDays,
      hasThemeNewsSupport: _hasThemeNewsSupport,
      hasEventCatalystSupport: _hasEventCatalystNewsSupport,
      passesChipConcentration: _passesChipConcentration,
      breakoutMinVolumeRatioPercent: _breakoutMinVolumeRatioPercent,
      computeSecondaryVolumeRatio: computeSecondaryVolumeRatio,
      enableStrategyFilter: _enableStrategyFilter,
      normalizeTradeValue: normalizedTradeValueForFilter,
    )[mode] ?? false;
  }

  List<BreakoutMode> _matchedBreakoutModesForStock(
    StockModel stock,
    int score,
  ) {
    // Use BreakoutFilterService to get all matched modes
    return BreakoutFilterService.getMatchedModes(
      stock,
      score,
      latestVolumeReference: _latestVolumeReference,
      minTradeValueThreshold: _minTradeValueThreshold,
      minScoreThreshold: _minScoreThreshold,
      maxChaseChangePercent: _maxChaseChangePercent,
      minPriceThreshold: _maxPriceThreshold,
      enableBreakoutQuality: _enableBreakoutQuality,
      enableMultiDayBreakout: _enableMultiDayBreakout,
      breakoutStreakByCode: _breakoutStreakByCode,
      minBreakoutStreakDays: _minBreakoutStreakDays,
      hasThemeNewsSupport: _hasThemeNewsSupport,
      hasEventCatalystSupport: _hasEventCatalystNewsSupport,
      passesChipConcentration: _passesChipConcentration,
      breakoutMinVolumeRatioPercent: _breakoutMinVolumeRatioPercent,
      computeSecondaryVolumeRatio: computeSecondaryVolumeRatio,
      enableStrategyFilter: _enableStrategyFilter,
      normalizeTradeValue: normalizedTradeValueForFilter,
    );
  }

/// Diagnostic helper: prints detailed breakout-stage checks for a stock.
/// Intended for developer use only.
void diagnoseStock(StockModel stock, int score) {
  debugPrint('--- Diagnose ${stock.code} ${stock.name} ---');
  debugPrint('closePrice=${stock.closePrice} change%=${stock.change.toStringAsFixed(2)} volume=${stock.volume} tradeValue=${stock.tradeValue}');
  debugPrint('foreign=${stock.foreignNet} trust=${stock.trustNet} dealer=${stock.dealerNet} marginDiff=${stock.marginBalanceDiff}');

  final effectiveMinScore = _effectiveMinScoreThreshold(stock);
  debugPrint('effectiveMinScore=$effectiveMinScore providedScore=$score');

  final volumeReference = _latestVolumeReference <= 0 ? 0.0 : _latestVolumeReference;
  final volumeRatio = volumeReference <= 0 ? 0.0 : stock.volume / volumeReference;
  debugPrint('volumeReference=$volumeReference volumeRatio=${volumeRatio.toStringAsFixed(3)}');

  for (final mode in BreakoutMode.values) {
    final passes = _passesBreakoutStageByMode(mode, stock, score);
    debugPrint('mode=${mode.toString().split('.').last} => ${passes ? 'PASS' : 'FAIL'}');
  }

  final matched = _matchedBreakoutModesForStock(stock, score);
  debugPrint('matchedModes=${matched.map((m) => m.toString().split('.').last).join(', ')}');

  final isFalse = _isLikelyFalseBreakout(stock, score);
  debugPrint('likelyFalseBreakout=${isFalse}');

  final eventOk = _passesEventRiskExclusion(stock);
  debugPrint('eventRiskExcluded=${!eventOk} (passesEventRiskExclusion=$eventOk)');

  debugPrint('--- End diagnose ---');
}

  bool _isLikelyFalseBreakout(StockModel stock, int score) {
    if (!_enableFalseBreakoutProtection) {
      return false;
    }

    final volumeRatio = _latestVolumeReference <= 0
        ? 0.0
        : stock.volume / _latestVolumeReference;
    final veryHighChange = stock.change >= (_maxChaseChangePercent + 1);
    final weakFollowThrough = stock.change >= 3.0 && volumeRatio < 1.1;
    final weakScoreJump =
        stock.change >= 2.5 && score < (_minScoreThreshold + 5);
    return veryHighChange || weakFollowThrough || weakScoreJump;
  }

  bool _passesEventRiskExclusion(StockModel stock) {
    if (!_enableEventRiskExclusion) {
      return true;
    }
    if (BreakoutMode == BreakoutMode.preEventPosition) {
      return true;
    }
    final snapshot = _marketNewsSnapshot;
    if (snapshot == null || snapshot.items.isEmpty) {
      return true;
    }

    final riskKeywords = <String>['財報', '法說', '?��???, '增�?', '減�?', '?��?'];
    for (final item in snapshot.items.take(20)) {
      final title = item.title;
      final hitStock = title.contains(stock.code) || title.contains(stock.name);
      final hitRisk = riskKeywords.any((keyword) => title.contains(keyword));
      if (hitStock && hitRisk) {
        return false;
      }
    }
    return true;
  }

  bool _isPostMarketOrNight([DateTime? value]) {
    final now = value ?? DateTime.now();
    final minutes = now.hour * 60 + now.minute;
    return minutes < 9 * 60 || minutes > (13 * 60 + 30);
  }

  bool _isTradingDayMorningWindow([DateTime? value]) {
    final now = value ?? DateTime.now();
    if (now.weekday == DateTime.saturday || now.weekday == DateTime.sunday) {
      return false;
    }
    final minutes = now.hour * 60 + now.minute;
    return minutes >= (8 * 60) && minutes <= (10 * 60 + 30);
  }

  _ModeRecommendation _buildModeRecommendationForContext({
    required _MarketRegime regime,
    required double breadth,
    required NewsRiskLevel? newsLevel,
    required bool isNightSession,
  }) {
    if (isNightSession) {
      if (newsLevel == NewsRiskLevel.medium ||
          newsLevel == NewsRiskLevel.high) {
        return _ModeRecommendation(
          mode: BreakoutMode.preEventPosition,
          reason: '?��??�盤�?夜�?，�??��??�度較�?，建議用事件?�卡位�??�日觀察�??��?,
        );
      }
      if (regime == _MarketRegime.defensive || breadth < 1.0) {
        return _ModeRecommendation(
          mode: BreakoutMode.squeezeSetup,
          reason:
              '?��??�盤�?夜�?，�??��?弱�?寬度 ${breadth.toStringAsFixed(2)}）�?建議?�以?�縮待噴?��?風險?�選??,
        );
      }
      return _ModeRecommendation(
        mode: BreakoutMode.confirmed,
        reason: '?��??�盤�?夜�?，建議以確�?突破模�?規�??�日?�場，�?低�?夜�?訊�?,
      );
    }

    if (regime == _MarketRegime.defensive || breadth < 0.95) {
      return _ModeRecommendation(
        mode: BreakoutMode.squeezeSetup,
        reason: '?�勢?�防守�?寬度 ${breadth.toStringAsFixed(2)}）�??�用?�縮待噴?��?追�?風險??,
      );
    }

    if (regime == _MarketRegime.bull && breadth >= 1.25) {
      return _ModeRecommendation(
        mode: BreakoutMode.early,
        reason: '?�勢?��?且寬度強�?{breadth.toStringAsFixed(2)}）�??�用?��??�搶第�?段�?,
      );
    }

    if (regime == _MarketRegime.bull && breadth >= 1.05) {
      return _ModeRecommendation(
        mode: BreakoutMode.pullbackRebreak,
        reason: '多頭延�?但�?極強，�?檔�??�可?�顧?��??�入?��??��?,
      );
    }

    if (newsLevel == NewsRiskLevel.medium && breadth >= 1.0) {
      return const _ModeRecommendation(
        mode: BreakoutMode.preEventPosition,
        reason: '?��??�度?�溫但未?�極端�??�用事件?�卡位�??�試?��?,
      );
    }

    if (regime == _MarketRegime.range && breadth >= 1.0) {
      return _ModeRecommendation(
        mode: BreakoutMode.confirmed,
        reason: '?�整市以確�?突破?�濾?��?，避?��?突破??,
      );
    }

    return const _ModeRecommendation(
      mode: BreakoutMode.lowBaseTheme,
      reason: '輪�??�快?��?低基?��??�模式通常較容?�找?��?漲股??,
    );
  }

  double _riskRewardRatioForStock(StockModel stock) {
    if (_stopLossPercent <= 0) {
      return 0;
    }
    final adaptiveTakeProfit = _adaptiveTakeProfitThreshold(stock);
    return adaptiveTakeProfit / _stopLossPercent;
  }

  bool _passesRiskRewardPrefilter(StockModel stock) {
    if (!_enableRiskRewardPrefilter) {
      return true;
    }
    final ratio = _riskRewardRatioForStock(stock);
    return ratio >= (_minRiskRewardRatioX100 / 100);
  }

  Future<void> _maybeRunWeeklyAutoTune(List<StockModel> stocks) async {
    if (!_enableWeeklyWalkForwardAutoTune || stocks.isEmpty) {
      return;
    }

    final now = DateTime.now();
    if (_lastWeeklyAutoTuneAt != null &&
        now.difference(_lastWeeklyAutoTuneAt!).inDays < 7) {
      return;
    }

    final candidates = List<StockModel>.from(stocks)
      ..sort(
        (a, b) => normalizedTradeValueForFilter(
          b.tradeValue,
        ).compareTo(
          normalizedTradeValueForFilter(a.tradeValue),
        ),
      );
    final targets = candidates.take(3).toList();

    final scoreByParam = <String, List<double>>{};
    final avgPnlSamples = <double>[];
    final tunedSymbols = <String>[];

    for (final target in targets) {
      try {
        final result = await _backtestService.runWalkForwardBacktest(
          stockCode: target.code,
          months: 10,
          minVolume: _surgeVolumeThreshold,
          minTradeValue: _minTradeValueThreshold,
          stopLossCandidates: const <int>[4, 5, 6, 7],
          takeProfitCandidates: const <int>[8, 10, 12, 14],
          enableTrailingStop: _enableTrailingStop,
          trailingPullbackPercent: _trailingPullbackPercent,
          enableAdaptiveAtr: _enableAdaptiveAtrExit,
          atrTakeProfitMultiplier: _atrTakeProfitMultiplier,
          feeBps: 14,
          slippageBps: 10,
          trainMonths: 4,
          validationMonths: 1,
        );

        if (result.windows.isEmpty) {
          continue;
        }

        tunedSymbols.add(target.code);
        avgPnlSamples.add(result.averagePnlPercent);
        for (final window in result.windows) {
          final key = '${window.stopLossPercent}-${window.takeProfitPercent}';
          scoreByParam.putIfAbsent(key, () => <double>[]).add(
                window.result.totalPnlPercent,
              );
        }
      } catch (_) {}
    }

    if (scoreByParam.isEmpty || avgPnlSamples.isEmpty) {
      return;
    }

    var bestKey = scoreByParam.keys.first;
    var bestAvg = -9999.0;
    scoreByParam.forEach((key, values) {
      final avg =
          values.fold<double>(0.0, (sum, value) => sum + value) / values.length;
      if (avg > bestAvg) {
        bestAvg = avg;
        bestKey = key;
      }
    });

    final parts = bestKey.split('-');
    final tunedStopLoss = int.tryParse(parts.first) ?? _stopLossPercent;
    final tunedTakeProfit = int.tryParse(parts.last) ?? _takeProfitPercent;
    final avgPnlAcrossTargets =
        avgPnlSamples.fold<double>(0.0, (sum, value) => sum + value) /
            avgPnlSamples.length;
    final tunedMinScore = (_minScoreThreshold +
            (avgPnlAcrossTargets < 0
                ? 3
                : avgPnlAcrossTargets > 3
                    ? -2
                    : 0))
        .clamp(_minScore, _maxScore);

    if (!mounted) {
      return;
    }

    setState(() {
      _stopLossPercent = tunedStopLoss;
      _takeProfitPercent = tunedTakeProfit;
      _minScoreThreshold = tunedMinScore;
      _lastWeeklyAutoTuneAt = now;
    });
    await _savePreferences();

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '每週自?�微調�??��?${tunedSymbols.join('/')}）�??��? -$tunedStopLoss% / ?�利 +$tunedTakeProfit% / ?�低�? $tunedMinScore',
        ),
      ),
    );
  }

  double? _calculateSuggestedLots({
    required double riskBudget,
    required double entryPrice,
    required double stopLossPrice,
  }) {
    final riskPerShare = entryPrice - stopLossPrice;
    if (riskBudget <= 0 || riskPerShare <= 0) {
      return null;
    }

    final lots = riskBudget / (riskPerShare * 1000);
    if (lots <= 0) {
      return null;
    }

    return lots;
  }

  double _newsRiskBudgetMultiplier() {
    if (!_autoDefensiveOnHighNewsRisk) {
      return 1.0;
    }

    final level = _marketNewsSnapshot?.level;
    if (level == NewsRiskLevel.high) {
      return 0.5;
    }
    if (level == NewsRiskLevel.medium) {
      return 0.8;
    }
    return 1.0;
  }

  double _lossStreakBudgetMultiplier() {
    final streak = _autoLossStreakFromJournal();
    if (streak >= 4) {
      return 0.4;
    }
    if (streak >= 3) {
      return 0.6;
    }
    if (streak >= 2) {
      return 0.8;
    }
    return 1.0;
  }

  Future<void> _openPositionSizingDialog(
    StockModel stock,
    _EntryPlan entryPlan,
  ) async {
    final riskController = TextEditingController(
      text: _riskBudgetPerTrade.toString(),
    );
    final entryController = TextEditingController(
      text: entryPlan.conservativeEntry.toStringAsFixed(2),
    );
    final stopController = TextEditingController(
      text: entryPlan.stopLossPrice.toStringAsFixed(2),
    );
    double? calculatedLots;
    double? calculatedEntry;
    String resultText = '';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('?��?計�? - ${stock.code} ${stock.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: riskController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '?��??�大可?��??��?（�?�?,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: entryController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '?��??�場??),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stopController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '?��???),
                  ),
                  const SizedBox(height: 12),
                  if (resultText.isNotEmpty)
                    Text(
                      resultText,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('?��?'),
                ),
                TextButton(
                  onPressed: calculatedLots == null || calculatedEntry == null
                      ? null
                      : () async {
                          setState(() {
                            _entryPriceByCode[stock.code] = calculatedEntry!;
                            _positionLotsByCode[stock.code] = calculatedLots!;
                          });
                          await _savePreferences();
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '已�???${stock.code} ?�本 ${calculatedEntry!.toStringAsFixed(2)} / 張數 ${calculatedLots!.toStringAsFixed(calculatedLots! % 1 == 0 ? 0 : 2)}',
                              ),
                            ),
                          );
                        },
                  child: const Text('套用?��???),
                ),
                FilledButton(
                  onPressed: () {
                    final riskBudget =
                        double.tryParse(riskController.text.trim());
                    final entry = double.tryParse(entryController.text.trim());
                    final stop = double.tryParse(stopController.text.trim());

                    if (riskBudget == null || entry == null || stop == null) {
                      setDialogState(() {
                        resultText = '請輸?�正確數�?;
                      });
                      return;
                    }

                    final newsRiskMultiplier = _newsRiskBudgetMultiplier();
                    final streakMultiplier = _lossStreakBudgetMultiplier();
                    final riskMultiplier =
                        newsRiskMultiplier * streakMultiplier;
                    final effectiveRiskBudget = riskBudget * riskMultiplier;
                    final lots = _calculateSuggestedLots(
                      riskBudget: effectiveRiskBudget,
                      entryPrice: entry,
                      stopLossPrice: stop,
                    );

                    if (lots == null) {
                      setDialogState(() {
                        resultText = '?��??��?小於?�場?��?且虧?��?額�?大於 0';
                      });
                      return;
                    }

                    final tierPercent = _scoreTierSizingPercent(stock);
                    final adjustedLots = lots * (tierPercent / 100);
                    final roundedLots =
                        double.parse(adjustedLots.toStringAsFixed(2));
                    final positionAmount = roundedLots * entry * 1000;

                    setDialogState(() {
                      calculatedLots = roundedLots;
                      calculatedEntry = entry;
                      resultText =
                          '建議張數：�? $roundedLots 張�??�數?��? ${tierPercent}%）\n?�估?�入：�? ${_formatCurrency(positionAmount)}\n每股風險�?{(entry - stop).toStringAsFixed(2)}\n?��?係數 x${newsRiskMultiplier.toStringAsFixed(2)} ? ??��係數 x${streakMultiplier.toStringAsFixed(2)} = x${riskMultiplier.toStringAsFixed(2)}（可?��??��? ${_formatCurrency(effectiveRiskBudget)}�?;
                    });

                    setState(() {
                      _riskBudgetPerTrade = riskBudget.round();
                    });
                    _savePreferences();
                  },
                  child: const Text('計�?'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _openBacktestPage() async {
    final tuning = await Navigator.of(context).push<BacktestTuningResult>(
      MaterialPageRoute(
        builder: (_) => BacktestPage(
          initialStopLoss: _stopLossPercent,
          initialTakeProfit: _takeProfitPercent,
          initialEnableTrailingStop: _enableTrailingStop,
          initialTrailingPullback: _trailingPullbackPercent,
        ),
      ),
    );
    await _applyBacktestTuningResult(tuning);
  }

  Future<void> _openGoogleBackupSheet() async {
    var localEnableDaily = _enableGoogleDailyBackup;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Google ?�端?�份',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _googleBackupEmail == null
                        ? '?��??��?�� Google 帳�?'
                        : '已�?���?_googleBackupEmail',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_lastGoogleBackupAt != null)
                    Text(
                      '?�近�?份�?${_lastGoogleBackupAt!.year}-${_lastGoogleBackupAt!.month.toString().padLeft(2, '0')}-${_lastGoogleBackupAt!.day.toString().padLeft(2, '0')} ${_lastGoogleBackupAt!.hour.toString().padLeft(2, '0')}:${_lastGoogleBackupAt!.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: localEnableDaily,
                    title: const Text('每日?��??�份（�???App ?�新?�觸?��?'),
                    onChanged: (value) {
                      setLocalState(() {
                        localEnableDaily = value;
                      });
                      setState(() {
                        _enableGoogleDailyBackup = value;
                      });
                      _savePreferences();
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _isGoogleBackupBusy
                            ? null
                            : () async {
                                final email = await _googleDriveBackupService
                                    .signInAndGetEmail();
                                if (!mounted) {
                                  return;
                                }
                                if (email == null) {
                                  _showGoogleSignInNullFeedback(
                                    fallback: 'Google ?�入?��?',
                                    showFeedback: true,
                                  );
                                  return;
                                }
                                setState(() {
                                  _googleBackupEmail = email;
                                });
                                await _savePreferences();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('已�?�� Google�?email�?)),
                                );
                              },
                        icon: const Icon(Icons.login),
                        label: const Text('??�� Google'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isGoogleBackupBusy
                            ? null
                            : () => _backupNowToGoogle(showFeedback: true),
                        icon: const Icon(Icons.cloud_upload),
                        label: const Text('立即?�份'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isGoogleBackupBusy
                            ? null
                            : _restoreFromGoogleBackup,
                        icon: const Icon(Icons.cloud_download),
                        label: const Text('?�端?��?'),
                      ),
                      TextButton.icon(
                        onPressed: _isGoogleBackupBusy
                            ? null
                            : () async {
                                await _googleDriveBackupService.signOut();
                                if (!mounted) {
                                  return;
                                }
                                setState(() {
                                  _googleBackupEmail = null;
                                });
                                await _savePreferences();
                              },
                        icon: const Icon(Icons.logout),
                        label: const Text('?�出'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openStockExclusionDiagnosticDialog({
    required List<StockModel> stocks,
    required Map<String, List<String>> dropReasonsByCode,
    required Set<String> strategyCodes,
    required Set<String> candidateCodes,
    required Set<String> qualityCodes,
    required Set<String> strongOnlyCodes,
    required Set<String> searchedCodes,
    required Set<String> limitedCodes,
    required Set<String> displayedCodes,
    String? initialQuery,
  }) async {
    final queryController = TextEditingController(text: initialQuery ?? '');
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          String diagnosis = '';
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void rememberQuery(String query) {
                final normalized = query.trim();
                if (normalized.isEmpty) {
                  return;
                }
                _recentDiagnosticQueries.remove(normalized);
                _recentDiagnosticQueries.insert(0, normalized);
                if (_recentDiagnosticQueries.length > 6) {
                  _recentDiagnosticQueries.removeRange(
                      6, _recentDiagnosticQueries.length);
                }
              }

              void runDiagnosis() {
                final query = queryController.text.trim();
                if (query.isEmpty) {
                  setDialogState(() {
                    diagnosis = '請輸?�股票代?��??�稱';
                  });
                  return;
                }

                rememberQuery(query);

                final lower = query.toLowerCase();
                StockModel? matched = stocks.firstWhere(
                  (stock) => stock.code.toLowerCase() == lower,
                  orElse: () => const StockModel(
                    code: '',
                    name: '',
                    closePrice: 0,
                    volume: 0,
                    tradeValue: 0,
                    change: 0,
                  ),
                );
                if (matched.code.isEmpty) {
                  matched = stocks.firstWhere(
                    (stock) =>
                        stock.code.toLowerCase().contains(lower) ||
                        stock.name.toLowerCase().contains(lower),
                    orElse: () => const StockModel(
                      code: '',
                      name: '',
                      closePrice: 0,
                      volume: 0,
                      tradeValue: 0,
                      change: 0,
                    ),
                  );
                }

                if (matched.code.isEmpty) {
                  setDialogState(() {
                    diagnosis = '?��??�符?��??�票';
                  });
                  return;
                }

                final reasons = <String>{
                  ...(dropReasonsByCode[matched.code] ?? const <String>[]),
                };
                final effectiveShowStrongOnly = _showStrongOnly && _enableScoring;
                if (effectiveShowStrongOnly &&
                    !strongOnlyCodes.contains(matched.code)) {
                  reasons.add('強勢?��?（�?強勢訊�?�?);
                }
                if (_searchKeyword.trim().isNotEmpty &&
                    !searchedCodes.contains(matched.code)) {
                  reasons.add('不符?�目?��?尋�??��?');
                }
                if (_limitTopCandidates &&
                    searchedCodes.contains(matched.code) &&
                    !limitedCodes.contains(matched.code)) {
                  reasons.add('超出??$_topCandidateLimit 檔�???);
                }
                if (_showOnlyFavorites &&
                    !_favoriteStockCodes.contains(matched.code)) {
                  reasons.add('?��??�收?�模式�?此�??�收?��?');
                }
                if (_showOnlyHoldings &&
                    !_positionLotsByCode.containsKey(matched.code) &&
                    !_entryPriceByCode.containsKey(matched.code)) {
                  reasons.add('?��??��??�模式�?此�??��??��?');
                }

                final inDisplay = displayedCodes.contains(matched.code);
                final stage = !strategyCodes.contains(matched.code)
                    ? '?��?條件?�段'
                    : (!candidateCodes.contains(matched.code)
                        ? '?�數?�檻�?�?
                        : (!qualityCodes.contains(matched.code)
                            ? '?��?/風險?�段'
                            : (inDisplay ? '已在?��?清單' : '後�?視�??�濾?�段')));

                final lines = <String>[
                  '${matched.code} ${matched.name}',
                  '?��??�段�?stage',
                ];
                if (inDisplay) {
                  lines.add('???��??��??�中');
                } else if (reasons.isEmpty) {
                  lines.add('?��? ?��??�顯示�?但無?�確?�除?��?（可?��??��?/?�制影響�?);
                } else {
                  lines.add('?�除?��?�?);
                  lines.addAll(reasons.map((reason) => '??$reason'));
                }

                setDialogState(() {
                  diagnosis = lines.join('\n');
                });
              }

              return AlertDialog(
                title: const Text('?��??�除診斷'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: queryController,
                        decoration: const InputDecoration(
                          labelText: '輸入�???��?稱�?例�?3576 ???��??��?�?,
                        ),
                        onSubmitted: (_) => runDiagnosis(),
                      ),
                      if (_searchKeyword.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              queryController.text = _searchKeyword.trim();
                              queryController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: queryController.text.length),
                              );
                              setDialogState(() {});
                            },
                            icon: const Icon(Icons.input),
                            label: Text('帶入?��??��?�?{_searchKeyword.trim()}'),
                          ),
                        ),
                      ],
                      if (_recentDiagnosticQueries.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '?�近查�?,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _recentDiagnosticQueries
                              .take(4)
                              .map(
                                (item) => ActionChip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(item),
                                  onPressed: () {
                                    queryController.text = item;
                                    queryController.selection =
                                        TextSelection.fromPosition(
                                      TextPosition(
                                          offset: queryController.text.length),
                                    );
                                    runDiagnosis();
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      const SizedBox(height: 10),
                      if (diagnosis.isNotEmpty)
                        Text(
                          diagnosis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('?��?'),
                  ),
                  FilledButton(
                    onPressed: runDiagnosis,
                    child: const Text('診斷'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      queryController.dispose();
    }
  }

  void _toggleShowOnlyFavorites() {
    setState(() {
      final next = !_showOnlyFavorites;
      _showOnlyFavorites = next;
      if (next) {
        _showOnlyHoldings = false;
      }
    });
    _savePreferences();
  }

  List<String> _buildBullishRationales({
    required StockModel stock,
    required int score,
    required _EntrySignal entrySignal,
    required int effectiveVolumeThreshold,
    required List<({String tag, int score})> topicStrengths,
    int? revenueMomentumScore,
    int? earningsSurpriseScore,
    int? nearestEventWindowDays,
  }) {
    final reasons = <String>[];
    final effectiveMinScore = _effectiveMinScoreThreshold(stock);
    final strongScoreThreshold =
        (effectiveMinScore + _strongScoreBuffer()).clamp(0, 100);
    final strongVolumeThreshold =
        (_latestVolumeReference * _strongVolumeMultiplier());
    final strongMinChange = _strongMinChangePercent();
    final sector = _sectorGroupForCode(stock.code);
    final matchedModes = _matchedBreakoutModesForStock(stock, score);
    final modeLabel = matchedModes.isEmpty
        ? BreakoutModeLabel(BreakoutMode)
        : BreakoutModeLabel(matchedModes.first);

    String modeNarrative(BreakoutMode mode) {
      return switch (mode) {
        BreakoutMode.early => '?��??�「�?突破?��??��??��??�是?�延�?,
        BreakoutMode.confirmed => '?��??�「確認�??�」�??��??��??��??�否站穩',
        BreakoutMode.lowBaseTheme => '?��??�「�??��?補漲?��??�常屬�??�輪?�接�?,
        BreakoutMode.pullbackRebreak => '?��??�「�?檔�??�」�??��??��?測�??�放??,
        BreakoutMode.squeezeSetup => '?��??�「�?縮�??�」�??��??�是?�放?�脫?�盤??,
        BreakoutMode.preEventPosition => '?��??�「�?件�??��??��??��??��?件�?資�??�否?��?',
      };
    }

    String sectorNarrative(String value) {
      if (value.contains('?��?')) {
        return '?��?屬�??��?常�??��?/?��??��??��??��??�影??;
      }
      if (value.contains('?��?') ||
          value.contains('?��?�?) ||
          value.contains('?��?')) {
        return '?��?屬�??�?�長，常?�AI/伺�????�氣循環帶�?';
      }
      if (value.contains('?�鐵')) {
        return '?��?屬景�?��?��?常�??�價?��??��??�格影響';
      }
      if (value.contains('食�?') || value.contains('塑�?')) {
        return '?��??��????�物?��?常�??�本?��?求�??�影??;
      }
      return '?��?資�??�輪?�跡象�?建議?��??�價?��??��?�?;
    }

    final topicNarrativeByTag = <String, String>{
      'AI': 'AI/算�?題�??�溫，�??��?好伺?�器?��?導�???,
      '低�?衛�?': '低�?衛�?題�??�溫，�??��?好網?��??��?設�???,
      '?��?': '?�疫/?��?題�??�溫，�??�可?��??��??�?��??�防?��?',
      '?�藥?��?': '?�藥/?��?題�??�溫，�??�可?��??��??�?�醫?��?',
      '軍工?�緣': '?�緣風險題�??�溫，�??�可?��??��?�?安控/資�???,
      '?��??�物??: '?��??��??��?題�??�溫，�??�可?��??��?游�??�代?��???,
      '供�???: '供�??��?組�??��?溫�?資�??�能流�??�代供�??�在?��???,
      '?��??��?': '?��?/?��?題�??�溫，�??��??��??��??�群較�??��?�?,
    };

    final topicSectorKeywords = <String, List<String>>{
      'AI': <String>['?��?', '?��?�?, '?��?'],
      '低�?衛�?': <String>['?��?', '?��?'],
      '?��?': <String>['食�?', '塑�?'],
      '?�藥?��?': <String>['食�?', '塑�?'],
      '軍工?�緣': <String>['?��?', '?��?'],
      '?��??�物??: <String>['食�?', '塑�?', '?�鐵'],
      '供�???: <String>['?�鐵', '?��?'],
      '?��??��?': <String>['?��?'],
    };

    switch (entrySignal.type) {
      case _EntrySignalType.strong:
        reasons.add(
          '?�術面：�???$score ?�強?��?�?${strongScoreThreshold.toStringAsFixed(0)}，�?漲�? ${stock.change.toStringAsFixed(2)}% ??${strongMinChange.toStringAsFixed(2)}%',
        );
        reasons.add(
          '?�價?��??�交??${_formatWithThousandsSeparator(stock.volume)} 高於強勢?��?�?${_formatWithThousandsSeparator(strongVolumeThreshold.round())}',
        );
        break;
      case _EntrySignalType.watch:
        reasons.add(
          '?�術面：�???$score 已�??��?察�?�?$effectiveMinScore，價?�維?��?漲�?${stock.change.toStringAsFixed(2)}%�?,
        );
        reasons.add('節奏面：目?��??��?觀察、�?延�??�而�?追價');
        break;
      case _EntrySignalType.wait:
        reasons.add('訊�??�?��??��??��?待�?建議等�??��?確�?後�??�場');
        break;
      case _EntrySignalType.avoid:
        reasons.add('訊�??�?��??��??�避?�追高�??��?風險?�溫較穩??);
        break;
      case _EntrySignalType.neutral:
        reasons.add('訊�??�?��??��??��??�進場篩選，建議�??�風?�控管設�?);
        break;
    }

    reasons.add(
      '?��??��?$modeLabel�?{modeNarrative(matchedModes.isEmpty ? BreakoutMode : matchedModes.first)}',
    );
    reasons.add(
      '?�本?��?：�??��?標�?${_formatWithThousandsSeparator(stock.volume)} ??${_formatWithThousandsSeparator(effectiveVolumeThreshold)}�?,
    );

    final sectorBonus = _sectorRotationBonus(stock);
    if (sectorBonus > 0) {
      reasons.add('?��??��?$sector（輪?��???+$sectorBonus）�?${sectorNarrative(sector)}');
    } else {
      reasons.add('?��??��?$sector�?{sectorNarrative(sector)}');
    }

    final matchedTopic = topicStrengths.firstWhere(
      (topic) {
        if (topic.score < 30) {
          return false;
        }
        final keywords = topicSectorKeywords[topic.tag] ?? const <String>[];
        return keywords.any((keyword) => sector.contains(keyword));
      },
      orElse: () => (tag: '', score: 0),
    );

    if (matchedTopic.tag.isNotEmpty) {
      reasons.add(
        '題�??��?${topicNarrativeByTag[matchedTopic.tag] ?? '主�?資�?輪�??�強'}�?{matchedTopic.tag} 強度 ${matchedTopic.score}�?,
      );
    } else {
      final topTopic =
          topicStrengths.isEmpty ? (tag: '', score: 0) : topicStrengths.first;
      if (topTopic.score >= 30) {
        reasons.add(
          '題�??��??��??�面主�??��?{topTopic.tag}?��?強度 ${topTopic.score}）�?但�?此股?�聯度普?��?建議保�??�批',
        );
      }
    }

    if (revenueMomentumScore != null) {
      final momentumText = revenueMomentumScore >= 2
          ? '?�強'
          : (revenueMomentumScore >= 0 ? '中�? : '?�弱');
      reasons.add('?�收?�能�?momentumText（�???$revenueMomentumScore�?);
    }

    if (earningsSurpriseScore != null) {
      final surpriseText = earningsSurpriseScore >= 2
          ? '?�正??
          : (earningsSurpriseScore >= 0 ? '中�? : '?��???);
      reasons.add('財報 surprise�?surpriseText（�???$earningsSurpriseScore�?);
    }

    if (nearestEventWindowDays != null) {
      final eventText = nearestEventWindowDays >= 0
          ? 'D-${nearestEventWindowDays.abs()}'
          : 'D+${nearestEventWindowDays.abs()}';
      reasons.add('法說/財報事件窗�?$eventText');
    }

    final deduped = <String>[];
    final seen = <String>{};
    for (final reason in reasons) {
      if (seen.add(reason)) {
        deduped.add(reason);
      }
    }
    return deduped.take(4).toList();
  }

  String _premarketRiskTypeLabel(_PremarketRiskType type) {
    return switch (type) {
      _PremarketRiskType.high => '�?,
      _PremarketRiskType.medium => '�?,
      _PremarketRiskType.low => '�?,
    };
  }

  String _decisionSummaryFor(
    _EntrySignalType signalType,
    _PremarketRiskType riskType,
  ) {
    final riskTail = switch (riskType) {
      _PremarketRiskType.high => '（盤?�風?��?，嚴?�倉�?�?,
      _PremarketRiskType.medium => '（盤?�風?�中，�??��?佳�?',
      _PremarketRiskType.low => '',
    };

    return switch (signalType) {
      _EntrySignalType.strong => '?��??�試??riskTail',
      _EntrySignalType.watch => '?��?察�?等�?強�???riskTail',
      _EntrySignalType.wait => '?��?訊�?確�?$riskTail',
      _EntrySignalType.avoid => '?�避?��?不追??riskTail',
      _EntrySignalType.neutral => '?��?風險設�??�決�?riskTail',
    };
  }

  Future<void> _openRiskReductionSuggestionsDialog({
    required List<
            ({
              String code,
              String name,
              double? lots,
              double? closePrice,
              double? entryPrice,
              _PremarketRiskType premarketRiskType,
              String decisionSummary,
            })>
        rows,
  }) async {
    final candidates = rows
        .where((row) =>
            (row.lots ?? 0) > 0 &&
            (row.premarketRiskType == _PremarketRiskType.high ||
                row.premarketRiskType == _PremarketRiskType.medium))
        .toList();

    if (candidates.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('?��?沒�??��?供�??�建議�?�?中風?��???)),
      );
      return;
    }

    double keepLotsOf(
      _PremarketRiskType riskType,
      double lots,
    ) {
      final ratio = switch (riskType) {
        _PremarketRiskType.high => 0.5,
        _PremarketRiskType.medium => 0.75,
        _PremarketRiskType.low => 1.0,
      };
      return double.parse((lots * ratio).toStringAsFixed(2));
    }

    double closeLotsOf(
      _PremarketRiskType riskType,
      double lots,
    ) {
      return double.parse(
          (lots - keepLotsOf(riskType, lots)).toStringAsFixed(2));
    }

    final totalCloseLots = candidates.fold<double>(0, (sum, row) {
      final lots = row.lots ?? 0;
      return sum + closeLotsOf(row.premarketRiskType, lots);
    });

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('�?中風?��??��??�建�?),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '建議規�?：�?風險保�? 50%?�中風險保�? 75%（�??�示，�??�自?�改?�庫存�?',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '建議?��??��?減碼 ${totalCloseLots.toStringAsFixed(totalCloseLots % 1 == 0 ? 0 : 2)} �?,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: candidates.map((row) {
                      final lots = row.lots ?? 0;
                      final keepLots = keepLotsOf(row.premarketRiskType, lots);
                      final closeLots =
                          closeLotsOf(row.premarketRiskType, lots);
                      final closeRatioText =
                          row.premarketRiskType == _PremarketRiskType.high
                              ? '50%'
                              : '25%';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('${row.code} ${row.name}'),
                        subtitle: Text(
                          '風險 ${_premarketRiskTypeLabel(row.premarketRiskType)}｜目??${lots.toStringAsFixed(lots % 1 == 0 ? 0 : 2)} 張�?建議?��?�?$closeRatioText（�? $closeLots 張�?保�? $keepLots 張�?\n'
                          '${row.entryPrice == null || row.closePrice == null ? '' : '?�本 ${row.entryPrice!.toStringAsFixed(2)} / ?�價 ${row.closePrice!.toStringAsFixed(2)}�?}${row.decisionSummary}',
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('?��?'),
            ),
          ],
        );
      },
    );
  }

  void _toggleShowOnlyHoldings() {
    setState(() {
      final next = !_showOnlyHoldings;
      _showOnlyHoldings = next;
      if (next) {
        _showOnlyFavorites = false;
      }
    });
    _savePreferences();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhoneLayout = screenWidth < 600;
    final isCompactPhone = screenWidth < 390;
    final compactDensity =
        isPhoneLayout && _mobileUiDensity == _MobileUiDensity.compact;
    final textScaleFactor =
      isPhoneLayout ? _mobileTextScaleFactor(_mobileTextScale) : 1.0;
    final densityFactor = compactDensity ? 0.85 : 1.0;
    final horizontalInset = isCompactPhone ? 12.0 : 16.0;
    final topGap = 10.0 * densityFactor;
    final sectionGap = 8.0 * densityFactor;
    final actionTopGap = 12.0 * densityFactor;
    final actionBottomGap = 4.0 * densityFactor;
    final stackedButtonGap = 8.0 * densityFactor;
    final emptyListTopPadding = 24.0 * densityFactor;
    final useCompactAppBarActions = isCompactPhone;

    return Scaffold(
      appBar: AppBar(
        title: const Text('?�股飆股?��?'),
        actions: useCompactAppBarActions
            ? [
                IconButton(
                  tooltip: '?�新?��?資�?',
                  onPressed: _refreshStocks,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Google ?�份',
                  onPressed: _openGoogleBackupSheet,
                  icon: const Icon(Icons.cloud_sync),
                ),
                PopupMenuButton<_CompactTopAction>(
                  tooltip: '?��??�能',
                  onSelected: (action) {
                    switch (action) {
                      case _CompactTopAction.backtest:
                        _openBacktestPage();
                      case _CompactTopAction.morningScan:
                        _runMorningScan();
                      case _CompactTopAction.tradeJournal:
                        _openTradeJournalPage();
                      case _CompactTopAction.testNotification:
                        _sendTestNotification();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem<_CompactTopAction>(
                      value: _CompactTopAction.backtest,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.analytics),
                        title: Text('?�測MVP'),
                      ),
                    ),
                    PopupMenuItem<_CompactTopAction>(
                      value: _CompactTopAction.morningScan,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.bolt),
                        title: Text('?�盤一?��???),
                      ),
                    ),
                    PopupMenuItem<_CompactTopAction>(
                      value: _CompactTopAction.tradeJournal,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.menu_book),
                        title: Text('交�??��?'),
                      ),
                    ),
                    PopupMenuItem<_CompactTopAction>(
                      value: _CompactTopAction.testNotification,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.notifications_active),
                        title: Text('測試?��?'),
                      ),
                    ),
                  ],
                ),
              ]
            : [
                IconButton(
                  tooltip: '?�測MVP',
                  onPressed: _openBacktestPage,
                  icon: const Icon(Icons.analytics),
                ),
                IconButton(
                  tooltip: '?�盤一?��???,
                  onPressed: _runMorningScan,
                  icon: const Icon(Icons.bolt),
                ),
                IconButton(
                  tooltip: '交�??��?',
                  onPressed: _openTradeJournalPage,
                  icon: const Icon(Icons.menu_book),
                ),
                IconButton(
                  tooltip: '測試?��?',
                  onPressed: _sendTestNotification,
                  icon: const Icon(Icons.notifications_active),
                ),
                IconButton(
                  tooltip: '?�新?��?資�?',
                  onPressed: _refreshStocks,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'Google ?�份',
                  onPressed: _openGoogleBackupSheet,
                  icon: const Icon(Icons.cloud_sync),
                ),
              ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: isCompactPhone
          ? FloatingActionButton(
              onPressed: _openFilterSheet,
              child: const Icon(Icons.filter_alt),
            )
          : FloatingActionButton.extended(
              onPressed: _openFilterSheet,
              icon: const Icon(Icons.filter_alt),
              label: const Text('篩選飆股'),
            ),
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScaleFactor),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            visualDensity: compactDensity
                ? VisualDensity.compact
                : VisualDensity.standard,
          ),
          child: FutureBuilder<List<StockModel>>(
          future: _stocksFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '載入?�股資�?失�?',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _retryFetch,
                        icon: const Icon(Icons.refresh),
                        label: const Text('?�試'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final stocks = snapshot.data ?? const <StockModel>[];
            final marketBreadthRatio = _marketBreadthRatio(stocks);
            final marketRegime = _autoRegimeEnabled
                ? _detectMarketRegime(stocks)
                : _currentRegime;
            final riskSnapshot = _buildRiskSnapshotForContext(
              regime: marketRegime,
              breadth: marketBreadthRatio,
            );
            final marketAverageVolume = _stableMarketAverageVolume(stocks);
            final effectiveVolumeThreshold =
                (_effectiveVolumeThresholdWithSnapshot(
                          marketAverageVolume,
                          riskSnapshot: riskSnapshot,
                        ) *
                        _regimeVolumeMultiplierFor(marketRegime))
                    .round();
            final entrySignalCache = <String, _EntrySignal>{};
            _EntrySignal resolveEntrySignal(StockModel stock, int score) {
              return entrySignalCache.putIfAbsent(
                stock.code,
                () => _evaluateEntrySignal(stock, score),
              );
            }

            final revenueMomentumByCode = <String, int>{};
            int revenueMomentumOf(StockModel stock) {
              return revenueMomentumByCode.putIfAbsent(
                stock.code,
                () => _revenueMomentumScore(stock),
              );
            }

            final earningsSurpriseByCode = <String, int>{};
            int earningsSurpriseOf(StockModel stock) {
              return earningsSurpriseByCode.putIfAbsent(
                stock.code,
                () => _earningsSurpriseScore(stock),
              );
            }

            final eventWindowDaysByCode = <String, int?>{};
            int? eventWindowDaysOf(StockModel stock) {
              return eventWindowDaysByCode.putIfAbsent(
                stock.code,
                () => _daysToNearestEventWindow(stock),
              );
            }

            _syncRealtimeContextForRender(
              stocks: stocks,
              marketBreadthRatio: marketBreadthRatio,
              marketRegime: marketRegime,
              effectiveVolumeThreshold: effectiveVolumeThreshold,
            );

            final filterDropReasonCounts = <String, int>{};
            void countDrop(String reason) {
              filterDropReasonCounts.update(reason, (v) => v + 1,
                  ifAbsent: () => 1);
            }
            // persist today's reasons for later aggregation
            void recordFilterStats() {
              if (filterDropReasonCounts.isNotEmpty) {
                _upsertDailyFilterStats(filterDropReasonCounts);
              }
            }

            final dropReasonsByCode = <String, List<String>>{};
            void markDrop(StockModel stock, String reason) {
              countDrop(reason);
              dropReasonsByCode
                  .putIfAbsent(stock.code, () => <String>[])
                  .add(reason);
            }

            final strategyStocks = <StockModel>[];
            for (final stock in stocks) {
              if (!_enableStrategyFilter) {
                strategyStocks.add(stock);
                continue;
              }

              if (stock.closePrice > _maxPriceThreshold) {
                markDrop(stock, '?�價超�???);
                continue;
              }
              if (stock.volume < effectiveVolumeThreshold) {
                markDrop(stock, '?�能不足');
                continue;
              }
              if (normalizedTradeValueForFilter(stock.tradeValue) <
                  _minTradeValueThreshold) {
                markDrop(stock, '?�交?��?�?);
                continue;
              }
              if (_onlyRising && stock.change <= 0) {
                markDrop(stock, '?��?漲股');
                continue;
              }
              if (_excludeOverheated &&
                  stock.change >= _maxChaseChangePercent) {
                markDrop(stock, '追�?風險');
                continue;
              }
              if (_enableForeignFlowFilter &&
                  stock.foreignNet < _minForeignNet) {
                markDrop(stock, '外�?買�?不足');
                continue;
              }
              if (_enableTrustFlowFilter && stock.trustNet < _minTrustNet) {
                markDrop(stock, '?�信買�?不足');
                continue;
              }
              if (_enableDealerFlowFilter &&
                  stock.dealerNet < _minDealerNet) {
                markDrop(stock, '?��??�買超�?�?);
                continue;
              }
              if (_enableMarginDiffFilter &&
                  stock.marginBalanceDiff < _minMarginBalanceDiff) {
                markDrop(stock, '?��?餘�?變�?不足');
                continue;
              }
              strategyStocks.add(stock);
            }

            // save today?�s drop reasons for historical analysis
            recordFilterStats();

            final scoredStocks = strategyStocks
                .map(
                  (stock) => _ScoredStock(
                    stock: stock,
                    score: _calculateStockScore(stock),
                  ),
                )
                .toList()
              ..sort((a, b) {
                if (_enableScoring) {
                  final aRank = a.score + _sectorRotationBonus(a.stock);
                  final bRank = b.score + _sectorRotationBonus(b.stock);
                  final rankCompare = bRank.compareTo(aRank);
                  if (rankCompare != 0) {
                    return rankCompare;
                  }
                }

                final tradeValueCompare = normalizedTradeValueForFilter(
                      b.stock.tradeValue,
                    ).compareTo(
                      normalizedTradeValueForFilter(a.stock.tradeValue),
                    );
                if (tradeValueCompare != 0) {
                  return tradeValueCompare;
                }

                final changeCompare = b.stock.change.compareTo(a.stock.change);
                if (changeCompare != 0) {
                  return changeCompare;
                }

                final volumeCompare = b.stock.volume.compareTo(a.stock.volume);
                if (volumeCompare != 0) {
                  return volumeCompare;
                }

                return a.stock.code.compareTo(b.stock.code);
              });

            final candidateStocks = <_ScoredStock>[];
            for (final item in scoredStocks) {
              if (!_enableScoring) {
                candidateStocks.add(item);
                continue;
              }
              final minScore = _effectiveMinScoreThresholdWithSnapshot(
                stock: item.stock,
                riskSnapshot: riskSnapshot,
                regime: marketRegime,
              );
              if (item.score < minScore) {
                markDrop(item.stock, '?�數不足');
                continue;
              }
              candidateStocks.add(item);
            }

            final holdingCodesForExposure = <String>{
              ..._entryPriceByCode.keys,
              ..._positionLotsByCode.keys,
            };
            final sectorCountByCode = <String, int>{};
            for (final stock in stocks) {
              final sector = _sectorGroupForCode(stock.code);
              final count = sectorCountByCode[sector] ?? 0;
              if (holdingCodesForExposure.contains(stock.code)) {
                sectorCountByCode[sector] = count + 1;
              }
            }
            final sectorQuotaUsage = <String, int>{
              for (final entry in sectorCountByCode.entries)
                entry.key: entry.value,
            };

            final qualityFilteredStocks = <_ScoredStock>[];
            for (final item in candidateStocks) {
              if (!_passesBreakoutStage(item.stock, item.score)) {
                markDrop(item.stock, '?��?不符');
                continue;
              }
              if (!_passesRiskRewardPrefilter(item.stock)) {
                markDrop(item.stock, '風險?�酬不足');
                continue;
              }
              if (_isLikelyFalseBreakout(item.stock, item.score)) {
                markDrop(item.stock, '?�似?��???);
                continue;
              }
              if (!_passesEventRiskExclusion(item.stock)) {
                markDrop(item.stock, '事件風險?�除');
                continue;
              }
              if (_enableEventCalendarWindow &&
                  BreakoutMode != BreakoutMode.preEventPosition) {
                final days = eventWindowDaysOf(item.stock);
                if (days != null && days.abs() <= _eventCalendarGuardDays) {
                  markDrop(item.stock, '法說/財報事件�?);
                  continue;
                }
              }
              if (_enableRevenueMomentumFilter) {
                final momentum = revenueMomentumOf(item.stock);
                if (momentum < _minRevenueMomentumScore) {
                  markDrop(item.stock, '?�收?�能?�弱');
                  continue;
                }
              }
              if (_enableEarningsSurpriseFilter) {
                final surprise = earningsSurpriseOf(item.stock);
                if (surprise < _minEarningsSurpriseScore) {
                  markDrop(item.stock, '財報驚�?度�?�?);
                  continue;
                }
              }
              if (_isLikelyOvernightGapRisk(item.stock)) {
                markDrop(item.stock, '?�日跳空風險');
                continue;
              }
              if (_enableSectorExposureCap &&
                  !holdingCodesForExposure.contains(item.stock.code)) {
                final sector = _sectorGroupForCode(item.stock.code);
                final used = sectorQuotaUsage[sector] ?? 0;
                if (used >= _maxHoldingPerSector) {
                  markDrop(item.stock, '?�業?�中度�???);
                  continue;
                }
                sectorQuotaUsage[sector] = used + 1;
              }
              qualityFilteredStocks.add(item);
            }

            final strategyCodes =
                strategyStocks.map((item) => item.code).toSet();
            final candidateCodes =
                candidateStocks.map((item) => item.stock.code).toSet();
            final qualityCodes =
                qualityFilteredStocks.map((item) => item.stock.code).toSet();

            final effectiveShowStrongOnly = _showStrongOnly && _enableScoring;
            final strongOnlyStocks = effectiveShowStrongOnly
                ? qualityFilteredStocks.where((item) {
                    final signal = resolveEntrySignal(item.stock, item.score);
                    return signal.type == _EntrySignalType.strong;
                  }).toList()
                : qualityFilteredStocks;

            final searchedStocks = _searchKeyword.trim().isEmpty
                ? strongOnlyStocks
                : strongOnlyStocks.where((item) {
                    final key = _searchKeyword.trim().toLowerCase();
                    return item.stock.code.toLowerCase().contains(key) ||
                        item.stock.name.toLowerCase().contains(key);
                  }).toList();
            final strongOnlyCodes =
                strongOnlyStocks.map((item) => item.stock.code).toSet();
            final searchedCodes =
                searchedStocks.map((item) => item.stock.code).toSet();

            final limitedCandidateStocks = _limitTopCandidates &&
                    searchedStocks.length > _topCandidateLimit
                ? searchedStocks.take(_topCandidateLimit).toList()
                : searchedStocks;
            final limitedCodes =
                limitedCandidateStocks.map((item) => item.stock.code).toSet();

            _upsertDailyCandidateArchive(
              coreCandidateCodes: qualityCodes,
              limitedCodes: limitedCodes,
              strongOnlyCodes: strongOnlyCodes,
            );

            _upsertDailyPredictionArchive(
              limitedCandidateStocks: limitedCandidateStocks,
              coreCandidateCodes: qualityCodes,
              strongOnlyCodes: strongOnlyCodes,
              resolveEntrySignal: resolveEntrySignal,
            );

            final currentFilterContext = _buildCandidateFilterContextSnapshot();
            _upsertDailyContextArchive(
              marketBreadthRatio: marketBreadthRatio,
              marketRegime: marketRegime,
              filterContext: currentFilterContext,
            );
            final changedFilterContextLabels =
              _lastCandidateFilterContext.isEmpty
                ? <String>[]
                : _candidateFilterContextDiffLabels(
                  previous: _lastCandidateFilterContext,
                  current: currentFilterContext,
                  );
            final driftBaselineReset = _hasLimitedCandidateSnapshot &&
              changedFilterContextLabels.isNotEmpty;
            final canCompareCandidateDrift =
                _hasLimitedCandidateSnapshot && !driftBaselineReset;

            final coreCandidateCodes = qualityCodes;

            final addedCodes = canCompareCandidateDrift
                ? (coreCandidateCodes
                    .difference(_lastLimitedCandidateCodes)
                    .toList()
                  ..sort())
                : <String>[];
            final removedCodes = canCompareCandidateDrift
                ? (_lastLimitedCandidateCodes
                    .difference(coreCandidateCodes)
                    .toList()
                  ..sort())
                : <String>[];
            final hasCandidateDrift = canCompareCandidateDrift &&
                (addedCodes.isNotEmpty || removedCodes.isNotEmpty);

            String removedReasonHint(String code) {
              final reasons = dropReasonsByCode[code] ?? const <String>[];
              if (reasons.isNotEmpty) {
                return reasons.take(2).join('??);
              }
              if (effectiveShowStrongOnly && !strongOnlyCodes.contains(code)) {
                return '強勢?��?（�?強勢訊�?�?;
              }
              if (_limitTopCandidates &&
                  searchedCodes.contains(code) &&
                  !limitedCodes.contains(code)) {
                return '超出??$_topCandidateLimit 檔�???;
              }
              return '?��?變�?（無主�??�除條件�?;
            }

            String addedReasonHint(String code) {
              final previousReasons =
                  _lastDropReasonsByCodeSnapshot[code] ?? const <String>[];
              if (previousReasons.isNotEmpty) {
                return '?��??��?�?{previousReasons.take(2).join('??)}';
              }
              if (_limitTopCandidates) {
                return '?��??�能?��? $_topCandidateLimit 檔�???;
              }
              return '條件轉佳?��?序�?�?;
            }

            String reasonBucketLabel(String reason) {
              if (reason.startsWith('?��??��?�?)) {
                final text = reason.substring('?��??��?�?.length);
                return text.split('??).first;
              }
              return reason.split('�?).first.split('??).first;
            }

            final removedReasonPreview = removedCodes
                .take(3)
                .map((code) => '$code�?{removedReasonHint(code)}�?)
                .toList();
            final addedReasonPreview = addedCodes
                .take(3)
                .map((code) => '$code�?{addedReasonHint(code)}�?)
                .toList();

            final reasonWeight = <String, int>{};
            for (final code in removedCodes) {
              final bucket = reasonBucketLabel(removedReasonHint(code));
              reasonWeight.update(bucket, (v) => v + 1, ifAbsent: () => 1);
            }
            for (final code in addedCodes) {
              final bucket = reasonBucketLabel(addedReasonHint(code));
              reasonWeight.update(bucket, (v) => v + 1, ifAbsent: () => 1);
            }
            final reasonWeightSummary = reasonWeight.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value));
            final totalReasonCount =
                reasonWeightSummary.fold<int>(0, (sum, item) => sum + item.value);

            if (!_hasLimitedCandidateSnapshot) {
              _lastLimitedCandidateCodes = Set<String>.from(coreCandidateCodes);
              _hasLimitedCandidateSnapshot = true;
              _lastCandidateFilterContext =
                  Map<String, String>.from(currentFilterContext);
              _scheduleDiagnosticsSnapshotPersist();
            } else if (driftBaselineReset || hasCandidateDrift) {
              if (driftBaselineReset) {
                _lastCandidateFilterContextBeforeReset =
                    Map<String, String>.from(_lastCandidateFilterContext);
                _appendCandidateDriftRecord(
                  type: 'reset',
                  addedCount: 0,
                  removedCount: 0,
                  changedFilters: changedFilterContextLabels,
                );
              } else {
                _appendCandidateDriftRecord(
                  type: 'drift',
                  addedCount: addedCodes.length,
                  removedCount: removedCodes.length,
                  changedFilters: changedFilterContextLabels,
                );
              }
              _lastLimitedCandidateCodes = Set<String>.from(coreCandidateCodes);
              _lastCandidateFilterContext =
                  Map<String, String>.from(currentFilterContext);
              _scheduleDiagnosticsSnapshotPersist();
            }

            _lastDropReasonsByCodeSnapshot
              ..clear()
              ..addAll(
                {
                  for (final entry in dropReasonsByCode.entries)
                    entry.key: List<String>.from(entry.value),
                },
              );

            _updateSignalTracking(
              stocks,
              limitedCandidateStocks,
              resolveEntrySignal,
            );

            final strongPerf =
                _buildSignalPerformanceSummary(_EntrySignalType.strong);
            final watchPerf =
                _buildSignalPerformanceSummary(_EntrySignalType.watch);

            final stockByCode = <String, StockModel>{
              for (final stock in stocks) stock.code: stock,
            };
            final holdingCodes = <String>{
              ..._entryPriceByCode.keys,
              ..._positionLotsByCode.keys,
            };

            final baseDisplayedStocks = _showOnlyFavorites
                ? limitedCandidateStocks
                    .where(
                        (item) => _favoriteStockCodes.contains(item.stock.code))
                    .toList()
                : limitedCandidateStocks;

            final holdingDisplayStocks = stocks
                .where((stock) => holdingCodes.contains(stock.code))
                .where((stock) {
                  final key = _searchKeyword.trim().toLowerCase();
                  if (key.isEmpty) {
                    return true;
                  }
                  return stock.code.toLowerCase().contains(key) ||
                      stock.name.toLowerCase().contains(key);
                })
                .map(
                  (stock) => _ScoredStock(
                    stock: stock,
                    score: _calculateStockScore(stock),
                  ),
                )
                .toList()
              ..sort((a, b) => a.stock.code.compareTo(b.stock.code));

            final displayedStocks =
                _showOnlyHoldings ? holdingDisplayStocks : baseDisplayedStocks;
            final displayedCodes =
                displayedStocks.map((item) => item.stock.code).toSet();

            final holdingRows = holdingCodes.map((code) {
              final stock = stockByCode[code];
              final entryPrice = _entryPriceByCode[code];
              final lots = _positionLotsByCode[code];
              final score = stock == null ? null : _calculateStockScore(stock);
              final matchedModes = (stock == null || score == null)
                  ? const <BreakoutMode>[]
                  : _matchedBreakoutModesForStock(stock, score);
              final pnlPercent = stock == null
                  ? null
                  : _calculatePnlPercent(stock, entryPrice);
              final pnlAmount = stock == null
                  ? null
                  : _calculatePnlAmount(stock, entryPrice, lots);
              final entrySignal = (stock == null || score == null)
                  ? const _EntrySignal(
                      label: '資�?不足',
                      type: _EntrySignalType.wait,
                    )
                  : resolveEntrySignal(stock, score);
              final premarketRisk = stock == null
                  ? const _PremarketRisk(
                      label: '資�?不足',
                      type: _PremarketRiskType.medium,
                    )
                  : _evaluatePremarketRisk(stock);
              return (
                code: code,
                name: stock?.name ?? '-',
                stock: stock,
                closePrice: stock?.closePrice,
                entryPrice: entryPrice,
                lots: lots,
                matchedModes: matchedModes,
                pnlPercent: pnlPercent,
                pnlAmount: pnlAmount,
                entrySignalLabel: entrySignal.label,
                premarketRiskLabel: premarketRisk.label,
                premarketRiskType: premarketRisk.type,
                decisionSummary:
                    _decisionSummaryFor(entrySignal.type, premarketRisk.type),
              );
            }).toList()
              ..sort((a, b) => a.code.compareTo(b.code));

            int premarketRiskRank(_PremarketRiskType type) {
              return switch (type) {
                _PremarketRiskType.high => 0,
                _PremarketRiskType.medium => 1,
                _PremarketRiskType.low => 2,
              };
            }

            final filteredHoldingRows = _showOnlyHighRiskHoldings
                ? holdingRows
                    .where((row) =>
                        row.premarketRiskType == _PremarketRiskType.high)
                    .toList()
                : holdingRows.toList();
            if (_sortHoldingsByRisk) {
              filteredHoldingRows.sort((a, b) {
                final rankCompare = premarketRiskRank(a.premarketRiskType)
                    .compareTo(premarketRiskRank(b.premarketRiskType));
                if (rankCompare != 0) {
                  return rankCompare;
                }
                final aAbsPnl = a.pnlPercent?.abs() ?? 0;
                final bAbsPnl = b.pnlPercent?.abs() ?? 0;
                final pnlCompare = bAbsPnl.compareTo(aAbsPnl);
                if (pnlCompare != 0) {
                  return pnlCompare;
                }
                return a.code.compareTo(b.code);
              });
            }

            final highRiskHoldingCount = holdingRows
                .where(
                    (row) => row.premarketRiskType == _PremarketRiskType.high)
                .length;
            final mediumRiskHoldingCount = holdingRows
                .where(
                    (row) => row.premarketRiskType == _PremarketRiskType.medium)
                .length;
            final holdingReductionRows = holdingRows
                .map(
                  (row) => (
                    code: row.code,
                    name: row.name,
                    lots: row.lots,
                    closePrice: row.closePrice,
                    entryPrice: row.entryPrice,
                    premarketRiskType: row.premarketRiskType,
                    decisionSummary: row.decisionSummary,
                  ),
                )
                .toList();

            final marketTimingStatus = _buildMarketTimingStatus();
            final showOpenConfirmHint =
                _requireOpenConfirm && _isBeforeOpenConfirmTime();

            final tagCounts = _buildCandidateTagCounts(
                limitedCandidateStocks, resolveEntrySignal);
            final strategyWarnings = _buildStrategyConsistencyWarnings();
            final suggestedEventTemplate =
                _suggestNewsEventTemplate(_marketNewsSnapshot);
            final activeEventTemplate =
                _templateById(_activeNewsEventTemplateId);
            final eventTemplateAutoRestoreDaysLeft =
                (_lastNewsEventTemplateHitAt == null)
                    ? null
                    : (_autoRestoreNewsEventTemplateAfterDays -
                            DateTime.now()
                                .difference(_lastNewsEventTemplateHitAt!)
                                .inDays)
                        .clamp(0, 999);
            final modeRecommendation = _buildModeRecommendationForContext(
              regime: marketRegime,
              breadth: marketBreadthRatio,
              newsLevel: _marketNewsSnapshot?.level,
              isNightSession: _isPostMarketOrNight(),
            );
            final recommendationSessionLabel =
                _isPostMarketOrNight() ? '?��?/夜�?' : '?�中';
            final autoStreak = _autoLossStreakFromJournal();
            final sectorRegimeSummary = _sectorRegimeByGroup.entries
                .take(3)
                .map((entry) => '${entry.key}:${_regimeLabelOf(entry.value)}')
                .join(' / ');
            final scanSummary =
                '?�選 ${limitedCandidateStocks.length} 檔�?強勢 ${tagCounts[_EntrySignalType.strong] ?? 0} 檔�?觀�?${tagCounts[_EntrySignalType.watch] ?? 0} 檔�?模�? ${BreakoutModeLabel(BreakoutMode)}｜寬�?${marketBreadthRatio.toStringAsFixed(2)}｜Regime ${_regimeLabelOf(marketRegime)}｜板�?${sectorRegimeSummary.isEmpty ? '-' : sectorRegimeSummary}｜�?�� $autoStreak �?;
            final googleBackupStatusLabel = _googleBackupStatusLabel();
            final googleBackupConnected = _isGoogleBackupConnected();
            final googleBackupFreshToday = _isGoogleBackupFreshToday();
            final currentControlLayerLabel = _currentControlLayerLabel();
            final currentControlLayerIcon = _currentControlLayerIcon();
            final topicStrengths = _buildTopicStrengths(
              _marketNewsSnapshot?.items ?? const <MarketNewsItem>[],
            );
            final topicBeneficiaryHints =
                _topicBeneficiaryHints(topicStrengths);

            return RefreshIndicator(
              onRefresh: _refreshStocks,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, topGap, horizontalInset, 0),
                          child: _SignalLegend(),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: _MarketTimingBanner(
                            status: marketTimingStatus,
                            autoRefreshEnabled: _autoRefreshEnabled,
                            autoRefreshMinutes: _autoRefreshMinutes,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: _MarketNewsCard(
                            snapshot: _marketNewsSnapshot,
                            topicStrengths: topicStrengths,
                            isLoading: _isLoadingNews,
                            error: _newsError,
                            autoDefensiveOnHighNewsRisk:
                                _autoDefensiveOnHighNewsRisk,
                            isHighNewsRiskDefenseActive:
                                _isHighNewsRiskDefenseActive,
                            onRetry: () => _refreshNews(showFeedback: true),
                            onOpenNews: _openNewsLink,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              avatar: Icon(currentControlLayerIcon, size: 16),
                              label: Text(currentControlLayerLabel),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                        if (topicBeneficiaryHints.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(horizontalInset,
                                sectionGap, horizontalInset, 0),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '議�??��??��?�?,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    ...topicBeneficiaryHints.map(
                                      (hint) => Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 4),
                                        child: Text('??$hint'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              scanSummary,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons
                                          .account_balance_wallet_outlined),
                                      const SizedBox(width: 6),
                                      Text(
                                        '?�股總覽�?{filteredHoldingRows.length}/${holdingRows.length} 檔�?',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                      const Spacer(),
                                      if (holdingRows.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(right: 8),
                                          child: Text(
                                            '高風??$highRiskHoldingCount｜中風險 $mediumRiskHoldingCount',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall,
                                          ),
                                        ),
                                      if (highRiskHoldingCount > 0)
                                        IconButton(
                                          tooltip: '檢�?第�?檔�?風險K�?,
                                          onPressed: () {
                                            final target =
                                                filteredHoldingRows.firstWhere(
                                              (row) =>
                                                  row.premarketRiskType ==
                                                  _PremarketRiskType.high,
                                              orElse: () => filteredHoldingRows
                                                  .firstWhere(
                                                (row) => row.stock != null,
                                                orElse: () =>
                                                    filteredHoldingRows.first,
                                              ),
                                            );
                                            if (target.stock != null) {
                                              _openKLineChart(target.stock!);
                                            }
                                          },
                                          icon: const Icon(
                                              Icons.candlestick_chart),
                                        ),
                                      TextButton.icon(
                                        onPressed: () =>
                                            _openRiskReductionSuggestionsDialog(
                                          rows: holdingReductionRows,
                                        ),
                                        icon: const Icon(Icons.shield_outlined),
                                        label: const Text('?�倉建�?),
                                      ),
                                      TextButton.icon(
                                        onPressed: _openManualHoldingDialog,
                                        icon: const Icon(Icons.add),
                                        label: const Text('?��?庫�?'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      FilterChip(
                                        label: const Text('依風?��?�?),
                                        selected: _sortHoldingsByRisk,
                                        onSelected: (selected) {
                                          setState(() {
                                            _sortHoldingsByRisk = selected;
                                          });
                                          _savePreferences();
                                        },
                                      ),
                                      FilterChip(
                                        label: const Text('?��?高風?��???),
                                        selected: _showOnlyHighRiskHoldings,
                                        onSelected: (selected) {
                                          setState(() {
                                            _showOnlyHighRiskHoldings =
                                                selected;
                                          });
                                          _savePreferences();
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (holdingRows.isEmpty)
                                    const Text('?��?尚未設�?任�??�股（�???張數�?)
                                  else if (filteredHoldingRows.isEmpty)
                                    const Text('?��?沒�?符�?篩選條件?��???)
                                  else
                                    ...filteredHoldingRows.map(
                                      (row) => ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        title: Text('${row.code} ${row.name}'),
                                        subtitle: Text(
                                          '${row.entryPrice == null ? '?�本 -' : '?�本 ${row.entryPrice!.toStringAsFixed(2)}'}�?
                                          '${row.lots == null ? '張數 -' : '張數 ${row.lots!.toStringAsFixed(row.lots! % 1 == 0 ? 0 : 2)}'}�?
                                          '${row.closePrice == null ? '?�價 -' : '?�價 ${row.closePrice!.toStringAsFixed(2)}'}'
                                          '\n一?�話�?{row.decisionSummary}'
                                          '｜�???${row.entrySignalLabel}'
                                          '｜盤?�風??${_premarketRiskTypeLabel(row.premarketRiskType)}'
                                          '${row.matchedModes.isEmpty ? '' : '\n?�中模�?�?{row.matchedModes.take(3).map(BreakoutModeLabel).join(' / ')}${row.matchedModes.length > 3 ? ' +${row.matchedModes.length - 3}' : ''}'}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            row.pnlPercent == null
                                                ? const Text('-')
                                                : Text(
                                                    '${row.pnlPercent! >= 0 ? '+' : ''}${row.pnlPercent!.toStringAsFixed(2)}%\n${row.pnlAmount == null ? '' : '${row.pnlAmount! >= 0 ? '+' : ''}${_formatCurrency(row.pnlAmount!)}'}',
                                                    textAlign: TextAlign.right,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium,
                                                  ),
                                            const SizedBox(width: 6),
                                            if (row.stock != null)
                                              IconButton(
                                                tooltip: '?��?K�?,
                                                icon: const Icon(
                                                    Icons.candlestick_chart),
                                                onPressed: () =>
                                                    _openKLineChart(row.stock!),
                                              ),
                                            IconButton(
                                              tooltip: '?�除庫�?',
                                              icon: const Icon(
                                                  Icons.delete_outline),
                                              onPressed: () async {
                                                setState(() {
                                                  _entryPriceByCode
                                                      .remove(row.code);
                                                  _positionLotsByCode
                                                      .remove(row.code);
                                                });
                                                await _savePreferences();
                                                if (!mounted) {
                                                  return;
                                                }
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          '已刪??${row.code} 庫�?')),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Chip(
                              avatar: Icon(
                                _googleBackupStatusIcon(),
                                size: 18,
                              ),
                              label: Text(googleBackupStatusLabel),
                              visualDensity: VisualDensity.compact,
                              backgroundColor: googleBackupConnected
                                  ? (googleBackupFreshToday
                                      ? Theme.of(context)
                                          .colorScheme
                                          .secondaryContainer
                                      : Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest)
                                  : Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: ExpansionTile(
                              leading: const Icon(Icons.tune),
                              title: const Text('篩選診斷（�??�被?�除主�?�?),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              children: [
                                if (filterDropReasonCounts.isEmpty)
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text('?��??��??��???),
                                  )
                                else
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children:
                                        (filterDropReasonCounts.entries.toList()
                                              ..sort((a, b) =>
                                                  b.value.compareTo(a.value)))
                                            .take(6)
                                            .map(
                                              (entry) => Chip(
                                                label: Text(
                                                    '${entry.key} ${entry.value}'),
                                                visualDensity:
                                                    VisualDensity.compact,
                                              ),
                                            )
                                            .toList(),
                                  ),
                                const SizedBox(height: 8),
                                // show aggregated past 5-day reasons
                                Builder(builder: (ctx) {
                                  final recent = _aggregateRecentFilterReasons(5);
                                  if (recent.isEmpty) return const SizedBox();
                                  // sort and build chip list separately to keep types
                                  final sorted = recent.entries.toList()
                                    ..sort((a, b) => b.value.compareTo(a.value));
                                  final chips = sorted
                                      .take(6)
                                      .map((e) => Chip(
                                            label: Text('${e.key} ${e.value}'),
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: Theme.of(ctx)
                                                .colorScheme
                                                .secondaryContainer,
                                          ))
                                      .toList();
                                  return Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: chips,
                                  );
                                }),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () =>
                                        _openStockExclusionDiagnosticDialog(
                                      stocks: stocks,
                                      dropReasonsByCode: dropReasonsByCode,
                                      strategyCodes: strategyCodes,
                                      candidateCodes: candidateCodes,
                                      qualityCodes: qualityCodes,
                                      strongOnlyCodes: strongOnlyCodes,
                                      searchedCodes: searchedCodes,
                                      limitedCodes: limitedCodes,
                                      displayedCodes: displayedCodes,
                                    ),
                                    icon: const Icon(Icons.search),
                                    label: const Text('?��??�除診斷'),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _openBullRunReplayDialog,
                                    icon: const Icon(Icons.history_edu_outlined),
                                    label: const Text('上週�??��???),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: _openAnalyticsExportDialog,
                                    icon: const Icon(Icons.file_download_outlined),
                                    label: const Text('?�出?�中??CSV'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(Icons.compare_arrows),
                              title: const Text('?�選穩�??��??�次 vs 上次�?),
                              subtitle: !_hasLimitedCandidateSnapshot
                                  ? const Text('尚未建�?比�?快照')
                                  : (driftBaselineReset
                                      ? Text(
                                          '已�?置�?較基準�??��??�數變更）�??��??�選 ${qualityCodes.length} 檔�??�面顯示 ${limitedCodes.length} 檔\n'
                                          '變更�?{changedFilterContextLabels.take(6).join('??)}${changedFilterContextLabels.length > 6 ? ' +${changedFilterContextLabels.length - 6}' : ''}')
                                      : !hasCandidateDrift
                                    ? Text(
                                      '?��??�選 ${qualityCodes.length} 檔�??��?次相?��?｜畫?�顯�?${limitedCodes.length} �?)
                                    : Text(
                                      '?��? ${addedCodes.length}｜移??${removedCodes.length}｜更??${_formatTimeHHmm(DateTime.now())}\n'
                                      '?��?�?{addedCodes.isEmpty ? '-' : addedCodes.take(5).join('??)}\n'
                                      '移除�?{removedCodes.isEmpty ? '-' : removedCodes.take(5).join('??)}\n'
                                      '?��?主�?�?{addedReasonPreview.isEmpty ? '-' : addedReasonPreview.join('??)}\n'
                                      '移除主�?�?{removedReasonPreview.isEmpty ? '-' : removedReasonPreview.join('??)}\n'
                                      '?��??�選 ${qualityCodes.length} 檔�??�面顯示 ${limitedCodes.length} �?,
                                    )),
                              isThreeLine: true,
                              trailing: _candidateDriftHistory.isEmpty
                                  ? null
                                  : Tooltip(
                                      message: _candidateDriftHistory
                                          .take(5)
                                          .map(_candidateDriftHistoryLabel)
                                          .join('\n'),
                                      child: const Icon(
                                          Icons.history_toggle_off_outlined),
                                    ),
                            ),
                          ),
                        ),
                        if (driftBaselineReset &&
                            _lastCandidateFilterContextBeforeReset.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalInset, 4, horizontalInset, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _restorePreviousCandidateFilterSnapshot,
                                icon: const Icon(Icons.history),
                                label: const Text('?��?上次比�??�數'),
                              ),
                            ),
                          ),
                        if (reasonWeightSummary.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalInset, 4, horizontalInset, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: reasonWeightSummary
                                    .take(3)
                                    .map(
                                      (entry) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${entry.key} ${(entry.value * 100 / (totalReasonCount == 0 ? 1 : totalReasonCount)).toStringAsFixed(0)}%',
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (_candidateDriftHistory.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(horizontalInset, 4,
                                horizontalInset, 0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _candidateDriftHistory
                                    .take(3)
                                    .map(
                                      (entry) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                            _candidateDriftHistoryLabel(entry)),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (_candidateDriftHistory.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalInset, 4, horizontalInset, 0),
                            child: Card(
                              child: ExpansionTile(
                                leading: const Icon(Icons.timeline),
                                title: const Text('變�??��?軸�??��?8 次�?'),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 10),
                                children: _candidateDriftHistory
                                    .take(8)
                                    .map(
                                      (entry) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Text(
                                            '??${_candidateDriftHistoryLabel(entry)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (_parameterChangeAuditHistory.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalInset, 4, horizontalInset, 0),
                            child: Card(
                              child: ExpansionTile(
                                leading: const Icon(Icons.manage_history),
                                title: const Text('?��??�數變更紀?��??��?8 次�?'),
                                childrenPadding: const EdgeInsets.fromLTRB(
                                    12, 0, 12, 10),
                                children: _parameterChangeAuditHistory
                                    .take(8)
                                    .map(
                                      (entry) => Align(
                                        alignment: Alignment.centerLeft,
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Text(
                                            '??${_parameterAuditHistoryLabel(entry)}\n  ${entry.changes.take(3).join('??)}${entry.changes.length > 3 ? ' +${entry.changes.length - 3}' : ''}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                        if (_lockSelectionParameters)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                                horizontalInset, sectionGap, horizontalInset, 0),
                            child: Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .secondaryContainer,
                              child: const ListTile(
                                dense: true,
                                leading: Icon(Icons.lock_outline),
                                title: Text('?�股?�數已�?�?),
                                subtitle: Text('?��?模�??��??��?件模?�自?��??�暫??),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: ExpansionTile(
                              leading: const Icon(Icons.analytics_outlined),
                              title: const Text('訊�??�中追蹤�?/3/5?�平?��?'),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '強勢�?D ${strongPerf.day1Avg.toStringAsFixed(2)}% / ?��? ${strongPerf.day1WinRate.toStringAsFixed(1)}% / ?�撤 ${strongPerf.day1MaxDrawdown.toStringAsFixed(2)}% (${strongPerf.day1Count})�?D ${strongPerf.day3Avg.toStringAsFixed(2)}% / ?��? ${strongPerf.day3WinRate.toStringAsFixed(1)}% / ?�撤 ${strongPerf.day3MaxDrawdown.toStringAsFixed(2)}% (${strongPerf.day3Count})�?D ${strongPerf.day5Avg.toStringAsFixed(2)}% / ?��? ${strongPerf.day5WinRate.toStringAsFixed(1)}% / ?�撤 ${strongPerf.day5MaxDrawdown.toStringAsFixed(2)}% (${strongPerf.day5Count})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '觀察�?1D ${watchPerf.day1Avg.toStringAsFixed(2)}% / ?��? ${watchPerf.day1WinRate.toStringAsFixed(1)}% / ?�撤 ${watchPerf.day1MaxDrawdown.toStringAsFixed(2)}% (${watchPerf.day1Count})�?D ${watchPerf.day3Avg.toStringAsFixed(2)}% / ?��? ${watchPerf.day3WinRate.toStringAsFixed(1)}% / ?�撤 ${watchPerf.day3MaxDrawdown.toStringAsFixed(2)}% (${watchPerf.day3Count})�?D ${watchPerf.day5Avg.toStringAsFixed(2)}% / ?��? ${watchPerf.day5WinRate.toStringAsFixed(1)}% / ?�撤 ${watchPerf.day5MaxDrawdown.toStringAsFixed(2)}% (${watchPerf.day5Count})',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '?��?度�??�?��???1/3/5 ?�交?�日?��?填入對�?欄�?；樣?��?足�??�顯�?0??,
                                    style:
                                        Theme.of(context).textTheme.labelSmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, 6, horizontalInset, 0),
                          child: Card(
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.calendar_view_week),
                              title: const Text('每週命中�??��?（�?�?7 天�?'),
                              subtitle: Text(_buildWeeklyHitRateSummaryText()),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, 4, horizontalInset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _openAutoTuneSuggestionDialog,
                              icon: const Icon(Icons.auto_fix_high_outlined),
                              label: const Text('?�中?�自?�調?�建�?),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              leading: const Icon(Icons.speed),
                              title: Text(
                                '風險?�數 ${riskSnapshot.score}�?{riskSnapshot.level}',
                              ),
                              subtitle: Text(
                                _enableAutoRiskAdjustment
                                    ? (_autoRiskAdjustmentSuppressedReason() ==
                                            null
                                        ? '已�??�自?�調?��?強度 ${_autoRiskAdjustmentStrength} ${_riskAdjustmentIntensityLabel()}）�??�數?��?${_riskScoreBias(riskSnapshot) >= 0 ? '+' : ''}${_riskScoreBias(riskSnapshot)}?��???x${_riskVolumeMultiplier(riskSnapshot).toStringAsFixed(2)}?��???x${_riskTakeProfitMultiplier(riskSnapshot).toStringAsFixed(2)}｜�?7??${_riskScoreTrendText()}'
                                        : '已�??�自?�調?��?但目?�為${_autoRiskAdjustmentSuppressedReason()}｜�?7??${_riskScoreTrendText()}')
                                    : '?��?調�?已�??��?使用?��??�數�?,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        BreakoutModeIcon(
                                            modeRecommendation.mode),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '$recommendationSessionLabel建議模�?�?{BreakoutModeLabel(modeRecommendation.mode)}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                      ),
                                      if (BreakoutMode !=
                                          modeRecommendation.mode)
                                        FilledButton.tonal(
                                          onPressed: () {
                                            setState(() {
                                              BreakoutMode =
                                                  modeRecommendation.mode;
                                            });
                                            _savePreferences();
                                          },
                                          child: const Text('套用建議'),
                                        )
                                      else
                                        const Chip(label: Text('已�???)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    modeRecommendation.reason,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  if (suggestedEventTemplate != null) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '?��?事件?��?�?{suggestedEventTemplate.label}�?{suggestedEventTemplate.adjustmentSummary}�?,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _applyNewsEventTemplate(
                                                suggestedEventTemplate),
                                        icon: const Icon(Icons.tune),
                                        label: Text(
                                            '套用${suggestedEventTemplate.label}'),
                                      ),
                                    ),
                                  ],
                                  if (_hasNewsEventTuneBackup()) ...[
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: _restoreNewsEventTemplate,
                                        icon: const Icon(
                                            Icons.settings_backup_restore),
                                        label: Text(
                                          activeEventTemplate == null
                                              ? '?��?事件?��???
                                              : '?��?${activeEventTemplate.label}?��???,
                                        ),
                                      ),
                                    ),
                                    if (_autoApplyNewsEventTemplate &&
                                        eventTemplateAutoRestoreDaysLeft !=
                                            null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text(
                                          '?��??��??�數�?eventTemplateAutoRestoreDaysLeft 天�??��?件命中�?',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall,
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (strategyWarnings.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.fromLTRB(horizontalInset,
                                sectionGap, horizontalInset, 0),
                            child: Card(
                              color:
                                  Theme.of(context).colorScheme.errorContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '策略一?�性警�?,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 4),
                                    ...strategyWarnings.take(2).map(
                                          (warning) => Text('??$warning'),
                                        ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '?��?�???��?稱�??��?�??�?,
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _searchKeyword = value;
                              });
                            },
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  avatar:
                                      const Icon(Icons.visibility, size: 16),
                                  label: Text(
                                    _showOnlyHoldings
                                        ? '?��?視�?：只?��???
                                        : (_showOnlyFavorites
                                            ? '?��?視�?：只?�收??
                                            : '?��?視�?：�??�候選'),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                if (effectiveShowStrongOnly)
                                  const Chip(
                                    label: Text('強勢?��?'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                if (_showStrongOnly && !_enableScoring)
                                  const Chip(
                                    label: Text('強勢?��?（�??�用?��?�?),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              horizontalInset, sectionGap, horizontalInset, 0),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                avatar: Icon(
                                  _showOnlyFavorites
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                ),
                                label: const Text('?��?模�?'),
                                selected: _showOnlyFavorites,
                                onSelected: (_) => _toggleShowOnlyFavorites(),
                              ),
                              FilterChip(
                                avatar: Icon(
                                  _showOnlyHoldings
                                      ? Icons.account_balance_wallet
                                      : Icons.account_balance_wallet_outlined,
                                  size: 16,
                                ),
                                label: const Text('?�股模�?'),
                                selected: _showOnlyHoldings,
                                onSelected: (_) => _toggleShowOnlyHoldings(),
                              ),
                              ...BreakoutMode.values.map(
                                (mode) {
                                  final scheme = Theme.of(context).colorScheme;
                                  final selectedColor = switch (mode) {
                                    BreakoutMode.early =>
                                      scheme.errorContainer,
                                    BreakoutMode.confirmed =>
                                      scheme.primaryContainer,
                                    BreakoutMode.lowBaseTheme =>
                                      scheme.tertiaryContainer,
                                    BreakoutMode.pullbackRebreak =>
                                      scheme.secondaryContainer,
                                    BreakoutMode.squeezeSetup =>
                                      scheme.surfaceVariant,
                                    BreakoutMode.preEventPosition =>
                                      scheme.primaryContainer,
                                  };
                                  final selectedForeground = switch (mode) {
                                    BreakoutMode.early =>
                                      scheme.onErrorContainer,
                                    BreakoutMode.confirmed =>
                                      scheme.onPrimaryContainer,
                                    BreakoutMode.lowBaseTheme =>
                                      scheme.onTertiaryContainer,
                                    BreakoutMode.pullbackRebreak =>
                                      scheme.onSecondaryContainer,
                                    BreakoutMode.squeezeSetup =>
                                      scheme.onSurfaceVariant,
                                    BreakoutMode.preEventPosition =>
                                      scheme.onPrimaryContainer,
                                  };

                                  return ChoiceChip(
                                    label: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(BreakoutModeIcon(mode),
                                            size: 16),
                                        const SizedBox(width: 4),
                                        Text(BreakoutModeLabel(mode)),
                                      ],
                                    ),
                                    selected: BreakoutMode == mode,
                                    selectedColor: selectedColor,
                                    labelStyle: TextStyle(
                                      color: BreakoutMode == mode
                                          ? selectedForeground
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    onSelected: (selected) {
                                      if (!selected) {
                                        return;
                                      }
                                      setState(() {
                                        BreakoutMode = mode;
                                        if (_showOnlyHoldings) {
                                          _showOnlyHoldings = false;
                                        }
                                      });
                                      _savePreferences();
                                    },
                                  );
                                },
                              ),
                              FilterChip(
                                label: Text(
                                  _enableScoring
                                      ? '?��?強勢?�場'
                                      : '?��?強勢?�場（�??��??��??��?',
                                ),
                                selected: effectiveShowStrongOnly,
                                onSelected: !_enableScoring
                                    ? null
                                    : (selected) {
                                        setState(() {
                                          _showStrongOnly = selected;
                                        });
                                      },
                              ),
                              _CountChip(
                                label: '強勢',
                                count: tagCounts[_EntrySignalType.strong] ?? 0,
                                color: Colors.red,
                              ),
                              _CountChip(
                                label: '觀�?,
                                count: tagCounts[_EntrySignalType.watch] ?? 0,
                                color: Colors.blue,
                              ),
                              _CountChip(
                                label: '等�?',
                                count: tagCounts[_EntrySignalType.wait] ?? 0,
                                color: Colors.teal,
                              ),
                              _CountChip(
                                label: '?��?',
                                count: tagCounts[_EntrySignalType.avoid] ?? 0,
                                color: Colors.orange,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalInset,
                            actionTopGap,
                            horizontalInset,
                            actionBottomGap,
                          ),
                          child: isCompactPhone
                              ? Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _saveCandidatesToFavorites(
                                          limitedCandidateStocks
                                              .map((item) => item.stock)
                                              .toList(),
                                        ),
                                        icon: const Icon(
                                            Icons.playlist_add_check),
                                        label: const Text('?��??��??�選??),
                                      ),
                                    ),
                                    SizedBox(height: stackedButtonGap),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _exportFavoritesText(scoredStocks),
                                        icon: const Icon(Icons.copy_all),
                                        label: const Text('?�出?��??��?'),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _saveCandidatesToFavorites(
                                          limitedCandidateStocks
                                              .map((item) => item.stock)
                                              .toList(),
                                        ),
                                        icon: const Icon(
                                            Icons.playlist_add_check),
                                        label: const Text('?��??��??�選??),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FilledButton.tonalIcon(
                                        onPressed: () =>
                                            _exportFavoritesText(scoredStocks),
                                        icon: const Icon(Icons.copy_all),
                                        label: const Text('?�出?��??��?'),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                  if (displayedStocks.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalInset,
                          emptyListTopPadding,
                          horizontalInset,
                          16,
                        ),
                        child: Center(
                          child: Text(
                            _showOnlyFavorites
                                ? '?��??�單?��?沒�?符�?條件?�股�?
                                : (_showOnlyHoldings
                                    ? '?�股清單?��?沒�?符�?條件?�股�?
                                    : '?��?沒�?符�?條件?�股票�???),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalInset,
                        sectionGap,
                        horizontalInset,
                        16,
                      ),
                      sliver: SliverList.builder(
                        itemCount: displayedStocks.length,
                        itemBuilder: (context, index) {
                          final scored = displayedStocks[index];
                          final entrySignal =
                              resolveEntrySignal(scored.stock, scored.score);
                          final bullishRationales = _buildBullishRationales(
                            stock: scored.stock,
                            score: scored.score,
                            entrySignal: entrySignal,
                            effectiveVolumeThreshold: effectiveVolumeThreshold,
                            topicStrengths: topicStrengths,
                            revenueMomentumScore:
                                revenueMomentumOf(scored.stock),
                            earningsSurpriseScore:
                                earningsSurpriseOf(scored.stock),
                            nearestEventWindowDays:
                                eventWindowDaysOf(scored.stock),
                          );
                          final premarketRisk =
                              _evaluatePremarketRisk(scored.stock);
                          final entryPlan =
                              _buildEntryPlan(scored.stock, entrySignal);
                          final exitSignal =
                              _evaluateExitSignal(scored.stock, scored.score);
                          final matchedBreakoutModes =
                              _matchedBreakoutModesForStock(
                            scored.stock,
                            scored.score,
                          );
                          final matchedBreakoutModeLabels = matchedBreakoutModes
                              .map(BreakoutModeLabel)
                              .toList();
                          return _StockCard(
                            stock: scored.stock,
                            score: _enableScoring ? scored.score : null,
                            breakoutStreakByCode: _breakoutStreakByCode,
                            entrySignal: entrySignal,
                            bullishRationales: bullishRationales,
                            premarketRisk: premarketRisk,
                            marketTimingStatusLabel: marketTimingStatus.label,
                            showOpenConfirmHint: showOpenConfirmHint,
                            entryPlan: entryPlan,
                            exitSignal: exitSignal,
                            entryPrice: _entryPriceByCode[scored.stock.code],
                            lots: _positionLotsByCode[scored.stock.code],
                            pnlPercent: _calculatePnlPercent(
                              scored.stock,
                              _entryPriceByCode[scored.stock.code],
                            ),
                            pnlAmount: _calculatePnlAmount(
                              scored.stock,
                              _entryPriceByCode[scored.stock.code],
                              _positionLotsByCode[scored.stock.code],
                            ),
                            matchedBreakoutModeLabels:
                                matchedBreakoutModeLabels,
                            isHolding: holdingCodes.contains(scored.stock.code),
                            expandAggressiveEstimateByDefault:
                                _expandAggressiveEstimateByDefault,
                            expandDetailsByDefault:
                              _expandCardDetailsByDefault,
                            onOpenBacktest: () =>
                                _openBacktestForStock(scored.stock),
                            onOpenPositionSizing: () =>
                                _openPositionSizingDialog(
                                    scored.stock, entryPlan),
                            onOpenKLine: () => _openKLineChart(scored.stock),
                            onOpenDiscussion: () =>
                                _openCMoneyDiscussion(scored.stock),
                            onSetEntryPrice: () =>
                                _openEntryPriceDialog(scored.stock),
                            onRecordTrade: () => _openTradeRecordDialog(
                              scored.stock,
                              exitLabel: exitSignal.label,
                            ),
                            isFavorite:
                                _favoriteStockCodes.contains(scored.stock.code),
                            onFavoritePressed: () =>
                                _toggleFavorite(scored.stock.code),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
          ),
        ),
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  const _StockCard({
    required this.stock,
    required this.score,
    required this.entrySignal,
    required this.bullishRationales,
    required this.premarketRisk,
    required this.marketTimingStatusLabel,
    required this.showOpenConfirmHint,
    required this.entryPlan,
    required this.exitSignal,
    required this.entryPrice,
    required this.lots,
    required this.pnlPercent,
    required this.pnlAmount,
    required this.matchedBreakoutModeLabels,
    required this.isHolding,
    required this.expandAggressiveEstimateByDefault,
    required this.expandDetailsByDefault,
    required this.onOpenBacktest,
    required this.onOpenPositionSizing,
    required this.onOpenKLine,
    required this.onOpenDiscussion,
    required this.onSetEntryPrice,
    required this.onRecordTrade,
    required this.isFavorite,
    required this.onFavoritePressed,
    required this.breakoutStreakByCode,
  });

  final StockModel stock;
  final int? score;
  final _EntrySignal entrySignal;
  final List<String> bullishRationales;
  final _PremarketRisk premarketRisk;
  final String marketTimingStatusLabel;
  final bool showOpenConfirmHint;
  final _EntryPlan entryPlan;
  final _ExitSignal exitSignal;
  final double? entryPrice;
  final double? lots;
  final double? pnlPercent;
  final double? pnlAmount;
  final List<String> matchedBreakoutModeLabels;
  final bool isHolding;
  final bool expandAggressiveEstimateByDefault;
  final bool expandDetailsByDefault;
  final VoidCallback onOpenBacktest;
  final VoidCallback onOpenPositionSizing;
  final VoidCallback onOpenKLine;
  final VoidCallback onOpenDiscussion;
  final VoidCallback onSetEntryPrice;
  final VoidCallback onRecordTrade;
  final bool isFavorite;
  final VoidCallback onFavoritePressed;
  final Map<String, int> breakoutStreakByCode;

  @override
  Widget build(BuildContext context) {
    final isUp = stock.change > 0;
    final changeColor = isUp ? Colors.red : Colors.green;
    final changePrefix = isUp ? '+' : '';
    final scheme = Theme.of(context).colorScheme;
    final planBasePrice = stock.closePrice;

    final conservativeStopPrice = entryPlan.stopLossPrice;
    final conservativeTargetPrice = entryPlan.takeProfitPrice;
    final conservativeTargetSpacePercent =
        ((conservativeTargetPrice - planBasePrice) / planBasePrice) * 100;
    final conservativeRiskSpacePercent =
        ((planBasePrice - conservativeStopPrice) / planBasePrice) * 100;
    final conservativeR = conservativeRiskSpacePercent <= 0
        ? null
        : conservativeTargetSpacePercent / conservativeRiskSpacePercent;

    final conservativeRiskRatio = entryPlan.conservativeEntry <= 0
        ? 0.0
        : ((entryPlan.conservativeEntry - entryPlan.stopLossPrice) /
            entryPlan.conservativeEntry);
    final conservativeGainRatio = entryPlan.conservativeEntry <= 0
        ? 0.0
        : ((entryPlan.takeProfitPrice - entryPlan.conservativeEntry) /
            entryPlan.conservativeEntry);
    final aggressiveStopPrice =
        entryPlan.aggressiveEntry * (1 - conservativeRiskRatio);
    final aggressiveTargetPrice =
        entryPlan.aggressiveEntry * (1 + conservativeGainRatio);
    final aggressiveTargetSpacePercent =
        ((aggressiveTargetPrice - planBasePrice) / planBasePrice) * 100;
    final aggressiveRiskSpacePercent =
        ((planBasePrice - aggressiveStopPrice) / planBasePrice) * 100;
    final aggressiveR = aggressiveRiskSpacePercent <= 0
        ? null
        : aggressiveTargetSpacePercent / aggressiveRiskSpacePercent;

    final estimateLots = lots ?? 1.0;
    final estimateShares = estimateLots * 1000;
    final conservativeEstimatedProfitAmount =
        (conservativeTargetPrice - entryPlan.conservativeEntry) *
            estimateShares;
    final conservativeEstimatedLossAmount =
        (entryPlan.conservativeEntry - conservativeStopPrice) * estimateShares;
    final aggressiveEstimatedProfitAmount =
        (aggressiveTargetPrice - entryPlan.aggressiveEntry) * estimateShares;
    final aggressiveEstimatedLossAmount =
        (entryPlan.aggressiveEntry - aggressiveStopPrice) * estimateShares;
    final estimateScopeLabel = lots == null
        ? '（�? 1 張估算�?'
        : '（�??��?張數 ${estimateLots.toStringAsFixed(estimateLots % 1 == 0 ? 0 : 2)}�?;
    final riskTail = switch (premarketRisk.type) {
      _PremarketRiskType.high => '（盤?�風?��?，嚴?�倉�?�?,
      _PremarketRiskType.medium => '（盤?�風?�中，�??��?佳�?',
      _PremarketRiskType.low => '',
    };
    final (decisionText, decisionBg, decisionFg) = switch (entrySignal.type) {
      _EntrySignalType.strong => (
          '一?�話：可小倉試??riskTail',
          Colors.red,
          Colors.white
        ),
      _EntrySignalType.watch => (
          '一?�話：�?觀察�?等�?強�???riskTail',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
      _EntrySignalType.wait => (
          '一?�話：�?等�??�確�?riskTail',
          scheme.tertiaryContainer,
          scheme.onTertiaryContainer,
        ),
      _EntrySignalType.avoid => (
          '一?�話：�??��?，�?追價$riskTail',
          Colors.orange,
          Colors.white
        ),
      _EntrySignalType.neutral => (
          '一?�話：�??�風?�設定�?決�?$riskTail',
          scheme.surfaceContainerHighest,
          scheme.onSurfaceVariant,
        ),
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrowCard = constraints.maxWidth < 640;
        final changeSummaryChip = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: changeColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$changePrefix${stock.change.toStringAsFixed(2)}\n??${_formatWithThousandsSeparator(stock.volume)}${score == null ? '' : '\n??$score'}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

        IconButton buildActionButton({
          required String tooltip,
          required VoidCallback onPressed,
          required IconData icon,
        }) {
          return IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: Icon(icon),
          );
        }

        final actionButtons = Wrap(
          spacing: 2,
          runSpacing: 2,
          children: [
            buildActionButton(
              tooltip: '一?�帶?��?�?,
              onPressed: onOpenBacktest,
              icon: Icons.analytics,
            ),
            buildActionButton(
              tooltip: '?��?計�?',
              onPressed: onOpenPositionSizing,
              icon: Icons.calculate,
            ),
            buildActionButton(
              tooltip: '?��?K�?,
              onPressed: onOpenKLine,
              icon: Icons.candlestick_chart,
            ),
            buildActionButton(
              tooltip: 'CMoney討�?',
              onPressed: onOpenDiscussion,
              icon: Icons.forum_outlined,
            ),
            buildActionButton(
              tooltip: '設�??�股',
              onPressed: onSetEntryPrice,
              icon: Icons.edit_note,
            ),
            buildActionButton(
              tooltip: '記�?平�?,
              onPressed: onRecordTrade,
              icon: Icons.task_alt,
            ),
            buildActionButton(
              tooltip: isFavorite ? '?��??��?' : '?�入?��?',
              onPressed: onFavoritePressed,
              icon: isFavorite ? Icons.star : Icons.star_border,
            ),
          ],
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${stock.code} ${stock.name}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            stock.closePrice.toStringAsFixed(2),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: decisionBg,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              decisionText,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: decisionFg,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                          if (isHolding) ...[
                            const SizedBox(height: 6),
                            const _HoldingBadge(),
                            if (matchedBreakoutModeLabels.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: matchedBreakoutModeLabels
                                    .take(3)
                                    .map(
                                      (label) => Chip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text('?�中�?label'),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                          const SizedBox(height: 6),
                          _EntrySignalBadge(signal: entrySignal),
                          const SizedBox(height: 6),
                          Theme(
                            data: Theme.of(context)
                                .copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              initiallyExpanded:
                                  !isNarrowCard || expandDetailsByDefault,
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: EdgeInsets.zero,
                              title: Text(
                                '?��?詳細說�??�進出規�?',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              children: [
                                if (isNarrowCard) ...[
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: expandDetailsByDefault,
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding: EdgeInsets.zero,
                                      title: Text(
                                        '依�??�風??,
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                      children: [
                                        if (bullishRationales.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              entrySignal.type ==
                                                      _EntrySignalType.strong
                                                  ? '強勢依�?�?{bullishRationales.join('�?)}'
                                                  : '?�場依�?�?{bullishRationales.join('�?)}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '?��?：此?��?件命中說?��??��?證�?漲�?請搭?��??�控管�?,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall,
                                            ),
                                          ),
                                        ],
                                        if (showOpenConfirmHint) ...[
                                          const SizedBox(height: 4),
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              '?�段?��?�?marketTimingStatusLabel�?9:30 後�?確�?�?,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: _PremarketRiskBadge(
                                              risk: premarketRisk),
                                        ),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child:
                                              _ExitSignalBadge(signal: exitSignal),
                                        ),
                                        const SizedBox(height: 6),
                                        // 美�?後�?診斷?��?顯示（若??score�?
                                        if (score != null) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceVariant,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '診斷?��?',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall,
                                                ),
                                                const SizedBox(height: 6),
                                                FutureBuilder<DiagnosisReport>(
                                                  future: getDiagnosisReportStructuredAsync(
                                                    stock,
                                                    score!,
                                                    breakoutStreakByCode:
                                                        breakoutStreakByCode,
                                                    date: DateTime.now(),
                                                  ),
                                                  builder: (context, snap) {
                                                    if (!snap.hasData) {
                                                      return const SizedBox();
                                                    }
                                                    final report = snap.data!;
                                                    // show institution streak chips and confirmed badge
                                                    final inst = report.institutionStreaks;
                                                    final instChips = Row(
                                                      children: [
                                                        Chip(
                                                          label: Text('外�? ${inst['foreign'] ?? 0}'),
                                                          backgroundColor: Colors.blue.shade50,
                                                          avatar: const Icon(Icons.trending_up, size: 16, color: Colors.blue),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Chip(
                                                          label: Text('?�信 ${inst['trust'] ?? 0}'),
                                                          backgroundColor: Colors.purple.shade50,
                                                          avatar: const Icon(Icons.account_balance, size: 16, color: Colors.purple),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Chip(
                                                          label: Text('?��? ${inst['dealer'] ?? 0}'),
                                                          backgroundColor: Colors.amber.shade50,
                                                          avatar: const Icon(Icons.store, size: 16, color: Colors.amber),
                                                        ),
                                                        const Spacer(),
                                                        if (report.confirmed)
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.green.shade700,
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                const Icon(Icons.verified, size: 14, color: Colors.white),
                                                                const SizedBox(width: 6),
                                                                Text('Confirmed', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                                                              ],
                                                            ),
                                                          ),
                                                      ],
                                                    );

                                                    return Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        instChips,
                                                        const SizedBox(height: 6),
                                                        ...report.lines.map((ln) {
                                                          Widget icon = const SizedBox.shrink();
                                                          Color? iconColor;
                                                          if (ln.severity == 'success') {
                                                            icon = const Icon(Icons.check_circle, size: 16);
                                                            iconColor = Colors.green.shade600;
                                                          } else if (ln.severity == 'danger') {
                                                            icon = const Icon(Icons.error_outline, size: 16);
                                                            iconColor = Colors.red.shade600;
                                                          } else if (ln.severity == 'warning') {
                                                            icon = const Icon(Icons.warning_amber_outlined, size: 16);
                                                            iconColor = Colors.orange.shade700;
                                                          } else if (ln.severity == 'info') {
                                                            icon = const Icon(Icons.info_outline, size: 16);
                                                            iconColor = Colors.blue.shade600;
                                                          }

                                                          return Padding(
                                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                                            child: Row(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                SizedBox(width: 22, child: IconTheme(data: IconThemeData(color: iconColor), child: icon)),
                                                                const SizedBox(width: 8),
                                                                Expanded(
                                                                  child: Text(
                                                                    ln.title + (ln.value != null ? ' ${ln.value}' : ''),
                                                                    style: Theme.of(context).textTheme.bodySmall,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Theme(
                                    data: Theme.of(context).copyWith(
                                        dividerColor: Colors.transparent),
                                    child: ExpansionTile(
                                      initiallyExpanded: expandDetailsByDefault,
                                      tilePadding: EdgeInsets.zero,
                                      childrenPadding: EdgeInsets.zero,
                                      title: Text(
                                        '?�出規�?',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                      children: [
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            entryPrice == null ||
                                                    pnlPercent == null ||
                                                    lots == null
                                                ? '?�設定�??��??�本/張數�?
                                                : '?�本 ${entryPrice!.toStringAsFixed(2)}  張數 ${lots!.toStringAsFixed(lots! % 1 == 0 ? 0 : 2)}  ?��? ${pnlPercent! >= 0 ? '+' : ''}${pnlPercent!.toStringAsFixed(2)}%${pnlAmount == null ? '' : ' (${pnlAmount! >= 0 ? '+' : ''}${_formatCurrency(pnlAmount!)})'}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '建議?�場 保�? ${entryPlan.conservativeEntry.toStringAsFixed(2)} / 積極 ${entryPlan.aggressiveEntry.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '?�追高�???> ${entryPlan.avoidAbovePrice.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '?�場規�? ?��? ${entryPlan.stopLossPrice.toStringAsFixed(2)} / ?�利 ${entryPlan.takeProfitPrice.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '保�?估�?$estimateScopeLabel ?��? ${conservativeTargetSpacePercent >= 0 ? '+' : ''}${conservativeTargetSpacePercent.toStringAsFixed(2)}%｜風??-${conservativeRiskSpacePercent.abs().toStringAsFixed(2)}%｜R ${conservativeR == null ? '-' : conservativeR.toStringAsFixed(2)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '保�??��? ?�利 ${conservativeEstimatedProfitAmount >= 0 ? '+' : ''}${_formatCurrency(conservativeEstimatedProfitAmount)} / ?��? -${_formatCurrency(conservativeEstimatedLossAmount.abs())}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                        Theme(
                                          data: Theme.of(context).copyWith(
                                              dividerColor: Colors.transparent),
                                          child: ExpansionTile(
                                            initiallyExpanded:
                                                expandAggressiveEstimateByDefault,
                                            tilePadding: EdgeInsets.zero,
                                            childrenPadding: EdgeInsets.zero,
                                            title: Text(
                                              '?��?積極估�?',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: scheme.error,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            children: [
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '積極估�?$estimateScopeLabel ?��? ${aggressiveTargetSpacePercent >= 0 ? '+' : ''}${aggressiveTargetSpacePercent.toStringAsFixed(2)}%｜風??-${aggressiveRiskSpacePercent.abs().toStringAsFixed(2)}%｜R ${aggressiveR == null ? '-' : aggressiveR.toStringAsFixed(2)}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme.error,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ),
                                              Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  '積極?��? ?�利 ${aggressiveEstimatedProfitAmount >= 0 ? '+' : ''}${_formatCurrency(aggressiveEstimatedProfitAmount)} / ?��? -${_formatCurrency(aggressiveEstimatedLossAmount.abs())}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: scheme.error,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            '?�交??${_formatCurrency(stock.tradeValue)}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '依�??�風??,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  if (bullishRationales.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        entrySignal.type ==
                                                _EntrySignalType.strong
                                            ? '強勢依�?�?{bullishRationales.join('�?)}'
                                            : '?�場依�?�?{bullishRationales.join('�?)}',
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '?��?：此?��?件命中說?��??��?證�?漲�?請搭?��??�控管�?,
                                        style:
                                            Theme.of(context).textTheme.labelSmall,
                                      ),
                                    ),
                                  ],
                                  if (showOpenConfirmHint) ...[
                                    const SizedBox(height: 4),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        '?�段?��?�?marketTimingStatusLabel�?9:30 後�?確�?�?,
                                        style:
                                            Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child:
                                        _PremarketRiskBadge(risk: premarketRisk),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: _ExitSignalBadge(signal: exitSignal),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '?�出規�?',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      entryPrice == null ||
                                              pnlPercent == null ||
                                              lots == null
                                          ? '?�設定�??��??�本/張數�?
                                          : '?�本 ${entryPrice!.toStringAsFixed(2)}  張數 ${lots!.toStringAsFixed(lots! % 1 == 0 ? 0 : 2)}  ?��? ${pnlPercent! >= 0 ? '+' : ''}${pnlPercent!.toStringAsFixed(2)}%${pnlAmount == null ? '' : ' (${pnlAmount! >= 0 ? '+' : ''}${_formatCurrency(pnlAmount!)})'}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '建議?�場 保�? ${entryPlan.conservativeEntry.toStringAsFixed(2)} / 積極 ${entryPlan.aggressiveEntry.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '?�追高�???> ${entryPlan.avoidAbovePrice.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '?�場規�? ?��? ${entryPlan.stopLossPrice.toStringAsFixed(2)} / ?�利 ${entryPlan.takeProfitPrice.toStringAsFixed(2)}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '保�?估�?$estimateScopeLabel ?��? ${conservativeTargetSpacePercent >= 0 ? '+' : ''}${conservativeTargetSpacePercent.toStringAsFixed(2)}%｜風??-${conservativeRiskSpacePercent.abs().toStringAsFixed(2)}%｜R ${conservativeR == null ? '-' : conservativeR.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '保�??��? ?�利 ${conservativeEstimatedProfitAmount >= 0 ? '+' : ''}${_formatCurrency(conservativeEstimatedProfitAmount)} / ?��? -${_formatCurrency(conservativeEstimatedLossAmount.abs())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '積極估�?$estimateScopeLabel ?��? ${aggressiveTargetSpacePercent >= 0 ? '+' : ''}${aggressiveTargetSpacePercent.toStringAsFixed(2)}%｜風??-${aggressiveRiskSpacePercent.abs().toStringAsFixed(2)}%｜R ${aggressiveR == null ? '-' : aggressiveR.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '積極?��? ?�利 ${aggressiveEstimatedProfitAmount >= 0 ? '+' : ''}${_formatCurrency(aggressiveEstimatedProfitAmount)} / ?��? -${_formatCurrency(aggressiveEstimatedLossAmount.abs())}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: scheme.error,
                                          ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '?�交??${_formatCurrency(stock.tradeValue)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isNarrowCard) ...[
                      const SizedBox(width: 10),
                      changeSummaryChip,
                    ],
                  ],
                ),
                if (isNarrowCard) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: changeSummaryChip,
                  ),
                ],
                const SizedBox(height: 8),
                actionButtons,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntrySignalBadge extends StatelessWidget {
  const _EntrySignalBadge({required this.signal});

  final _EntrySignal signal;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (signal.type) {
      _EntrySignalType.strong => (Colors.red, Colors.white),
      _EntrySignalType.watch => (Colors.blue, Colors.white),
      _EntrySignalType.wait => (
          Theme.of(context).colorScheme.secondaryContainer,
          Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      _EntrySignalType.avoid => (Colors.orange, Colors.white),
      _EntrySignalType.neutral => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '?�場�?{signal.label}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _PremarketRiskBadge extends StatelessWidget {
  const _PremarketRiskBadge({required this.risk});

  final _PremarketRisk risk;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (risk.type) {
      _PremarketRiskType.high => (Colors.red, Colors.white),
      _PremarketRiskType.medium => (Colors.orange, Colors.white),
      _PremarketRiskType.low => (
          Theme.of(context).colorScheme.tertiaryContainer,
          Theme.of(context).colorScheme.onTertiaryContainer,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '?��?風險�?{risk.label}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MarketTimingBanner extends StatelessWidget {
  const _MarketTimingBanner({
    required this.status,
    required this.autoRefreshEnabled,
    required this.autoRefreshMinutes,
  });

  final _MarketTimingStatus status;
  final bool autoRefreshEnabled;
  final int autoRefreshMinutes;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (status.type) {
      _MarketTimingType.premarket => (
          Theme.of(context).colorScheme.secondaryContainer,
          Theme.of(context).colorScheme.onSecondaryContainer,
          Icons.schedule,
        ),
      _MarketTimingType.openConfirm => (
          Theme.of(context).colorScheme.tertiaryContainer,
          Theme.of(context).colorScheme.onTertiaryContainer,
          Icons.warning_amber_rounded,
        ),
      _MarketTimingType.tradable => (
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.onPrimaryContainer,
          Icons.check_circle_outline,
        ),
      _MarketTimingType.closed => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
          Icons.nightlight_round,
        ),
    };

    return Card(
      color: background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, color: foreground),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '?��??�段�?{status.label}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: foreground,
                        ),
                  ),
                  Text(
                    status.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: foreground,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              autoRefreshEnabled ? '�?${autoRefreshMinutes} ?? : '?��??�新',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketNewsCard extends StatelessWidget {
  const _MarketNewsCard({
    required this.snapshot,
    required this.topicStrengths,
    required this.isLoading,
    required this.error,
    required this.autoDefensiveOnHighNewsRisk,
    required this.isHighNewsRiskDefenseActive,
    required this.onRetry,
    required this.onOpenNews,
  });

  final MarketNewsSnapshot? snapshot;
  final List<({String tag, int score})> topicStrengths;
  final bool isLoading;
  final String? error;
  final bool autoDefensiveOnHighNewsRisk;
  final bool isHighNewsRiskDefenseActive;
  final VoidCallback onRetry;
  final ValueChanged<String> onOpenNews;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(child: Text('?��?風險?��??�新�?..')),
            ],
          ),
        ),
      );
    }

    if (error != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '?��?風險?��??��?不可??,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(error!),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('?�試?��??�新'),
              ),
            ],
          ),
        ),
      );
    }

    final data = snapshot;
    if (data == null) {
      return const SizedBox.shrink();
    }

    final (background, foreground, label) = switch (data.level) {
      NewsRiskLevel.high => (Colors.red, Colors.white, '?��?'),
      NewsRiskLevel.medium => (Colors.orange, Colors.white, '中�?'),
      NewsRiskLevel.low => (Colors.teal, Colors.white, '?��?'),
    };

    final topNews = data.items.take(3).toList();
    final latestNews = topNews.isEmpty ? null : topNews.first;
    final keywordHits = <String>{
      for (final item in topNews) ...item.matchedKeywords,
    }.toList();
    final topicTags = topicStrengths;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '?��?風險�?label (${data.riskScore})',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onRetry,
                  child: const Text('?�新?��?'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              data.summary,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (keywordHits.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '?�中?�鍵�?,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: keywordHits
                    .take(8)
                    .map(
                      (keyword) => Chip(
                        label: Text(keyword),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (topicTags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '?��?議�?',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: topicTags
                    .take(6)
                    .map(
                      (topic) => Chip(
                        label: Text('${topic.tag} ${topic.score}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (latestNews != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: () => onOpenNews(latestNews.link),
                child: Row(
                  children: [
                    const Icon(Icons.article_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        latestNews.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  '?��??��??�細${topNews.isEmpty ? '' : '�?{topNews.length} ?��?'}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                children: [
                  Text(
                    autoDefensiveOnHighNewsRisk
                        ? (isHighNewsRiskDefenseActive
                            ? '?�大事件模�?：已?��?保�?策略'
                            : '?�大事件模�?：已?�用（�?風險?�自?��?保�?�?)
                        : '?�大事件模�?：已?��?',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '?�新?��?�?{_formatNewsTime(data.asOf)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                  if (topNews.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...topNews.map(
                      (news) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.article_outlined, size: 18),
                        title: Text(
                          news.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${news.source}�?{_formatNewsTime(news.publishedAt)}',
                        ),
                        onTap: () => onOpenNews(news.link),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNewsTime(DateTime? time) {
  if (time == null) {
    return '-';
  }

  final now = DateTime.now();
  final diff = now.difference(time.toLocal());
  if (diff.inMinutes < 1) {
    return '?��?';
  }
  if (diff.inMinutes < 60) {
    return '${diff.inMinutes} ?��???;
  }
  if (diff.inHours < 24) {
    return '${diff.inHours} 小�???;
  }
  return '${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class _SignalLegend extends StatelessWidget {
  const _SignalLegend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '訊�??��?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: const [
                _LegendTag(text: '?�場：強?�進場', bgColor: Colors.red),
                _LegendTag(text: '?�場：�?察進場', bgColor: Colors.blue),
                _LegendTag(text: '?�場：�?待�???, bgColor: Colors.teal),
                _LegendTag(text: '?�場：避?�追�?, bgColor: Colors.orange),
                _LegendTag(text: '?�場：未?�用', bgColor: Colors.grey),
                _LegendTag(text: '?�場：�??�警�?, bgColor: Colors.red),
                _LegendTag(text: '?�場：�??��???, bgColor: Colors.indigo),
                _LegendTag(text: '?�場：�??��?�?, bgColor: Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendTag extends StatelessWidget {
  const _LegendTag({
    required this.text,
    required this.bgColor,
  });

  final String text;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: CircleAvatar(
        backgroundColor: color,
        child: Text(
          '$count',
          style: const TextStyle(color: Colors.white, fontSize: 11),
        ),
      ),
      label: Text(label),
    );
  }
}

class _ExitSignalBadge extends StatelessWidget {
  const _ExitSignalBadge({required this.signal});

  final _ExitSignal signal;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (signal.type) {
      _ExitSignalType.danger => (Colors.red, Colors.white),
      _ExitSignalType.profit => (Colors.blue, Colors.white),
      _ExitSignalType.caution => (Colors.orange, Colors.white),
      _ExitSignalType.hold => (
          Theme.of(context).colorScheme.secondaryContainer,
          Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      _ExitSignalType.neutral => (
          Theme.of(context).colorScheme.surfaceContainerHighest,
          Theme.of(context).colorScheme.onSurfaceVariant,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '?�場�?{signal.label}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _HoldingBadge extends StatelessWidget {
  const _HoldingBadge();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '庫�?',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _formatWithThousandsSeparator(int value) {
  final text = value.toString();
  return text.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}

String _formatCurrency(num value) {
  final rounded = value.round();
  final absText = rounded.abs().toString();
  final formatted = absText.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
  return 'NT\$$formatted';
}

class _PositionInput {
  const _PositionInput({
    this.entryPrice,
    this.lots,
    this.clear = false,
  });

  final double? entryPrice;
  final double? lots;
  final bool clear;
}

class _BatchCostResult {
  const _BatchCostResult({
    required this.averagePrice,
    required this.totalLots,
  });

  final double averagePrice;
  final double totalLots;
}

class _FilterState {
  const _FilterState({
    required this.enabled,
    required this.onlyRising,
    required this.maxPrice,
    required this.minVolume,
    required this.useRelativeVolumeFilter,
    required this.relativeVolumePercent,
    required this.minTradeValue,
    required this.enableScoring,
    required this.limitTopCandidates,
    required this.autoRefreshEnabled,
    required this.lockSelectionParameters,
    required this.autoApplyRecommendedMode,
    required this.autoApplyOnlyTradingMorning,
    required this.autoRefreshMinutes,
    required this.requireOpenConfirm,
    required this.autoDefensiveOnHighNewsRisk,
    required this.autoApplyNewsEventTemplate,
    required this.autoRestoreNewsEventTemplateAfterDays,
    required this.autoRegimeEnabled,
    required this.timeSegmentTuningEnabled,
    required this.sectorRulesText,
    required this.excludeOverheated,
    required this.maxChaseChangePercent,
    required this.enableExitSignal,
    required this.holdingNotifyIncludeCaution,
    required this.enableAutoRiskAdjustment,
    required this.mobileUiDensity,
    required this.mobileTextScale,
    required this.autoRiskAdjustmentStrength,
    required this.expandAggressiveEstimateByDefault,
    required this.expandCardDetailsByDefault,
    required this.stopLossPercent,
    required this.takeProfitPercent,
    required this.enableTrailingStop,
    required this.trailingPullbackPercent,
    required this.enableAdaptiveAtrExit,
    required this.atrTakeProfitMultiplier,
    required this.cooldownDays,
    required this.enableScoreTierSizing,
    required this.enableSectorRotationBoost,
    required this.enableBreakoutQuality,
    required this.breakoutMinVolumeRatioPercent,
    required this.enableChipConcentrationFilter,
    required this.minChipConcentrationPercent,
    required this.concentrationWeight,
    required this.tradeValueWeight,
    required this.enableMasterTrapFilter,
    required this.masterTrapDropPercent,
    required this.enableRiskRewardPrefilter,
    required this.minRiskRewardRatioX100,
    required this.enableMultiDayBreakout,
    required this.minBreakoutStreakDays,
    required this.enableFalseBreakoutProtection,
    required this.enableMarketBreadthFilter,
    required this.minMarketBreadthRatioX100,
    required this.enableEventRiskExclusion,
    required this.enableEventCalendarWindow,
    required this.eventCalendarGuardDays,
    required this.enableRevenueMomentumFilter,
    required this.minRevenueMomentumScore,
    required this.enableEarningsSurpriseFilter,
    required this.minEarningsSurpriseScore,
    required this.enableOvernightGapRiskGuard,
    required this.enableSectorExposureCap,
    required this.maxHoldingPerSector,
    required this.breakoutStageMode,
    required this.enableWeeklyWalkForwardAutoTune,
    required this.manualLossStreak,
    required this.minScore,
    required this.volumeWeight,
    required this.changeWeight,
    required this.priceWeight,
    // fund?�flow / margin options
    required this.enableForeignFlowFilter,
    required this.minForeignNet,
    required this.enableTrustFlowFilter,
    required this.minTrustNet,
    required this.enableDealerFlowFilter,
    required this.minDealerNet,
    required this.enableMarginDiffFilter,
    required this.minMarginBalanceDiff,
  });

  final bool enabled;
  final bool onlyRising;
  final int maxPrice;
  final int minVolume;
  final bool useRelativeVolumeFilter;
  final int relativeVolumePercent;
  final int minTradeValue;
  final bool enableScoring;
  final bool limitTopCandidates;
  final bool autoRefreshEnabled;
  final bool lockSelectionParameters;
  final bool autoApplyRecommendedMode;
  final bool autoApplyOnlyTradingMorning;
  final int autoRefreshMinutes;
  final bool requireOpenConfirm;
  final bool autoDefensiveOnHighNewsRisk;
  final bool autoApplyNewsEventTemplate;
  final int autoRestoreNewsEventTemplateAfterDays;
  final bool autoRegimeEnabled;
  final bool timeSegmentTuningEnabled;
  final String sectorRulesText;
  final bool excludeOverheated;
  final int maxChaseChangePercent;
  final bool enableExitSignal;
  final bool holdingNotifyIncludeCaution;
  final bool enableAutoRiskAdjustment;
  final _MobileUiDensity mobileUiDensity;
  final _MobileTextScale mobileTextScale;
  final int autoRiskAdjustmentStrength;
  final bool expandAggressiveEstimateByDefault;
  final bool expandCardDetailsByDefault;
  final int stopLossPercent;
  final int takeProfitPercent;
  final bool enableTrailingStop;
  final int trailingPullbackPercent;
  final bool enableAdaptiveAtrExit;
  final int atrTakeProfitMultiplier;
  final int cooldownDays;
  final bool enableScoreTierSizing;
  final bool enableSectorRotationBoost;
  final bool enableBreakoutQuality;
  final int breakoutMinVolumeRatioPercent;
  final bool enableChipConcentrationFilter;
  final double minChipConcentrationPercent;
  final int concentrationWeight;
  final int tradeValueWeight;
  final bool enableMasterTrapFilter;
  final double masterTrapDropPercent;
  final bool enableRiskRewardPrefilter;
  final int minRiskRewardRatioX100;
  final bool enableMultiDayBreakout;
  final int minBreakoutStreakDays;
  final bool enableFalseBreakoutProtection;
  final bool enableMarketBreadthFilter;
  final int minMarketBreadthRatioX100;
  final bool enableEventRiskExclusion;
  final bool enableEventCalendarWindow;
  final int eventCalendarGuardDays;
  final bool enableRevenueMomentumFilter;
  final int minRevenueMomentumScore;
  final bool enableEarningsSurpriseFilter;
  final int minEarningsSurpriseScore;
  final bool enableOvernightGapRiskGuard;
  final bool enableSectorExposureCap;
  final int maxHoldingPerSector;
  final BreakoutMode breakoutStageMode;
  final bool enableWeeklyWalkForwardAutoTune;
  final int manualLossStreak;
  final int minScore;
  final int volumeWeight;
  final int changeWeight;
  final int priceWeight;
  final bool enableForeignFlowFilter;
  final int minForeignNet;
  final bool enableTrustFlowFilter;
  final int minTrustNet;
  final bool enableDealerFlowFilter;
  final int minDealerNet;
  final bool enableMarginDiffFilter;
  final int minMarginBalanceDiff;
}

class _EntrySignal {
  const _EntrySignal({required this.label, required this.type});

  final String label;
  final _EntrySignalType type;
}

class _ModeRecommendation {
  const _ModeRecommendation({required this.mode, required this.reason});

  final BreakoutMode mode;
  final String reason;
}

class _RiskSnapshot {
  const _RiskSnapshot({required this.score, required this.level});

  final int score;
  final String level;
}

class _RiskScorePoint {
  const _RiskScorePoint({required this.date, required this.score});

  final DateTime date;
  final int score;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'score': score,
    };
  }

  static _RiskScorePoint? fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse((json['date'] ?? '').toString());
    final score = int.tryParse((json['score'] ?? '').toString());
    if (date == null || score == null) {
      return null;
    }
    return _RiskScorePoint(date: date, score: score.clamp(0, 100));
  }
}

class _CandidateDriftRecord {
  const _CandidateDriftRecord({
    required this.timestamp,
    required this.type,
    required this.addedCount,
    required this.removedCount,
    required this.changedFilters,
  });

  final DateTime timestamp;
  final String type;
  final int addedCount;
  final int removedCount;
  final List<String> changedFilters;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'type': type,
      'addedCount': addedCount,
      'removedCount': removedCount,
      'changedFilters': changedFilters,
    };
  }

  static _CandidateDriftRecord? fromJson(Map<String, dynamic> json) {
    final timestamp =
        DateTime.tryParse((json['timestamp'] ?? '').toString());
    final type = (json['type'] ?? '').toString().trim();
    final addedCount = int.tryParse((json['addedCount'] ?? '').toString()) ?? 0;
    final removedCount =
        int.tryParse((json['removedCount'] ?? '').toString()) ?? 0;
    final rawFilters = json['changedFilters'];
    final changedFilters = <String>[];
    if (rawFilters is List) {
      for (final item in rawFilters) {
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          changedFilters.add(text);
        }
      }
    }

    if (timestamp == null || type.isEmpty) {
      return null;
    }

    return _CandidateDriftRecord(
      timestamp: timestamp,
      type: type,
      addedCount: addedCount,
      removedCount: removedCount,
      changedFilters: changedFilters,
    );
  }
}

class _DailyFilterStats {
  const _DailyFilterStats({
    required this.dateKey,
    required this.reasonCounts,
  });

  final String dateKey;
  final Map<String, int> reasonCounts;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'reasonCounts': reasonCounts,
    };
  }

  static _DailyFilterStats? fromJson(Map<String, dynamic> json) {
    final dateKey = (json['dateKey'] ?? '').toString().trim();
    final raw = json['reasonCounts'];
    final map = <String, int>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = k.toString();
        final val = int.tryParse(v.toString());
        if (val != null) map[key] = val;
      });
    }
    if (dateKey.isEmpty) return null;
    return _DailyFilterStats(dateKey: dateKey, reasonCounts: map);
  }
}

class _DailyCandidateSnapshot {
  const _DailyCandidateSnapshot({
    required this.dateKey,
    required this.capturedAt,
    required this.coreCandidateCodes,
    required this.limitedCandidateCodes,
    required this.strongOnlyCodes,
  });

  final String dateKey;
  final DateTime capturedAt;
  final List<String> coreCandidateCodes;
  final List<String> limitedCandidateCodes;
  final List<String> strongOnlyCodes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'capturedAt': capturedAt.toIso8601String(),
      'coreCandidateCodes': coreCandidateCodes,
      'limitedCandidateCodes': limitedCandidateCodes,
      'strongOnlyCodes': strongOnlyCodes,
    };
  }

  static _DailyCandidateSnapshot? fromJson(Map<String, dynamic> json) {
    final dateKey = (json['dateKey'] ?? '').toString().trim();
    final capturedAt = DateTime.tryParse((json['capturedAt'] ?? '').toString());

    List<String> parseList(dynamic raw) {
      final output = <String>[];
      if (raw is List) {
        for (final item in raw) {
          final text = item.toString().trim();
          if (text.isNotEmpty) {
            output.add(text);
          }
        }
      }
      output.sort();
      return output;
    }

    if (dateKey.isEmpty || capturedAt == null) {
      return null;
    }

    return _DailyCandidateSnapshot(
      dateKey: dateKey,
      capturedAt: capturedAt,
      coreCandidateCodes: parseList(json['coreCandidateCodes']),
      limitedCandidateCodes: parseList(json['limitedCandidateCodes']),
      strongOnlyCodes: parseList(json['strongOnlyCodes']),
    );
  }
}

class _DailyPredictionRow {
  const _DailyPredictionRow({
    required this.code,
    required this.stockName,
    required this.signalType,
    required this.rank,
    required this.score,
    required this.inCore,
    required this.inTop20,
    required this.inStrong,
  });

  final String code;
  final String stockName;
  final String signalType;
  final int rank;
  final int score;
  final bool inCore;
  final bool inTop20;
  final bool inStrong;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'stockName': stockName,
      'signalType': signalType,
      'rank': rank,
      'score': score,
      'inCore': inCore,
      'inTop20': inTop20,
      'inStrong': inStrong,
    };
  }

  String toCsvKey() {
    return '$code|$signalType|$rank|$score|$inCore|$inTop20|$inStrong';
  }

  static _DailyPredictionRow? fromJson(Map<String, dynamic> json) {
    final code = (json['code'] ?? '').toString().trim();
    final stockName = (json['stockName'] ?? '').toString().trim();
    final signalType = (json['signalType'] ?? '').toString().trim();
    final rank = int.tryParse((json['rank'] ?? '').toString()) ?? 0;
    final score = int.tryParse((json['score'] ?? '').toString()) ?? 0;
    if (code.isEmpty || rank <= 0) {
      return null;
    }

    return _DailyPredictionRow(
      code: code,
      stockName: stockName,
      signalType: signalType.isEmpty ? 'wait' : signalType,
      rank: rank,
      score: score,
      inCore: (json['inCore'] == true) || (json['inCore'].toString() == '1'),
      inTop20:
          (json['inTop20'] == true) || (json['inTop20'].toString() == '1'),
      inStrong:
          (json['inStrong'] == true) || (json['inStrong'].toString() == '1'),
    );
  }
}

class _DailyPredictionSnapshot {
  const _DailyPredictionSnapshot({
    required this.dateKey,
    required this.capturedAt,
    required this.rows,
  });

  final String dateKey;
  final DateTime capturedAt;
  final List<_DailyPredictionRow> rows;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'capturedAt': capturedAt.toIso8601String(),
      'rows': rows.map((row) => row.toJson()).toList(),
    };
  }

  static _DailyPredictionSnapshot? fromJson(Map<String, dynamic> json) {
    final dateKey = (json['dateKey'] ?? '').toString().trim();
    final capturedAt = DateTime.tryParse((json['capturedAt'] ?? '').toString());
    if (dateKey.isEmpty || capturedAt == null) {
      return null;
    }
    final rows = <_DailyPredictionRow>[];
    final rawRows = json['rows'];
    if (rawRows is List) {
      for (final item in rawRows) {
        if (item is Map) {
          final parsed =
              _DailyPredictionRow.fromJson(Map<String, dynamic>.from(item));
          if (parsed != null) {
            rows.add(parsed);
          }
        }
      }
    }
    return _DailyPredictionSnapshot(
      dateKey: dateKey,
      capturedAt: capturedAt,
      rows: rows,
    );
  }
}

class _DailyContextSnapshot {
  const _DailyContextSnapshot({
    required this.dateKey,
    required this.capturedAt,
    required this.marketBreadthRatio,
    required this.newsRiskLevel,
    required this.breakoutMode,
    required this.marketRegime,
    required this.keyParamsHash,
  });

  final String dateKey;
  final DateTime capturedAt;
  final double marketBreadthRatio;
  final String newsRiskLevel;
  final String breakoutMode;
  final String marketRegime;
  final String keyParamsHash;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dateKey': dateKey,
      'capturedAt': capturedAt.toIso8601String(),
      'marketBreadthRatio': marketBreadthRatio,
      'newsRiskLevel': newsRiskLevel,
      'breakoutMode': breakoutMode,
      'marketRegime': marketRegime,
      'keyParamsHash': keyParamsHash,
    };
  }

  static _DailyContextSnapshot? fromJson(Map<String, dynamic> json) {
    final dateKey = (json['dateKey'] ?? '').toString().trim();
    final capturedAt = DateTime.tryParse((json['capturedAt'] ?? '').toString());
    final breadth =
        double.tryParse((json['marketBreadthRatio'] ?? '').toString()) ?? 1.0;
    final newsRiskLevel = (json['newsRiskLevel'] ?? '').toString().trim();
    final breakoutMode = (json['breakoutMode'] ?? '').toString().trim();
    final marketRegime = (json['marketRegime'] ?? '').toString().trim();
    final keyParamsHash = (json['keyParamsHash'] ?? '').toString().trim();
    if (dateKey.isEmpty || capturedAt == null) {
      return null;
    }
    return _DailyContextSnapshot(
      dateKey: dateKey,
      capturedAt: capturedAt,
      marketBreadthRatio: breadth,
      newsRiskLevel: newsRiskLevel,
      breakoutMode: breakoutMode,
      marketRegime: marketRegime,
      keyParamsHash: keyParamsHash,
    );
  }
}

class _AutoTuneSuggestion {
  const _AutoTuneSuggestion({
    required this.id,
    required this.title,
    required this.summary,
    required this.minScore,
    required this.maxChaseChangePercent,
    required this.minTradeValue,
  });

  final String id;
  final String title;
  final String summary;
  final int minScore;
  final int maxChaseChangePercent;
  final int minTradeValue;
}

class _ParameterChangeAuditEntry {
  const _ParameterChangeAuditEntry({
    required this.timestamp,
    required this.source,
    required this.changes,
  });

  final DateTime timestamp;
  final String source;
  final List<String> changes;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'changes': changes,
    };
  }

  static _ParameterChangeAuditEntry? fromJson(Map<String, dynamic> json) {
    final timestamp =
        DateTime.tryParse((json['timestamp'] ?? '').toString());
    final source = (json['source'] ?? '').toString().trim();
    final rawChanges = json['changes'];
    final changes = <String>[];
    if (rawChanges is List) {
      for (final item in rawChanges) {
        final text = item.toString().trim();
        if (text.isNotEmpty) {
          changes.add(text);
        }
      }
    }

    if (timestamp == null || source.isEmpty || changes.isEmpty) {
      return null;
    }

    return _ParameterChangeAuditEntry(
      timestamp: timestamp,
      source: source,
      changes: changes,
    );
  }
}

class _SignalTrackEntry {
  _SignalTrackEntry({
    required this.date,
    required this.stockCode,
    required this.stockName,
    required this.signalType,
    required this.entryPrice,
    this.return1Day,
    this.return3Day,
    this.return5Day,
  });

  final DateTime date;
  final String stockCode;
  final String stockName;
  final _EntrySignalType signalType;
  final double entryPrice;
  double? return1Day;
  double? return3Day;
  double? return5Day;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'date': date.toIso8601String(),
      'stockCode': stockCode,
      'stockName': stockName,
      'signalType': signalType.name,
      'entryPrice': entryPrice,
      'return1Day': return1Day,
      'return3Day': return3Day,
      'return5Day': return5Day,
    };
  }

  static _SignalTrackEntry? fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse((json['date'] ?? '').toString());
    final stockCode = (json['stockCode'] ?? '').toString();
    final stockName = (json['stockName'] ?? '').toString();
    final typeRaw = (json['signalType'] ?? '').toString();
    final entryPrice =
        double.tryParse((json['entryPrice'] ?? '').toString()) ?? 0;

    if (date == null ||
        stockCode.isEmpty ||
        stockName.isEmpty ||
        entryPrice <= 0) {
      return null;
    }

    final signalType = _EntrySignalType.values.firstWhere(
      (e) => e.name == typeRaw,
      orElse: () => _EntrySignalType.wait,
    );

    return _SignalTrackEntry(
      date: date,
      stockCode: stockCode,
      stockName: stockName,
      signalType: signalType,
      entryPrice: entryPrice,
      return1Day: double.tryParse((json['return1Day'] ?? '').toString()),
      return3Day: double.tryParse((json['return3Day'] ?? '').toString()),
      return5Day: double.tryParse((json['return5Day'] ?? '').toString()),
    );
  }
}

class _SignalPerformanceSummary {
  const _SignalPerformanceSummary({
    required this.sampleSize,
    required this.day1Count,
    required this.day3Count,
    required this.day5Count,
    required this.day1Avg,
    required this.day3Avg,
    required this.day5Avg,
    required this.day1WinRate,
    required this.day3WinRate,
    required this.day5WinRate,
    required this.day1MaxDrawdown,
    required this.day3MaxDrawdown,
    required this.day5MaxDrawdown,
  });

  const _SignalPerformanceSummary.empty()
      : sampleSize = 0,
        day1Count = 0,
        day3Count = 0,
        day5Count = 0,
        day1Avg = 0,
        day3Avg = 0,
        day5Avg = 0,
        day1WinRate = 0,
        day3WinRate = 0,
        day5WinRate = 0,
        day1MaxDrawdown = 0,
        day3MaxDrawdown = 0,
        day5MaxDrawdown = 0;

  final int sampleSize;
  final int day1Count;
  final int day3Count;
  final int day5Count;
  final double day1Avg;
  final double day3Avg;
  final double day5Avg;
  final double day1WinRate;
  final double day3WinRate;
  final double day5WinRate;
  final double day1MaxDrawdown;
  final double day3MaxDrawdown;
  final double day5MaxDrawdown;
}

class _PremarketRisk {
  const _PremarketRisk({required this.label, required this.type});

  final String label;
  final _PremarketRiskType type;
}

class _MarketTimingStatus {
  const _MarketTimingStatus({
    required this.label,
    required this.description,
    required this.type,
  });

  final String label;
  final String description;
  final _MarketTimingType type;
}

class _EntryPlan {
  const _EntryPlan({
    required this.conservativeEntry,
    required this.aggressiveEntry,
    required this.avoidAbovePrice,
    required this.stopLossPrice,
    required this.takeProfitPrice,
  });

  final double conservativeEntry;
  final double aggressiveEntry;
  final double avoidAbovePrice;
  final double stopLossPrice;
  final double takeProfitPrice;
}

enum _EntrySignalType {
  strong,
  watch,
  wait,
  avoid,
  neutral,
}

enum _PremarketRiskType {
  high,
  medium,
  low,
}

enum _MarketTimingType {
  premarket,
  openConfirm,
  tradable,
  closed,
}

class _ExitSignal {
  const _ExitSignal({required this.label, required this.type});

  final String label;
  final _ExitSignalType type;
}

enum _ExitSignalType {
  danger,
  profit,
  caution,
  hold,
  neutral,
}

class _ScoredStock {
  const _ScoredStock({
    required this.stock,
    required this.score,
  });

  final StockModel stock;
  final int score;
}

class _StrategyPreset {
  const _StrategyPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.onlyRising,
    required this.maxPrice,
    required this.minVolume,
    required this.minTradeValue,
    required this.enableScoring,
    required this.minScore,
    required this.volumeWeight,
    required this.changeWeight,
    required this.priceWeight,
  });

  final String id;
  final String label;
  final String description;
  final bool onlyRising;
  final int maxPrice;
  final int minVolume;
  final int minTradeValue;
  final bool enableScoring;
  final int minScore;
  final int volumeWeight;
  final int changeWeight;
  final int priceWeight;
}

class _NewsEventTemplate {
  const _NewsEventTemplate({
    required this.id,
    required this.label,
    required this.adjustmentSummary,
    required this.minScore,
    required this.minTradeValue,
    required this.maxChase,
    required this.stopLoss,
    required this.takeProfit,
    required this.riskBudget,
    required this.triggerKeywords,
  });

  final String id;
  final String label;
  final String adjustmentSummary;
  final int minScore;
  final int minTradeValue;
  final int maxChase;
  final int stopLoss;
  final int takeProfit;
  final int riskBudget;
  final List<String> triggerKeywords;
}

class _SectorRule {
  const _SectorRule({
    required this.start,
    required this.end,
    required this.group,
  });

  final int start;
  final int end;
  final String group;
}

class _TradeJournalEntry {
  const _TradeJournalEntry({
    required this.timestamp,
    required this.stockCode,
    required this.stockName,
    required this.pnlPercent,
    required this.pnlAmount,
    required this.reason,
    required this.strategyTag,
  });

  final DateTime timestamp;
  final String stockCode;
  final String stockName;
  final double pnlPercent;
  final double pnlAmount;
  final String reason;
  final String strategyTag;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'timestamp': timestamp.toIso8601String(),
      'stockCode': stockCode,
      'stockName': stockName,
      'pnlPercent': pnlPercent,
      'pnlAmount': pnlAmount,
      'reason': reason,
      'strategyTag': strategyTag,
    };
  }

  static _TradeJournalEntry? fromJson(Map<String, dynamic> json) {
    final timestamp = DateTime.tryParse((json['timestamp'] ?? '').toString());
    final stockCode = (json['stockCode'] ?? '').toString().trim();
    final stockName = (json['stockName'] ?? '').toString().trim();
    final pnlPercent = double.tryParse((json['pnlPercent'] ?? '').toString());
    final pnlAmount = double.tryParse((json['pnlAmount'] ?? '').toString());
    final reason = (json['reason'] ?? '').toString();
    final rawTag = (json['strategyTag'] ?? 'A').toString().trim().toUpperCase();
    final strategyTag = rawTag == 'B' ? 'B' : 'A';

    if (timestamp == null ||
        stockCode.isEmpty ||
        stockName.isEmpty ||
        pnlPercent == null ||
        pnlAmount == null) {
      return null;
    }

    return _TradeJournalEntry(
      timestamp: timestamp,
      stockCode: stockCode,
      stockName: stockName,
      pnlPercent: pnlPercent,
      pnlAmount: pnlAmount,
      reason: reason,
      strategyTag: strategyTag,
    );
  }
}

enum _MarketRegime {
  bull,
  range,
  defensive,
}

enum _MobileUiDensity {
  comfortable,
  compact,
}

enum _MobileTextScale {
  small,
  medium,
  large,
}

enum _CompactTopAction {
  backtest,
  morningScan,
  tradeJournal,
  testNotification,
}

class _TradeJournalPage extends StatefulWidget {
  const _TradeJournalPage({required this.entries});

  final List<_TradeJournalEntry> entries;

  @override
  State<_TradeJournalPage> createState() => _TradeJournalPageState();
}

class _TradeJournalPageState extends State<_TradeJournalPage> {
  int _maxRows = 50;

  @override
  Widget build(BuildContext context) {
    final sorted = List<_TradeJournalEntry>.from(widget.entries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final visible = sorted.take(_maxRows).toList();

    final total = visible.length;
    final winCount = visible.where((e) => e.pnlPercent > 0).length;
    final winRate = total == 0 ? 0.0 : (winCount / total) * 100;
    final avgPnlPercent = total == 0
        ? 0.0
        : visible.fold<double>(0.0, (sum, e) => sum + e.pnlPercent) / total;
    final avgPnlAmount = total == 0
        ? 0.0
        : visible.fold<double>(0.0, (sum, e) => sum + e.pnlAmount) / total;
    final totalPnlAmount =
        visible.fold<double>(0.0, (sum, e) => sum + e.pnlAmount);

    _StrategyStats buildStrategyStats(String tag) {
      final rows = visible.where((e) => e.strategyTag == tag).toList();
      final rowCount = rows.length;
      final wins = rows.where((e) => e.pnlPercent > 0).length;
      final strategyWinRate = rowCount == 0 ? 0.0 : (wins / rowCount) * 100;
      final strategyAvgPnl = rowCount == 0
          ? 0.0
          : rows.fold<double>(0.0, (sum, e) => sum + e.pnlPercent) / rowCount;
      return _StrategyStats(
        count: rowCount,
        winRate: strategyWinRate,
        avgPnlPercent: strategyAvgPnl,
      );
    }

    final statsA = buildStrategyStats('A');
    final statsB = buildStrategyStats('B');

    return Scaffold(
      appBar: AppBar(
        title: const Text('交�??��?'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('顯示?��?),
                        const SizedBox(width: 10),
                        DropdownButton<int>(
                          value: _maxRows,
                          items: const [20, 50, 100, 200]
                              .map(
                                (value) => DropdownMenuItem<int>(
                                  value: value,
                                  child: Text('$value �?),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _maxRows = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('?��? ${winRate.toStringAsFixed(1)}%�?winCount/$total�?),
                    Text(
                        '平�??�酬 ${avgPnlPercent >= 0 ? '+' : ''}${avgPnlPercent.toStringAsFixed(2)}%'),
                    Text(
                        '平�??��? ${avgPnlAmount >= 0 ? '+' : ''}${_formatCurrency(avgPnlAmount)}'),
                    Text(
                        '總�???${totalPnlAmount >= 0 ? '+' : ''}${_formatCurrency(totalPnlAmount)}'),
                    const SizedBox(height: 6),
                    Text(
                      'A 策略�?{statsA.count} 筆�??��? ${statsA.winRate.toStringAsFixed(1)}%｜�??�酬 ${statsA.avgPnlPercent >= 0 ? '+' : ''}${statsA.avgPnlPercent.toStringAsFixed(2)}%',
                    ),
                    Text(
                      'B 策略�?{statsB.count} 筆�??��? ${statsB.winRate.toStringAsFixed(1)}%｜�??�酬 ${statsB.avgPnlPercent >= 0 ? '+' : ''}${statsB.avgPnlPercent.toStringAsFixed(2)}%',
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: visible.isEmpty
                ? const Center(child: Text('沒�??�顯示�?交�?紀??))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: visible.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final pnlText =
                          '${item.pnlPercent >= 0 ? '+' : ''}${item.pnlPercent.toStringAsFixed(2)}%';
                      final amountText =
                          '${item.pnlAmount >= 0 ? '+' : ''}${_formatCurrency(item.pnlAmount)}';
                      final color =
                          item.pnlPercent >= 0 ? Colors.red : Colors.green;
                      final timeText =
                          '${item.timestamp.year}-${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')} '
                          '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}';

                      return Card(
                        child: ListTile(
                          title: Text('${item.stockCode} ${item.stockName}'),
                          subtitle: Text(
                              '$timeText｜�???{item.strategyTag}�?{item.reason}'),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                pnlText,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                amountText,
                                style: TextStyle(color: color),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _StrategyStats {
  const _StrategyStats({
    required this.count,
    required this.winRate,
    required this.avgPnlPercent,
  });

  final int count;
  final double winRate;
  final double avgPnlPercent;
}

/// Compare two filter states and return differing fields with values.
// Private helper may be unused in some builds; suppress unused_element lint.
// ignore: unused_element
Map<String, Map<String, dynamic>> _compareFilterStates(
  _FilterState a, _FilterState b) {
  final diffs = <String, Map<String, dynamic>>{};
  void check(String name, dynamic va, dynamic vb) {
    if (va != vb) {
      diffs[name] = {'a': va, 'b': vb};
    }
  }

  check('enabled', a.enabled, b.enabled);
  check('onlyRising', a.onlyRising, b.onlyRising);
  check('maxPrice', a.maxPrice, b.maxPrice);
  check('minVolume', a.minVolume, b.minVolume);
  check('useRelativeVolumeFilter', a.useRelativeVolumeFilter, b.useRelativeVolumeFilter);
  check('relativeVolumePercent', a.relativeVolumePercent, b.relativeVolumePercent);
  check('minTradeValue', a.minTradeValue, b.minTradeValue);
  check('enableScoring', a.enableScoring, b.enableScoring);
  check('limitTopCandidates', a.limitTopCandidates, b.limitTopCandidates);
  check('enableChipConcentrationFilter', a.enableChipConcentrationFilter, b.enableChipConcentrationFilter);
  check('minChipConcentrationPercent', a.minChipConcentrationPercent, b.minChipConcentrationPercent);
  check('concentrationWeight', a.concentrationWeight, b.concentrationWeight);
  check('tradeValueWeight', a.tradeValueWeight, b.tradeValueWeight);
  check('enableMasterTrapFilter', a.enableMasterTrapFilter, b.enableMasterTrapFilter);
  check('masterTrapDropPercent', a.masterTrapDropPercent, b.masterTrapDropPercent);
  // continue with other fields as needed
  return diffs;
}
