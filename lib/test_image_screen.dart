import 'package:flutter/material.dart';
import 'dart:io';
import 'utils/test_image_generator.dart';
import 'utils/screenshot_helper.dart';

class TestImageScreen extends StatefulWidget {
  @override
  _TestImageScreenState createState() => _TestImageScreenState();
}

class _TestImageScreenState extends State<TestImageScreen> {
  List<File> _generatedImages = [];
  bool _isGenerating = false;
  String _status = '';

  Future<void> _generateTestImages() async {
    setState(() {
      _isGenerating = true;
      _status = 'Generating test images...';
    });

    try {
      final images = await TestImageGenerator.generateMultipleTestImages();
      setState(() {
        _generatedImages = images;
        _status = 'Generated ${images.length} test images successfully!';
      });
    } catch (e) {
      setState(() {
        _status = 'Error generating images: $e';
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Future<void> _copyToGallery(File imageFile, String name) async {
    setState(() {
      _status = 'Copying $name to gallery...';
    });

    try {
      final copiedFile = await TestImageGenerator.copyToGallery(imageFile, name);
      if (copiedFile != null) {
        setState(() {
          _status = 'Successfully copied $name to gallery!';
        });
      } else {
        setState(() {
          _status = 'Failed to copy $name to gallery';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error copying to gallery: $e';
      });
    }
  }

  Future<void> _takeScreenshot() async {
    setState(() {
      _status = 'Taking screenshot...';
    });

    try {
      final screenshotFile = await ScreenshotHelper.takeScreenshot(
        context,
        'test_screen_screenshot',
      );
      
      if (screenshotFile != null) {
        setState(() {
          _status = 'Screenshot saved successfully! You can now use it in photo selection.';
        });
      } else {
        setState(() {
          _status = 'Failed to take screenshot';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Error taking screenshot: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Image Generator'),
        backgroundColor: Color(0xFF2254C5),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Generate Test Images for Photo Selection',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            
            // Status
            if (_status.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  _status,
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            
            SizedBox(height: 16),
            
            // Generate button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateTestImages,
                icon: _isGenerating 
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.add_photo_alternate),
                label: Text(_isGenerating ? 'Generating...' : 'Generate Test Images'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF2254C5),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            SizedBox(height: 12),
            
            // Screenshot button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _takeScreenshot,
                icon: Icon(Icons.camera_alt),
                label: Text('Take Screenshot of This Screen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            
            SizedBox(height: 24),
            
            // Generated images list
            if (_generatedImages.isNotEmpty) ...[
              Text(
                'Generated Images:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _generatedImages.length,
                  itemBuilder: (context, index) {
                    final image = _generatedImages[index];
                    final fileName = image.path.split('/').last;
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: FileImage(image),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        title: Text(fileName),
                        subtitle: Text('Size: ${image.lengthSync()} bytes'),
                        trailing: ElevatedButton(
                          onPressed: () => _copyToGallery(image, fileName),
                          child: Text('Copy to Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            
            // Instructions
            if (_generatedImages.isEmpty && !_isGenerating)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.photo_library,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Tap "Generate Test Images" to create sample images for testing photo selection',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
