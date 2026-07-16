import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/operations_repository.dart';
import '../domain/operations/operations_models.dart';
import 'app_navigation.dart';

class HostsPage extends StatefulWidget {
  const HostsPage({
    super.key,
    required this.source,
    required this.onAddHost,
    required this.onOpenHost,
    required this.onDestinationSelected,
  });

  final HostListSource source;
  final VoidCallback onAddHost;
  final ValueChanged<HostProfileModel> onOpenHost;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<HostsPage> createState() => _HostsPageState();
}

class _HostsPageState extends State<HostsPage> {
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<HostSearchResult> _hosts = const [];
  var _favoritesOnly = false;
  var _loading = true;
  var _loadFailed = false;
  var _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_loadHosts());
  }

  @override
  void didUpdateWidget(covariant HostsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.source, widget.source)) unawaited(_loadHosts());
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_loadHosts()),
    );
  }

  void _selectFilter(bool favoritesOnly) {
    if (_favoritesOnly == favoritesOnly) return;
    setState(() => _favoritesOnly = favoritesOnly);
    unawaited(_loadHosts());
  }

  Future<void> _loadHosts() async {
    final generation = ++_loadGeneration;
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final hosts = await widget.source.searchHosts(
        query: _searchController.text,
        favoritesOnly: _favoritesOnly,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _hosts = hosts;
        _loading = false;
      });
    } on Object {
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          Expanded(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onAddHost: widget.onAddHost),
                    const SizedBox(height: 25),
                    _SearchField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                    ),
                    const SizedBox(height: 18),
                    _Filters(
                      favoritesOnly: _favoritesOnly,
                      onSelected: _selectFilter,
                    ),
                    const SizedBox(height: 14),
                    Expanded(child: _content()),
                  ],
                ),
              ),
            ),
          ),
          DaylinkBottomNavigation(
            currentDestination: AppDestination.hosts,
            onSelected: widget.onDestinationSelected,
          ),
        ],
      ),
    ),
  );

  Widget _content() {
    if (_loading) {
      return const Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: 26),
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF3370FF),
            ),
          ),
        ),
      );
    }
    if (_loadFailed) return _LoadError(onRetry: _loadHosts);
    if (_hosts.isEmpty) {
      return _EmptyHosts(
        searching: _searchController.text.trim().isNotEmpty || _favoritesOnly,
        onAddHost: widget.onAddHost,
      );
    }
    return RefreshIndicator(
      color: const Color(0xFF3370FF),
      onRefresh: _loadHosts,
      child: ListView(
        key: const Key('hosts-list'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.only(bottom: 28),
        children: [_HostList(hosts: _hosts, onOpenHost: widget.onOpenHost)],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onAddHost});

  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '主机',
              key: Key('hosts-title'),
              style: TextStyle(
                color: Color(0xFF1F2329),
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.1,
              ),
            ),
            SizedBox(height: 9),
            Text(
              '连接和管理你的设备',
              style: TextStyle(
                color: Color(0xFF8F959E),
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Semantics(
          button: true,
          label: '添加主机',
          child: Material(
            color: const Color(0xFF3370FF),
            shape: const CircleBorder(),
            child: InkWell(
              key: const Key('hosts-add'),
              customBorder: const CircleBorder(),
              onTap: onAddHost,
              child: const SizedBox.square(
                dimension: 39,
                child: Icon(Icons.add_rounded, size: 25, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: TextField(
      key: const Key('hosts-search'),
      controller: controller,
      onChanged: onChanged,
      maxLength: 255,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: Color(0xFF1F2329), fontSize: 16),
      decoration: InputDecoration(
        counterText: '',
        hintText: '搜索主机',
        hintStyle: const TextStyle(color: Color(0xFF8F959E), fontSize: 16),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: Color(0xFF646A73),
          size: 24,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        enabledBorder: _border(),
        focusedBorder: _border(color: const Color(0xFF3370FF)),
      ),
    ),
  );

  OutlineInputBorder _border({Color color = const Color(0xFFD9DCE1)}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(13),
        borderSide: BorderSide(color: color),
      );
}

class _Filters extends StatelessWidget {
  const _Filters({required this.favoritesOnly, required this.onSelected});

  final bool favoritesOnly;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _FilterChip(
        key: const Key('hosts-filter-all'),
        label: '全部',
        selected: !favoritesOnly,
        onTap: () => onSelected(false),
      ),
      const SizedBox(width: 10),
      _FilterChip(
        key: const Key('hosts-filter-favorites'),
        label: '收藏',
        selected: favoritesOnly,
        onTap: () => onSelected(true),
      ),
    ],
  );
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFFE8F1FF) : Colors.white,
    shape: RoundedRectangleBorder(
      side: BorderSide(
        color: selected ? const Color(0xFFB7D3FF) : const Color(0xFFD9DCE1),
      ),
      borderRadius: BorderRadius.circular(13),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF3370FF) : const Color(0xFF4E5969),
            fontSize: 14,
            height: 1.2,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _HostList extends StatelessWidget {
  const _HostList({required this.hosts, required this.onOpenHost});

  final List<HostSearchResult> hosts;
  final ValueChanged<HostProfileModel> onOpenHost;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: Color(0xFFD9DCE1)),
      borderRadius: BorderRadius.circular(14),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < hosts.length; index++) ...[
          _HostRow(
            result: hosts[index],
            onTap: () => onOpenHost(hosts[index].host),
          ),
          if (index != hosts.length - 1)
            const Divider(height: 1, thickness: 1, color: Color(0xFFEDEFF2)),
        ],
      ],
    ),
  );
}

