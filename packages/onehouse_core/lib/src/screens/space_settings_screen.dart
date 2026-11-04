import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../app_services.dart';
import '../space_summary.dart';
import '../theme.dart';
import '../widgets/dialogs.dart';
import '../widgets/links.dart';
import '../widgets/report_sheet.dart';
import '../widgets/role_badge.dart';
import 'members_screen.dart';
import 'recovery_code_screen.dart';

/// 가계부·메모집 설정. 나가거나 삭제하면 true를 돌려준다 (목록으로 돌아가야 함).
class SpaceSettingsScreen extends StatefulWidget {
  const SpaceSettingsScreen({super.key, required this.services, required this.spaceId, this.extraTiles});

  final AppServices services;
  final String spaceId;

  /// 앱마다 더 넣을 항목 (예: 가계부의 카테고리 관리). 멤버 관리와 같은 묶음 맨 위에 들어간다.
  /// 탭해서 무언가 바뀌었으면 [markChanged]를 불러 주면 설정을 닫을 때 목록을 새로 고친다.
  final List<Widget> Function(BuildContext context, SpaceRole role, VoidCallback markChanged)? extraTiles;

  @override
  State<SpaceSettingsScreen> createState() => _SpaceSettingsScreenState();
}

class _SpaceSettingsScreenState extends State<SpaceSettingsScreen> {
  Map<String, dynamic>? _detail;
  String? _error;
  bool _changed = false;

