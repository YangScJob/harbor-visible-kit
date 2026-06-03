import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:harbor_visible_kit/app/localization/app_strings.dart';
import 'package:harbor_visible_kit/app/theme/app_theme.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_connection.dart';
import 'package:harbor_visible_kit/domain/harbor/harbor_server.dart';
import 'package:harbor_visible_kit/app/state/connection_store.dart';
import 'package:harbor_visible_kit/data/harbor/harbor_api_service.dart';
import 'package:harbor_visible_kit/core/widgets/app_select.dart';
import 'package:harbor_visible_kit/core/widgets/app_notice.dart';
import 'package:harbor_visible_kit/core/widgets/connection_status_badge.dart';
import 'package:harbor_visible_kit/core/widgets/labeled_field.dart';
import 'package:harbor_visible_kit/core/widgets/log_console.dart';
import 'package:harbor_visible_kit/core/widgets/section_title.dart';

/// Harbor connection configuration page.
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  static const double _connectionFieldWidth = 430;

  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '8085');
  final _userController = TextEditingController(text: 'admin');
  final _passController = TextEditingController();

  final List<LogEntry> _logs = [];
  bool _isTesting = false;
  bool _rememberPassword = false;
  bool _obscurePassword = true;
  ConnectionStore? _connectionStore;
  String? _syncedSelectionKey;

  @override
  void initState() {
    super.initState();
    _connectionStore = context.read<ConnectionStore>()
      ..addListener(_handleConnectionStoreChanged);
    _syncFormFromStore(_connectionStore!, notify: false);
  }

  void _handleConnectionStoreChanged() {
    final store = _connectionStore;
    if (!mounted || store == null) return;

    final nextKey = _storeSelectionKey(store);
    if (nextKey == _syncedSelectionKey) return;

    _syncFormFromStore(store);
  }

  void _syncFormFromStore(ConnectionStore store, {bool notify = true}) {
    final conn = store.connection;
    _hostController.text = conn.host;
    _portController.text = conn.port.toString();
    _userController.text = conn.username;
    _passController.text = conn.password;
    _rememberPassword = store.rememberPassword;
    _syncedSelectionKey = _storeSelectionKey(store);
    if (notify && mounted) {
      setState(() {});
    }
  }

  String _storeSelectionKey(ConnectionStore store) {
    return [
      store.selectedServerId ?? '',
      store.selectedUsername,
      store.rememberPassword.toString(),
    ].join('|');
  }

  HarborConnection get _currentConnection => HarborConnection(
    host: _hostController.text.trim(),
    port: int.tryParse(_portController.text.trim()) ?? 8085,
    username: _userController.text.trim(),
    password: _passController.text,
  );

  void _addLog(String message, {LogLevel level = LogLevel.info}) {
    setState(() {
      _logs.add(LogEntry(message: message, level: level));
    });
  }

  Future<void> _testConnection() async {
    final strings = context.l10n;
    final conn = _currentConnection;
    if (!conn.isValid) {
      _addLog(
        strings.pick(
          '请填写完整的连接信息',
          'Please complete the connection information',
        ),
        level: LogLevel.warning,
      );
      return;
    }

    setState(() => _isTesting = true);
    _addLog(
      strings.pick('正在测试连接 ${conn.registry}...', 'Testing ${conn.registry}...'),
    );

    final api = context.read<HarborApiService>();
    final store = context.read<ConnectionStore>();

    try {
      api.configure(conn);
      final version = await api.ping();
      final authenticatedUser = await api.authenticate();

      _addLog(
        strings.pick(
          '连接成功! Harbor 版本: $version，认证用户: $authenticatedUser',
          'Connected. Harbor version: $version, authenticated user: $authenticatedUser',
        ),
        level: LogLevel.success,
      );
      if (mounted) {
        AppNotice.success(
          context,
          title: strings.pick('连接成功', 'Connection successful'),
          message: strings.pick(
            'Harbor $version，认证用户 $authenticatedUser',
            'Harbor $version, authenticated user $authenticatedUser',
          ),
        );
      }

      // Save the configuration and update global connection state.
      await store.updateConnection(conn, rememberPassword: _rememberPassword);
      store.setConnected(version);
    } catch (e) {
      _addLog(
        strings.pick('连接失败: $e', 'Connection failed: $e'),
        level: LogLevel.error,
      );
      if (mounted) {
        AppNotice.error(
          context,
          title: strings.pick('连接失败', 'Connection failed'),
          message: strings.errorMessage(e),
        );
      }
      api.disconnect();
      store.setDisconnected();
    } finally {
      setState(() => _isTesting = false);
    }
  }

  @override
  void dispose() {
    _connectionStore?.removeListener(_handleConnectionStoreChanged);
    _hostController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ConnectionStore>();
    final strings = context.l10n;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header.
          Builder(
            builder: (context) {
              final b = Theme.of(context).brightness;
              return Row(
                children: [
                  Icon(Icons.link_rounded, color: AppTheme.prim(b), size: 26),
                  const SizedBox(width: 12),
                  Text(
                    strings.pick('连接面板', 'Connection panel'),
                    style: TextStyle(
                      color: AppTheme.textP(b),
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConnectionStatusBadge(isConnected: store.isConnected),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final b = Theme.of(context).brightness;
              return Text(
                strings.pick(
                  '配置 Harbor Registry 与账号凭据',
                  'Configure Harbor Registry and account credentials',
                ),
                style: TextStyle(color: AppTheme.textM(b), fontSize: 14),
              );
            },
          ),
          const SizedBox(height: 28),

          // Connection information card.
          Builder(
            builder: (context) {
              final b = Theme.of(context).brightness;
              return Container(
                padding: const EdgeInsets.all(22),
                decoration: AppTheme.cardDeco(b),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionTitle(
                      icon: Icons.dns_rounded,
                      title: strings.pick(
                        'Registry 凭据',
                        'Registry credentials',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildServerSelector(context, store),
                    const SizedBox(height: 12),
                    LabeledField(
                      label: strings.pick('用户名', 'Username'),
                      child: SizedBox(
                        width: _connectionFieldWidth,
                        child: TextField(
                          controller: _userController,
                          decoration: InputDecoration(
                            hintText: 'admin',
                            prefixIcon: const Icon(
                              Icons.person_rounded,
                              size: 18,
                            ),
                            suffixIcon: _buildUsernameActions(
                              context,
                              store.usernames,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildPasswordField(b),
                    const SizedBox(height: 6),
                    _buildRememberPasswordControl(b),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.bg(b),
                              ),
                            )
                          : const Icon(Icons.link_rounded, size: 18),
                      label: Text(
                        _isTesting
                            ? strings.pick('连接中...', 'Connecting...')
                            : strings.pick('连接', 'Connect'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 20),

          // Logs.
          LogConsole(
            logs: _logs,
            onClear: () => setState(() => _logs.clear()),
            maxHeight: 280,
          ),
        ],
      ),
    );
  }

  Widget _buildServerSelector(BuildContext context, ConnectionStore store) {
    final b = Theme.of(context).brightness;
    final strings = context.l10n;
    final servers = store.servers;
    final selectedId =
        servers.any((server) => server.id == store.selectedServerId)
        ? store.selectedServerId
        : null;
    final selectedServer = selectedId == null
        ? null
        : servers.firstWhere((server) => server.id == selectedId);

    return LabeledField(
      label: strings.pick('服务器', 'Server'),
      child: Row(
        children: [
          AppSelect<HarborServer>(
            width: _connectionFieldWidth,
            menuWidth: _connectionFieldWidth,
            items: servers,
            value: selectedServer,
            hint: servers.isEmpty
                ? strings.pick('暂无已保存服务器', 'No saved servers')
                : strings.pick('选择服务器', 'Choose server'),
            itemLabel: (server) => server.displayLabel,
            leadingIcon: Icons.dns_rounded,
            brightness: b,
            tooltip: strings.pick('选择服务器', 'Choose server'),
            onChanged: (selected) async {
              if (selected == null) return;
              await context.read<ConnectionStore>().selectServer(selected.id);
              _addLog(
                strings.pick(
                  '已切换服务器: ${selected.displayLabel}',
                  'Switched server: ${selected.displayLabel}',
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          _buildCompactIconButton(
            icon: Icons.clear_rounded,
            color: selectedId == null ? AppTheme.textM(b) : AppTheme.textS(b),
            tooltip: strings.pick('清空服务器选择', 'Clear server selection'),
            onPressed: selectedId == null
                ? null
                : () async {
                    await context.read<ConnectionStore>().clearSelectedServer();
                    _addLog(
                      strings.pick('已清空服务器选择', 'Cleared server selection'),
                    );
                  },
          ),
          _buildCompactIconButton(
            icon: Icons.add_circle_outline_rounded,
            color: AppTheme.prim(b),
            tooltip: strings.pick('新增服务器', 'Add server'),
            onPressed: () => _showServerDialog(context),
          ),
          _buildCompactIconButton(
            icon: Icons.delete_outline_rounded,
            color: selectedId == null ? AppTheme.textM(b) : AppTheme.err(b),
            tooltip: strings.pick('删除当前服务器', 'Delete current server'),
            onPressed: selectedId == null
                ? null
                : () async {
                    final current = servers.firstWhere(
                      (server) => server.id == selectedId,
                    );
                    await context.read<ConnectionStore>().deleteServer(
                      selectedId,
                    );
                    _addLog(
                      strings.pick(
                        '已删除服务器: ${current.displayLabel}',
                        'Deleted server: ${current.displayLabel}',
                      ),
                      level: LogLevel.warning,
                    );
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, color: color, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      splashRadius: 20,
    );
  }

  Widget _buildUsernameActions(BuildContext context, List<String> usernames) {
    final b = Theme.of(context).brightness;
    final strings = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<String>(
          tooltip: strings.pick('选择已保存用户名', 'Choose a saved username'),
          enabled: usernames.isNotEmpty,
          color: AppTheme.surf(b),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: BorderSide(color: AppTheme.div(b)),
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 20,
            color: usernames.isEmpty ? AppTheme.textM(b) : AppTheme.textS(b),
          ),
          onSelected: (username) async {
            _userController.text = username;
            await context.read<ConnectionStore>().selectUsername(username);
            _addLog(
              strings.pick('已选中用户名: $username', 'Selected username: $username'),
            );
          },
          itemBuilder: (context) {
            return usernames.map((username) {
              final selected = username == _userController.text.trim();
              return PopupMenuItem<String>(
                value: username,
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? AppTheme.primDim(b) : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: selected ? AppTheme.prim(b) : AppTheme.textM(b),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected
                                ? AppTheme.prim(b)
                                : AppTheme.textP(b),
                            fontSize: 13,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: selected ? AppTheme.prim(b) : Colors.transparent,
                      ),
                    ],
                  ),
                ),
              );
            }).toList();
          },
        ),
        _buildClearIconButton(
          _userController,
          tooltip: strings.pick('清空用户名', 'Clear username'),
        ),
      ],
    );
  }

  Widget _buildPasswordActions() {
    final strings = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _obscurePassword
              ? strings.pick('显示密码', 'Show password')
              : strings.pick('隐藏密码', 'Hide password'),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            size: 18,
          ),
          onPressed: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
        ),
        _buildClearIconButton(
          _passController,
          tooltip: strings.pick('清空密码', 'Clear password'),
        ),
      ],
    );
  }

  Widget _buildPasswordField(Brightness b) {
    final strings = context.l10n;
    return SizedBox(
      width: _connectionFieldWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.pick('密码', 'Password'),
            style: TextStyle(
              color: AppTheme.textS(b),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _passController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              hintText: strings.pick('输入密码', 'Enter password'),
              prefixIcon: const Icon(Icons.lock_rounded, size: 18),
              suffixIcon: _buildPasswordActions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberPasswordControl(Brightness b) {
    final strings = context.l10n;
    return SizedBox(
      width: _connectionFieldWidth,
      child: Align(
        alignment: Alignment.centerRight,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          onTap: () {
            setState(() => _rememberPassword = !_rememberPassword);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _rememberPassword,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) {
                    setState(() => _rememberPassword = value ?? false);
                  },
                ),
              ),
              const SizedBox(width: 6),
              Text(
                strings.pick('记住密码', 'Remember password'),
                style: TextStyle(color: AppTheme.textS(b), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClearIconButton(
    TextEditingController controller, {
    required String tooltip,
  }) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.clear_rounded, size: 18),
      onPressed: () {
        controller.clear();
        setState(() {});
      },
    );
  }

  InputDecoration _dialogInputDecoration({
    required String hintText,
    required TextEditingController controller,
    IconData? prefixIcon,
  }) {
    final strings = context.l10n;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 18),
      suffixIcon: _buildClearIconButton(controller, tooltip: strings.clear),
    );
  }

  Future<void> _showServerDialog(BuildContext context) async {
    final strings = context.l10n;
    final store = context.read<ConnectionStore>();
    final hostController = TextEditingController();
    final portController = TextEditingController();

    final server = await showDialog<HarborServer>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surf(Theme.of(ctx).brightness),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          title: Text(strings.pick('新增服务器', 'Add server')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: hostController,
                  decoration: _dialogInputDecoration(
                    hintText: strings.pick('请输入服务器地址', 'Enter server address'),
                    controller: hostController,
                    prefixIcon: Icons.computer_rounded,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: portController,
                  decoration: _dialogInputDecoration(
                    hintText: strings.pick('请输入端口', 'Enter port'),
                    controller: portController,
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final host = hostController.text.trim();
                final port = int.tryParse(portController.text.trim()) ?? 0;
                if (host.isEmpty || port <= 0) {
                  _addLog(
                    strings.pick(
                      '请填写有效的服务器地址和端口',
                      'Enter a valid server address and port',
                    ),
                    level: LogLevel.warning,
                  );
                  return;
                }
                Navigator.pop(ctx, HarborServer(host: host, port: port));
              },
              child: Text(strings.pick('保存服务器', 'Save server')),
            ),
          ],
        );
      },
    );

    hostController.dispose();
    portController.dispose();

    if (server == null || !mounted) return;
    await store.saveServer(server);
    _addLog(
      strings.pick(
        '已保存服务器: ${server.displayLabel}',
        'Saved server: ${server.displayLabel}',
      ),
      level: LogLevel.success,
    );
  }
}
