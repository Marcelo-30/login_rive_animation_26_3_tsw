import 'package:material_ui/material_ui.dart';

import '../models/player.dart';
import '../models/team.dart';
import '../services/football_api.dart';
import '../widgets/action_form.dart';
import '../widgets/resource_list.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key, required this.api, required this.team});

  final FootballApi api;
  final Team team;

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  int _revision = 0;

  Future<void> _create() async {
    final saved = await showActionForm(
      context,
      title: 'Registrar jugador',
      inputs: const [
        FormInput('name', 'Nombre'),
        FormInput('number', 'Dorsal', numeric: true),
        FormInput('position', 'Posición'),
      ],
      submit: (values) async {
        await widget.api.createPlayer(
          widget.team.teamId,
          name: values['name']!,
          number: int.parse(values['number']!),
          position: values['position']!,
        );
      },
    );
    if (saved && mounted) setState(() => _revision++);
  }

  Future<void> _delete(Player player) async {
    final deleted = await showActionForm(
      context,
      title: 'Eliminar jugador',
      description: '¿Eliminar a «${player.name}»?',
      submitLabel: 'Eliminar',
      submit: (_) => widget.api.deletePlayer(player.playerId),
    );
    if (deleted && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Jugadores · ${widget.team.name}')),
    body: ResourceList<Player>(
      load: () => widget.api.getPlayers(widget.team.teamId),
      revision: _revision,
      emptyMessage: 'Este equipo todavía no tiene jugadores registrados.',
      itemBuilder: (context, player) => ListTile(
        leading: CircleAvatar(child: Text('${player.number}')),
        title: Text(player.name),
        subtitle: Text(player.position),
        trailing: IconButton(
          tooltip: 'Eliminar jugador',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _delete(player),
        ),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Registrar jugador',
      onPressed: _create,
      child: const Icon(Icons.person_add),
    ),
  );
}
