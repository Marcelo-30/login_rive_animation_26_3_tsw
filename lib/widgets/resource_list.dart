import 'package:material_ui/material_ui.dart';

class ResourceList<T> extends StatefulWidget {
  const ResourceList({
    super.key,
    required this.load,
    required this.itemBuilder,
    required this.emptyMessage,
    this.revision = 0,
  });

  final Future<List<T>> Function() load;
  final Widget Function(BuildContext, T) itemBuilder;
  final String emptyMessage;
  final int revision;

  @override
  State<ResourceList<T>> createState() => _ResourceListState<T>();
}

class _ResourceListState<T> extends State<ResourceList<T>> {
  late Future<List<T>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  @override
  void didUpdateWidget(covariant ResourceList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) _future = widget.load();
  }

  Future<void> _refresh() async {
    final future = widget.load();
    setState(() {
      _future = future;
    });
    try {
      await future;
    } catch (_) {
      // FutureBuilder displays the error and offers another attempt.
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Actualizar'),
        ),
      ),
      Expanded(
        child: FutureBuilder<List<T>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 40),
                      const SizedBox(height: 12),
                      Text('${snapshot.error}', textAlign: TextAlign.center),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(widget.emptyMessage, textAlign: TextAlign.center),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) =>
                    widget.itemBuilder(context, items[index]),
              ),
            );
          },
        ),
      ),
    ],
  );
}
