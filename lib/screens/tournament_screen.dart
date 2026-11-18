import 'package:material_ui/material_ui.dart';

import '../models/team.dart';
import '../models/tournament.dart';
import '../models/tournament_match.dart';
import '../services/football_api.dart';
import '../widgets/action_form.dart';
import '../widgets/resource_list.dart';
import 'team_screen.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({
    super.key,
    required this.api,
    required this.tournament,
  });

  final FootballApi api;
  final Tournament tournament;

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  int _revision = 0;
  bool _preparingMatch = false;

  Future<void> _createTeam() async {
    final saved = await showActionForm(
      context,
      title: 'Registrar equipo',
      inputs: const [
        FormInput('name', 'Nombre'),
        FormInput('city', 'Ciudad', optional: true),
      ],
      submit: (values) async {
        await widget.api.createTeam(
          widget.tournament.tournamentId,
          name: values['name']!,
          city: values['city']!.isEmpty ? null : values['city'],
        );
      },
    );
    if (saved && mounted) setState(() => _revision++);
  }

  Future<void> _createMatch() async {
    if (_preparingMatch) return;
    setState(() => _preparingMatch = true);
    try {
      final teams = await widget.api.getTeams(widget.tournament.tournamentId);
      if (!mounted) return;
      if (teams.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registra al menos dos equipos en este torneo.'),
          ),
        );
        return;
      }
      final choices = {
        for (final team in teams)
          '${team.teamId}': '${team.name} (#${team.teamId})',
      };
      final saved = await showActionForm(
        context,
        title: 'Programar partido',
        description: 'Selecciona equipos de este torneo. Usa la fecha y hora local, sin zona horaria.',
        inputs: [
          FormInput('homeTeamId', 'Equipo local', choices: choices),
          FormInput('awayTeamId', 'Equipo visitante', choices: choices),
          FormInput(
            'scheduledAt',
            'Fecha y hora local',
            maxLength: 26,
            hint: '2026-11-20T18:00:00',
            validate: (value) {
              if (!RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2})?$')
                  .hasMatch(value)) {
                return 'Usa AAAA-MM-DDTHH:MM o AAAA-MM-DDTHH:MM:SS.';
              }
              final date = DateTime.tryParse(value);
              if (date == null || !date.toIso8601String().startsWith(value)) {
                return 'Introduce una fecha y hora válidas.';
              }
              return null;
            },
          ),
        ],
        submit: (values) async {
          await widget.api.createMatch(
            widget.tournament.tournamentId,
            homeTeamId: int.parse(values['homeTeamId']!),
            awayTeamId: int.parse(values['awayTeamId']!),
            scheduledAt: DateTime.parse(values['scheduledAt']!),
          );
        },
      );
      if (saved && mounted) setState(() => _revision++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _preparingMatch = false);
    }
  }

  Future<void> _delete(
    String title,
    String description,
    Future<void> Function() action,
  ) async {
    final deleted = await showActionForm(
      context,
      title: title,
      description: description,
      submitLabel: 'Eliminar',
      submit: (_) => action(),
    );
    if (deleted && mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text('${widget.tournament.name} · ${widget.tournament.season}'),
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Equipos'),
            Tab(text: 'Partidos'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: _createTeam,
                  icon: const Icon(Icons.add),
                  label: const Text('Registrar equipo'),
                ),
              ),
              Expanded(
                child: ResourceList<Team>(
                  load: () =>
                      widget.api.getTeams(widget.tournament.tournamentId),
                  revision: _revision,
                  emptyMessage: 'Este torneo todavía no tiene equipos.',
                  itemBuilder: (context, team) => ListTile(
                    leading: const Icon(Icons.groups_outlined),
                    title: Text(team.name),
                    subtitle: Text(
                      team.city?.isNotEmpty == true
                          ? team.city!
                          : 'Sin ciudad registrada',
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar equipo',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(
                        'Eliminar equipo',
                        '¿Eliminar «${team.name}» y sus jugadores? Si tiene partidos, elimina esos partidos primero.',
                        () => widget.api.deleteTeam(team.teamId),
                      ),
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TeamScreen(api: widget.api, team: team),
                        ),
                      );
                      if (mounted) setState(() => _revision++);
                    },
                  ),
                ),
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  onPressed: _preparingMatch ? null : _createMatch,
                  icon: const Icon(Icons.add),
                  label: const Text('Programar partido'),
                ),
              ),
              Expanded(
                child: ResourceList<TournamentMatch>(
                  load: () =>
                      widget.api.getMatches(widget.tournament.tournamentId),
                  revision: _revision,
                  emptyMessage:
                      'Este torneo todavía no tiene partidos programados.',
                  itemBuilder: (context, match) => ListTile(
                    leading: const Icon(Icons.sports_soccer),
                    title: Text(
                      '${match.homeTeamName} vs ${match.awayTeamName}',
                    ),
                    subtitle: Text(
                      '${match.scheduledAt.toIso8601String().replaceFirst('T', ' ').substring(0, 16)} (hora local)',
                    ),
                    trailing: IconButton(
                      tooltip: 'Eliminar partido',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(
                        'Eliminar partido',
                        '¿Eliminar el partido ${match.homeTeamName} vs ${match.awayTeamName}?',
                        () => widget.api.deleteMatch(match.matchId),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
