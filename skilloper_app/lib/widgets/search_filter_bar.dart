import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class FilterOption {
  final String value;
  final String label;

  const FilterOption({required this.value, required this.label});
}

/// Common filter options for quiz type (practice/exam)
const kQuizTypeFilterOptions = [
  FilterOption(value: 'practice', label: 'Practice'),
  FilterOption(value: 'exam', label: 'Exam'),
];

/// Helper to check if an item matches search query and type filter
bool matchesFilter({
  required String title,
  required String type,
  required String searchQuery,
  required String typeFilter,
}) {
  // Filter by search query
  if (searchQuery.isNotEmpty) {
    if (!title.toLowerCase().contains(searchQuery)) {
      return false;
    }
  }
  // Filter by type
  if (typeFilter.isNotEmpty && type != typeFilter) {
    return false;
  }
  return true;
}

class SearchFilterBar extends StatefulWidget {
  final String searchHint;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final List<FilterOption> filterOptions;
  final String selectedFilter; // Empty string means "All"
  final ValueChanged<String> onFilterChanged;

  const SearchFilterBar({
    super.key,
    required this.searchHint,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterOptions,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  State<SearchFilterBar> createState() => _SearchFilterBarState();
}

class _SearchFilterBarState extends State<SearchFilterBar> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    setState(() {});
  }

  String _getSelectedLabel() {
    if (widget.selectedFilter.isEmpty) return 'All';
    return widget.filterOptions
        .firstWhere(
          (o) => o.value == widget.selectedFilter,
          orElse: () => const FilterOption(value: '', label: 'All'),
        )
        .label;
  }

  Widget _buildCheckIcon(bool isSelected) {
    return SizedBox(
      width: 18,
      child: isSelected
          ? Icon(Icons.check, size: 18, color: Theme.of(context).primaryColor)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.searchController.text.isNotEmpty;
    final hasFilter = widget.selectedFilter.isNotEmpty;

    return Row(
      children: [
        // Search field
        Expanded(
          child: TextField(
            controller: widget.searchController,
            onChanged: widget.onSearchChanged,
            decoration: InputDecoration(
              hintText: widget.searchHint,
              hintStyle: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search,
                color: AppColors.textDisabled,
                size: 20,
              ),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        color: AppColors.textDisabled,
                        size: 18,
                      ),
                      onPressed: () {
                        widget.searchController.clear();
                        widget.onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Filter button
        PopupMenuButton<String>(
          onSelected: widget.onFilterChanged,
          offset: const Offset(0, 45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasFilter
                  ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                  : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
              border: hasFilter
                  ? Border.all(
                      color: Theme.of(context).primaryColor,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.filter_list,
                  size: 20,
                  color: hasFilter
                      ? Theme.of(context).primaryColor
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  _getSelectedLabel(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasFilter
                        ? Theme.of(context).primaryColor
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: hasFilter
                      ? Theme.of(context).primaryColor
                      : AppColors.textTertiary,
                ),
              ],
            ),
          ),
          itemBuilder: (context) => [
            PopupMenuItem<String>(
              value: '',
              child: Row(
                children: [
                  _buildCheckIcon(widget.selectedFilter.isEmpty),
                  const SizedBox(width: 8),
                  const Text('All'),
                ],
              ),
            ),
            ...widget.filterOptions.map(
              (option) => PopupMenuItem<String>(
                value: option.value,
                child: Row(
                  children: [
                    _buildCheckIcon(widget.selectedFilter == option.value),
                    const SizedBox(width: 8),
                    Text(option.label),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
