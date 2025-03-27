import 'package:english_words/english_words.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'japanese_recognition_page.dart';
import 'learn_page.dart'; // Updated import
import 'dart:developer' as developer;

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
  
  // Add this to track the current tab index
  int _currentIndex = 0;
  
  @override
  void dispose() {
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
          : LearnPage(), // Updated widget name
      
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
            icon: Icon(Icons.school), // Updated icon to match "Learn" theme
            label: 'Learn', // Updated label
          ),
        ],
      ),
      // Removed FloatingActionButton as it's now in the TextField
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
              suffixIcon: IconButton(
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
            ),
          ),
        ),
        
        // Main content
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('A lovely idea:'),
                Text(appState.current.asLowerCase),
                ElevatedButton(
                  onPressed: () {
                    appState.getNext();
                  },
                  child: Text('Next'),
                ),
              ],
            ),
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
}