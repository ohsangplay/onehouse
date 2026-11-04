import 'package:flutter/material.dart';

import '../app_services.dart';
import '../space_summary.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/report_sheet.dart';
import '../widgets/role_badge.dart';

/// 멤버 관리 (방장·부방장): 참여 요청 승인·거절·기존 멤버로 연결, 부방장 지정, 차단, 방장 넘기기
class MembersScreen extends StatefulWidget {
  const MembersScreen({
    super.key,
    required this.services,
    required this.spaceId,
    required this.myMemberId,
    required this.myRole,
  });

  final AppServices services;
  final String spaceId;
  final String myMemberId;
  final SpaceRole myRole;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _Member {
  _Member(Map<String, dynamic> json)
      : id = json['id'] as String,
        nickname = json['nickname'] as String,
        role = parseRole(json['role'] as String?) ?? SpaceRole.member,
        wasRevoked = json['was_revoked'] == true;

  final String id;
  final String nickname;
  final SpaceRole role;
  final bool wasRevoked;
}

class _MembersScreenState extends State<MembersScreen> {
  List<_Member>? _members;
  List<_Member> _pending = const [];
  bool _busy = false;
  String? _error;
  SpaceRole _myRole = SpaceRole.member;

  String get _base => '${widget.services.space.apiPath}/${widget.spaceId}';
  bool get _isOwner => _myRole == SpaceRole.owner;

  @override
  void initState() {
    super.initState();
    _myRole = widget.myRole;
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.services.api.get('$_base/members');
      if (!mounted) return;
      setState(() {
        _members = (res['members'] as List).map((e) => _Member(e as Map<String, dynamic>)).toList();
        _pending = (res['pending'] as List).map((e) => _Member(e as Map<String, dynamic>)).toList();
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '멤버 목록을 불러오지 못했어요.');
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, done);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _approve(_Member m) =>
      _run(() => widget.services.api.post('$_base/members/${m.id}/approve'), '${m.nickname}님을 승인했어요.');

  Future<void> _reject(_Member m) async {
    if (!await confirmDialog(context, title: '${m.nickname}님의 요청을 거절할까요?', action: '거절', danger: true)) return;
    await _run(() => widget.services.api.post('$_base/members/${m.id}/reject'), '요청을 거절했어요.');
  }

  /// 폰을 바꾼 기존 멤버가 다시 요청한 경우: 새 기기를 기존 멤버 자리에 이어 붙인다
  Future<void> _link(_Member request) async {
    final candidates = (_members ?? const <_Member>[]).where((m) => m.id != widget.myMemberId).toList();
    if (candidates.isEmpty) {
      showMessage(context, '연결할 수 있는 기존 멤버가 없어요.');
      return;
    }
    final target = await showModalBottomSheet<_Member>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '${request.nickname}님을 어느 멤버로 이을까요?',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                '폰을 바꾼 멤버라면 기존 자리로 이어서, 쓴 기록과 역할이 그대로 남아요.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
              ),
            ),
            for (final m in candidates)
              ListTile(
                title: Text(m.nickname),
                trailing: RoleBadge(m.role),
                onTap: () => Navigator.of(context).pop(m),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    await _run(
      () => widget.services.api.post('$_base/members/${request.id}/approve', {'link_to_member_id': target.id}),
      '${target.nickname}님 자리로 이었어요.',
    );
  }