  String get _base => '${widget.services.space.apiPath}/${widget.spaceId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.services.api.get(_base);
      if (!mounted) return;
      setState(() {
        _detail = res;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isForbidden || e.status == 404) {
        Navigator.of(context).pop(true);
        return;
      }
      setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = errorMessage(e));
    }
  }

  Map<String, dynamic> get _member => _detail!['member'] as Map<String, dynamic>;
  SpaceRole get _role => parseRole(_member['role'] as String?) ?? SpaceRole.member;

  Future<void> _copy(String text, String done) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showMessage(context, done);
  }

  Future<void> _rename() async {
    final space = widget.services.space;
    final name = await promptText(context, title: '${space.noun} 이름', initial: _detail!['name'] as String);
    if (name == null) return;
    try {
      await widget.services.api.patch(_base, {'name': name});
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _nickname() async {
    final nickname = await promptText(
      context,
      title: '내 닉네임',
      initial: _member['nickname'] as String,
      maxLength: 20,
    );
    if (nickname == null) return;
    try {
      await widget.services.api.patch('$_base/me', {'nickname': nickname});
      _changed = true;
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _reissueInvite() async {
    final ok = await confirmDialog(
      context,
      title: '초대코드를 새로 만들까요?',
      message: '지금 코드는 더 이상 쓸 수 없어요. 이미 들어온 멤버에게는 영향이 없어요.',
      action: '새로 만들기',
    );
    if (!ok) return;
    try {
      await widget.services.api.post('$_base/invite-code');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _recoveryCode() async {
    final needs = _detail!['needs_recovery_code'] == true;
    if (!needs) {
      final ok = await confirmDialog(
        context,
        title: '복구코드를 새로 만들까요?',
        message: '지금 복구코드는 더 이상 쓸 수 없어요.',
        action: '새로 만들기',
      );
      if (!ok) return;
    }
    try {
      final res = await widget.services.api.post('$_base/recovery-code');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (_) => RecoveryCodeScreen(
            space: widget.services.space,
            spaceName: _detail!['name'] as String,
            recoveryCode: res['recovery_code'] as String,
            reissued: true,
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _transferCode() async {
    try {
      final code = await widget.services.session.createTransferCode();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('기기 이전 코드', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '새 폰의 첫 화면에서 "기존 기기에서 이전하기"를 누르고 이 코드를 넣어 주세요. 10분 동안 한 번만 쓸 수 있어요.',
                style: TextStyle(height: 1.5),
              ),
              const SizedBox(height: 16),
              SelectableText(
                code.code,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: 2, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: code.code)),
              child: const Text('복사'),
            ),
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('닫기')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _leave() async {
    final space = widget.services.space;
    final ok = await confirmDialog(
      context,
      title: '이 ${space.noun}에서 나갈까요?',
      message: '다시 들어오려면 초대코드로 요청하고 승인을 받아야 해요. 내가 쓴 기록은 남아요.',
      action: '나가기',
      danger: true,
    );
    if (!ok) return;
    try {
      await widget.services.api.post('$_base/leave');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete() async {
    final space = widget.services.space;
    final name = _detail!['name'] as String;
    final typed = await promptText(
      context,
      title: '${space.nounObj} 삭제할까요?',
      message: '모든 멤버가 더 이상 볼 수 없어요. 확인을 위해 이름 "$name"을(를) 그대로 입력해 주세요.',
      hint: name,
      action: '삭제',
      danger: true,
    );
    if (typed == null) return;
    try {
      await widget.services.api.delete(_base, {'confirm_name': typed});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final space = widget.services.space;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed ? false : null);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('${space.noun} 설정')),
        body: detail == null
            ? Center(
                child: _error == null
                    ? const CircularProgressIndicator()
                    : TextButton(onPressed: _load, child: Text('$_error\n다시 시도', textAlign: TextAlign.center)),
              )
            : _buildBody(detail),
      ),
    );
  }

  Widget _buildBody(Map<String, dynamic> detail) {
    final space = widget.services.space;
    final role = _role;
    final owner = role == SpaceRole.owner;
    final manager = isManager(role);
    final invite = detail['invite_code'] as String?;
    final primary = Theme.of(context).colorScheme.primary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _Group(children: [
          ListTile(
            title: Text(detail['name'] as String, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            subtitle: Text('나: ${_member['nickname']}'),
            trailing: RoleBadge(role),
          ),
        ]),
        if (owner && detail['needs_recovery_code'] == true)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.expenseBg, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('방장 복구코드가 아직 없어요',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenseFg)),
                const SizedBox(height: 4),
                const Text('폰을 잃어버렸을 때 방장 권한을 되찾으려면 복구코드를 만들어 저장해 두세요.',
                    style: TextStyle(height: 1.5, color: AppColors.expenseFg)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _recoveryCode,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  child: const Text('복구코드 만들기', style: TextStyle(fontSize: 15)),
                ),
              ],
            ),
          ),
        if (manager && invite != null)
          _Group(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('초대코드', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          invite,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                            color: primary,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '초대코드 복사',
                        onPressed: () => _copy(
                          '${space.appName} 초대코드: $invite\n앱에서 "초대코드로 참여하기"를 눌러 입력해 주세요.',
                          '초대 문구를 복사했어요',
                        ),
                        icon: const Icon(Icons.copy),
                      ),
                    ],
                  ),
                  const Text('코드를 받은 사람이 참여 요청을 보내면, 방장·부방장이 승인해야 들어올 수 있어요.',
                      style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (owner)
              ListTile(leading: const Icon(Icons.refresh), title: const Text('초대코드 새로 만들기'), onTap: _reissueInvite),
          ]),
        _Group(children: [
          ...?widget.extraTiles?.call(context, role, () => _changed = true),
          if (manager)
            ListTile(
              leading: const Icon(Icons.group_outlined),
              title: const Text('멤버 관리'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final gone = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => MembersScreen(
                      services: widget.services,
                      spaceId: widget.spaceId,
                      myMemberId: _member['id'] as String,
                      myRole: role,
                    ),
                  ),
                );
                if (gone == true) _changed = true;
                await _load();
              },
            ),
          ListTile(leading: const Icon(Icons.badge_outlined), title: const Text('내 닉네임 바꾸기'), onTap: _nickname),
          if (owner)
            ListTile(leading: const Icon(Icons.edit_outlined), title: Text('${space.noun} 이름 바꾸기'), onTap: _rename),
          if (owner)
            ListTile(leading: const Icon(Icons.key_outlined), title: const Text('방장 복구코드 새로 만들기'), onTap: _recoveryCode),
        ]),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.phonelink_setup),
            title: const Text('기기 이전 코드 만들기'),
            subtitle: const Text('새 폰으로 바꿀 때 써요'),
            onTap: _transferCode,
          ),
        ]),
        _Group(children: [
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('개인정보처리방침'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => openExternal(context, privacyUrl(widget.services.api)),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('신고하기'),
            subtitle: const Text('부적절한 내용이나 멤버를 운영자에게 알려요'),
            onTap: () => showReportSheet(
              context,
              services: widget.services,
              spaceId: widget.spaceId,
              targetLabel: '${_detail!['name']} ${space.noun}',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('문의하기'),
            subtitle: const Text(supportEmail),
            onTap: () => openExternal(context, 'mailto:$supportEmail?subject=${Uri.encodeComponent(space.appName)}'),
          ),
        ]),
        _Group(children: [
          if (!owner)
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.danger),
              title: Text('${space.noun}에서 나가기', style: const TextStyle(color: AppColors.danger)),
              onTap: _leave,
            ),
          if (owner)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('${space.noun} 삭제', style: const TextStyle(color: AppColors.danger)),
              subtitle: const Text('방장은 나갈 수 없어요. 방장을 넘기거나 삭제해 주세요.'),
              onTap: _delete,
            ),
        ]),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      );
}
