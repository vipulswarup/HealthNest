import 'package:flutter/cupertino.dart';
import 'package:sanovault/api/models.dart';
import 'package:sanovault/session/session_scope.dart';
import 'package:sanovault/theme/sv_colors.dart';
import 'package:sanovault/widgets/person_picker.dart';
import 'package:sanovault/widgets/sv_page.dart';
import 'package:share_plus/share_plus.dart';

class DoctorPage extends StatefulWidget {
  const DoctorPage({super.key, this.patientId});
  final String? patientId;

  @override
  State<DoctorPage> createState() => _DoctorPageState();
}

class _DoctorPageState extends State<DoctorPage> {
  List<Person> _people = const [];
  DoctorPacket? _packet;
  String? _patientId;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = SessionScope.of(context).api;
    setState(() {
      _loading = _packet == null;
      _error = null;
    });
    try {
      final people = await api.patients();
      _patientId ??= await loadInitialPersonId(people);
      final packet = _patientId == null ? null : await api.doctorPacket(_patientId!);
      if (!mounted) return;
      setState(() {
        _people = people;
        _packet = packet;
        _loading = false;
      });
    } catch (caught) {
      if (!mounted) return;
      setState(() {
        _error = caught.toString();
        _loading = false;
      });
    }
  }

  String _text(DoctorPacket packet) {
    final blocks = <String>[
      packet.patientName,
      if (packet.age != null) 'Age ${packet.age}',
      if (packet.gender.isNotEmpty) packet.gender,
      if (packet.bloodGroup.isNotEmpty) 'Blood group ${packet.bloodGroup}',
      if (packet.conditions.isNotEmpty) 'Conditions\n${packet.conditions.join('\n')}',
      if (packet.medicines.isNotEmpty) 'Medicines\n${packet.medicines.join('\n')}',
      if (packet.labHighlights.isNotEmpty) 'Labs\n${packet.labHighlights.join('\n')}',
      if (packet.bloodPressure.isNotEmpty) 'Blood pressure\n${packet.bloodPressure.join('\n')}',
      if (packet.growth.isNotEmpty) 'Growth\n${packet.growth.join('\n')}',
      if (packet.vaccinations.isNotEmpty) 'Vaccinations\n${packet.vaccinations.join('\n')}',
      if (packet.visitNotes.isNotEmpty) 'Visit notes\n${packet.visitNotes.join('\n')}',
    ];
    return blocks.join('\n\n');
  }

  Widget _section(String title, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return CupertinoListSection.insetGrouped(
      header: Text(title),
      children: [for (final line in lines) CupertinoListTile(title: Text(line))],
    );
  }

  @override
  Widget build(BuildContext context) {
    final packet = _packet;
    return SvLargePage(
      title: 'For the Doctor',
      error: _error,
      onRefresh: _load,
      trailing: packet == null
          ? null
          : CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => SharePlus.instance.share(ShareParams(text: _text(packet))),
              child: const Text('Share'),
            ),
      child: Column(
        children: [
          PersonPicker(
            people: _people,
            selectedId: _patientId,
            onSelected: (id) {
              setState(() => _patientId = id);
              rememberPerson(context, id);
              _load();
            },
          ),
          if (_loading)
            const Padding(padding: EdgeInsets.only(top: 32), child: CupertinoActivityIndicator())
          else if (packet == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Choose a person.', style: TextStyle(color: SvColors.slate)),
            )
          else ...[
            _section('Who', [
              packet.patientName,
              if (packet.age != null) 'Age ${packet.age}',
              packet.gender,
              if (packet.bloodGroup.isNotEmpty) packet.bloodGroup,
            ].where((line) => line.isNotEmpty).toList()),
            _section('Conditions', packet.conditions),
            _section('Medicines', packet.medicines),
            _section('Labs', packet.labHighlights),
            _section('Blood pressure', packet.bloodPressure),
            _section('Growth', packet.growth),
            _section('Vaccinations', packet.vaccinations),
            _section('Visit notes', packet.visitNotes),
          ],
        ],
      ),
    );
  }
}
