import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import '../../data/sprite_credits.dart';
import '../../utils/app_strings.dart';

Future<void> showSpriteCreditsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const SpriteCreditsDialog(),
  );
}

class SpriteCreditsDialog extends StatefulWidget {
  const SpriteCreditsDialog({super.key});

  @override
  State<SpriteCreditsDialog> createState() => _SpriteCreditsDialogState();
}

class _SpriteCreditsDialogState extends State<SpriteCreditsDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = (size.width - 64).clamp(280.0, 480.0);
    final height = (size.height - 160).clamp(360.0, 640.0);
    return AlertDialog(
      title: Text(AppStrings.t('sprite.credits.title')),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<SpriteCreditsData>(
          future: SpriteCreditsData.load(),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data!;
            return Column(
              children: [
                TabBar(
                  controller: _tabs,
                  tabs: [
                    Tab(text: AppStrings.t('sprite.credits.tabProjects')),
                    Tab(text: AppStrings.t('sprite.credits.tabArtists')),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ProjectsTab(projects: data.projects),
                      _ArtistsTab(artists: data.artists),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppStrings.t('action.close')),
        ),
      ],
    );
  }
}

class _ProjectsTab extends StatelessWidget {
  final List<ProjectCredit> projects;
  const _ProjectsTab({required this.projects});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: projects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final p = projects[i];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                if (p.url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => ul.launchUrl(Uri.parse(p.url),
                        mode: ul.LaunchMode.externalApplication),
                    child: Text(
                      p.url,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
                if (p.leadArtists.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${AppStrings.t('sprite.credits.leadArtists')}: ${p.leadArtists.join(', ')}',
                    style: TextStyle(fontSize: 12, color: hint),
                  ),
                ],
                if (p.licenseText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    p.licenseText,
                    style: TextStyle(
                      fontSize: 11,
                      color: hint,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ArtistsTab extends StatelessWidget {
  final List<ArtistCredit> artists;
  const _ArtistsTab({required this.artists});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: artists.length,
      itemBuilder: (ctx, i) {
        final a = artists[i];
        return ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Text(a.name,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Text(
            AppStrings.t('sprite.credits.spriteCount')
                .replaceAll('{n}', '${a.count}'),
            style: TextStyle(fontSize: 11, color: hint),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                a.contributedSprites.join(', '),
                style: TextStyle(
                    fontSize: 11, color: hint, height: 1.5),
              ),
            ),
          ],
        );
      },
    );
  }
}
