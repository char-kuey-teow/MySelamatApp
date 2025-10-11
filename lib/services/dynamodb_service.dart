import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import '../config.dart';

class DynamoDBService {
  static const String _region = 'us-east-1';
  static const String _service = 'dynamodb';
  static const String _host = 'dynamodb.us-east-1.amazonaws.com';
  static const String _tableName = 'sos';

  /// Update SOS status in DynamoDB
  static Future<bool> updateSOSStatus(String sosId, String newStatus, {String? reason}) async {
    try {
      print('🔄 Updating SOS status in DynamoDB: $sosId -> $newStatus');
      
      final timestamp = DateTime.now().toIso8601String();
      
      final updateExpression = 'SET #status = :status, updatedAt = :updatedAt';
      final expressionAttributeNames = {
        '#status': 'status',
      };
      final expressionAttributeValues = {
        ':status': {'S': newStatus},
        ':updatedAt': {'S': timestamp},
      };

      // Add reason if provided
      if (reason != null && reason.isNotEmpty) {
        expressionAttributeValues[':reason'] = {'S': reason};
        updateExpression.replaceAll('updatedAt = :updatedAt', 'updatedAt = :updatedAt, reason = :reason');
      }

      final payload = {
        'TableName': _tableName,
        'Key': {
          'sosId': {'S': sosId}
        },
        'UpdateExpression': updateExpression,
        'ExpressionAttributeNames': expressionAttributeNames,
        'ExpressionAttributeValues': expressionAttributeValues,
        'ReturnValues': 'UPDATED_NEW'
      };

      final response = await _makeDynamoDBRequest('UpdateItem', payload);
      
      if (response.statusCode == 200) {
        print('✅ SOS status updated successfully in DynamoDB');
        return true;
      } else {
        print('❌ Failed to update SOS status: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error updating SOS status in DynamoDB: $e');
      return false;
    }
  }

  /// Get SOS record from DynamoDB
  static Future<Map<String, dynamic>?> getSOSRecord(String sosId) async {
    try {
      print('🔍 Getting SOS record from DynamoDB: $sosId');
      
      final payload = {
        'TableName': _tableName,
        'Key': {
          'sosId': {'S': sosId}
        }
      };

      final response = await _makeDynamoDBRequest('GetItem', payload);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['Item'] != null) {
          print('✅ SOS record retrieved successfully');
          return _convertDynamoDBItem(data['Item']);
        } else {
          print('⚠️ SOS record not found');
          return null;
        }
      } else {
        print('❌ Failed to get SOS record: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Error getting SOS record from DynamoDB: $e');
      return null;
    }
  }

