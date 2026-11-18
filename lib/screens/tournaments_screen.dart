import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../models/tournament.dart';
import '../services/football_api.dart';
import '../widgets/action_form.dart';
import '../widgets/resource_list.dart';
import 'login_screen.dart';
import 'tournament_screen.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key, this.api});

  final FootballApi? api;

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late final FootballApi _api = widget.api ?? FootballApi();
  final _searchController = TextEditingController();
  String _search = '';
  int _revision = 0;
  bool _signingOut = false;

  Future<void> _create() async {
    final saved = await showActionForm(
      context,
      title: 'Nuevo torneo',
      inputs: const [
        FormInput('name', 'Nombre', maxLength: 100),
        FormInput('season', 'Temporada', maxLength: 20),
      ],
      submit: (values) async {
        await _api.createTournament(
          name: values['name']!,
          season: values['season']!,
        );
      },
    );
    if (saved && mounted) setState(() => _revision++);
  }

  Future<void> _delete(Tournament tournament) async {
    final deleted = await showActionForm(
      context,
      title: 'Eliminar torneo',
      description:
          '¿Eliminar «${tournament.name}»? También se eliminarán sus equipos, jugadores y partidos.',
      submitLabel: 'Eliminar',
      submit: (_) => _api.deleteTournament(tournament.tournamentId),
    );
    if (deleted && mounted) setState(() => _revision++);
  }

  Future<void> _logout() async {
    setState(() => _signingOut = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _signingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar sesión.')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (widget.api == null) _api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Torneos de fútbol'),
      actions: [
        IconButton(
          tooltip: 'Cerrar sesión',
          onPressed: _signingOut ? null : _logout,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() {
              _search = _searchController.text.trim();
              _revision++;
            }),
            decoration: InputDecoration(
              labelText: 'Buscar torneo por nombre',
              border: const OutlineInputBorder(),
              prefixIcon: IconButton(
                tooltip: 'Buscar',
                icon: const Icon(Icons.search),
                onPressed: () => setState(() {
                  _search = _searchController.text.trim();
                  _revision++;
                }),
              ),
              suffixIcon: IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  _searchController.clear();
                  _search = '';
                  _revision++;
                }),
              ),
            ),
          ),
        ),
        Expanded(
          child: ResourceList<Tournament>(
            load: () => _api.getTournaments(name: _search),
            revision: _revision,
            emptyMessage: _search.isEmpty
                ? 'No hay torneos registrados. Crea el primero con el botón +.'
                : 'No se encontraron torneos con ese nombre.',
            itemBuilder: (context, tournament) => ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(tournament.name),
              subtitle: Text('Temporada ${tournament.season}'),
              trailing: IconButton(
                tooltip: 'Eliminar torneo',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _delete(tournament),
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TournamentScreen(api: _api, tournament: tournament),
                  ),
                );
                if (mounted) setState(() => _revision++);
              },
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Nuevo torneo',
      onPressed: _create,
      child: const Icon(Icons.add),
    ),
  );
}
