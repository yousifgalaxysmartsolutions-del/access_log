import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/di/injection.dart';
import '../../core/localization/app_strings.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/incidents/data/mappers/incident_mapper.dart';
import '../../features/incidents/data/models/incident_list_models.dart';
import '../../features/requests/presentation/bloc/request_details_cubit.dart';
import '../../widgets/app_button.dart';
import '../../widgets/info_row.dart';
import '../../widgets/section_card.dart';
import '../incidents/incident_details_screen.dart' show formatCapApiDate;

class ApiRequestDetailsScreen extends StatelessWidget {
  const ApiRequestDetailsScreen({super.key, required this.requestId});
  final int requestId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => services<RequestDetailsCubit>()..load(requestId),
    child: BlocBuilder<RequestDetailsCubit, RequestDetailsState>(
      builder: (context, state) {
        final data = state.data;
        final incident = data?.incident;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Request Details', 'تفاصيل الطلب')),
          ),
          body: SafeArea(
            child: state.loading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          context.tr(
                            'Loading request details…',
                            'جارٍ تحميل تفاصيل الطلب…',
                          ),
                        ),
                      ],
                    ),
                  )
                : data == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 44,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr(
                              'Unable to load request details.',
                              'تعذر تحميل تفاصيل الطلب.',
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => context
                                .read<RequestDetailsCubit>()
                                .load(requestId),
                            icon: const Icon(Icons.refresh),
                            label: Text(context.tr('Retry', 'إعادة المحاولة')),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        context.read<RequestDetailsCubit>().load(requestId),
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        Text(
                          context.requestTypeLabel(
                            data.requestType?.id,
                            name: data.requestType?.name,
                          ),
                          style: AppTypography.title,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.tr('Request #${data.id}', 'طلب #${data.id}'),
                          style: AppTypography.meta,
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.info_outline, size: 18),
                              label: Text(_text(data.requestStatus?.name)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: context.tr(
                            'Request information',
                            'بيانات الطلب',
                          ),
                          icon: Icons.info_outline,
                          child: Column(
                            children: [
                              _row(
                                context,
                                'Incident Number',
                                'رقم البلاغ',
                                incident?.incidentNo,
                              ),
                              _row(
                                context,
                                'Site',
                                'الموقع',
                                incident?.location?.name,
                              ),
                              _row(
                                context,
                                'Site Code',
                                'كود الموقع',
                                incident?.location?.id,
                              ),
                              _row(
                                context,
                                'Region',
                                'الإقليم',
                                incident?.location?.region?.name,
                              ),
                              _row(
                                context,
                                'Area',
                                'المنطقة',
                                incident?.location?.area?.name,
                              ),
                              _row(
                                context,
                                'Created Date',
                                'تاريخ الإنشاء',
                                formatCapApiDate(data.createdDate),
                              ),
                              _row(
                                context,
                                'Created By',
                                'أنشأه',
                                data.createdBy?.name,
                              ),
                              _row(context, 'Remark', 'ملاحظات', data.remark),
                              if (data.noOfMinute != null)
                                _row(
                                  context,
                                  'Renewal Minutes',
                                  'مدة التجديد بالدقائق',
                                  '${data.noOfMinute}',
                                ),
                              _row(
                                context,
                                'Last Modified By',
                                'آخر تعديل بواسطة',
                                data.lastModifiedBy?.name,
                              ),
                              _row(
                                context,
                                'Last Modified Date',
                                'تاريخ آخر تعديل',
                                formatCapApiDate(data.lastModifiedDate),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: context.tr(
                            'Questionnaire answers',
                            'إجابات النموذج',
                          ),
                          icon: Icons.fact_check_outlined,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (data.questionFormId != null)
                                _row(
                                  context,
                                  'Form ID',
                                  'رقم النموذج',
                                  data.questionFormId,
                                ),
                              if (data.formName != null)
                                Text(
                                  data.formName!,
                                  style: AppTypography.section,
                                ),
                              if (data.formDescription != null)
                                Text(data.formDescription!),
                              if (data.formAnswers.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    context.tr(
                                      'No questionnaire answers returned.',
                                      'لا توجد إجابات نموذج في البيانات المستلمة.',
                                    ),
                                  ),
                                ),
                              for (final answer in data.formAnswers)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Divider(),
                                      Text(
                                        _text(answer.questionText),
                                        style: AppTypography.label,
                                      ),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (answer.questionTypeInfo?.name !=
                                              null)
                                            Text(
                                              answer.questionTypeInfo!.name!,
                                              style: AppTypography.meta,
                                            ),
                                          if (answer.mandatory == true)
                                            Text(
                                              context.tr('Required', 'إلزامي'),
                                              style: AppTypography.meta
                                                  .copyWith(
                                                    color: AppColors.orangeDark,
                                                  ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      SelectableText(
                                        answer.textAnswer ??
                                            _optionText(answer.optionAnswer),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SectionCard(
                          title: context.tr(
                            'Request Timeline',
                            'الخط الزمني للطلب',
                          ),
                          icon: Icons.timeline,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (data.timeline.isEmpty)
                                Text(
                                  context.tr(
                                    'No activity returned.',
                                    'لا توجد أنشطة في البيانات المستلمة.',
                                  ),
                                ),
                              for (final event in data.timeline)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.history,
                                        color: AppColors.orange,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _text(
                                                event.eventTitle ??
                                                    event.actionType?.name,
                                              ),
                                              style: AppTypography.label,
                                            ),
                                            Text(
                                              formatCapApiDate(event.dateTime),
                                              style: AppTypography.meta,
                                            ),
                                            if (event.actionType?.name != null)
                                              Text(event.actionType!.name!),
                                            if (event.eventDescription != null)
                                              Text(event.eventDescription!),
                                            if (event.performedBy?.name != null)
                                              Text(event.performedBy!.name!),
                                            if (event.remark != null)
                                              Text(event.remark!),
                                            if (event.oldValue?.name != null)
                                              _row(
                                                context,
                                                'Previous Status',
                                                'الحالة السابقة',
                                                event.oldValue!.name,
                                              ),
                                            if (event.newValue?.name != null)
                                              _row(
                                                context,
                                                'New Status',
                                                'الحالة الجديدة',
                                                event.newValue!.name,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          bottomNavigationBar: incident?.id != null && incident!.id! > 0
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AppButton(
                      label: context.tr(
                        'View Related Incident',
                        'عرض البلاغ المرتبط',
                      ),
                      icon: Icons.open_in_new,
                      expanded: true,
                      onPressed: () {
                        final mapped = IncidentMapper.toIncident(
                          IncidentListItem(
                            incidentId: incident.id!,
                            incidentNo: incident.incidentNo ?? '',
                            description: incident.title ?? '',
                            locationName: incident.location?.name ?? '',
                            locationCode: incident.location?.id ?? '',
                            regionName: incident.location?.region?.name ?? '',
                            areaName: incident.location?.area?.name ?? '',
                            incidentType: incident.incidentType?.name ?? '',
                            assignedTeam: incident.assignedEngineer?.name ?? '',
                            statusName: incident.status?.name ?? '',
                            statusId: incident.status?.id ?? 0,
                            priorityName: incident.priority?.name ?? '',
                            priorityId: incident.priority?.id ?? 0,
                            occurredAt: DateTime.tryParse(
                              incident.createdDate ?? '',
                            ),
                          ),
                          requestedOn: DateTime.now(),
                        );
                        Navigator.pushNamed(
                          context,
                          AppRoutes.incidentDetails,
                          arguments: mapped,
                        );
                      },
                    ),
                  ),
                )
              : null,
        );
      },
    ),
  );
}

String _text(String? value) => value == null || value.isEmpty ? '-' : value;

Widget _row(
  BuildContext context,
  String english,
  String arabic,
  String? value,
) => InfoRow(
  icon: Icons.info_outline,
  label: context.tr(english, arabic),
  value: _text(value),
);

/// Never turn an unknown option object into visible JSON.
String _optionText(Object? value) => switch (value) {
  String text => text,
  num number => '$number',
  bool flag => '$flag',
  Map map when map['name'] is String => map['name'] as String,
  List values => values.map(_optionText).join(', '),
  _ => '-',
};
