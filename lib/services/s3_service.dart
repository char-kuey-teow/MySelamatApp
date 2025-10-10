import 'dart:convert';
import 'dart:typed_data';
import 'package:aws_s3_api/s3-2006-03-01.dart';
import '../config.dart';

class S3Service {
  static String get _region => Config.awsRegion;
  static String get _bucketName => Config.s3BucketName;
  static String get _accessKey => Config.awsAccessKey;
  static String get _secretKey => Config.awsSecretKey;

  /// Validate AWS configuration
  static bool _validateConfig() {
    if (_accessKey.isEmpty || _secretKey.isEmpty) {
      print('❌ AWS credentials are empty');
      return false;
    }
    
    if (_bucketName.isEmpty) {
      print('❌ S3 bucket name is empty');
      return false;
    }
    
    if (_region.isEmpty) {
      print('❌ AWS region is empty');
      return false;
    }

    // Check if credentials look like placeholder values
    if (_accessKey.contains('YOUR_') || _secretKey.contains('YOUR_') ||
        _accessKey.contains('PLACEHOLDER') || _secretKey.contains('PLACEHOLDER') ||
        _accessKey.length < 16 || _secretKey.length < 16) {
      print('❌ AWS credentials appear to be invalid or placeholder values');
      print('   Access Key: ${_accessKey.substring(0, 8)}... (length: ${_accessKey.length})');
      print('   Secret Key: ${_secretKey.substring(0, 8)}... (length: ${_secretKey.length})');
      return false;
    }

    // Basic format validation for AWS credentials
    if (!_accessKey.startsWith('AKIA') || _accessKey.length != 20) {
      print('❌ Invalid AWS Access Key format');
      print('   Expected: AKIA followed by 16 characters (total 20)');
      print('   Got: $_accessKey (length: ${_accessKey.length})');
      return false;
    }

    return true;
  }

  /// Test AWS credentials without making S3 calls
  static Future<bool> testCredentials() async {
    try {
      print('=== Testing AWS Credentials ===');
      
      if (!_validateConfig()) {
        return false;
      }

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Try to list buckets (this tests credentials without needing specific bucket permissions)
      print('Testing AWS credentials by listing buckets...');
      final response = await s3Client.listBuckets();
      
      print('✅ AWS credentials are valid!');
      print('Found ${response.buckets?.length ?? 0} buckets in your account');
      
      // Check if our target bucket exists
      final bucketExists = response.buckets?.any((bucket) => bucket.name == _bucketName) ?? false;
      if (bucketExists) {
        print('✅ Target bucket "$_bucketName" exists');
      } else {
        print('❌ Target bucket "$_bucketName" not found in your account');
        print('Available buckets: ${response.buckets?.map((b) => b.name).join(", ") ?? "None"}');
      }
      
      return bucketExists;
    } catch (e, stackTrace) {
      print('❌ AWS credentials test failed: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack Trace: $stackTrace');
      
      // Provide specific error information
      if (e.toString().contains('InvalidAccessKeyId')) {
        print('❌ Invalid AWS Access Key ID');
        print('💡 Check your AWS Access Key in config.dart');
      } else if (e.toString().contains('SignatureDoesNotMatch')) {
        print('❌ AWS Secret Key is incorrect');
        print('💡 Check your AWS Secret Key in config.dart');
      } else if (e.toString().contains('AccessDenied')) {
        print('❌ Access denied - insufficient permissions');
        print('💡 Ensure your AWS user has at least s3:ListAllMyBuckets permission');
      } else if (e.toString().contains('Network')) {
        print('❌ Network connectivity issue');
        print('💡 Check your internet connection and firewall settings');
      }
      
      return false;
    }
  }

