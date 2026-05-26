import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class ProjectCredit {
  final String name;
  final String url;
  final List<String> leadArtists;
  final String licenseText;

  ProjectCredit({
    required this.name,
    required this.url,
    required this.leadArtists,
    required this.licenseText,
  });
}

class ArtistCredit {
  final String name;
  final List<String> contributedSprites;
  final List<String> projects;
  final List<String> threadUrls;
  final String permissionNote;

  ArtistCredit({
    required this.name,
    required this.contributedSprites,
    required this.projects,
    required this.threadUrls,
    required this.permissionNote,
  });

  int get count => contributedSprites.length;
}

class SpriteCreditsData {
  final List<ProjectCredit> projects;
  final List<ArtistCredit> artists;

  SpriteCreditsData({required this.projects, required this.artists});

  static SpriteCreditsData? _cached;
  static Future<SpriteCreditsData>? _loading;

  static Future<SpriteCreditsData> load() {
    if (_cached != null) return Future.value(_cached!);
    return _loading ??= _doLoad();
  }

  static Future<SpriteCreditsData> _doLoad() async {
    final raw = await rootBundle.loadString('assets/sprite_credits.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final projectsMap = json['project_credits'] as Map<String, dynamic>;
    final projects = projectsMap.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return ProjectCredit(
        name: e.key,
        url: (v['url'] ?? '') as String,
        leadArtists: ((v['lead_artists'] as List?) ?? const [])
            .map((x) => x.toString())
            .toList(),
        licenseText: (v['license_text'] ?? '') as String,
      );
    }).toList();

    final artistsMap = json['by_artist'] as Map<String, dynamic>;
    final artists = artistsMap.entries.map((e) {
      final v = e.value as Map<String, dynamic>;
      return ArtistCredit(
        name: e.key,
        contributedSprites: ((v['contributed_sprites'] as List?) ?? const [])
            .map((x) => x.toString())
            .toList(),
        projects: ((v['projects'] as List?) ?? const [])
            .map((x) => x.toString())
            .toList(),
        threadUrls: ((v['thread_urls'] as List?) ?? const [])
            .map((x) => x.toString())
            .toList(),
        permissionNote: (v['permission_note'] ?? '') as String,
      );
    }).toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return _cached = SpriteCreditsData(projects: projects, artists: artists);
  }
}
