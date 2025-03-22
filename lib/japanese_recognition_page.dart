import 'package:flutter/material.dart' hide Ink;
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart';
import 'dart:developer' as developer;

// Widget for the inline drawing canvas
class JapaneseDrawingCanvas extends StatefulWidget {
  final Function(List<String>, bool) onTextRecognized;
  
  const JapaneseDrawingCanvas({Key? key, required this.onTextRecognized}) : super(key: key);
  
  @override
  State<JapaneseDrawingCanvas> createState() => _JapaneseDrawingCanvasState();
}

class _JapaneseDrawingCanvasState extends State<JapaneseDrawingCanvas> {
  var _digitalInkRecognizer = DigitalInkRecognizer(languageCode: 'ja');
  final DigitalInkRecognizerModelManager _modelManager = DigitalInkRecognizerModelManager();
  final Ink _ink = Ink();
  List<StrokePoint> _points = [];
  
  List<String> _recognizedText = [];
  bool _isRecognizing = false;
  
  // Keep a reference to the drawing area for accurate position calculation
  final GlobalKey _drawingAreaKey = GlobalKey();
  
  @override
  void dispose() {
    _digitalInkRecognizer.close();
    super.dispose();
  }
  
  Future<void> _recognizeText() async {
    if (_ink.strokes.isEmpty) return;
    
    setState(() {
      _isRecognizing = true;
    });
    
    try {
      developer.log('Starting Japanese character recognition...');
      final candidates = await _digitalInkRecognizer.recognize(_ink);
      
      final recognizedStrings = candidates.map((candidate) => candidate.text).toList();
      
      setState(() {
        _recognizedText = recognizedStrings;
        _isRecognizing = false;
      });
      
      developer.log('Recognition complete: ${recognizedStrings.join(", ")}');
      // Don't send to parent yet - wait for user to select an option
    } catch (e) {
      developer.log('Recognition error: $e', error: e);
      setState(() {
        _isRecognizing = false;
      });
    }
  }
  
  // Add a new function to commit a selected character
  void _commitCharacter(String character) {
    // Send the selected character to the parent
    widget.onTextRecognized([character], true);
    developer.log('Adding character "$character" to search box');
    
    // Clear everything for the next character
    _clearPad();
  }
  
  void _clearPad() {
    setState(() {
      _ink.strokes.clear();
      _points.clear();
      _recognizedText.clear();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Always visible recognition toolbar (fixed position)
        Container(
          height: 65, // Further increased height for button spacing
          clipBehavior: Clip.none, // Prevents clipping of shadows

          decoration: BoxDecoration(
            color: Colors.grey[200],
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          margin: EdgeInsets.only(bottom: 8),
          padding: EdgeInsets.symmetric(vertical: 6), // Increased vertical padding
          child: Row(
            children: [
              // Clear button
              Container(
                margin: EdgeInsets.symmetric(horizontal: 8),
                child: IconButton(
                  onPressed: _clearPad,
                  icon: Icon(Icons.clear),
                  tooltip: 'Clear',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black54,
                  ),
                ),
              ),
              
              // Divider
              Container(
                width: 1,
                margin: EdgeInsets.symmetric(vertical: 8),
                color: Colors.grey[400],
              ),
              
              // Character options area
              Expanded(
                child: _recognizedText.isEmpty 
                  ? Container() // No placeholder boxes
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical:4.25),
                      itemCount: _recognizedText.length, // Show all available options
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: ElevatedButton(
                            onPressed: () {
                              // When an option is selected, immediately commit it
                              _commitCharacter(_recognizedText[index]);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: index == 0 ? Colors.deepOrange.shade100 : null,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              elevation: 2,
                            ),
                            child: Text(
                              _recognizedText[index],
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
        
        // Drawing area with toolbar
        Expanded(
          child: Stack(
            children: [
              // Drawing area
              Container(
                key: _drawingAreaKey,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: GestureDetector(
                  onPanStart: (DragStartDetails details) {
                    _ink.strokes.add(Stroke());
                    _points.clear();
                    
                    // Get the drawing area's render box for accurate position calculation
                    final RenderBox box = _drawingAreaKey.currentContext!.findRenderObject() as RenderBox;
                    final Offset localPosition = box.globalToLocal(details.globalPosition);
                    
                    _points.add(StrokePoint(
                      x: localPosition.dx,
                      y: localPosition.dy,
                      t: DateTime.now().millisecondsSinceEpoch,
                    ));
                    
                    // Update the stroke
                    if (_ink.strokes.isNotEmpty) {
                      _ink.strokes.last.points = _points.toList();
                    }
                    setState(() {});
                  },
                  onPanUpdate: (DragUpdateDetails details) {
                    // Get the drawing area's render box for accurate position calculation
                    final RenderBox box = _drawingAreaKey.currentContext!.findRenderObject() as RenderBox;
                    final Offset localPosition = box.globalToLocal(details.globalPosition);
                    
                    setState(() {
                      _points.add(StrokePoint(
                        x: localPosition.dx,
                        y: localPosition.dy,
                        t: DateTime.now().millisecondsSinceEpoch,
                      ));
                      
                      // Update the stroke
                      if (_ink.strokes.isNotEmpty) {
                        _ink.strokes.last.points = _points.toList();
                      }
                    });
                  },
                  onPanEnd: (DragEndDetails details) {
                    _points.clear();
                    // Automatically recognize text after each stroke but don't commit yet
                    _recognizeText();
                  },
                  child: CustomPaint(
                    painter: Signature(ink: _ink),
                    size: Size.infinite,
                  ),
                ),
              ),
              
              
              // Loading indicator
              if (_isRecognizing)
                Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ],
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
      // Only draw if there are at least 2 points
      if (stroke.points.length > 1) {
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
  }

  @override
  bool shouldRepaint(Signature oldDelegate) => true;
}