class _HostRow extends StatelessWidget {
  const _HostRow({required this.result, required this.onTap});

  final HostSearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final host = result.host;
    final status = _hostStatus(host.agentState);
    final system = host.system.trim();
    final subtitle = system.isEmpty
        ? host.address
        : '${host.address} · $system';
    final isServer =
        system.toLowerCase().contains('ubuntu') ||
        system.toLowerCase().contains('linux');
    return InkWell(
      key: Key('host-${host.id}'),
      onTap: onTap,
      child: SizedBox(
        height: 72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(19, 0, 14, 0),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 35,
                child: Icon(
                  isServer
                      ? Icons.dns_outlined
                      : Icons.desktop_windows_outlined,
                  color: const Color(0xFF646A73),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1F2329),
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8F959E),
                        fontSize: 13,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: status.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                status.label,
                style: const TextStyle(
                  color: Color(0xFF646A73),
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: Color(0xFF8F959E),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHosts extends StatelessWidget {
  const _EmptyHosts({required this.searching, required this.onAddHost});

  final bool searching;
  final VoidCallback onAddHost;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.55),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.desktop_windows_outlined,
          size: 34,
          color: const Color(0xFF8F959E).withValues(alpha: 0.8),
        ),
        const SizedBox(height: 12),
        Text(
          searching ? '没有匹配的主机' : '还没有主机',
          key: const Key('hosts-empty'),
          style: const TextStyle(color: Color(0xFF646A73), fontSize: 15),
        ),
        if (!searching) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onAddHost, child: const Text('添加主机')),
        ],
      ],
    ),
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Align(
    alignment: const Alignment(0, -0.55),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '主机列表加载失败',
          key: Key('hosts-load-error'),
          style: TextStyle(color: Color(0xFF646A73), fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

({String label, Color color}) _hostStatus(String state) {
  final normalized = state.trim().toLowerCase();
  if (const {
    'online',
    'connected',
    'healthy',
    'running',
  }.contains(normalized)) {
    return (label: '在线', color: const Color(0xFF34C77B));
  }
  if (const {'offline', 'disconnected', 'stopped'}.contains(normalized)) {
    return (label: '离线', color: const Color(0xFF9AA0A9));
  }
  return (label: '未知', color: const Color(0xFF9AA0A9));
}
