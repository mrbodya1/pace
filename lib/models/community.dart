import 'competition.dart';

class CommunityItem {
  CommunityItem.fromJson(Map<String, dynamic> data)
    : id = data['id'] as String,
      name = data['name'] as String,
      description = data['description'] as String,
      city = data['city'] as String? ?? '',
      sport = data['sport'] as String,
      owner = data['owner'] == true,
      joined = data['joined'] == true,
      members = data['members'] as int,
      kind = data['kind'] as String? ?? 'club',
      audience = data['audience'] as String? ?? 'open',
      clubId = data['clubId'] as String?,
      clubName = data['clubName'] as String?,
      clubJoined = data['clubJoined'] == true,
      startsAt = DateTime.tryParse(data['startsAt'] as String? ?? '')
          ?.toLocal(),
      endsAt = DateTime.tryParse(data['endsAt'] as String? ?? '')?.toLocal(),
      scoring = data['scoring'] is Map
          ? CompetitionRule.fromJson(
              Map<String, dynamic>.from(data['scoring'] as Map),
            )
          : null;

  final String id, name, description, city, sport, kind, audience;
  final String? clubId, clubName;
  final bool owner, joined, clubJoined;
  final int members;
  final DateTime? startsAt, endsAt;
  final CompetitionRule? scoring;
  bool get isClub => kind == 'club';
  int get requiredXp => isClub || audience == 'club' ? 9000 : 1000;
  int get requiredLevel => isClub || audience == 'club' ? 5 : 2;
  String? joinRestriction(int xp, DateTime now) {
    if (!isClub && endsAt != null && !endsAt!.isAfter(now)) {
      return 'Событие завершено';
    }
    if (xp < requiredXp) {
      return 'С уровня $requiredLevel · ещё ${requiredXp - xp} XP';
    }
    if (!isClub && audience == 'club' && !clubJoined) {
      return 'Сначала вступи в клуб';
    }
    return null;
  }
}

class CommunityFeed {
  CommunityFeed.fromJson(Map<String, dynamic> data)
    : xp = data['xp'] as int,
      page = data['page'] as int,
      hasMore = data['hasMore'] == true,
      clubs = _items(data['clubs']),
      events = _items(data['events']),
      ownedClubs = (data['ownedClubs'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  final int xp, page;
  final bool hasMore;
  final List<CommunityItem> clubs, events;
  final List<Map<String, dynamic>> ownedClubs;
  static List<CommunityItem> _items(dynamic items) => (items as List)
      .map((e) => CommunityItem.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
}
