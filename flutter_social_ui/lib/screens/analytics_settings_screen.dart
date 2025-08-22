import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../constants.dart';
import '../models/analytics_insight_model.dart';
import '../services/analytics_insights_service.dart';
import '../services/auth_service.dart';

class AnalyticsSettingsScreen extends StatefulWidget {
  final String userId;

  const AnalyticsSettingsScreen({super.key, required this.userId});

  @override
  State<AnalyticsSettingsScreen> createState() =>
      _AnalyticsSettingsScreenState();
}

class _AnalyticsSettingsScreenState extends State<AnalyticsSettingsScreen>
    with SingleTickerProviderStateMixin {
  final AnalyticsInsightsService _analyticsService = AnalyticsInsightsService();
  final AuthService _authService = AuthService();

  late TabController _tabController;
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.month;

  bool _isLoading = true;
  bool _isOwner = false;

  // Analytics data
  List<AnalyticsMetric> _metrics = [];
  List<AnalyticsInsight> _insights = [];
  Map<String, List<AnalyticsDataPoint>> _chartData = {};
  Map<String, dynamic>? _comparisons;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _verifyOwnership();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _verifyOwnership() async {
    final currentUserId = _authService.currentUserId;
    setState(() {
      _isOwner = currentUserId == widget.userId;
    });

    if (_isOwner) {
      await _loadAnalyticsData();
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadAnalyticsData() async {
    if (!_isOwner) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final analyticsData = await _analyticsService.getProfileAnalytics(
        userId: widget.userId,
        period: _selectedPeriod,
        includeComparisons: true,
      );

      setState(() {
        _metrics = analyticsData['metrics'] as List<AnalyticsMetric>;
        _insights = analyticsData['insights'] as List<AnalyticsInsight>;
        _chartData =
            analyticsData['chart_data']
                as Map<String, List<AnalyticsDataPoint>>;
        _comparisons = analyticsData['comparisons'] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Failed to load analytics data: $e');
    }
  }

  void _onPeriodChanged(AnalyticsPeriod period) {
    if (period != _selectedPeriod) {
      setState(() {
        _selectedPeriod = period;
      });
      _loadAnalyticsData();
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  void _handleInsightAction(AnalyticsInsight insight) {
    // Handle insight actions (same as profile screen implementation)
    // final actionType = insight.actionData?['type'] as String?; // Currently unused

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Row(
          children: [
            Icon(insight.type.icon, color: insight.type.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                insight.title,
                style: const TextStyle(color: kTextColor, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              insight.description,
              style: const TextStyle(color: kLightTextColor),
            ),
            if (insight.data.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Details:',
                style: const TextStyle(
                  color: kTextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              ...insight.data.entries.map(
                (e) => Text(
                  '${e.key}: ${e.value}',
                  style: const TextStyle(color: kLightTextColor, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: kPrimaryColor)),
          ),
          if (insight.isActionable)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showComingSoon(insight.actionLabel ?? 'Feature');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text(insight.actionLabel ?? 'Take Action'),
            ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: Text(feature, style: const TextStyle(color: kTextColor)),
        content: Text(
          '$feature functionality is coming soon!',
          style: const TextStyle(color: kLightTextColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: kPrimaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOwner) {
      return Scaffold(
        backgroundColor: kBackgroundColor,
        appBar: AppBar(
          backgroundColor: kCardColor,
          elevation: 0,
          title: const Text(
            'Analytics',
            style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: kTextColor),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: kLightTextColor),
              SizedBox(height: 16),
              Text(
                'Access Denied',
                style: TextStyle(
                  color: kTextColor,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Analytics are only visible to account owners.',
                style: TextStyle(color: kLightTextColor),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kCardColor,
        elevation: 0,
        title: const Text(
          'My Analytics',
          style: TextStyle(color: kTextColor, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: kTextColor),
        ),
        actions: [
          PopupMenuButton<AnalyticsPeriod>(
            icon: const Icon(Icons.date_range, color: kTextColor),
            onSelected: _onPeriodChanged,
            itemBuilder: (context) => AnalyticsPeriod.values
                .map(
                  (period) => PopupMenuItem(
                    value: period,
                    child: Row(
                      children: [
                        Icon(
                          _selectedPeriod == period
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: _selectedPeriod == period
                              ? kPrimaryColor
                              : kLightTextColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          period.label,
                          style: TextStyle(
                            color: _selectedPeriod == period
                                ? kPrimaryColor
                                : kTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kPrimaryColor,
          unselectedLabelColor: kLightTextColor,
          indicatorColor: kPrimaryColor,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Performance'),
            Tab(text: 'Audience'),
            Tab(text: 'Insights'),
          ],
        ),
      ),
      body: _isLoading
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildPerformanceTab(),
                _buildAudienceTab(),
                _buildInsightsTab(),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector skeleton
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 16),
        // Metrics cards skeleton
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: List.generate(
            6,
            (index) => Container(
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Chart skeleton
        Container(
          height: 250,
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        _buildPeriodSelector(),
        const SizedBox(height: 16),

        // Key metrics grid
        _buildMetricsGrid(),
        const SizedBox(height: 24),

        // Performance chart
        _buildPerformanceChart(),
        const SizedBox(height: 24),

        // Quick insights
        _buildQuickInsights(),
      ],
    );
  }

  Widget _buildPerformanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailedMetrics(),
        const SizedBox(height: 24),
        _buildContentPerformance(),
        const SizedBox(height: 24),
        _buildBenchmarkComparison(),
      ],
    );
  }

  Widget _buildAudienceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAudienceOverview(),
        const SizedBox(height: 24),
        _buildAudienceDemographics(),
        const SizedBox(height: 24),
        _buildEngagementPatterns(),
      ],
    );
  }

  Widget _buildInsightsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_insights.isEmpty)
          _buildNoInsights()
        else
          ..._insights.map(_buildInsightCard),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: AnalyticsPeriod.values.take(4).map((period) {
          final isSelected = period == _selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodChanged(period),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  period.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : kLightTextColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMetricsGrid() {
    if (_metrics.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: _metrics.take(6).map(_buildMetricCard).toList(),
    );
  }

  Widget _buildMetricCard(AnalyticsMetric metric) {
    final formattedValue = _formatMetricValue(metric);
    final change = metric.changePercentage;
    final changeText = metric.changeText;
    final isPositive = metric.isPositiveChange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric.label,
            style: const TextStyle(
              color: kLightTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            formattedValue,
            style: const TextStyle(
              color: kTextColor,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (changeText != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  changeText,
                  style: TextStyle(
                    color: isPositive ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (_chartData.isEmpty) {
      return Container(
        height: 250,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'No chart data available',
            style: TextStyle(color: kLightTextColor),
          ),
        ),
      );
    }

    final engagementData = _chartData['engagement'] ?? [];
    if (engagementData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Engagement Trend',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: engagementData.length / 5,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        if (value.toInt() >= engagementData.length)
                          return Container();
                        final date = engagementData[value.toInt()].timestamp;
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            '${date.month}/${date.day}',
                            style: const TextStyle(
                              color: kLightTextColor,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 42,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        return Text(
                          '${value.toInt()}%',
                          style: const TextStyle(
                            color: kLightTextColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: engagementData.length - 1.0,
                minY: 0,
                maxY:
                    engagementData
                        .map((e) => e.value)
                        .reduce((a, b) => a > b ? a : b) +
                    1,
                lineBarsData: [
                  LineChartBarData(
                    spots: engagementData
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
                        .toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.3)],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          kPrimaryColor.withOpacity(0.3),
                          kPrimaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInsights() {
    if (_insights.isEmpty) {
      return const SizedBox.shrink();
    }

    final topInsights = _insights.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Insights',
          style: TextStyle(
            color: kTextColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...topInsights.map(
          (insight) => Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: insight.priority.color.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: insight.type.color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    insight.type.icon,
                    color: insight.type.color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title.replaceAll(RegExp(r'[^\w\s]'), ''),
                        style: const TextStyle(
                          color: kTextColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        insight.description,
                        style: const TextStyle(
                          color: kLightTextColor,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (insight.isActionable)
                  Icon(Icons.chevron_right, color: kLightTextColor, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detailed Performance',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ..._metrics.map(
            (metric) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          metric.label,
                          style: const TextStyle(
                            color: kTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (metric.changeText != null)
                          Text(
                            metric.changeText!,
                            style: TextStyle(
                              color: metric.isPositiveChange
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMetricValue(metric),
                    style: const TextStyle(
                      color: kTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentPerformance() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Performance',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Top performing content analysis coming soon!',
            style: TextStyle(
              color: kLightTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkComparison() {
    if (_comparisons == null) return const SizedBox.shrink();

    final industryAverages =
        _comparisons!['industry_averages'] as Map<String, dynamic>?;
    final userPercentile = _comparisons!['user_percentile'] as int?;
    final category = _comparisons!['category'] as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Industry Benchmark',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (category != null)
            Text(
              'Category: $category',
              style: const TextStyle(
                color: kPrimaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 8),
          if (userPercentile != null)
            Text(
              'You\'re in the ${userPercentile}th percentile',
              style: const TextStyle(color: kLightTextColor),
            ),
          const SizedBox(height: 16),
          if (industryAverages != null)
            ...industryAverages.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      entry.key
                          .replaceAll('_', ' ')
                          .split(' ')
                          .map(
                            (word) => word[0].toUpperCase() + word.substring(1),
                          )
                          .join(' '),
                      style: const TextStyle(color: kLightTextColor),
                    ),
                    Text(
                      '${entry.value}${entry.key.contains('rate') ? '%' : ''}',
                      style: const TextStyle(
                        color: kTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudienceOverview() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Audience Overview',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Detailed audience analytics coming soon!',
            style: TextStyle(
              color: kLightTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceDemographics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demographics',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Age, location, and interest demographics coming soon!',
            style: TextStyle(
              color: kLightTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementPatterns() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Patterns',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Best times to post and engagement pattern analysis coming soon!',
            style: TextStyle(
              color: kLightTextColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(AnalyticsInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: insight.priority.color.withOpacity(0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: insight.isActionable
              ? () => _handleInsightAction(insight)
              : null,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: insight.type.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        insight.type.icon,
                        color: insight.type.color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.title.replaceAll(RegExp(r'[^\w\s]'), ''),
                            style: const TextStyle(
                              color: kTextColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            insight.priority.label,
                            style: TextStyle(
                              color: insight.priority.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (insight.isActionable)
                      const Icon(Icons.chevron_right, color: kLightTextColor),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  insight.description,
                  style: const TextStyle(color: kLightTextColor, height: 1.5),
                ),
                if (insight.isActionable && insight.actionLabel != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => _handleInsightAction(insight),
                        child: Text(
                          insight.actionLabel!,
                          style: const TextStyle(color: kPrimaryColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoInsights() {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Column(
        children: [
          Icon(Icons.lightbulb_outline, size: 64, color: kLightTextColor),
          SizedBox(height: 16),
          Text(
            'No Insights Available',
            style: TextStyle(
              color: kTextColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Keep creating content and engaging with your audience to generate insights!',
            style: TextStyle(color: kLightTextColor),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatMetricValue(AnalyticsMetric metric) {
    switch (metric.type) {
      case MetricType.percentage:
        return '${metric.value.toStringAsFixed(1)}%';
      case MetricType.duration:
        return '${metric.value.toStringAsFixed(0)}${metric.unit}';
      case MetricType.currency:
        return '\$${metric.value.toStringAsFixed(0)}';
      case MetricType.rate:
        return '${metric.value.toStringAsFixed(2)}${metric.unit}';
      case MetricType.count:
      default:
        final intValue = metric.value.toInt();
        return _formatNumber(intValue);
    }
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
