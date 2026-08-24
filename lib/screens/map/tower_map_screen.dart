import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/app_strings.dart';
import '../../core/localization/mock_content_localization.dart';
import '../../core/theme/app_tokens.dart';
import '../../mock/mock_data.dart';
import '../../models/models.dart';
import '../../widgets/cap_incident_card.dart';
import '../../widgets/empty_state.dart';
import '../incidents/incident_details_screen.dart';
import '../requests/my_requests_screen.dart';

class TowerMapScreen extends StatefulWidget {
  const TowerMapScreen({super.key, this.enableTiles = true});

  /// Disabled by widget tests only. Production uses live OpenStreetMap tiles.
  final bool enableTiles;

  @override
  State<TowerMapScreen> createState() => _TowerMapScreenState();
}

class _TowerMapScreenState extends State<TowerMapScreen> {
  final mapController = MapController();
  final searchController = TextEditingController();
  bool listMode = false;
  TowerSite? selected;

  List<TowerSite> get towers {
    final query = searchController.text.trim().toLowerCase();
    if (query.isEmpty) return MockData.towerSites;
    return MockData.towerSites
        .where(
          (tower) => [
            tower.name,
            tower.code,
            tower.region,
            tower.area,
          ].any((value) => value.toLowerCase().contains(query)),
        )
        .toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    mapController.dispose();
    super.dispose();
  }

  List<CapIncident> _incidents(TowerSite tower) => MockData.capIncidents
      .where((incident) => incident.siteCode == tower.code)
      .toList();

  List<MyRequest> _requests(TowerSite tower) => MockData.myRequests
      .where((request) => request.siteCode == tower.code)
      .toList();

  void _selectTower(TowerSite tower) {
    setState(() => selected = tower);
    if (!listMode) {
      mapController.move(LatLng(tower.latitude, tower.longitude), 13.5);
    }
    _showTowerPreview(tower);
  }

