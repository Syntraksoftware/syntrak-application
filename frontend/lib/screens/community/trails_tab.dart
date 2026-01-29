import 'package:flutter/material.dart';
import 'package:syntrak/core/theme.dart';
import 'package:syntrak/models/ski_trail.dart';

class TrailsTab extends StatefulWidget {
  const TrailsTab({super.key});

  @override
  State<TrailsTab> createState() => _TrailsTabState();
}

class _TrailsTabState extends State<TrailsTab> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<SkiTrail> _trails = [];
  List<SkiTrail> _filteredTrails = [];
  bool _isLoading = false;
  bool _isSearchFocused = false;
  TrailDifficulty? _selectedDifficulty;
  String? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadTrails();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
    _searchController.addListener(() {
      setState(() {
        // Trigger rebuild when text changes to update clear button
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTrails() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: Fetch from backend API when available
    if (mounted) {
      setState(() {
        _trails = [];
        _filteredTrails = [];
        _isLoading = false;
      });
    }
  }

  void _filterTrails() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredTrails = _trails.where((trail) {
        final matchesSearch = query.isEmpty ||
            trail.name.toLowerCase().contains(query) ||
            trail.resort.toLowerCase().contains(query) ||
            trail.country.toLowerCase().contains(query);

        final matchesDifficulty = _selectedDifficulty == null ||
            trail.difficulty == _selectedDifficulty;

        final matchesCountry =
            _selectedCountry == null || trail.country == _selectedCountry;

        return matchesSearch && matchesDifficulty && matchesCountry;
      }).toList();
    });
  }

  List<String> get _countries {
    return _trails.map((t) => t.country).toSet().toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTrails,
            color: SyntrakColors.primary,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _filteredTrails.isEmpty
                  ? 3
                  : _filteredTrails.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildFilterChips();
                }
                if (index == 1) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: SyntrakSpacing.md),
                    child: _buildResultsHeader(),
                  );
                }
                if (_filteredTrails.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.terrain,
                            size: 64,
                            color: SyntrakColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No trails yet',
                            style: SyntrakTypography.headlineSmall.copyWith(
                              color: SyntrakColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Trails will appear when the API is connected.',
                            style: SyntrakTypography.bodyMedium.copyWith(
                              color: SyntrakColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: SyntrakSpacing.md),
                  child: _TrailCard(trail: _filteredTrails[index - 2]),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  // Modern search bar at top
  Widget _buildSearchBar() {
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: SyntrakColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: SyntrakSpacing.md,
        vertical: SyntrakSpacing.sm,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SyntrakRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          height: 48,
          decoration: BoxDecoration(
            color: _isSearchFocused
                ? SyntrakColors.surface
                : SyntrakColors.surfaceVariant,
            borderRadius: BorderRadius.circular(SyntrakRadius.lg),
            border: Border.all(
              color: _isSearchFocused
                  ? SyntrakColors.primary
                  : SyntrakColors.divider,
              width: _isSearchFocused ? 1.5 : 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              inputDecorationTheme: InputDecorationTheme(
                fillColor: Colors.transparent,
                filled: false,
              ),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => _filterTrails(),
              style: SyntrakTypography.bodyMedium.copyWith(
                color: SyntrakColors.textPrimary,
                height: 1.5, // Ensure consistent line height
              ),
              decoration: InputDecoration(
                hintText: 'Search trails, resorts...',
                hintStyle: SyntrakTypography.bodyMedium.copyWith(
                  color: SyntrakColors.textTertiary,
                  height: 1.5, // Match text line height
                ),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 4.0),
                  child: Icon(
                    Icons.search_rounded,
                    color: _isSearchFocused
                        ? SyntrakColors.primary
                        : SyntrakColors.textTertiary,
                    size: 20,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 44,
                  minHeight: 48,
                ),
                suffixIcon: hasText
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: SyntrakColors.textSecondary,
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _filterTrails();
                          _searchFocusNode.unfocus();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SyntrakSpacing.md,
                  vertical: 14,
                ),
                isDense: false, // Changed to false for better alignment
              ),
              cursorColor: SyntrakColors.primary,
              showCursor: true,
            ),
          ),
        ),
      ),
    );
  }

  // Filter chips - SCROLLS with list
  Widget _buildFilterChips() {
    return Container(
      color: SyntrakColors.surface,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: SyntrakSpacing.md),
              children: [
                _buildDifficultyChip(),
                const SizedBox(width: SyntrakSpacing.sm),
                _buildCountryChip(),
                if (_selectedDifficulty != null ||
                    _selectedCountry != null) ...[
                  const SizedBox(width: SyntrakSpacing.sm),
                  _buildClearFiltersChip(),
                ],
              ],
            ),
          ),
          const SizedBox(height: SyntrakSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip() {
    final isSelected = _selectedDifficulty != null;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: isSelected
          ? Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(_selectedDifficulty!.color),
                shape: BoxShape.circle,
              ),
            )
          : Icon(
              Icons.terrain,
              size: 16,
              color: SyntrakColors.textSecondary,
            ),
      label: Text(
        isSelected ? _selectedDifficulty!.shortName : 'Difficulty',
        style: SyntrakTypography.labelMedium.copyWith(
          color:
              isSelected ? SyntrakColors.primary : SyntrakColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: SyntrakColors.surfaceVariant,
      selectedColor: SyntrakColors.primary.withAlpha(25),
      side: BorderSide(
        color: isSelected ? SyntrakColors.primary : Colors.transparent,
      ),
      onSelected: (_) => _showDifficultyPicker(),
    );
  }

  Widget _buildCountryChip() {
    final isSelected = _selectedCountry != null;
    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        Icons.public,
        size: 16,
        color: isSelected ? SyntrakColors.primary : SyntrakColors.textSecondary,
      ),
      label: Text(
        isSelected ? _selectedCountry! : 'Country',
        style: SyntrakTypography.labelMedium.copyWith(
          color:
              isSelected ? SyntrakColors.primary : SyntrakColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      backgroundColor: SyntrakColors.surfaceVariant,
      selectedColor: SyntrakColors.primary.withAlpha(25),
      side: BorderSide(
        color: isSelected ? SyntrakColors.primary : Colors.transparent,
      ),
      onSelected: (_) => _showCountryPicker(),
    );
  }

  Widget _buildClearFiltersChip() {
    return ActionChip(
      avatar: const Icon(Icons.close, size: 16),
      label: const Text('Clear'),
      onPressed: () {
        setState(() {
          _selectedDifficulty = null;
          _selectedCountry = null;
        });
        _filterTrails();
      },
    );
  }

  void _showDifficultyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SyntrakColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SyntrakRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SyntrakSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SyntrakColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: SyntrakSpacing.md),
            Text(
              'Select Difficulty',
              style: SyntrakTypography.headlineSmall,
            ),
            const SizedBox(height: SyntrakSpacing.md),
            ListTile(
              leading: const Icon(Icons.clear_all),
              title: const Text('All Difficulties'),
              selected: _selectedDifficulty == null,
              onTap: () {
                setState(() => _selectedDifficulty = null);
                _filterTrails();
                Navigator.pop(context);
              },
            ),
            ...TrailDifficulty.values.map((d) => ListTile(
                  leading: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Color(d.color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        d.icon,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                  title: Text(d.displayName),
                  selected: _selectedDifficulty == d,
                  onTap: () {
                    setState(() => _selectedDifficulty = d);
                    _filterTrails();
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: SyntrakSpacing.lg),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: SyntrakColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SyntrakRadius.xl)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SyntrakSpacing.md),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SyntrakColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: SyntrakSpacing.md),
            Text(
              'Select Country',
              style: SyntrakTypography.headlineSmall,
            ),
            const SizedBox(height: SyntrakSpacing.md),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('All Countries'),
              selected: _selectedCountry == null,
              onTap: () {
                setState(() => _selectedCountry = null);
                _filterTrails();
                Navigator.pop(context);
              },
            ),
            ..._countries.map((c) => ListTile(
                  leading: const Icon(Icons.place),
                  title: Text(c),
                  selected: _selectedCountry == c,
                  onTap: () {
                    setState(() => _selectedCountry = c);
                    _filterTrails();
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: SyntrakSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.only(
        top: SyntrakSpacing.sm,
        bottom: SyntrakSpacing.sm,
      ),
      child: Row(
        children: [
          Text(
            '${_filteredTrails.length} trails',
            style: SyntrakTypography.labelLarge.copyWith(
              color: SyntrakColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Sort button
          TextButton.icon(
            onPressed: () {
              // TODO: Implement sort
            },
            icon: Icon(
              Icons.sort,
              size: 18,
              color: SyntrakColors.textSecondary,
            ),
            label: Text(
              'Sort',
              style: SyntrakTypography.labelMedium.copyWith(
                color: SyntrakColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Enhanced Trail Card with Strava-like design
class _TrailCard extends StatelessWidget {
  final SkiTrail trail;

  const _TrailCard({required this.trail});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: SyntrakSpacing.md),
      decoration: BoxDecoration(
        color: SyntrakColors.surface,
        borderRadius: BorderRadius.circular(SyntrakRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Trail details for ${trail.name} coming soon!'),
                duration: const Duration(seconds: 1),
              ),
            );
          },
          borderRadius: BorderRadius.circular(SyntrakRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(SyntrakSpacing.md),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(trail.difficulty.color).withAlpha(40),
                      Color(trail.difficulty.color).withAlpha(10),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(SyntrakRadius.lg),
                    topRight: Radius.circular(SyntrakRadius.lg),
                  ),
                ),
                child: Row(
                  children: [
                    // Difficulty badge
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Color(trail.difficulty.color),
                        borderRadius: BorderRadius.circular(SyntrakRadius.md),
                        boxShadow: [
                          BoxShadow(
                            color: Color(trail.difficulty.color).withAlpha(80),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          trail.difficulty.icon,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SyntrakSpacing.md),
                    // Trail info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            trail.name,
                            style: SyntrakTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.place,
                                size: 14,
                                color: SyntrakColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${trail.resort}, ${trail.country}',
                                  style: SyntrakTypography.bodySmall.copyWith(
                                    color: SyntrakColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Rating
                    if (trail.rating != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SyntrakSpacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withAlpha(30),
                          borderRadius: BorderRadius.circular(SyntrakRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              trail.rating!.toStringAsFixed(1),
                              style: SyntrakTypography.labelMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Stats section
              Padding(
                padding: const EdgeInsets.all(SyntrakSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats row with icons
                    Row(
                      children: [
                        _StatItem(
                          icon: Icons.straighten,
                          value: '${trail.lengthKm.toStringAsFixed(1)} km',
                          label: 'Length',
                        ),
                        const SizedBox(width: SyntrakSpacing.lg),
                        _StatItem(
                          icon: Icons.trending_down,
                          value: '${trail.elevationDropM} m',
                          label: 'Drop',
                        ),
                        const Spacer(),
                        // Badges
                        if (trail.isGroomed)
                          _Badge(
                            icon: Icons.ac_unit,
                            label: 'Groomed',
                            color: SyntrakColors.info,
                          ),
                      ],
                    ),
                    // Description
                    if (trail.description != null) ...[
                      const SizedBox(height: SyntrakSpacing.md),
                      Text(
                        trail.description!,
                        style: SyntrakTypography.bodySmall.copyWith(
                          color: SyntrakColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // Features tags
                    if (trail.features != null &&
                        trail.features!.isNotEmpty) ...[
                      const SizedBox(height: SyntrakSpacing.md),
                      Wrap(
                        spacing: SyntrakSpacing.xs,
                        runSpacing: SyntrakSpacing.xs,
                        children: trail.features!
                            .take(4)
                            .map((f) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SyntrakColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(
                                        SyntrakRadius.round),
                                  ),
                                  child: Text(
                                    f,
                                    style:
                                        SyntrakTypography.labelSmall.copyWith(
                                      color: SyntrakColors.textSecondary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: SyntrakColors.textTertiary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: SyntrakTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: SyntrakColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: SyntrakTypography.labelSmall.copyWith(
                color: SyntrakColors.textTertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(SyntrakRadius.sm),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: SyntrakTypography.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
