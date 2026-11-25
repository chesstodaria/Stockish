import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/audit_repository.dart';
import '../../models/audit_event.dart';
import '../../services/formatters.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/grouped_list.dart';
import '../../widgets/section_header.dart';
import '../../widgets/state_views.dart';

/// Jejak aktivitas gudang operator (sub-layar Profil).
///
/// Hanya baca: catatan ditulis server, aplikasi tidak punya jalur untuk
/// mengubah atau menghapusnya.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Future<List<AuditEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = context.read<AuditRepository>().recent();
  }

  void _reload() {
    setState(() {
      _events = context.read<AuditRepository>().recent();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aktivitas')),
      body: FutureBuilder<List<AuditEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Memuat aktivitas...');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: snapshot.error.toString(),
              title: 'Gagal memuat aktivitas',
              onRetry: _reload,
            );
          }
          final events = snapshot.data ?? const <AuditEvent>[];
          if (events.isEmpty) {
            return const EmptyView(
              icon: Icons.history_toggle_off_rounded,
              title: 'Belum ada aktivitas',
              message: 'Jejak masuk, kunci dokumen, dan submit akan muncul '
                  'di sini.',
            );
          }
          return _EventList(events: events);
        },
      ),
    );
  }
}

class _EventList extends StatelessWidget {
  final List<AuditEvent> events;

  const _EventList({required this.events});

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<AuditEvent>>{};
    for (final event in events) {
      groups.putIfAbsent(Fmt.date(event.at), () => []).add(event);
    }

    final children = <Widget>[];
    var first = true;
    for (final entry in groups.entries) {
      if (!first) children.add(const SizedBox(height: AppSpace.xl));
      first = false;
      children.add(SectionHeader(entry.key, trailing: '${entry.value.length}'));
      children.add(const SizedBox(height: AppSpace.sm));
      children.add(GroupedList(
        children: [
          for (final event in entry.value)
            GroupedRow(child: _EventRow(event: event)),
        ],
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.screen,
        AppSpace.lg,
        AppSpace.screen,
        AppSpace.xl,
      ),
      children: children,
    );
  }
}

class _EventRow extends StatelessWidget {
  final AuditEvent event;

  const _EventRow({required this.event});

  static const _labels = {
    'login': 'Masuk',
    'logout': 'Keluar',
    'claim': 'Kunci',
    'release': 'Lepas kunci',
    'submit': 'Submit',
    'force_session': 'Sesi',
  };

  static String _time(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}.${two(at.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final label = _labels[event.action] ?? event.action;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.summary, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 2),
              Text(
                '$label  ·  ${_time(event.at)}  ·  NIK ${event.actorNik}',
                style: AppTextStyles.code,
              ),
            ],
          ),
        ),
        if (event.entityId != null) ...[
          const SizedBox(width: AppSpace.sm),
          Text(
            event.entityId!,
            style: AppTextStyles.code.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
