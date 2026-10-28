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
    Color(0xFFFFFFFF), // pure white
    Color(0xFF8E8E93), // neutral gray
    Color(0xFF3A3A3C), // dark slate gray
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
        height: 180,
        alignment: Alignment.center,
        child: const Text(
          'No usage data collected yet today',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.6,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 42,
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
                final radius = isTouched ? 54.0 : 46.0;
                final isWhiteSlice = i == 0;
                return PieChartSectionData(
                  color: _colors[i].withValues(alpha: isHighlighted ? 1.0 : 0.3),
                  value: values[i],
                  title: values[i] > 0
                      ? '${(values[i] / total * 100).toStringAsFixed(0)}%'
                      : '',
                  radius: radius,
                  titleStyle: TextStyle(
                    color: isWhiteSlice ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final isActive = widget.highlightedCategory == null ||
                widget.highlightedCategory == _labels[i];
            return GestureDetector(
              onTap: () {
                if (widget.onCategoryTapped != null) {
                  widget.onCategoryTapped!(
                      widget.highlightedCategory == _labels[i]
                          ? null
                          : _labels[i]);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
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
                      _displayNames[i],
                      style: TextStyle(
                        color: isActive
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
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
