import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';

typedef CategoryTapCallback = void Function(String? category);

class CategoryChart extends StatefulWidget {
  final Map<String, int> categoryTotals;
  final CategoryTapCallback? onCategoryTapped;
  final String? highlightedCategory;

  const CategoryChart({
    super.key,
    required this.categoryTotals,
    this.onCategoryTapped,
    this.highlightedCategory,
  });

  @override
  State<CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<CategoryChart> {
  int _touchedIndex = -1;

  static const _labels = ['productive', 'distracting', 'neutral'];
  static const _colors = [
    AppColors.productive,
    AppColors.distracting,
    AppColors.neutral,
  ];
  static const _displayNames = ['Productive', 'Distracting', 'Neutral'];

  @override
  Widget build(BuildContext context) {
    final productiveSecs = (widget.categoryTotals['productive'] ?? 0).toDouble();
    final distractingSecs = (widget.categoryTotals['distracting'] ?? 0).toDouble();
    final neutralSecs = (widget.categoryTotals['neutral'] ?? 0).toDouble();
    final values = [productiveSecs, distractingSecs, neutralSecs];
    final total = productiveSecs + distractingSecs + neutralSecs;

    if (total == 0) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        child: const Text(
          'No usage data collected yet today',
          style: TextStyle(color: AppColors.textDisabled, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 52,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions ||
                          response == null ||
                          response.touchedSection == null) {
                        setState(() => _touchedIndex = -1);
                        return;
                      }
                      final idx = response.touchedSection!.touchedSectionIndex;
                      setState(() => _touchedIndex = idx);
                      if (event is FlTapUpEvent && widget.onCategoryTapped != null) {
                        final tapped = _labels[idx];
                        widget.onCategoryTapped!(
                            widget.highlightedCategory == tapped ? null : tapped);
                      }
                    },
                  ),
                  sections: List.generate(3, (i) {
                    final isHighlighted = widget.highlightedCategory == null ||
                        widget.highlightedCategory == _labels[i];
                    final isTouched = _touchedIndex == i;
                    final strokeWidth = isTouched ? 20.0 : 16.0;
                    return PieChartSectionData(
                      color: _colors[i].withValues(alpha: isHighlighted ? 0.95 : 0.25),
                      value: values[i] > 0 ? values[i] : 0.001,
                      showTitle: false,
                      radius: strokeWidth,
                    );
                  }),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(total / 3600).toStringAsFixed(1)}h',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final isActive = widget.highlightedCategory == null ||
                widget.highlightedCategory == _labels[i];
            final percent = total > 0 ? (values[i] / total * 100).toStringAsFixed(0) : '0';
            return GestureDetector(
              onTap: () {
                if (widget.onCategoryTapped != null) {
                  widget.onCategoryTapped!(
                      widget.highlightedCategory == _labels[i]
                          ? null
                          : _labels[i]);
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.surfaceElevated : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive ? AppColors.border : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _colors[i].withValues(alpha: isActive ? 1.0 : 0.3),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_displayNames[i]} $percent%',
                      style: TextStyle(
                        color: isActive ? AppColors.textPrimary : AppColors.textDisabled,
                        fontSize: 11,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
