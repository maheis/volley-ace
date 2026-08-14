import 'package:flutter/material.dart';

import 'app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial});

  final AppSettings initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _fontFamily;
  late double _textScaleFactor;

  bool get _hasChanges {
    return _fontFamily != widget.initial.fontFamily ||
        _textScaleFactor != widget.initial.textScaleFactor;
  }

  @override
  void initState() {
    super.initState();
    _fontFamily = widget.initial.fontFamily;
    _textScaleFactor = widget.initial.textScaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);

    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(_textScaleFactor)),
      child: Theme(
        data: baseTheme.copyWith(
          textTheme: baseTheme.textTheme.apply(fontFamily: _fontFamily),
          primaryTextTheme: baseTheme.primaryTextTheme.apply(
            fontFamily: _fontFamily,
          ),
        ),
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Einstellungen'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    AppSettings(
                      fontFamily: _fontFamily,
                      textScaleFactor: _textScaleFactor,
                    ),
                  );
                },
                child: Text(
                  'Speichern',
                  style: TextStyle(
                    color: _hasChanges ? Colors.red : null,
                    fontWeight:
                        _hasChanges ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Text(
                'Schriftart',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Schriftart:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _fontFamily,
                      items: AppSettings.availableFonts
                          .map(
                            (font) => DropdownMenuItem<String>(
                              value: font,
                              child: Text(font),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _fontFamily = value);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Schriftgröße: ${(_textScaleFactor * 100).round()} %',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Slider(
                value: _textScaleFactor,
                min: 0.5,
                max: 1.6,
                divisions: 22,
                label: '${(_textScaleFactor * 100).round()}%',
                onChanged: (value) {
                  setState(() => _textScaleFactor = value);
                },
              ),
              const Text('Bereich: 50 % bis 160 %'),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Vorschau',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'So sehen Texte in der App mit den aktuellen '
                        'Einstellungen aus.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
