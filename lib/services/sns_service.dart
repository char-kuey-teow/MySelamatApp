import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'backend_config.dart';

/// Service to handle Amazon SNS operations
class SNSService {
  static final SNSService _instance = SNSService._internal();
  factory SNSService() => _instance;
  SNSService._internal();

  
  // AWS configuration - these should come from your backend or environment
  static const String _region = BackendConfig.region;
  static const String _service = 'sns';
  static String get _host => 'sns.$_region.amazonaws.com';
  
  // These should be provided by your backend or stored securely
  String? _accessKeyId;
  String? _secretAccessKey;
  String? _sessionToken;

  /// Initialize SNS service with AWS credentials
  void initialize({
    required String accessKeyId,
    required String secretAccessKey,
    String? sessionToken,
  }) {
    _accessKeyId = accessKeyId;
    _secretAccessKey = secretAccessKey;
    _sessionToken = sessionToken;
  }


  /// Create a platform endpoint for FCM token
  Future<String?> createPlatformEndpoint({
    required String fcmToken,
    String? customUserData,
  }) async {
    try {
      final action = 'CreatePlatformEndpoint';
      final parameters = {
        'PlatformApplicationArn': BackendConfig.platformApplicationArn,
        'Token': fcmToken,
        if (customUserData != null) 'CustomUserData': customUserData,
      };

      final response = await _makeSNSRequest(action, parameters);
      
      if (response.statusCode == 200) {
        // Parse the response to get the endpoint ARN
        final responseBody = jsonDecode(response.body);
        final endpointArn = responseBody['CreatePlatformEndpointResponse']?['CreatePlatformEndpointResult']?['EndpointArn'];
        print('✅ Platform endpoint created: $endpointArn');
        return endpointArn;
      } else {
        final errorBody = response.body;
        print('❌ Failed to create platform endpoint: $errorBody');
        
        // Check for specific error cases
        if (errorBody.contains('EndpointAlreadyExists')) {
          throw Exception('EndpointAlreadyExists: An endpoint with this token already exists');
        } else if (errorBody.contains('InvalidParameter')) {
          throw Exception('InvalidParameter: Check your FCM token and platform application ARN');
        } else if (errorBody.contains('AuthorizationError')) {
          throw Exception('AuthorizationError: Check your AWS credentials and permissions');
        }
        
        return null;
      }
    } catch (e) {
      print('❌ Error creating platform endpoint: $e');
      return null;
    }
  }

  /// Publish a message to an endpoint
  Future<bool> publishToEndpoint({
    required String endpointArn,
    required String message,
    required String subject,
    Map<String, String>? messageAttributes,
  }) async {
    try {
      final action = 'Publish';
      final parameters = {
        'TargetArn': endpointArn,
        'Message': message,
        'Subject': subject,
        if (messageAttributes != null) ...messageAttributes,
      };

      print('🚀 Publishing message to endpoint: $endpointArn');
      print('📋 Message: $message');
      print('📝 Subject: $subject');
      
      final response = await _makeSNSRequest(action, parameters);
      
      print('📊 Response Status: ${response.statusCode}');
      print('📊 Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        print('✅ Message published successfully');
        return true;
      } else {
        print('❌ Failed to publish message: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error publishing message: $e');
      return false;
    }
  }



  /// Make a signed request to Amazon SNS
  Future<http.Response> _makeSNSRequest(
    String action,
    Map<String, dynamic> parameters,
  ) async {
    if (_accessKeyId == null || _secretAccessKey == null) {
      throw Exception('AWS credentials not initialized');
    }

    final uri = Uri.https(_host, '/');
    final now = DateTime.now().toUtc();
    
    // Create the request body
    final body = _createRequestBody(action, parameters);
    
    // Create the canonical request
    final canonicalRequest = _createCanonicalRequest(uri, body, now);
    
    // Create the string to sign
    final stringToSign = _createStringToSign(canonicalRequest, now);
    
    // Create the signature
    final signature = _createSignature(stringToSign, now);
    
    // Create the authorization header
    final authorization = _createAuthorizationHeader(signature, now);
    
    // Make the request
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/x-amz-json-1.0',
        'Authorization': authorization,
        'X-Amz-Date': _formatDateTime(now),
        if (_sessionToken != null) 'X-Amz-Security-Token': _sessionToken!,
      },
      body: body,
    );
    
