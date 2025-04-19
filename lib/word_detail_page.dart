import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'japanese_word.dart';

/// A page that displays detailed information for a single dictionary entry.
class WordDetailPage extends StatefulWidget {
  final int rowId;
  const WordDetailPage({Key? key, required this.rowId}) : super(key: key);

  @override
  State<WordDetailPage> createState() => _WordDetailPageState();
}

class _WordDetailPageState extends State<WordDetailPage> {
  JapaneseWord? _word;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWord();
  }

  Future<void> _loadWord() async {
    final map = await DatabaseHelper.instance.getWordByRowId(widget.rowId);
    if (mounted) {
      setState(() {
        if (map != null) {
          _word = JapaneseWord.fromMap(map);
        }
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_word?.japanese ?? 'Word Details'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _word == null
              ? Center(child: Text('Word not found.'))
              : SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _word!.data.entries
                        .where((entry) =>
                            entry.value != null &&
                            entry.value.toString().isNotEmpty)
                        .map((entry) {
                      final fieldName = entry.key;
                      final fieldValue = entry.value.toString();
                      final displayName =
                          '${fieldName[0].toUpperCase()}${fieldName.substring(1)}';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            SizedBox(height: 4),
                            Text(
                              fieldValue,
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
    );
  }
}