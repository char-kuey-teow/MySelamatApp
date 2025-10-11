import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

class TestImageGenerator {
  /// Generate a test image and save it to device storage
  static Future<File> generateTestImage(String imageName) async {
    try {
      // Create a simple test image
      final image = img.Image(width: 400, height: 300);
      
      // Fill with a gradient background
      for (int y = 0; y < 300; y++) {
        for (int x = 0; x < 400; x++) {
          final red = (255 * x / 400).toInt();
          final green = (255 * y / 300).toInt();
          final blue = 128;
          
          image.setPixel(x, y, img.ColorRgb8(red, green, blue));
        }
      }
      
      // Add some text-like shapes using drawRect
      for (int i = 0; i < 50; i++) {
        final x = (i * 7) % 350;
        final y = (i * 5) % 250;
        img.drawRect(image, 
          x1: x, y1: y, x2: x + 20, y2: y + 15, 
          color: img.ColorRgb8(255, 255, 255));
      }
      
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final testImagesDir = Directory('${directory.path}/test_images');
      
      // Create directory if it doesn't exist
      if (!await testImagesDir.exists()) {
        await testImagesDir.create(recursive: true);
      }
      
      // Save the image
      final file = File('${testImagesDir.path}/$imageName.jpg');
      final bytes = img.encodeJpg(image);
      await file.writeAsBytes(bytes);
      
      print('✅ Test image generated: ${file.path}');
      return file;
    } catch (e) {
      print('❌ Error generating test image: $e');
      rethrow;
    }
  }
  
  /// Generate multiple test images
  static Future<List<File>> generateMultipleTestImages() async {
    final images = <File>[];
    
    final testImages = [
      'flood_damage_1.jpg',
      'flood_damage_2.jpg', 
      'earthquake_damage_1.jpg',
      'landslide_damage_1.jpg',
      'emergency_scene_1.jpg',
    ];
    
    for (final imageName in testImages) {
      try {
        final image = await generateTestImage(imageName);
        images.add(image);
      } catch (e) {
        print('Failed to generate $imageName: $e');
      }
    }
    
    return images;
  }
  
  /// Copy a test image to the device's gallery folder
  static Future<File?> copyToGallery(File sourceFile, String newName) async {
    try {
      // Get the external storage directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        print('❌ External storage not available');
        return null;
      }
      
      // Create Pictures directory
      final picturesDir = Directory('${directory.path}/../Pictures/TestImages');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }
      
      // Copy the file
      final newFile = File('${picturesDir.path}/$newName');
      await sourceFile.copy(newFile.path);
      
      print('✅ Image copied to gallery: ${newFile.path}');
      return newFile;
    } catch (e) {
      print('❌ Error copying to gallery: $e');
      return null;
    }
  }
}
