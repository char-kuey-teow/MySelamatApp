import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ScreenshotHelper {
  static final ScreenshotController _screenshotController = ScreenshotController();

  /// Take a screenshot of the current widget and save it to gallery
  static Future<File?> takeScreenshot(
    BuildContext context,
    String imageName, {
    Widget? child,
    double? pixelRatio,
  }) async {
    try {
      // Request storage permission
      final permission = await Permission.photos.request();
      if (!permission.isGranted) {
        _showSnackBar(context, 'Storage permission is required to save screenshots');
        return null;
      }

      // Take screenshot
      final image = await _screenshotController.capture(
        pixelRatio: pixelRatio ?? 2.0,
      );

      if (image == null) {
        _showSnackBar(context, 'Failed to capture screenshot');
        return null;
      }

      // Save to gallery
      final file = await _saveImageToGallery(image, imageName);
      
      if (file != null) {
        _showSnackBar(context, 'Screenshot saved: $imageName');
        return file;
      } else {
        _showSnackBar(context, 'Failed to save screenshot');
        return null;
      }
    } catch (e) {
      _showSnackBar(context, 'Screenshot error: $e');
      return null;
    }
  }

  /// Save image bytes to device gallery
  static Future<File?> _saveImageToGallery(Uint8List imageBytes, String fileName) async {
    try {
      // Get external storage directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('❌ External storage not available');
        return null;
      }

      // Create Screenshots directory
      final screenshotsDir = Directory('${directory.path}/../Pictures/Screenshots');
      if (!await screenshotsDir.exists()) {
        await screenshotsDir.create(recursive: true);
      }

      // Generate unique filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final finalFileName = fileName.contains('.') 
          ? fileName.replaceAll('.', '_${timestamp}.')
          : '${fileName}_$timestamp.jpg';

      // Save the image
      final file = File('${screenshotsDir.path}/$finalFileName');
      await file.writeAsBytes(imageBytes);

      print('✅ Screenshot saved: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error saving screenshot: $e');
      return null;
    }
  }

  /// Show snackbar message
  static void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: message.contains('✅') || message.contains('saved')
            ? Colors.green
            : Colors.red,
      ),
    );
  }

  /// Get the screenshot controller
  static ScreenshotController get controller => _screenshotController;

  /// Take screenshot of current screen content
  static Future<File?> captureCurrentScreen(
    BuildContext context,
    String imageName,
  ) async {
    return takeScreenshot(
      context,
      imageName,
      child: Material(
        child: MediaQuery(
          data: MediaQuery.of(context),
          child: Navigator.of(context).widget,
        ),
      ),
    );
  }
}
