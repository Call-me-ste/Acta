part of 'document_scan_page.dart';

class _ScanSources extends StatelessWidget {
  const _ScanSources({
    required this.busy,
    required this.pageCount,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
    required this.onAttach,
  });

  final bool busy;
  final int pageCount;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final ValueChanged<int> onRemove;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.camera_alt_outlined),
          title: const Text('Scatta documento'),
          enabled: !busy,
          onTap: onCamera,
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: const Text('Scegli una foto'),
          enabled: !busy,
          onTap: onGallery,
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: ListView.builder(
            itemCount: pageCount,
            itemBuilder: (context, index) => ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('Pagina ${index + 1}'),
              trailing: IconButton(
                tooltip: 'Rimuovi pagina ${index + 1}',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: busy ? null : () => onRemove(index),
              ),
            ),
          ),
        ),
        if (pageCount > 0)
          FilledButton(
            onPressed: busy ? null : onAttach,
            child: const Text('Allega PDF'),
          ),
      ],
    );
  }
}