  Future<void> _memberActions(_Member m) async {
    final canRevoke = m.id != widget.myMemberId &&
        m.role != SpaceRole.owner &&
        (_isOwner || (_myRole == SpaceRole.coOwner && m.role == SpaceRole.member));
    final canRole = _isOwner && m.role != SpaceRole.owner;
    final canTransfer = _isOwner && m.id != widget.myMemberId;
    final canReport = m.id != widget.myMemberId;
    if (!canRevoke && !canRole && !canTransfer && !canReport) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(m.nickname, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (canRole)
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text(m.role == SpaceRole.coOwner ? '부방장 해제' : '부방장으로 지정'),
                onTap: () => Navigator.of(context).pop('role'),
              ),
            if (canTransfer)
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('방장 넘기기'),
                onTap: () => Navigator.of(context).pop('transfer'),
              ),
            if (canReport)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('신고'),
                onTap: () => Navigator.of(context).pop('report'),
              ),
            if (canRevoke)
              ListTile(
                leading: const Icon(Icons.block, color: AppColors.danger),
                title: const Text('차단', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.of(context).pop('revoke'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    final noun = widget.services.space.noun;

    switch (action) {
      case 'report':
        await showReportSheet(
          context,
          services: widget.services,
          spaceId: widget.spaceId,
          targetType: 'member',
          targetId: m.id,
          targetMemberId: m.id,
          targetLabel: '${m.nickname}님',
        );
      case 'role':
        final next = m.role == SpaceRole.coOwner ? 'member' : 'co_owner';
        await _run(
          () => widget.services.api.patch('$_base/members/${m.id}/role', {'role': next}),
          next == 'co_owner' ? '${m.nickname}님을 부방장으로 지정했어요.' : '부방장을 해제했어요.',
        );
      case 'transfer':
        final ok = await confirmDialog(
          context,
          title: '${m.nickname}님에게 방장을 넘길까요?',
          message: '나는 부방장이 되고(자리가 없으면 멤버), 새 방장이 복구코드를 새로 만들어야 해요.',
          action: '넘기기',
          danger: true,
        );
        if (!ok) return;
        await _run(() async {
          final res = await widget.services.api.post('$_base/transfer-owner', {'member_id': m.id});
          _myRole = parseRole(res['my_role'] as String?) ?? SpaceRole.member;
        }, '방장을 넘겼어요.');
        if (mounted && _myRole == SpaceRole.member) Navigator.of(context).pop(true);
      case 'revoke':
        final ok = await confirmDialog(
          context,
          title: '${m.nickname}님을 차단할까요?',
          message: '바로 이 $noun에 들어올 수 없게 돼요. 다시 요청하면 "이전에 차단한 멤버"로 표시돼요.',
          action: '차단',
          danger: true,
        );
        if (!ok) return;
        await _run(() => widget.services.api.post('$_base/members/${m.id}/revoke'), '${m.nickname}님을 차단했어요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = _members;
    return Scaffold(
      appBar: AppBar(title: const Text('멤버 관리')),
      body: members == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (_pending.isNotEmpty) ...[
                    _SectionTitle('참여 요청 ${_pending.length}'),
                    for (final p in _pending)
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(p.nickname,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                ),
                                if (p.wasRevoked) ...[
                                  const SizedBox(width: 8),
                                  const Tag('이전에 차단한 멤버', fg: AppColors.danger, bg: Color(0xFFFDECEA)),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _busy ? null : () => _approve(p),
                                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                                    child: const Text('승인', style: TextStyle(fontSize: 15)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _busy ? null : () => _reject(p),
                                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                                    child: const Text('거절', style: TextStyle(fontSize: 15)),
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _busy ? null : () => _link(p),
                              style: TextButton.styleFrom(minimumSize: const Size(0, 40), padding: EdgeInsets.zero),
                              child: const Text('폰을 바꾼 기존 멤버예요 → 기존 멤버로 연결',
                                  style: TextStyle(fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                  ],
                  _SectionTitle('멤버 ${members.length}'),
                  _Card(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final m in members)
                          ListTile(
                            title: Text(
                              m.id == widget.myMemberId ? '${m.nickname} (나)' : m.nickname,
                              style: const TextStyle(fontSize: 16),
                            ),
                            trailing: RoleBadge(m.role),
                            onTap: () => _memberActions(m),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
                    child: Text(
                      '멤버를 누르면 부방장 지정·차단·신고를 할 수 있어요.',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: padding,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}
