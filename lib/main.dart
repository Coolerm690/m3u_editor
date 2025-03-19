import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M3U Editor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'M3U Editor'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Channel> channels = [];
  Set<String> groups = {};
  Set<String> selectedGroups = {};
  String? currentFilePath;

  Future<void> _pickAndReadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m3u', 'm3u8'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        currentFilePath = result.files.first.path;
        if (currentFilePath != null) {
          final file = File(currentFilePath!);
          if (await file.exists()) {
            final contents = await file.readAsString();
            setState(() {
              channels = parseM3U(contents);
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File caricato con successo')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File non trovato')),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore durante il caricamento: $e')),
      );
    }
  }

  void _updateGroups() {
    setState(() {
      groups = channels.map((c) => c.group).toSet();
    });
  }

  List<Channel> parseM3U(String content) {
    List<Channel> channels = [];
    List<String> lines = content.split('\n');
    Channel? currentChannel;
    String currentGroup = '';

    for (String line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        currentChannel = Channel();
        // Parse channel name and group
        final nameMatch = RegExp(r'group-title="([^"]*)"').firstMatch(line);
        if (nameMatch != null) {
          currentGroup = nameMatch.group(1) ?? '';
        }

        final nameStart = line.lastIndexOf(',');
        if (nameStart != -1) {
          currentChannel.name = line.substring(nameStart + 1).trim();
          currentChannel.group = currentGroup;
        }
      } else if (line.isNotEmpty &&
          !line.startsWith('#') &&
          currentChannel != null) {
        currentChannel.url = line;
        channels.add(currentChannel);
        currentChannel = null;
      }
    }

    List<Channel> parsedChannels = channels;
    this.channels = parsedChannels;
    _updateGroups();
    return parsedChannels;
  }

  Future<void> _saveFile() async {
    if (currentFilePath == null) return;

    final file = File(currentFilePath!);
    String content = '#EXTM3U\n';

    for (var channel in channels) {
      content += '#EXTINF:-1 group-title="${channel.group}",${channel.name}\n';
      content += '${channel.url}\n';
    }

    await file.writeAsString(content);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('File salvato con successo!')),
    );
  }

  void _toggleAllGroups(bool? value) {
    setState(() {
      if (value ?? false) {
        selectedGroups = Set.from(groups);
      } else {
        selectedGroups.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          if (channels.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveFile,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: selectedGroups.isEmpty
                  ? null
                  : () {
                      setState(() {
                        channels.removeWhere((channel) =>
                            selectedGroups.contains(channel.group));
                        selectedGroups.clear();
                        _updateGroups();
                      });
                    },
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: channels.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Nessun file M3U caricato',
                      style: Theme.of(context).textTheme.headlineSmall),
                ),
              )
            : Column(
                children: [
                  // Sezione Gruppi
                  Card(
                    margin: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: const Text('Gruppi'),
                          trailing: Checkbox(
                            value: selectedGroups.length == groups.length,
                            tristate: true,
                            onChanged: _toggleAllGroups,
                          ),
                        ),
                        Wrap(
                          children: groups.map((group) {
                            return FilterChip(
                              selected: selectedGroups.contains(group),
                              label: Text(group),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedGroups.add(group);
                                  } else {
                                    selectedGroups.remove(group);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  // Lista Canali
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        final isGroupSelected =
                            selectedGroups.contains(channel.group);

                        return ListTile(
                          title: Text(channel.name),
                          subtitle: Text('Gruppo: ${channel.group}'),
                          selected: isGroupSelected,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                channels.removeAt(index);
                                _updateGroups();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndReadFile,
        tooltip: 'Carica file M3U',
        child: const Icon(Icons.file_open),
      ),
    );
  }
}

class Channel {
  String name = '';
  String url = '';
  String group = '';
}
