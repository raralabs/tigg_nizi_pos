import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tigg_nizi_pos/tigg_nizi_pos.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NiziPOS B30 Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const B30DemoPage(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class B30DemoPage extends StatefulWidget {
  const B30DemoPage({super.key});

  @override
  State<B30DemoPage> createState() => _B30DemoPageState();
}

class _B30DemoPageState extends State<B30DemoPage> {
  final _pos = TiggNiziPos();

  B30ConnectionState _connectionState = B30ConnectionState.disconnected;
  bool _isConnecting = false;
  String _lastStatus = 'Tap Connect to start';

  StreamSubscription<B30ConnectionState>? _connectionSub;

  // Text display
  final _textTitleCtrl = TextEditingController(text: 'Payment Info');
  final _textSubtitleCtrl = TextEditingController(text: 'Order #1234');
  final _textMsgCtrl = TextEditingController(text: 'Thank you!');

  // QR
  final _qrAmountCtrl = TextEditingController(text: 'Rs. 123.45');
  final _qrActionCtrl = TextEditingController(text: 'Scan to pay');
  final _qrDataCtrl = TextEditingController(text: 'https://yarsa.tech/products/nizipos/b30');

  // Loading
  final _loadingAmountCtrl = TextEditingController(text: 'Rs. 560.50');
  final _loadingMsgCtrl = TextEditingController(text: 'Processing payment...');

  // Success
  final _successTitleCtrl = TextEditingController(text: 'SUCCESS!');
  final _successMsgCtrl = TextEditingController(text: 'Payment successful');

  // Failure
  final _failAmountCtrl = TextEditingController(text: 'Rs. 560.50');
  final _failMsgCtrl = TextEditingController(
    text: 'Payment failed. Try again.',
  );

  // Warning
  final _warnTitleCtrl = TextEditingController(text: 'Device Not Ready');
  final _warnMsgCtrl = TextEditingController(text: 'Please wait...');

  // Info
  final _infoTitleCtrl = TextEditingController(text: 'Important');
  final _infoMsgCtrl = TextEditingController(text: 'Keep device connected');

  // Logo file
  final _logoFileCtrl = TextEditingController(text: 'logo.bmp');

  // Screen timeout
  final _screentimeCtrl = TextEditingController(text: '60');

  // Raw command
  final _rawCmdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _connectionSub = _pos.connectionStream.listen((state) {
      setState(() {
        _connectionState = state;
        _isConnecting = false;
        _lastStatus = switch (state) {
          B30ConnectionState.connected => 'Device connected',
          B30ConnectionState.disconnected => 'Device disconnected',
          B30ConnectionState.permissionDenied => 'USB permission denied',
        };
      });
    });
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    for (final c in [
      _textTitleCtrl,
      _textSubtitleCtrl,
      _textMsgCtrl,
      _qrAmountCtrl, _qrActionCtrl, _qrDataCtrl,
      _loadingAmountCtrl,
      _loadingMsgCtrl,
      _successTitleCtrl,
      _successMsgCtrl,
      _failAmountCtrl,
      _failMsgCtrl,
      _warnTitleCtrl,
      _warnMsgCtrl,
      _infoTitleCtrl,
      _infoMsgCtrl,
      _logoFileCtrl,
      _screentimeCtrl,
      _rawCmdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Connection ──────────────────────────────────────────────────────────────

  Future<void> _connect() async {
    setState(() {
      _isConnecting = true;
      _lastStatus = 'Connecting...';
    });
    try {
      final connected = await _pos.connect();
      if (connected) {
        setState(() {
          _connectionState = B30ConnectionState.connected;
          _lastStatus = 'Device connected';
          _isConnecting = false;
        });
      } else {
        setState(() {
          _lastStatus = 'No device found — plug in B30 or grant USB permission';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _lastStatus = 'Connect error: $e';
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnect() async {
    await _pos.disconnect();
    setState(() {
      _connectionState = B30ConnectionState.disconnected;
      _lastStatus = 'Disconnected';
    });
  }

  // ── Command helper ──────────────────────────────────────────────────────────

  Future<void> _run(String label, Future<void> Function() action) async {
    try {
      await action();
      setState(() => _lastStatus = '$label → sent');
    } catch (e) {
      setState(() => _lastStatus = '$label error: $e');
    }
  }

  bool get _connected => _connectionState == B30ConnectionState.connected;

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NiziPOS B30 Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          _StatusBar(
            state: _connectionState,
            status: _lastStatus,
            isConnecting: _isConnecting,
            onConnect: _connect,
            onDisconnect: _disconnect,
          ),
          Expanded(
            child: _connected ? _buildCommandList() : _buildConnectPrompt(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.usb_off, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'B30 device not connected',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect the device via USB and tap Connect',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isConnecting ? null : _connect,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.usb),
              label: Text(_isConnecting ? 'Connecting…' : 'Connect Device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandList() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Logo ──────────────────────────────────────────────────────────────
        _SectionHeader('Logo / Idle'),
        _ActionTile(
          title: 'Show Idle Logo',
          subtitle: 'Displays the built-in standby image  (IDLE)',
          icon: Icons.image_outlined,
          onTap: () => _run('Idle logo', _pos.showIdleLogo),
        ),
        _InputCard(
          title: 'Show Logo From File',
          icon: Icons.folder_open,
          fields: [_Fld('Filename', _logoFileCtrl)],
          onSend: () => _run(
            'Logo file',
            () => _pos.showLogoFromFile(_logoFileCtrl.text.trim()),
          ),
        ),

        // ── Display ───────────────────────────────────────────────────────────
        _SectionHeader('Display'),
        _InputCard(
          title: 'Text Display',
          icon: Icons.text_fields,
          fields: [
            _Fld('Main Title', _textTitleCtrl),
            _Fld('Subtitle', _textSubtitleCtrl),
            _Fld('Message', _textMsgCtrl),
          ],
          onSend: () => _run(
            'Text display',
            () => _pos.displayText(
              mainTitle: _textTitleCtrl.text,
              subtitle: _textSubtitleCtrl.text,
              message: _textMsgCtrl.text,
            ),
          ),
        ),
        _InputCard(
          title: 'QR Code',
          icon: Icons.qr_code,
          fields: [
            _Fld('Amount (e.g. Rs. 1234.00)', _qrAmountCtrl),
            _Fld('Action Text (e.g. Scan to pay)', _qrActionCtrl),
            _Fld('QR Payload / URL', _qrDataCtrl),
          ],
          onSend: () => _run(
            'QR code',
            () => _pos.displayQR(
              amount: _qrAmountCtrl.text,
              actionText: _qrActionCtrl.text,
              qrData: _qrDataCtrl.text,
            ),
          ),
        ),

        // ── Status screens ────────────────────────────────────────────────────
        _SectionHeader('Status Screens'),
        _InputCard(
          title: 'Loading / Wait',
          icon: Icons.hourglass_top,
          iconColor: Colors.blueGrey,
          fields: [
            _Fld('Amount', _loadingAmountCtrl),
            _Fld('Message', _loadingMsgCtrl),
          ],
          onSend: () => _run(
            'Loading',
            () => _pos.displayLoading(
              amount: _loadingAmountCtrl.text,
              message: _loadingMsgCtrl.text,
            ),
          ),
        ),
        _InputCard(
          title: 'Success',
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
          fields: [
            _Fld('Title', _successTitleCtrl),
            _Fld('Message', _successMsgCtrl),
          ],
          onSend: () => _run(
            'Success',
            () => _pos.displaySuccess(
              title: _successTitleCtrl.text,
              message: _successMsgCtrl.text,
            ),
          ),
        ),
        _InputCard(
          title: 'Failure',
          icon: Icons.cancel_outlined,
          iconColor: Colors.red,
          fields: [
            _Fld('Amount', _failAmountCtrl),
            _Fld('Message', _failMsgCtrl),
          ],
          onSend: () => _run(
            'Failure',
            () => _pos.displayFailure(
              amount: _failAmountCtrl.text,
              message: _failMsgCtrl.text,
            ),
          ),
        ),
        _InputCard(
          title: 'Warning',
          icon: Icons.warning_amber_outlined,
          iconColor: Colors.orange,
          fields: [
            _Fld('Title', _warnTitleCtrl),
            _Fld('Message', _warnMsgCtrl),
          ],
          onSend: () => _run(
            'Warning',
            () => _pos.displayWarning(
              title: _warnTitleCtrl.text,
              message: _warnMsgCtrl.text,
            ),
          ),
        ),
        _InputCard(
          title: 'Information',
          icon: Icons.info_outline,
          iconColor: Colors.blue,
          fields: [
            _Fld('Title', _infoTitleCtrl),
            _Fld('Message', _infoMsgCtrl),
          ],
          onSend: () => _run(
            'Info',
            () => _pos.displayInfo(
              title: _infoTitleCtrl.text,
              message: _infoMsgCtrl.text,
            ),
          ),
        ),

        // ── Device control ────────────────────────────────────────────────────
        _SectionHeader('Device Control'),
        _ActionTile(
          title: 'Wake Device',
          subtitle: 'Wake from sleep  (WAKE)',
          icon: Icons.wb_sunny_outlined,
          onTap: () => _run('Wake', _pos.wake),
        ),
        _ActionTile(
          title: 'Sleep / Reset',
          subtitle: 'Put device to sleep  (RESET)',
          icon: Icons.bedtime_outlined,
          onTap: () => _run('Sleep', _pos.sleep),
        ),
        _ActionTile(
          title: 'Format Display',
          subtitle: 'Clear the e-ink display  (FORMAT)',
          icon: Icons.format_clear,
          onTap: () => _run('Format', _pos.formatDisplay),
        ),
        _InputCard(
          title: 'Screen Timeout',
          icon: Icons.timer_outlined,
          fields: [
            _Fld(
              'Seconds (30–300)',
              _screentimeCtrl,
              type: TextInputType.number,
            ),
          ],
          onSend: () {
            final secs = int.tryParse(_screentimeCtrl.text.trim());
            if (secs == null || secs < 30 || secs > 300) {
              setState(() => _lastStatus = 'Seconds must be 30–300');
              return;
            }
            _run('Screen timeout', () => _pos.setScreenTimeout(secs));
          },
        ),

        // ── Raw command ───────────────────────────────────────────────────────
        _SectionHeader('Advanced'),
        _InputCard(
          title: 'Raw Command',
          icon: Icons.terminal,
          fields: [
            _Fld('Command (newline appended automatically)', _rawCmdCtrl),
          ],
          onSend: () {
            final cmd = _rawCmdCtrl.text.trim();
            if (cmd.isEmpty) {
              setState(() => _lastStatus = 'Command cannot be empty');
              return;
            }
            _run('Raw "$cmd"', () => _pos.sendCommand(cmd));
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.state,
    required this.status,
    required this.isConnecting,
    required this.onConnect,
    required this.onDisconnect,
  });

  final B30ConnectionState state;
  final String status;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final connected = state == B30ConnectionState.connected;
    final color = connected ? Colors.green : Colors.red;
    return ColoredBox(
      color: color.withAlpha(25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(connected ? Icons.usb : Icons.usb_off, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status,
                style: TextStyle(color: color, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isConnecting)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              TextButton(
                onPressed: connected ? onDisconnect : onConnect,
                child: Text(connected ? 'Disconnect' : 'Connect'),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: FilledButton.tonal(
          onPressed: onTap,
          child: const Text('Send'),
        ),
      ),
    );
  }
}

class _Fld {
  const _Fld(this.label, this.ctrl, {this.type});
  final String label;
  final TextEditingController ctrl;
  final TextInputType? type;
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.title,
    required this.icon,
    required this.fields,
    required this.onSend,
    this.iconColor,
  });

  final String title;
  final IconData icon;
  final Color? iconColor;
  final List<_Fld> fields;
  final void Function() onSend;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: iconColor ?? Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final f in fields) ...[
              TextField(
                controller: f.ctrl,
                keyboardType: f.type,
                decoration: InputDecoration(
                  labelText: f.label,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onSend,
                child: const Text('Send'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
