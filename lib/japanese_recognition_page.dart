import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';

class JapaneseRecognitionPage extends StatefulWidget {
  @override
  _JapaneseRecognitionPageState createState() => _JapaneseRecognitionPageState();
}

class _JapaneseRecognitionPageState extends State<JapaneseRecognitionPage> {
  final TextEditingController _textController = TextEditingController();
  final DigitalInkRecognizerModelManager _modelManager = 
      DigitalInkRecognizerModelManager();
  
  var _digitalInkRecognizer = DigitalInkRecognizer(languageCode: 'ja');
  final Ink _ink = Ink();
  List<StrokePoint> _points = [];
  
  List<String> _recognizedText = [];
  bool _isDrawingMode = false;

  @override
  void dispose() {
    _digitalInkRecognizer.close();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkModelStatus() async {
    bool isDownloaded = await _modelManager.isModelDownloaded('ja');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDownloaded 
            ? 'Japanese model is downloaded' 
            : 'Japanese model needs to be downloaded'),
        backgroundColor: isDownloaded ? Colors.green : Colors.orange,
      ),
    );
  }

  Future<void> _downloadModel() async {
    // Show downloading message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading Japanese model...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Download the model
    bool success = await _modelManager.downloadModel('ja');
    
    // Show result message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success 
            ? 'Japanese model downloaded successfully' 
            : 'Failed to download Japanese model'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _deleteModel() async {
    // Show deleting message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Deleting Japanese model...'),
        duration: Duration(seconds: 1),
      ),
    );
    
    // Delete the model
    bool success = await _modelManager.deleteModel('ja');
    
    // Show result message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success 
            ? 'Japanese model deleted successfully' 
            : 'Failed to delete Japanese model'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _recognizeText() async {
    // Show a dialog while recognizing
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Recognizing...'),
        content: CircularProgressIndicator(),
      ),
      barrierDismissible: false,
    );
    
    try {
      // Recognize the ink
      final candidates = await _digitalInkRecognizer.recognize(_ink);
      
      // Update the recognized text
      setState(() {
        _recognizedText = candidates.map((candidate) => candidate.text).toList();
      });
    } catch (e) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recognition error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    
    // Close the dialog
    Navigator.of(context).pop();
  }

  void _clearPad() {
    setState(() {
      _ink.strokes.clear();
      _points.clear();
      _recognizedText.clear();
    });
  }

  void _toggleInputMode() {
    setState(() {
      _isDrawingMode = !_isDrawingMode;
      _clearPad();
      _textController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Japanese Character Recognition'),
        actions: [
          IconButton(
            icon: Icon(_isDrawingMode ? Icons.keyboard : Icons.draw),
            onPressed: _toggleInputMode,
            tooltip: _isDrawingMode ? 'Switch to keyboard' : 'Switch to drawing',
          ),
        ],
      ),
      body: Column(
        children: [
          // Model management buttons
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _checkModelStatus,
                  child: Text('Check Model'),
                ),
                ElevatedButton(
                  onPressed: _downloadModel,
                  child: Icon(Icons.download),
                ),
                ElevatedButton(
                  onPressed: _deleteModel,
                  child: Icon(Icons.delete),
                ),
              ],
            ),
          ),
          
          // Drawing or text input area
          Expanded(
            child: _isDrawingMode
                ? _buildDrawingArea()
                : _buildTextInputArea(),
          ),
          
          // Action buttons for drawing mode
          if (_isDrawingMode)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _recognizeText,
                    child: Text('Recognize'),
                  ),
                  ElevatedButton(
                    onPressed: _clearPad,
                    child: Text('Clear Pad'),
                  ),
                ],
              ),
            ),
            
          // Recognized text area
          _buildRecognizedTextArea(),
        ],
      ),
    );
  }

  Widget _buildDrawingArea() {
    return GestureDetector(
      onPanStart: (DragStartDetails details) {
        _ink.strokes.add(Stroke());
        _points.clear();
      },
      onPanUpdate: (DragUpdateDetails details) {
        setState(() {
          final RenderObject? object = context.findRenderObject();
          final localPosition = (object as RenderBox?)
              ?.globalToLocal(details.localPosition);
          if (localPosition != null) {
            _points = List.from(_points)
              ..add(StrokePoint(
                x: localPosition.dx,
                y: localPosition.dy,
                t: DateTime.now().millisecondsSinceEpoch,
              ));
          }
          if (_ink.strokes.isNotEmpty) {
            _ink.strokes.last.points = _points.toList();
          }
        });
      },
      onPanEnd: (DragEndDetails details) {
        _points.clear();
        setState(() {});
      },
      child: CustomPaint(
        painter: Signature(ink: _ink),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildTextInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextField(
            controller: _textController,
            decoration: InputDecoration(
              hintText: 'Type Japanese text here',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
          ),
          SizedBox(height: 16),
          Text(
            'Switch to drawing mode to draw Japanese characters',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecognizedTextArea() {
    return Container(
      height: 150,
      width: double.infinity,
      padding: EdgeInsets.all(8.0),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recognized Text:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          if (_isDrawingMode && _recognizedText.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _recognizedText.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      '${index + 1}. ${_recognizedText[index]}',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                },
              ),
            )
          else if (!_isDrawingMode && _textController.text.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _textController.text,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Text(
                  _isDrawingMode
                      ? 'Draw a Japanese character and tap Recognize'
                      : 'Type Japanese text using your keyboard',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class Signature extends CustomPainter {
  Ink ink;

  Signature({required this.ink});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (final stroke in ink.strokes) {
      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];
        canvas.drawLine(
          Offset(p1.x.toDouble(), p1.y.toDouble()),
          Offset(p2.x.toDouble(), p2.y.toDouble()), 
          paint
        );
      }
    }
  }

  @override
  bool shouldRepaint(Signature oldDelegate) => true;
}