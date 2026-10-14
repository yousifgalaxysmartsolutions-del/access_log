import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/app_strings.dart';
import '../../core/di/injection.dart';
import '../../features/incidents/presentation/bloc/incident_map_cubit.dart';
import '../../core/theme/app_tokens.dart';
import '../../models/models.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/empty_state.dart';
import '../incidents/incident_details_screen.dart';
import '../requests/api_request_details_screen.dart';

class TowerMapScreen extends StatelessWidget {
  const TowerMapScreen({super.key, this.enableTiles = true});

  /// Disabled by widget tests only. Production uses live OpenStreetMap tiles.
  final bool enableTiles;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<IncidentMapCubit>()..refresh(),
    child: _TowerMapView(enableTiles: enableTiles),
  );
}

class _TowerMapView extends StatefulWidget {
  const _TowerMapView({required this.enableTiles});
  final bool enableTiles;
  @override
  State<_TowerMapView> createState() => _TowerMapScreenState();
}

class _TowerMapScreenState extends State<_TowerMapView> {
  final mapController = MapController();
  final searchController = TextEditingController();
  bool listMode = false;
  TowerSite? selected;

  List<TowerSite> get towers {
    return context
        .read<IncidentMapCubit>()
        .visibleSites
        .map((e) => e.tower)
        .toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  IncidentMapSite _site(TowerSite tower) => context
      .read<IncidentMapCubit>()
      .state
      .sites
      .firstWhere((e) => identical(e.tower, tower));
  List<CapIncident> _incidents(TowerSite tower) => _site(tower).incidents;

  void _selectTower(TowerSite tower) {
    setState(() => selected = tower);
    if (!listMode) {
      mapController.move(LatLng(tower.latitude, tower.longitude), 13.5);
    }
    _showTowerPreview(tower);
  }

  Future<void> _showTowerPreview(TowerSite tower) async {
    final incidents = _incidents(tower);
    final cubit = context.read<IncidentMapCubit>();
    final site = _site(tower);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TowerPreviewSheet(
        tower: tower,
        incidents: incidents,
        onViewAll: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: cubit,
                child: TowerRequestsScreen(site: site),
              ),
            ),
          );
        },
        onIncident: (incident) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IncidentDetailsScreen(incident: incident),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<IncidentMapCubit, IncidentMapState>(
    builder: (context, state) => Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Tower Map', 'خريطة الأبراج')),
        actions: [
          IconButton(
            tooltip: context.tr('Refresh', 'تحديث'),
            onPressed: () => context.read<IncidentMapCubit>().refresh(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: listMode
                ? context.tr('Map view', 'عرض الخريطة')
                : context.tr('List view', 'عرض القائمة'),
            onPressed: () => setState(() => listMode = !listMode),
            icon: Icon(
              listMode ? Icons.map_outlined : Icons.view_list_outlined,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : state.failure != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.failure!.message, textAlign: TextAlign.center),
                      TextButton(
                        onPressed: () =>
                            context.read<IncidentMapCubit>().refresh(),
                        child: Text(context.tr('Retry', 'إعادة المحاولة')),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  if (state.missingCoordinates > 0)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        context.tr(
                          '${state.missingCoordinates} incidents have no valid coordinates and are not shown on the map.',
                          '${state.missingCoordinates} بلاغات بدون إحداثيات صالحة لا تظهر على الخريطة.',
                        ),
                      ),
                    ),
                  Expanded(
                    child: state.sites.isEmpty
                        ? EmptyState(
                            icon: Icons.map_outlined,
                            title: context.tr(
                              'No mapped incidents today',
                              'لا توجد بلاغات بإحداثيات اليوم',
                            ),
                            description: context.tr(
                              'Today’s incidents with valid site coordinates will appear here.',
                              'ستظهر هنا بلاغات اليوم التي تحتوي على إحداثيات مواقع صالحة.',
                            ),
                          )
                        : listMode
                        ? _buildList()
                        : _buildMap(),
                  ),
                ],
              ),
      ),
    ),
  );

  void _fitSites() {
    final points = towers.map((e) => LatLng(e.latitude, e.longitude)).toList();
    if (points.isEmpty) return;
    mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(55, 100, 55, 100),
        maxZoom: 13.5,
      ),
    );
  }

  Widget _buildMap() => Stack(
    children: [
      ColoredBox(
        color: const Color(0xFFE9ECE8),
        child: FlutterMap(
          mapController: mapController,
          options: MapOptions(
            initialCenter: LatLng(
              context.read<IncidentMapCubit>().state.sites.first.tower.latitude,
              context
                  .read<IncidentMapCubit>()
                  .state
                  .sites
                  .first
                  .tower
                  .longitude,
            ),
            onMapReady: _fitSites,
            initialZoom: 10.2,
            minZoom: 5,
            maxZoom: 18,
            interactionOptions: InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            if (widget.enableTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.orange.accesslog.accessLogPlus',
                maxNativeZoom: 19,
              ),
            MarkerLayer(
              markers: towers
                  .map(
                    (tower) => Marker(
                      point: LatLng(tower.latitude, tower.longitude),
                      width: 70,
                      height: 78,
                      alignment: Alignment.topCenter,
                      child: _TowerMarker(
                        tower: tower,
                        incidentCount: _incidents(tower).length,
                        selected: identical(selected, tower),
                        onTap: () => _selectTower(tower),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (widget.enableTiles)
              const RichAttributionWidget(
                showFlutterMapAttribution: false,
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
          ],
        ),
      ),
      PositionedDirectional(
        top: 12,
        start: 14,
        end: 14,
        child: _MapSearchBar(
          controller: searchController,
          count: towers.length,
          onChanged: () =>
              context.read<IncidentMapCubit>().search(searchController.text),
          onClear: () {
            searchController.clear();
            context.read<IncidentMapCubit>().search('');
          },
        ),
      ),
      PositionedDirectional(
        end: 14,
        bottom: 52,
        child: Column(
          children: [
            _MapControl(
              tooltip: context.tr('Zoom in', 'تكبير'),
              icon: Icons.add,
              onTap: () => mapController.move(
                mapController.camera.center,
                mapController.camera.zoom + 1,
              ),
            ),
            const SizedBox(height: 8),
            _MapControl(
              tooltip: context.tr('Zoom out', 'تصغير'),
              icon: Icons.remove,
              onTap: () => mapController.move(
                mapController.camera.center,
                mapController.camera.zoom - 1,
              ),
            ),
            const SizedBox(height: 8),
            _MapControl(
              tooltip: context.tr('Reset map', 'إعادة ضبط الخريطة'),
              icon: Icons.my_location,
              onTap: _fitSites,
            ),
          ],
        ),
      ),
      PositionedDirectional(
        start: 14,
        bottom: 36,
        child: _MapLegend(visibleTowers: towers.length),
      ),
    ],
  );

  Widget _buildList() {
    final items = towers;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: _MapSearchBar(
            controller: searchController,
            count: items.length,
            onChanged: () =>
                context.read<IncidentMapCubit>().search(searchController.text),
            onClear: () {
              searchController.clear();
              context.read<IncidentMapCubit>().search('');
            },
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(
                  icon: Icons.cell_tower_outlined,
                  title: context.tr('No towers found', 'لا توجد أبراج'),
                  description: context.tr(
                    'Try another site name, code, region, or area.',
                    'جرّب اسم موقع أو كود أو إقليم أو منطقة أخرى.',
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final tower = items[index];
                    return _TowerListCard(
                      tower: tower,
                      incidents: _incidents(tower),
                      onTap: () => _selectTower(tower),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class TowerRequestsScreen extends StatefulWidget {
  const TowerRequestsScreen({super.key, required this.site});
  final IncidentMapSite site;
  @override
  State<TowerRequestsScreen> createState() => _TowerRequestsScreenState();
}

class _TowerRequestsScreenState extends State<TowerRequestsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<IncidentMapCubit>().loadRequests(widget.site);
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<IncidentMapCubit, IncidentMapState>(
    builder: (context, state) {
      final incidents = widget.site.incidents;
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Tower Requests', 'طلبات البرج')),
            bottom: TabBar(
              tabs: [
                Tab(
                  text: context.tr(
                    'Incidents (${incidents.length})',
                    'البلاغات (${incidents.length})',
                  ),
                ),
                Tab(
                  text: context.tr(
                    'Requests (${state.requestsLoading
                        ? '…'
                        : state.requestsFailure != null
                        ? '!'
                        : state.requests.length})',
                    'الطلبات (${state.requestsLoading
                        ? '…'
                        : state.requestsFailure != null
                        ? '!'
                        : state.requests.length})',
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              _TowerHero(
                tower: widget.site.tower,
                incidentCount: incidents.length,
                requestCount:
                    state.requestsLoading || state.requestsFailure != null
                    ? null
                    : state.requests.length,
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      itemCount: incidents.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, index) => CapIncidentCard(
                        incident: incidents[index],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IncidentDetailsScreen(
                              incident: incidents[index],
                            ),
                          ),
                        ),
                      ),
                    ),
                    state.requestsLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.requestsFailure != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.requestsFailure!.message,
                                    textAlign: TextAlign.center,
                                  ),
                                  TextButton(
                                    onPressed: () => context
                                        .read<IncidentMapCubit>()
                                        .loadRequests(widget.site),
                                    child: Text(
                                      context.tr('Retry', 'إعادة المحاولة'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : state.requests.isEmpty
                        ? EmptyState(
                            icon: Icons.inbox_outlined,
                            title: context.tr(
                              'No requests at this tower',
                              'لا توجد طلبات لهذا البرج',
                            ),
                            description: context.tr(
                              'No requests returned for these incidents.',
                              'لم ترجع طلبات مرتبطة بهذه البلاغات.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                            itemCount: state.requests.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, index) {
                              final request = state.requests[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.inbox_outlined),
                                  title: Text(
                                    context.tr(
                                      'Request #${request.id ?? '—'}',
                                      'طلب #${request.id ?? '—'}',
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${request.requestType?.name ?? '—'} • ${request.requestStatus?.name ?? '—'}',
                                  ),
                                  onTap: request.id == null || request.id! <= 0
                                      ? null
                                      : () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ApiRequestDetailsScreen(
                                                  requestId: request.id!,
                                                ),
                                          ),
                                        ),
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _TowerMarker extends StatelessWidget {
  const _TowerMarker({
    required this.tower,
    required this.incidentCount,
    required this.selected,
    required this.onTap,
  });
  final TowerSite tower;
  final int incidentCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    key: ValueKey(
      'tower-${tower.code.isNotEmpty ? tower.code : '${tower.latitude},${tower.longitude}'}',
    ),
    button: true,
    label: context.strings.isArabic
        ? '${tower.name}، $incidentCount بلاغات'
        : '${tower.name}, $incidentCount incidents',
    child: GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 48 : 43,
            height: selected ? 48 : 43,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.orange,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 9,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.cell_tower,
                    size: 23,
                    color: selected ? AppColors.orange : AppColors.ink,
                  ),
                ),
                PositionedDirectional(
                  top: -7,
                  end: -7,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 23),
                    height: 23,
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$incidentCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _MarkerPointerPainter(
              color: selected ? AppColors.ink : AppColors.orange,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MarkerPointerPainter extends CustomPainter {
  const _MarkerPointerPainter({required this.color});
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _MapSearchBar extends StatelessWidget {
  const _MapSearchBar({
    required this.controller,
    required this.count,
    required this.onChanged,
    required this.onClear,
  });
  final TextEditingController controller;
  final int count;
  final VoidCallback onChanged, onClear;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 8,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(AppRadius.control),
    child: TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        hintText: context.tr(
          'Search tower, code, region, or area',
          'ابحث بالبرج أو الكود أو الإقليم أو المنطقة',
        ),
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isEmpty
            ? Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    '$count',
                    style: AppTypography.label.copyWith(
                      color: AppColors.orangeDark,
                    ),
                  ),
                ),
              )
            : IconButton(
                tooltip: context.tr('Clear search', 'مسح البحث'),
                onPressed: onClear,
                icon: const Icon(Icons.close),
              ),
      ),
    ),
  );
}

class _MapControl extends StatelessWidget {
  const _MapControl({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    elevation: 5,
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(12),
    child: IconButton(tooltip: tooltip, onPressed: onTap, icon: Icon(icon)),
  );
}

class _MapLegend extends StatelessWidget {
  const _MapLegend({required this.visibleTowers});
  final int visibleTowers;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.ink.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cell_tower, size: 16, color: AppColors.orange),
        const SizedBox(width: 7),
        Text(
          context.strings.isArabic
              ? '$visibleTowers أبراج ظاهرة'
              : '$visibleTowers towers visible',
          style: AppTypography.meta.copyWith(color: Colors.white),
        ),
      ],
    ),
  );
}

class _TowerPreviewSheet extends StatelessWidget {
  const _TowerPreviewSheet({
    required this.tower,
    required this.incidents,
    required this.onViewAll,
    required this.onIncident,
  });
  final TowerSite tower;
  final List<CapIncident> incidents;
  final VoidCallback onViewAll;
  final ValueChanged<CapIncident> onIncident;

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .74,
    ),
    decoration: BoxDecoration(
      color: Theme.of(context).scaffoldBackgroundColor,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    ),
    child: SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TowerHero(
              tower: tower,
              incidentCount: incidents.length,
              compact: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('Recent Incidents', 'أحدث البلاغات'),
                    style: AppTypography.section,
                  ),
                ),
                TextButton(
                  onPressed: onViewAll,
                  child: Text(context.tr('View all', 'عرض الكل')),
                ),
              ],
            ),
            if (incidents.isEmpty)
              Text(
                context.tr(
                  'No incidents for this tower.',
                  'لا توجد بلاغات لهذا البرج.',
                ),
                style: AppTypography.body.copyWith(color: AppColors.muted),
              )
            else
              ...incidents
                  .take(3)
                  .map(
                    (incident) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () => onIncident(incident),
                      leading: CircleAvatar(
                        backgroundColor: capStatusColor(
                          incident.status,
                        ).withValues(alpha: .1),
                        child: Icon(
                          Icons.assignment_outlined,
                          color: capStatusColor(incident.status),
                        ),
                      ),
                      title: Text(
                        incident.number,
                        style: AppTypography.label.copyWith(
                          color: AppColors.orangeDark,
                        ),
                      ),
                      subtitle: Text(
                        incident.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: onViewAll,
              icon: const Icon(Icons.list_alt),
              label: Text(
                context.tr('Open All Tower Requests', 'فتح كل طلبات البرج'),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TowerHero extends StatelessWidget {
  const _TowerHero({
    required this.tower,
    required this.incidentCount,
    this.requestCount,
    this.compact = false,
  });
  final TowerSite tower;
  final int incidentCount;
  final int? requestCount;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    margin: compact
        ? EdgeInsets.zero
        : const EdgeInsets.fromLTRB(16, 14, 16, 0),
    padding: EdgeInsets.all(compact ? 15 : 17),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF111111), Color(0xFF292929)],
      ),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.cell_tower, color: AppColors.ink, size: 27),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tower.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.section.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                '${tower.code} • ${tower.region} / ${tower.area}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.meta.copyWith(color: Colors.white60),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _DarkCount(
                    label: context.tr('Incidents', 'البلاغات'),
                    count: incidentCount,
                  ),
                  if (requestCount != null)
                    _DarkCount(
                      label: context.tr('Requests', 'الطلبات'),
                      count: requestCount!,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DarkCount extends StatelessWidget {
  const _DarkCount({required this.label, required this.count});
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white10,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      '$count $label',
      style: AppTypography.meta.copyWith(color: AppColors.orange),
    ),
  );
}

class _TowerListCard extends StatelessWidget {
  const _TowerListCard({
    required this.tower,
    required this.incidents,
    required this.onTap,
  });
  final TowerSite tower;
  final List<CapIncident> incidents;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      minTileHeight: 84,
      leading: const CircleAvatar(
        backgroundColor: Color(0xFFFFE9D5),
        child: Icon(Icons.cell_tower, color: AppColors.orangeDark),
      ),
      title: Text(tower.name, style: AppTypography.section),
      subtitle: Text(
        '${tower.code}\n${tower.region} • ${tower.area}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.meta.copyWith(color: AppColors.muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${incidents.length}',
            style: AppTypography.title.copyWith(color: AppColors.orangeDark),
          ),
          Text(context.tr('Incidents', 'البلاغات'), style: AppTypography.meta),
        ],
      ),
    ),
  );
}