  /// Upload SOS data to S3 using AWS SDK
  static Future<bool> uploadSOSData(Map<String, dynamic> sosData) async {
    try {
      print('=== S3 SOS Upload Debug Info (AWS SDK) ===');
      print('Bucket: $_bucketName');
      print('Region: $_region');
      print('Access Key: ${_accessKey.substring(0, 8)}...');
      print('SOS Data: $sosData');

      // Validate configuration first
      if (!_validateConfig()) {
        return false;
      }

      // Generate unique filename for SOS data with folder structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'sos/sos_${sosData['userId']}_$timestamp.json';
      print('Filename: $filename');

      // Convert data to JSON
      final jsonData = jsonEncode(sosData);
      final bytes = Uint8List.fromList(utf8.encode(jsonData));
      print('JSON Data Length: ${jsonData.length} characters');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Upload to S3
      print('Uploading SOS data to S3...');
      final response = await s3Client.putObject(
        bucket: _bucketName,
        key: filename,
        body: bytes,
        contentType: 'application/json',
      );

      print('✅ Successfully uploaded SOS data to S3: $filename');
      print('ETag: ${response.eTag}');
      return true;
    } catch (e, stackTrace) {
      print('❌ Exception uploading SOS data to S3: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack Trace: $stackTrace');
      
      // Provide more specific error information
      if (e.toString().contains('InvalidAccessKeyId')) {
        print('❌ Invalid AWS Access Key ID');
      } else if (e.toString().contains('SignatureDoesNotMatch')) {
        print('❌ AWS Secret Key is incorrect');
      } else if (e.toString().contains('NoSuchBucket')) {
        print('❌ S3 bucket does not exist: $_bucketName');
      } else if (e.toString().contains('AccessDenied')) {
        print('❌ Access denied - check IAM permissions for S3');
      } else if (e.toString().contains('IllegalLocationConstraintException')) {
        print('❌ Region mismatch - bucket may be in different region');
      } else if (e.toString().contains('Network')) {
        print('❌ Network connectivity issue');
      }
      
      return false;
    }
  }

  /// Upload report data to S3 using AWS SDK
  static Future<bool> uploadReport(Map<String, dynamic> reportData) async {
    try {
      print('=== S3 Upload Debug Info (AWS SDK) ===');
      print('Bucket: $_bucketName');
      print('Region: $_region');
      print('Access Key: ${_accessKey.substring(0, 8)}...');
      print('Report Data: $reportData');

      // Validate configuration first
      if (!_validateConfig()) {
        return false;
      }

      // Generate unique filename with folder structure
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'reports/report_${reportData['userId']}_$timestamp.json';
      print('Filename: $filename');

      // Convert data to JSON
      final jsonData = jsonEncode(reportData);
      final bytes = Uint8List.fromList(utf8.encode(jsonData));
      print('JSON Data Length: ${jsonData.length} characters');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Upload to S3
      print('Uploading to S3...');
      final response = await s3Client.putObject(
        bucket: _bucketName,
        key: filename,
        body: bytes,
        contentType: 'application/json',
      );

      print('✅ Successfully uploaded report to S3: $filename');
      print('ETag: ${response.eTag}');
      return true;
    } catch (e, stackTrace) {
      print('❌ Exception uploading report to S3: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack Trace: $stackTrace');
      
      // Provide more specific error information
      if (e.toString().contains('InvalidAccessKeyId')) {
        print('❌ Invalid AWS Access Key ID');
      } else if (e.toString().contains('SignatureDoesNotMatch')) {
        print('❌ AWS Secret Key is incorrect');
      } else if (e.toString().contains('NoSuchBucket')) {
        print('❌ S3 bucket does not exist: $_bucketName');
      } else if (e.toString().contains('AccessDenied')) {
        print('❌ Access denied - check IAM permissions for S3');
      } else if (e.toString().contains('IllegalLocationConstraintException')) {
        print('❌ Region mismatch - bucket may be in different region');
      } else if (e.toString().contains('Network')) {
        print('❌ Network connectivity issue');
      }
      
      return false;
    }
  }

  /// Upload SOS status update to S3 (fallback for DynamoDB failures)
  static Future<bool> uploadSOSStatusUpdate(Map<String, dynamic> statusUpdate) async {
    try {
      print('📤 Uploading SOS status update to S3...');
      
      // Validate configuration
      if (!_validateConfig()) {
        print('❌ Invalid S3 configuration');
        return false;
      }

      // Convert to JSON
      final jsonString = jsonEncode(statusUpdate);
      final bytes = utf8.encode(jsonString);

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sosId = statusUpdate['sosId'] ?? 'unknown';
      final filename = 'sos-updates/sos_update_${sosId}_$timestamp.json';

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Upload to S3
      final response = await s3Client.putObject(
        bucket: _bucketName,
        key: filename,
        body: bytes,
        contentType: 'application/json',
      );

      print('✅ SOS status update uploaded successfully to S3');
      print('📁 File: $filename');
      print('ETag: ${response.eTag}');
      return true;
    } catch (e) {
      print('❌ Error uploading SOS status update to S3: $e');
      return false;
    }
  }