  Future<void> _showTowerPreview(TowerSite tower) async {
    final incidents = _incidents(tower);
    final requests = _requests(tower);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TowerPreviewSheet(
        tower: tower,
        incidents: incidents,
        requests: requests,
        onViewAll: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TowerRequestsScreen(tower: tower),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.tr('Tower Map', 'خريطة الأبراج')),
      actions: [
        IconButton(
          tooltip: listMode
              ? context.tr('Map view', 'عرض الخريطة')
              : context.tr('List view', 'عرض القائمة'),
          onPressed: () => setState(() => listMode = !listMode),
          icon: Icon(listMode ? Icons.map_outlined : Icons.view_list_outlined),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: listMode ? _buildList() : _buildMap(),
  );

  Widget _buildMap() => Stack(
    children: [
      ColoredBox(
        color: const Color(0xFFE9ECE8),
        child: FlutterMap(
          mapController: mapController,
          options: const MapOptions(
            initialCenter: LatLng(30.0444, 31.2357),
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
                        selected: selected?.code == tower.code,
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
          onChanged: () => setState(() {}),
          onClear: () {
            searchController.clear();
            setState(() {});
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
              onTap: () =>
                  mapController.move(const LatLng(30.0444, 31.2357), 10.2),
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
            onChanged: () => setState(() {}),
            onClear: () {
              searchController.clear();
              setState(() {});
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
                      requests: _requests(tower),
                      onTap: () => _selectTower(tower),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class TowerRequestsScreen extends StatelessWidget {
  const TowerRequestsScreen({super.key, required this.tower});
  final TowerSite tower;

  @override
  Widget build(BuildContext context) {
    final incidents = MockData.capIncidents
        .where((incident) => incident.siteCode == tower.code)
        .toList();
    final requests = MockData.myRequests
        .where((request) => request.siteCode == tower.code)
        .toList();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('Tower Requests', 'طلبات البرج')),
          bottom: TabBar(
            tabs: [
              Tab(
                text: context.strings.isArabic
                    ? 'البلاغات (${incidents.length})'
                    : 'Incidents (${incidents.length})',
              ),
              Tab(
                text: context.strings.isArabic
                    ? 'الطلبات (${requests.length})'
                    : 'Requests (${requests.length})',
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            _TowerHero(
              tower: tower,
              incidentCount: incidents.length,
              requestCount: requests.length,
            ),
            Expanded(
              child: TabBarView(
                children: [
                  incidents.isEmpty
                      ? EmptyState(
                          icon: Icons.assignment_outlined,
                          title: context.tr(
                            'No incidents at this tower',
                            'لا توجد بلاغات لهذا البرج',
                          ),
                          description: context.tr(
                            'There are no local mock incidents for this site.',
                            'لا توجد بلاغات تجريبية محلية لهذا الموقع.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                          itemCount: incidents.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
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
                  requests.isEmpty
                      ? EmptyState(
                          icon: Icons.inbox_outlined,
                          title: context.tr(
                            'No requests at this tower',
                            'لا توجد طلبات لهذا البرج',
                          ),
                          description: context.tr(
                            'Intervention, renewal, and departure requests will appear here.',
                            'ستظهر هنا طلبات التدخل والتجديد والمغادرة.',
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                          itemCount: requests.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) => _TowerRequestCard(
                            request: requests[index],
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestDetailsScreen(
                                  request: requests[index],
                                ),
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    key: ValueKey('tower-${tower.code}'),
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
    required this.requests,
    required this.onViewAll,
    required this.onIncident,
  });
  final TowerSite tower;
  final List<CapIncident> incidents;
  final List<MyRequest> requests;
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
              requestCount: requests.length,
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
                        context.mockText(incident.title),
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
    required this.requestCount,
    this.compact = false,
  });
  final TowerSite tower;
  final int incidentCount, requestCount;
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
                context.mockText(tower.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.section.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 3),
              Text(
                '${tower.code} • ${context.mockText(tower.region)} / ${context.mockText(tower.area)}',
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
                  _DarkCount(
                    label: context.tr('Requests', 'الطلبات'),
                    count: requestCount,
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
    required this.requests,
    required this.onTap,
  });
  final TowerSite tower;
  final List<CapIncident> incidents;
  final List<MyRequest> requests;
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
      title: Text(context.mockText(tower.name), style: AppTypography.section),
      subtitle: Text(
        '${tower.code}\n${context.mockText(tower.region)} • ${context.mockText(tower.area)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.meta.copyWith(color: AppColors.muted),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${incidents.length + requests.length}',
            style: AppTypography.title.copyWith(color: AppColors.orangeDark),
          ),
          Text(context.tr('items', 'عنصر'), style: AppTypography.meta),
        ],
      ),
    ),
  );
}

class _TowerRequestCard extends StatelessWidget {
  const _TowerRequestCard({required this.request, required this.onTap});
  final MyRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      minTileHeight: 82,
      leading: CircleAvatar(
        backgroundColor: AppColors.orange.withValues(alpha: .1),
        child: Icon(_requestIcon(request.type), color: AppColors.orangeDark),
      ),
      title: Text(
        request.number,
        style: AppTypography.label.copyWith(color: AppColors.orangeDark),
      ),
      subtitle: Text(
        '${_requestType(context, request.type)} • ${_requestStatus(context, request.status)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
    ),
  );
}

IconData _requestIcon(RelatedRequestType type) => switch (type) {
  RelatedRequestType.intervention => Icons.engineering_outlined,
  RelatedRequestType.renewal => Icons.autorenew,
  RelatedRequestType.departure => Icons.logout,
};

String _requestType(BuildContext context, RelatedRequestType type) =>
    switch (type) {
      RelatedRequestType.intervention => context.tr('Intervention', 'تدخل'),
      RelatedRequestType.renewal => context.tr('Renewal', 'تجديد'),
      RelatedRequestType.departure => context.tr('Departure', 'مغادرة'),
    };

String _requestStatus(BuildContext context, MyRequestStatus status) =>
    switch (status) {
      MyRequestStatus.pending => context.tr('Pending', 'قيد الانتظار'),
      MyRequestStatus.approved => context.tr('Approved', 'مقبول'),
      MyRequestStatus.rejected => context.tr('Rejected', 'مرفوض'),
      MyRequestStatus.completed => context.tr('Completed', 'مكتمل'),
    };
