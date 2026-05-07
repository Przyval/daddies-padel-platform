import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import 'package:daddies_app/core/theme/app_colors.dart';
import 'package:daddies_app/core/utils/snackbar_helper.dart';
import 'package:daddies_app/core/utils/haptic_helper.dart';
import 'package:daddies_app/core/widgets/success_overlay.dart';
import 'package:daddies_app/core/utils/americano_rotation.dart';
import 'package:daddies_app/models/match_result_model.dart';
import 'package:daddies_app/models/slot_model.dart';
import 'package:daddies_app/services/data_service.dart';
import 'package:provider/provider.dart';
import 'package:daddies_app/features/chips/providers/chips_provider.dart';

/// Screen for Mimin to input match results.
///
/// Supports Manual, Americano (circle-method rotation), and
/// Mexicano (reseed-by-points) formats with auto-pair + manual override.
class MatchScoringScreen extends StatefulWidget {
  final String sessionId;

  const MatchScoringScreen({super.key, required this.sessionId});

  @override
  State<MatchScoringScreen> createState() => _MatchScoringScreenState();
}

class _MatchScoringScreenState extends State<MatchScoringScreen> {
  final _uuid = const Uuid();
  final DataService _ds = DataService();

  List<SlotModel> _players = [];
  int _nextRound = 1;

  // Match format: null = manual, 'americano', 'mexicano'
  String? _matchFormat;
  List<RoundPairing>? _americanoSchedule;