  /// Test S3 connection using AWS SDK
  static Future<bool> testConnection() async {
    try {
      print('=== Testing S3 Connection (AWS SDK) ===');
      print('Bucket: $_bucketName');
      print('Region: $_region');
      print('Access Key: ${_accessKey.substring(0, 8)}...');

      // Validate configuration first
      if (!_validateConfig()) {
        return false;
      }

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Try to list bucket contents (simple test)
      print('Testing bucket access...');
      final response = await s3Client.listObjectsV2(
        bucket: _bucketName,
        maxKeys: 1, // Only get 1 object to test connection
      );

      print('✅ S3 connection test successful!');
      print('Bucket contains ${response.keyCount ?? 0} objects');
      return true;
    } catch (e, stackTrace) {
      print('❌ S3 connection test error: $e');
      print('Error type: ${e.runtimeType}');
      print('Stack Trace: $stackTrace');
      
      // Provide more specific error information
      if (e.toString().contains('InvalidAccessKeyId')) {
        print('❌ Invalid AWS Access Key ID');
      } else if (e.toString().contains('SignatureDoesNotMatch')) {
        print('❌ AWS Secret Key is incorrect');
      } else if (e.toString().contains('NoSuchBucket')) {
        print('❌ S3 bucket does not exist: $_bucketName');
      } else if (e.toString().contains('AccessDenied')) {
        print('❌ Access denied - check IAM permissions for S3');
      } else if (e.toString().contains('IllegalLocationConstraintException')) {
        print('❌ Region mismatch - bucket may be in different region');
      } else if (e.toString().contains('Network')) {
        print('❌ Network connectivity issue');
      }
      
      return false;
    }
  }

  /// List all reports from S3
  static Future<List<Map<String, dynamic>>> getAllReports() async {
    try {
      print('=== Getting all reports from S3 (AWS SDK) ===');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // List objects in bucket with prefix filter for reports folder
      final response = await s3Client.listObjectsV2(
        bucket: _bucketName,
        prefix: 'reports/', // Only list files in reports folder
      );

      final reports = <Map<String, dynamic>>[];
      
      if (response.contents != null) {
        for (final object in response.contents!) {
          if (object.key != null && object.key!.endsWith('.json')) {
            reports.add({
              'key': object.key,
              'filename': object.key!.split('/').last,
              'folder': 'reports',
              'uploadedAt': object.lastModified?.toIso8601String() ?? 'Unknown',
              'size': object.size ?? 0,
              'etag': object.eTag,
            });
          }
        }
      }

      print('✅ Retrieved ${reports.length} reports from S3');
      return reports;
    } catch (e, stackTrace) {
      print('❌ Error getting reports from S3: $e');
      print('Stack Trace: $stackTrace');
      return [];
    }
  }

