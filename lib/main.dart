import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'japanese_recognition_page.dart';
import 'learn_page.dart';
import 'dart:developer' as developer;
import 'database_helper.dart';
import 'japanese_word.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  developer.log('Starting Japanese Dictionary app...');
  
  // Check and download the Japanese model on app startup
  final modelManager = DigitalInkRecognizerModelManager();
  try {
    bool isModelDownloaded = await modelManager.isModelDownloaded('ja');
    developer.log('Japanese model status check: ${isModelDownloaded ? 'Already downloaded' : 'Not downloaded'}');
    
    if (!isModelDownloaded) {
      developer.log('Japanese model not found. Downloading model...');
      bool downloadResult = await modelManager.downloadModel('ja');
      developer.log('Japanese model download ${downloadResult ? 'successful!' : 'failed!'}');
    }
  } catch (e) {
    developer.log('Error checking/downloading model: $e', error: e);
  }
  
  // Initialize database from assets
  await DatabaseHelper.instance.ensureInitialized();
  
  // Log database info for debugging
  try {
    final tableNames = await DatabaseHelper.instance.getTableNames();
    developer.log('Tables in database: $tableNames');
    
    // Print schema of first table
    if (tableNames.isNotEmpty) {
      final columns = await DatabaseHelper.instance.getTableColumns(tableNames.first);
      developer.log('Columns in ${tableNames.first}: $columns');
    }
  } catch (e) {
    developer.log('Error inspecting database schema: $e', error: e);
  }
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Japanese Dictionary App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {
  var current = WordPair.random();
  
  void getNext() {
    current = WordPair.random();
    notifyListeners();
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showDrawingCanvas = false;
  final FocusNode _searchFocusNode = FocusNode();
  int _currentIndex = 0;
  
  // Add these for database search functionality
  List<JapaneseWord> _searchResults = [];
  bool _isSearching = false;
  String _lastSearchQuery = '';
  
  @override
  void initState() {
    super.initState();
    // Initialize with all words
    _loadAllWords();
    
    // Add listener to search controller
    _searchController.addListener(_onSearchChanged);
  }
  
  Future<void> _loadAllWords() async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      final wordMaps = await DatabaseHelper.instance.getAllWords();
      setState(() {
        _searchResults = wordMaps.map((wordMap) => JapaneseWord.fromMap(wordMap)).toList();
        _isSearching = false;
      });
    } catch (e) {
      developer.log('Error loading all words: $e', error: e);
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  void _onSearchChanged() {
    final searchText = _searchController.text.trim();
    
    // Skip if the search text hasn't changed
    if (searchText == _lastSearchQuery) {
      return;
    }
    
    _lastSearchQuery = searchText;
    
    if (searchText.isEmpty) {
      _loadAllWords();
    } else {
      // Add a small delay to avoid performing searches on every keystroke
      Future.delayed(Duration(milliseconds: 300), () {
        // Verify the search text hasn't changed during the delay
        if (_searchController.text.trim() == searchText) {
          _performSearch(searchText);
        }
      });
    }
  }
  
  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      final wordMaps = await DatabaseHelper.instance.searchWords(query);
      
      setState(() {
        _searchResults = wordMaps.map((wordMap) => JapaneseWord.fromMap(wordMap)).toList();
        _isSearching = false;
      });
      
      developer.log('Found ${_searchResults.length} results for "$query"');
    } catch (e) {
      developer.log('Error searching words: $e', error: e);
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    var appState = context.watch<MyAppState>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Japanese Dictionary App'),
      ),
      body: _currentIndex == 0 
          ? _buildDictionaryPage(appState)
          : LearnPage(),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
            // Hide drawing canvas when switching tabs
            _showDrawingCanvas = false;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            label: 'Dictionary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school),
            label: 'Learn',
          ),
        ],
      ),
    );
  }
  
  // Extract the dictionary page to a separate method
  Widget _buildDictionaryPage(MyAppState appState) {
    return Column(
      children: [
        // Search box with integrated toggle button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText: 'Search Japanese words',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              // Added toggle button as suffix icon
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Clear button
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                      tooltip: 'Clear search',
                    ),
                  // Draw toggle button
                  IconButton(
                    icon: Icon(_showDrawingCanvas ? Icons.keyboard : Icons.draw),
                    onPressed: () {
                      setState(() {
                        _showDrawingCanvas = !_showDrawingCanvas;
                        if (!_showDrawingCanvas) {
                          // If hiding the canvas, show keyboard
                          _searchFocusNode.requestFocus();
                        } else {
                          // If showing the canvas, hide keyboard
                          FocusManager.instance.primaryFocus?.unfocus();
                        }
                      });
                    },
                    tooltip: _showDrawingCanvas ? 'Show keyboard' : 'Show canvas',
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Show loading indicator when searching
        if (_isSearching)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          ),
        
        // Main content - search results
        if (!_isSearching)
          Expanded(
            child: _searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Try a different search term',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final word = _searchResults[index];
                      return Card(
                        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: ExpansionTile(
                          title: Text(
                            word.japanese,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (word.hiragana != null && word.hiragana!.isNotEmpty)
                                Text(
                                  word.hiragana!,
                                  style: TextStyle(fontSize: 16),
                                ),
                              if (word.furigana != null && word.furigana!.isNotEmpty)
                                Text(
                                  "Furigana: ${word.furigana!}",
                                  style: TextStyle(fontSize: 14),
                                ),
                              Text(
                                word.english,
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Display raw data
                                  Text(
                                    'Raw Data:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  SizedBox(height: 8),
                                  
                                  // Loop through all fields in the data map
                                  ...word.data.entries.map((entry) {
                                    // Skip empty values
                                    if (entry.value == null || entry.value.toString().isEmpty) {
                                      return SizedBox.shrink();
                                    }
                                    
                                    String fieldName = entry.key;
                                    String fieldValue = entry.value.toString();
                                    
                                    return _buildDetailRow(fieldName, fieldValue);
                                  }).toList(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        
        // Drawing canvas (conditionally shown)
        if (_showDrawingCanvas)
          Container(
            height: 350, // Increased height for more drawing room
            padding: EdgeInsets.all(8),
            child: JapaneseDrawingCanvas(
              onTextRecognized: (text, isNewCharacter) {
                if (text.isNotEmpty) {
                  setState(() {
                    // Always append the character to existing text
                    _searchController.text += text.first;
                    
                    // Place cursor at the end
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: _searchController.text.length),
                    );
                  });
                }
              },
            ),
          ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    // Highlight priority-related fields with a different color
    final bool isPriorityField = label == 'pri_point' || 
                                label == 'adjusted_pri_point';
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120, // Increased width for longer field names
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPriorityField ? Colors.deepOrange : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isPriorityField ? Colors.deepOrange : Colors.black,
                fontWeight: isPriorityField ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}