  // For current round input
  final List<String> _team1Ids = [];
  final List<String> _team1Names = [];
  final List<String> _team2Ids = [];
  final List<String> _team2Names = [];
  final _score1Controller = TextEditingController();
  final _score2Controller = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
    _loadMatchFormat();
  }

  @override
  void dispose() {
    _score1Controller.dispose();
    _score2Controller.dispose();
    super.dispose();
  }

  void _loadPlayers() {
    final allSlots = _ds.getSlotsForSession(widget.sessionId);
    _players = allSlots
        .where((s) =>
            s.status == SlotStatus.confirmed ||
            s.status == SlotStatus.paid ||
            s.status == SlotStatus.locked)
        .toList();

    final existing = _ds.getMatchResultsForSession(widget.sessionId);
    _nextRound = existing.isEmpty ? 1 : existing.last.round + 1;
  }

  void _loadMatchFormat() {
    final session = _ds.getSessionById(widget.sessionId);
    if (session != null && session.matchFormat != null) {
      _matchFormat = session.matchFormat;
      if (_matchFormat == 'americano') _generateAmericanoSchedule();
    }
  }

  void _setMatchFormat(String? format) {
    setState(() {
      _matchFormat = format;
      _americanoSchedule = null;
      _clearTeamSelection();
    });
    final session = _ds.getSessionById(widget.sessionId);
    if (session != null) {
      _ds.updateSession(session.copyWith(matchFormat: format));
    }
    if (format == 'americano') _generateAmericanoSchedule();
  }

  void _generateAmericanoSchedule() {
    if (_players.length < 4) return;
    setState(() {
      _americanoSchedule = AmericanoRotation.generateSchedule(
        _players.map((p) => p.userId).toList(),
      );
    });
  }

  void _autoPairCurrentRound() {
    if (_players.length < 4) {
      SnackbarHelper.showError(context, 'Minimal 4 pemain untuk auto-pair');
      return;
    }

    if (_matchFormat == 'americano' && _americanoSchedule != null) {
      final roundIdx = _nextRound - 1;
      if (roundIdx < _americanoSchedule!.length) {
        final round = _americanoSchedule![roundIdx];
        if (round.courts.isNotEmpty) {
          _applyPairing(round.courts.first.pair);
          return;
        }
      }
      SnackbarHelper.showError(context, 'Jadwal habis — gunakan manual pairing');
    } else if (_matchFormat == 'mexicano') {
      final existing = _ds.getMatchResultsForSession(widget.sessionId);
      final playerIds = _players.map((p) => p.userId).toList();
      final pointsMap = <String, int>{};
      final matchesMap = <String, int>{};
      for (final id in playerIds) {
        pointsMap[id] = 0;
        matchesMap[id] = 0;
      }
      for (final m in existing) {
        for (final id in m.allPlayerIds) {
          if (pointsMap.containsKey(id)) {
            pointsMap[id] = pointsMap[id]! + m.pointsFor(id);
            matchesMap[id] = matchesMap[id]! + 1;
          }
        }
      }
      final standings = playerIds
          .map((id) => PlayerStanding(
                playerId: id,
                totalPoints: pointsMap[id] ?? 0,
                matchesPlayed: matchesMap[id] ?? 0,
              ))
          .toList();
      final round = AmericanoRotation.generateMexicanoRound(standings, _nextRound);
      if (round.courts.isNotEmpty) _applyPairing(round.courts.first.pair);
    }
  }

  void _applyPairing(TeamPair pair) {
    setState(() {
      _clearTeamSelection();
      for (final id in pair.team1) {
        final p = _players.where((p) => p.userId == id).firstOrNull;
        if (p != null) { _team1Ids.add(p.userId); _team1Names.add(p.userName); }
      }
      for (final id in pair.team2) {
        final p = _players.where((p) => p.userId == id).firstOrNull;
        if (p != null) { _team2Ids.add(p.userId); _team2Names.add(p.userName); }
      }
    });
  }

  void _clearTeamSelection() {
    _team1Ids.clear(); _team1Names.clear();
    _team2Ids.clear(); _team2Names.clear();
    _score1Controller.clear(); _score2Controller.clear();
  }

  void _togglePlayer(SlotModel slot, int team) {
    setState(() {
      _team1Ids.remove(slot.userId); _team1Names.remove(slot.userName);
      _team2Ids.remove(slot.userId); _team2Names.remove(slot.userName);
      if (team == 1 && _team1Ids.length < 2) {
        _team1Ids.add(slot.userId); _team1Names.add(slot.userName);
      } else if (team == 2 && _team2Ids.length < 2) {
        _team2Ids.add(slot.userId); _team2Names.add(slot.userName);
      }
    });
  }

  void _removePlayer(String userId, int team) {
    setState(() {
      if (team == 1) {
        final idx = _team1Ids.indexOf(userId);
        if (idx != -1) { _team1Ids.removeAt(idx); _team1Names.removeAt(idx); }
      } else {
        final idx = _team2Ids.indexOf(userId);
        if (idx != -1) { _team2Ids.removeAt(idx); _team2Names.removeAt(idx); }
      }
    });
  }

  bool get _canSave =>
      _team1Ids.length == 2 && _team2Ids.length == 2 &&
      _score1Controller.text.isNotEmpty && _score2Controller.text.isNotEmpty;

  Future<void> _saveResult() async {
    if (!_canSave) return;
    final score1 = int.tryParse(_score1Controller.text) ?? 0;
    final score2 = int.tryParse(_score2Controller.text) ?? 0;
    setState(() => _isSaving = true);
    try {
      final result = MatchResultModel(
        id: _uuid.v4(), sessionId: widget.sessionId, round: _nextRound,
        team1PlayerIds: List.from(_team1Ids), team1PlayerNames: List.from(_team1Names),
        team2PlayerIds: List.from(_team2Ids), team2PlayerNames: List.from(_team2Names),
        team1Score: score1, team2Score: score2, createdAt: DateTime.now(),
      );
      await _ds.addMatchResult(result);
      if (!mounted) return;

      // Award chips for match result
      final isDraw = score1 == score2;
      final winnerIds = score1 > score2 ? result.team1PlayerIds : result.team2PlayerIds;
      final winnerNames = score1 > score2 ? result.team1PlayerNames : result.team2PlayerNames;
      final loserIds = score1 > score2 ? result.team2PlayerIds : result.team1PlayerIds;
      final loserNames = score1 > score2 ? result.team2PlayerNames : result.team1PlayerNames;
      await context.read<ChipsProvider>().awardMatchChips(
        matchResultId: result.id,
        sessionId: widget.sessionId,
        winnerIds: winnerIds,
        winnerNames: winnerNames,
        loserIds: loserIds,
        loserNames: loserNames,
        isDraw: isDraw,
        stakingEnabled: false,
        stakeAmount: 0,
      );
      if (!mounted) return;

      HapticHelper.success();
      SuccessOverlay.show(context, message: 'Round $_nextRound tersimpan!');
      setState(() { _isSaving = false; _clearTeamSelection(); _nextRound++; });
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) SnackbarHelper.showError(context, 'Gagal menyimpan: $e');
    }
  }

  int _teamForPlayer(String userId) {
    if (_team1Ids.contains(userId)) return 1;
    if (_team2Ids.contains(userId)) return 2;
    return 0;
  }

  void _showScheduleSheet() {
    if (_americanoSchedule == null || _americanoSchedule!.isEmpty) return;
    final nameMap = {for (final p in _players) p.userId: p.userName};
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6, minChildSize: 0.3, maxChildSize: 0.85, expand: false,
        builder: (context, sc) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('Jadwal Americano', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.deepCharcoal)),
            const SizedBox(height: 4),
            Text('${_americanoSchedule!.length} rounds, ${_players.length} pemain', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 16),
            Expanded(child: ListView.builder(
              controller: sc, itemCount: _americanoSchedule!.length,
              itemBuilder: (context, i) {
                final round = _americanoSchedule![i];
                final isCurrent = round.round == _nextRound;
                final isPast = round.round < _nextRound;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrent ? AppColors.forestInk.withValues(alpha: 0.08) : AppColors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: isCurrent ? Border.all(color: AppColors.forestInk, width: 1.5) : null,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text('Round ${round.round}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isPast ? AppColors.textTertiary : AppColors.forestInk)),
                      if (isCurrent) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.forestInk, borderRadius: BorderRadius.circular(4)), child: const Text('SEKARANG', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.white)))],
                      if (isPast) ...[const SizedBox(width: 8), const Icon(Icons.check_circle, size: 14, color: AppColors.statusCompleted)],
                    ]),
                    const SizedBox(height: 6),
                    ...round.courts.map((c) {
                      final t1 = c.pair.team1.map((id) => nameMap[id] ?? '?').join(' & ');
                      final t2 = c.pair.team2.map((id) => nameMap[id] ?? '?').join(' & ');
                      return Text('Court ${c.court}: $t1  vs  $t2', style: TextStyle(fontSize: 12, color: isPast ? AppColors.textTertiary : AppColors.textSecondary));
                    }),
                  ]),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existingResults = _ds.getMatchResultsForSession(widget.sessionId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Scoring — Round $_nextRound'),
        backgroundColor: AppColors.forestInk,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          if (_matchFormat == 'americano' && _americanoSchedule != null)
            IconButton(icon: const Icon(Icons.calendar_month_outlined, size: 22), tooltip: 'Jadwal', onPressed: _showScheduleSheet),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === FORMAT SELECTOR ===
          _buildFormatSelector(),
          const SizedBox(height: 16),

          // === EXISTING RESULTS ===
          if (existingResults.isNotEmpty) ...[
            const Text('Hasil Sebelumnya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.deepCharcoal)),
            const SizedBox(height: 8),
            ...existingResults.map(_buildResultCard),
            const SizedBox(height: 20),
          ],

          // === NEW ROUND HEADER ===
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.forestInk.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Round $_nextRound', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.forestInk)),
                const SizedBox(height: 4),
                Text(
                  _matchFormat == null ? 'Pilih 2 pemain per tim, lalu masukkan skor.'
                      : _matchFormat == 'americano' ? 'Americano — rotasi otomatis'
                      : 'Mexicano — reseed by poin',
                  style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
              ])),
              if (_matchFormat != null && _players.length >= 4)
                FilledButton.icon(
                  onPressed: _autoPairCurrentRound,
                  icon: const Icon(Icons.auto_awesome, size: 16),
                  label: const Text('Auto-pair'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forestInk, foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 16),

          // Team boxes
          Row(children: [
            Expanded(child: _buildTeamBox(1)),
            const SizedBox(width: 12),
            const Text('VS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forestInk)),
            const SizedBox(width: 12),
            Expanded(child: _buildTeamBox(2)),
          ]),
          const SizedBox(height: 16),

          // Player chips
          const Text('Pemain', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.deepCharcoal)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _players.map((slot) {
              final team = _teamForPlayer(slot.userId);
              final selected = team > 0;
              return GestureDetector(
                onTap: () {
                  if (selected) { _removePlayer(slot.userId, team); }
                  else if (_team1Ids.length < 2) { _togglePlayer(slot, 1); }
                  else if (_team2Ids.length < 2) { _togglePlayer(slot, 2); }
                },
                onLongPress: () { if (!selected && _team2Ids.length < 2) _togglePlayer(slot, 2); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: team == 1 ? AppColors.forestInk.withValues(alpha: 0.15) : team == 2 ? AppColors.mossAccent.withValues(alpha: 0.15) : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (selected) ...[
                      Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle, color: team == 1 ? AppColors.forestInk : AppColors.mossAccent),
                        child: Center(child: Text('$team', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.white)))),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Text(slot.userName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: selected ? AppColors.deepCharcoal : AppColors.textSecondary))),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Score input
          Row(children: [
            Expanded(child: _scoreField(_score1Controller, 'Tim 1', AppColors.forestInk)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.forestInk))),
            Expanded(child: _scoreField(_score2Controller, 'Tim 2', AppColors.mossAccent)),
          ]),
          const SizedBox(height: 24),

          // Save button
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: (_canSave && !_isSaving) ? _saveResult : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestInk, foregroundColor: AppColors.textOnPrimary,
                disabledBackgroundColor: AppColors.forestInk.withValues(alpha: 0.3),
                shape: const StadiumBorder(),
              ),
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                  : const Text('Simpan Round', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _scoreField(TextEditingController ctrl, String label, Color color) {
    return TextField(
      controller: ctrl, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color),
      decoration: InputDecoration(
        hintText: '0', hintStyle: TextStyle(color: AppColors.textTertiary.withValues(alpha: 0.3)),
        labelText: label, labelStyle: const TextStyle(fontSize: 12),
        filled: true, fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: 2)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        _formatChip(null, 'Manual', Icons.touch_app_outlined),
        _formatChip('americano', 'Americano', Icons.shuffle),
        _formatChip('mexicano', 'Mexicano', Icons.trending_up),
      ]),
    );
  }

  Widget _formatChip(String? format, String label, IconData icon) {
    final active = _matchFormat == format;
    return Expanded(child: GestureDetector(
      onTap: () => _setMatchFormat(format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: active ? AppColors.forestInk : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: active ? AppColors.white : AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w500, color: active ? AppColors.white : AppColors.textTertiary)),
        ]),
      ),
    ));
  }

  Widget _buildTeamBox(int team) {
    final ids = team == 1 ? _team1Ids : _team2Ids;
    final names = team == 1 ? _team1Names : _team2Names;
    final color = team == 1 ? AppColors.forestInk : AppColors.mossAccent;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Column(children: [
        Text('Tim $team', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 8),
        if (names.isEmpty)
          Text('Pilih 2 pemain', style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.5)))
        else
          ...names.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(children: [
              Expanded(child: Text(e.value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color), overflow: TextOverflow.ellipsis)),
              GestureDetector(onTap: () => _removePlayer(ids[e.key], team), child: Icon(Icons.close, size: 14, color: color)),
            ]),
          )),
      ]),
    );
  }

  Widget _buildResultCard(MatchResultModel result) {
    final w1 = result.winningTeam == 1;
    final w2 = result.winningTeam == 2;
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Round ${result.round}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Column(children: result.team1PlayerNames.map((n) => Text(n, style: TextStyle(fontSize: 13, fontWeight: w1 ? FontWeight.w700 : FontWeight.w500, color: w1 ? AppColors.statusCompleted : AppColors.deepCharcoal), textAlign: TextAlign.center)).toList())),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.forestInk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text('${result.team1Score} : ${result.team2Score}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.forestInk)),
          ),
          Expanded(child: Column(children: result.team2PlayerNames.map((n) => Text(n, style: TextStyle(fontSize: 13, fontWeight: w2 ? FontWeight.w700 : FontWeight.w500, color: w2 ? AppColors.statusCompleted : AppColors.deepCharcoal), textAlign: TextAlign.center)).toList())),
        ]),
      ]),
    );
  }
}