  /// Download specific report from S3
  static Future<Map<String, dynamic>?> downloadReport(String key) async {
    try {
      print('=== Downloading report from S3 (AWS SDK) ===');
      print('Key: $key');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Get object from S3
      final response = await s3Client.getObject(
        bucket: _bucketName,
        key: key,
      );

      if (response.body != null) {
        final jsonString = utf8.decode(response.body!);
        final reportData = jsonDecode(jsonString);
        print('✅ Successfully downloaded report: $key');
        return reportData;
      } else {
        print('❌ No data found for key: $key');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error downloading report from S3: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// List all SOS data from S3
  static Future<List<Map<String, dynamic>>> getAllSOSData() async {
    try {
      print('=== Getting all SOS data from S3 (AWS SDK) ===');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // List objects in bucket with prefix filter for sos folder
      final response = await s3Client.listObjectsV2(
        bucket: _bucketName,
        prefix: 'sos/', // Only list files in sos folder
      );

      final sosData = <Map<String, dynamic>>[];
      
      if (response.contents != null) {
        for (final object in response.contents!) {
          if (object.key != null && object.key!.endsWith('.json')) {
            sosData.add({
              'key': object.key,
              'filename': object.key!.split('/').last,
              'folder': 'sos',
              'uploadedAt': object.lastModified?.toIso8601String() ?? 'Unknown',
              'size': object.size ?? 0,
              'etag': object.eTag,
            });
          }
        }
      }

      print('✅ Retrieved ${sosData.length} SOS records from S3');
      return sosData;
    } catch (e, stackTrace) {
      print('❌ Error getting SOS data from S3: $e');
      print('Stack Trace: $stackTrace');
      return [];
    }
  }

  /// Download specific SOS data from S3
  static Future<Map<String, dynamic>?> downloadSOSData(String key) async {
    try {
      print('=== Downloading SOS data from S3 (AWS SDK) ===');
      print('Key: $key');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // Get object from S3
      final response = await s3Client.getObject(
        bucket: _bucketName,
        key: key,
      );

      if (response.body != null) {
        final jsonString = utf8.decode(response.body!);
        final sosData = jsonDecode(jsonString);
        print('✅ Successfully downloaded SOS data: $key');
        return sosData;
      } else {
        print('❌ No data found for key: $key');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Error downloading SOS data from S3: $e');
      print('Stack Trace: $stackTrace');
      return null;
    }
  }

  /// List all data (reports and SOS) from S3 with folder organization
  static Future<Map<String, List<Map<String, dynamic>>>> getAllData() async {
    try {
      print('=== Getting all data from S3 (AWS SDK) ===');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // List all objects in bucket
      final response = await s3Client.listObjectsV2(
        bucket: _bucketName,
      );

      final allData = <String, List<Map<String, dynamic>>>{
        'reports': <Map<String, dynamic>>[],
        'sos': <Map<String, dynamic>>[],
      };
      
      if (response.contents != null) {
        for (final object in response.contents!) {
          if (object.key != null && object.key!.endsWith('.json')) {
            final key = object.key!;
            final folder = key.split('/').first;
            
            if (folder == 'reports') {
              allData['reports']!.add({
                'key': key,
                'filename': key.split('/').last,
                'folder': folder,
                'uploadedAt': object.lastModified?.toIso8601String() ?? 'Unknown',
                'size': object.size ?? 0,
                'etag': object.eTag,
              });
            } else if (folder == 'sos') {
              allData['sos']!.add({
                'key': key,
                'filename': key.split('/').last,
                'folder': folder,
                'uploadedAt': object.lastModified?.toIso8601String() ?? 'Unknown',
                'size': object.size ?? 0,
                'etag': object.eTag,
              });
            }
          }
        }
      }

      print('✅ Retrieved ${allData['reports']!.length} reports and ${allData['sos']!.length} SOS records from S3');
      return allData;
    } catch (e, stackTrace) {
      print('❌ Error getting all data from S3: $e');
      print('Stack Trace: $stackTrace');
      return {'reports': [], 'sos': []};
    }
  }

  /// Get data from specific folder
  static Future<List<Map<String, dynamic>>> getDataByFolder(String folder) async {
    try {
      print('=== Getting data from $folder folder (AWS SDK) ===');

      // Create AWS credentials
      final credentials = AwsClientCredentials(
        accessKey: _accessKey,
        secretKey: _secretKey,
      );

      // Create S3 client
      final s3Client = S3(
        region: _region,
        credentials: credentials,
      );

      // List objects in bucket with folder prefix
      final response = await s3Client.listObjectsV2(
        bucket: _bucketName,
        prefix: '$folder/', // List files in specific folder
      );

      final data = <Map<String, dynamic>>[];
      
      if (response.contents != null) {
        for (final object in response.contents!) {
          if (object.key != null && object.key!.endsWith('.json')) {
            data.add({
              'key': object.key,
              'filename': object.key!.split('/').last,
              'folder': folder,
              'uploadedAt': object.lastModified?.toIso8601String() ?? 'Unknown',
              'size': object.size ?? 0,
              'etag': object.eTag,
            });
          }
        }
      }

      print('✅ Retrieved ${data.length} files from $folder folder');
      return data;
    } catch (e, stackTrace) {
      print('❌ Error getting data from $folder folder: $e');
      print('Stack Trace: $stackTrace');
      return [];
    }
  }
}