    return response;
  }

  /// Create the request body for SNS API calls
  String _createRequestBody(String action, Map<String, dynamic> parameters) {
    final requestBody = {
      'Action': action,
      ...parameters,
    };
    
    return jsonEncode(requestBody);
  }

  /// Create the canonical request for AWS signature
  String _createCanonicalRequest(Uri uri, String body, DateTime dateTime) {
    final method = 'POST';
    const canonicalUri = '/';
    const canonicalQueryString = '';
    
    final canonicalHeaders = [
      'host:${uri.host}',
      'x-amz-date:${_formatDateTime(dateTime)}',
    ];
    
    if (_sessionToken != null) {
      canonicalHeaders.add('x-amz-security-token:$_sessionToken');
    }
    
    final signedHeaders = _sessionToken != null
        ? 'host;x-amz-date;x-amz-security-token'
        : 'host;x-amz-date';
    
    final payloadHash = sha256.convert(utf8.encode(body)).toString();
    
    return [
      method,
      canonicalUri,
      canonicalQueryString,
      canonicalHeaders.join('\n') + '\n',
      signedHeaders,
      payloadHash,
    ].join('\n');
  }

  /// Create the string to sign for AWS signature
  String _createStringToSign(String canonicalRequest, DateTime dateTime) {
    final credentialScope = '${_formatDate(dateTime)}/$_region/$_service/aws4_request';
    
    final hashedCanonicalRequest = sha256.convert(utf8.encode(canonicalRequest)).toString();
    
    return [
      'AWS4-HMAC-SHA256',
      _formatDateTime(dateTime),
      credentialScope,
      hashedCanonicalRequest,
    ].join('\n');
  }

  /// Create the AWS signature
  String _createSignature(String stringToSign, DateTime dateTime) {
    final date = _formatDate(dateTime);
    final dateKey = _hmacSha256('AWS4$_secretAccessKey', date);
    final regionKey = _hmacSha256(dateKey, _region);
    final serviceKey = _hmacSha256(regionKey, _service);
    final signingKey = _hmacSha256(serviceKey, 'aws4_request');
    
    return _hmacSha256(signingKey, stringToSign);
  }

  /// Create the authorization header
  String _createAuthorizationHeader(String signature, DateTime dateTime) {
    final credentialScope = '${_formatDate(dateTime)}/$_region/$_service/aws4_request';
    
    final signedHeaders = _sessionToken != null
        ? 'host;x-amz-date;x-amz-security-token'
        : 'host;x-amz-date';
    
    return 'AWS4-HMAC-SHA256 '
        'Credential=$_accessKeyId/$credentialScope, '
        'SignedHeaders=$signedHeaders, '
        'Signature=$signature';
  }

  /// Format date for AWS signature
  String _formatDate(DateTime dateTime) {
    return dateTime.toIso8601String().substring(0, 10).replaceAll('-', '');
  }

  /// Format date time for AWS signature
  String _formatDateTime(DateTime dateTime) {
    return dateTime.toIso8601String().replaceAll(':', '').substring(0, 19) + 'Z';
  }

  /// HMAC SHA256 implementation
  String _hmacSha256(String key, String data) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(data);
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(dataBytes);
    return digest.toString();
  }

  /// Create FCM message payload
  Map<String, dynamic> createFCMPayload({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? sound,
    String? clickAction,
  }) {
    final payload = {
      'notification': {
        'title': title,
        'body': body,
        if (imageUrl != null) 'image': imageUrl,
        if (sound != null) 'sound': sound,
      },
      if (data != null) 'data': data,
      if (clickAction != null) 'click_action': clickAction,
    };

    return {
      'GCM': jsonEncode(payload),
    };
  }

  /// Create SNS message for FCM
  String createSNSMessage({
    required String title,
    required String body,
    Map<String, dynamic>? data,
    String? imageUrl,
    String? sound,
    String? clickAction,
  }) {
    final fcmPayload = createFCMPayload(
      title: title,
      body: body,
      data: data,
      imageUrl: imageUrl,
      sound: sound,
      clickAction: clickAction,
    );

    return jsonEncode(fcmPayload);
  }
}