  /// Get user's SOS history from DynamoDB
  static Future<List<Map<String, dynamic>>> getUserSOSHistory(String userId) async {
    try {
      print('📋 Getting SOS history for user: $userId');
      
      final payload = {
        'TableName': _tableName,
        'IndexName': 'userId-index', // Assuming you have a GSI on userId
        'KeyConditionExpression': 'userId = :userId',
        'ExpressionAttributeValues': {
          ':userId': {'S': userId}
        },
        'ScanIndexForward': false, // Sort by timestamp descending
        'Limit': 50
      };

      final response = await _makeDynamoDBRequest('Query', payload);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['Items'] as List? ?? [];
        print('✅ Retrieved ${items.length} SOS records');
        return items.map((item) => _convertDynamoDBItem(item)).toList();
      } else {
        print('❌ Failed to get SOS history: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('❌ Error getting SOS history from DynamoDB: $e');
      return [];
    }
  }

  /// Make DynamoDB API request with proper AWS Signature V4
  static Future<http.Response> _makeDynamoDBRequest(String action, Map<String, dynamic> payload) async {
    final uri = Uri.https(_host, '/');
    final body = jsonEncode(payload);
    final now = DateTime.now().toUtc();
    final amzDate = now.toIso8601String().replaceAll(':', '').split('.')[0] + 'Z';
    final dateStamp = now.toIso8601String().split('T')[0].replaceAll('-', '');
    
    // Create headers
    final headers = {
      'Content-Type': 'application/x-amz-json-1.0',
      'X-Amz-Target': 'DynamoDB_20120810.$action',
      'X-Amz-Date': amzDate,
      'Host': _host,
    };

    // Create canonical request
    final canonicalRequest = _createCanonicalRequest('POST', '/', headers, body);
    
    // Create string to sign
    final credentialScope = '$dateStamp/$_region/$_service/aws4_request';
    final stringToSign = _createStringToSign(amzDate, credentialScope, canonicalRequest);
    
    // Create signature
    final signature = _createSignature(stringToSign, dateStamp);
    
    // Add authorization header
    final signedHeaders = _getSignedHeaders(headers);
    final authorization = 'AWS4-HMAC-SHA256 Credential=${Config.awsAccessKey}/$credentialScope, SignedHeaders=$signedHeaders, Signature=$signature';
    headers['Authorization'] = authorization;

    // Make request
    return await http.post(uri, headers: headers, body: body);
  }

  /// Create canonical request for AWS Signature V4
  static String _createCanonicalRequest(String method, String uri, Map<String, String> headers, String body) {
    final sortedHeaders = headers.keys.toList()..sort();
    final canonicalHeaders = sortedHeaders.map((key) => '${key.toLowerCase()}:${headers[key]}').join('\n') + '\n';
    final signedHeaders = sortedHeaders.map((key) => key.toLowerCase()).join(';');
    final payloadHash = sha256.convert(utf8.encode(body)).toString();
    
    return '$method\n$uri\n\n$canonicalHeaders\n$signedHeaders\n$payloadHash';
  }

  /// Create string to sign for AWS Signature V4
  static String _createStringToSign(String amzDate, String credentialScope, String canonicalRequest) {
    final algorithm = 'AWS4-HMAC-SHA256';
    final canonicalRequestHash = sha256.convert(utf8.encode(canonicalRequest)).toString();
    
    return '$algorithm\n$amzDate\n$credentialScope\n$canonicalRequestHash';
  }

  /// Create signature for AWS Signature V4
  static String _createSignature(String stringToSign, String dateStamp) {
    final kDate = _hmacSha256(utf8.encode('AWS4${Config.awsSecretKey}'), utf8.encode(dateStamp));
    final kRegion = _hmacSha256(kDate, utf8.encode(_region));
    final kService = _hmacSha256(kRegion, utf8.encode(_service));
    final kSigning = _hmacSha256(kService, utf8.encode('aws4_request'));
    
    return _hmacSha256(kSigning, utf8.encode(stringToSign)).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }

  /// HMAC-SHA256 implementation
  static List<int> _hmacSha256(List<int> key, List<int> data) {
    final hmac = Hmac(sha256, key);
    return hmac.convert(data).bytes;
  }

  /// Get signed headers string
  static String _getSignedHeaders(Map<String, String> headers) {
    final sortedHeaders = headers.keys.map((key) => key.toLowerCase()).toList()..sort();
    return sortedHeaders.join(';');
  }


  /// Convert DynamoDB item to regular Map
  static Map<String, dynamic> _convertDynamoDBItem(Map<String, dynamic> item) {
    final result = <String, dynamic>{};
    
    item.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        // Handle DynamoDB attribute types
        if (value.containsKey('S')) {
          result[key] = value['S'];
        } else if (value.containsKey('N')) {
          result[key] = double.tryParse(value['N']) ?? value['N'];
        } else if (value.containsKey('BOOL')) {
          result[key] = value['BOOL'];
        } else if (value.containsKey('L')) {
          result[key] = (value['L'] as List).map((e) => _convertDynamoDBItem(e)).toList();
        } else if (value.containsKey('M')) {
          result[key] = _convertDynamoDBItem(value['M']);
        }
      }
    });
    
    return result;
  }

  /// Generate unique SOS ID
  static String generateSOSId(String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'sos_${userId}_$timestamp';
  }

  /// Validate SOS ID format
  static bool isValidSOSId(String sosId) {
    return sosId.startsWith('sos_') && sosId.contains('_') && sosId.length > 10;
  }
}
