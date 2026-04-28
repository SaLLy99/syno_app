import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../presentation/providers/registration_provider.dart';

/// A service class for handling user authentication.
class AuthService {
  final String _backendUrl;

  AuthService(this._backendUrl);

 
  Future<bool> register(String email, String password) async {
    debugPrint("[AuthService] Attempting to register...");
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Email and password cannot be empty.');
    }

    final url = Uri.parse('$_backendUrl/api/auth/register');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );
     

      if (response.statusCode == 201) {
          final data = jsonDecode(response.body);
          final token = data['access_token'];
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
          debugPrint("[AuthService] Registration successful for step 1.");
          return true;
      } else {
        debugPrint("[AuthService] Registration API call failed with status ${response.statusCode}: ${response.body}");
        // You might want to parse the error message from the body
        throw Exception('Registration failed: ${response.body}');
      }
    } on SocketException {
      throw Exception('Failed to connect to the server. Please check your network connection.');
    } catch (e) {
      debugPrint("[AuthService] An error occurred during registration: $e");
      rethrow;
    }
  }

  /// Sends all registration data (Step 1, 2, 3) in a single multipart request.
  Future<void> registerCompleteUser(RegistrationData data) async {
    debugPrint("[AuthService] Attempting complete registration...");
    final url = Uri.parse('$_backendUrl/api/auth/register-complete');

    final request = http.MultipartRequest('POST', url);

    // 1. Step 1 Data (Email/Password)
    request.fields['email'] = data.step1Data['email'] ?? '';
    request.fields['password'] = data.step1Data['password'] ?? '';

    // 2. Step 2 Data (Profile Details)
    data.step2Data.forEach((key, value) {
      if (value is DateTime) {
        request.fields[key] = value.toIso8601String();
      } else if (value != null) {
        request.fields[key] = value.toString();
      }
    });

    // 3. Core Values & Intentions
    // JSON-encode lists to match backend expectation for multipart forms
    request.fields['core_value_ids'] = json.encode(data.coreValueIds);
    request.fields['intention_ids'] = json.encode(data.intentionIds);

    // 4. Photos
    for (var file in data.photos) {
      final stream = http.ByteStream(file.openRead());
      final length = await file.length();
      final multipartFile = http.MultipartFile(
        'photos',
        stream,
        length,
        filename: file.path.split('/').last,
      );
      request.files.add(multipartFile);
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final token = responseData['access_token'];
        if (token != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', token);
        }
        debugPrint("[AuthService] Complete registration successful.");
      } else {
        debugPrint("[AuthService] Registration failed: ${response.body}");
        throw Exception('Registration failed: ${response.body}');
      }
    } catch (e) {
      debugPrint("[AuthService] Error during complete registration: $e");
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    debugPrint("[AuthService] Attempting to log in...");
    // The endpoint for logging in.
    final url = Uri.parse('$_backendUrl/api/auth/login');


    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("[AuthService] Login API call failed with status ${response.statusCode}: ${response.body}");
        throw Exception('Login failed: ${response.body}');
      }

      final data = json.decode(response.body);
      final token = data['access_token'];
      if (token == null) {
        throw Exception('Token missing in login response');
      }

      // SAVE TOKEN BEFORE RETURNING
      debugPrint("[AuthService] Login successful. Saving token...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      debugPrint("[AuthService] Token saved successfully.");
    } on SocketException {
      // Handle network errors specifically
      throw Exception('Failed to connect to the server. Please check your network connection.');
    } catch (e) {
      // Handle network errors or other exceptions
      debugPrint("[AuthService] An error occurred during login: $e");
      rethrow;
    }
  }

  /// Clears the authentication token from local storage.
  ///
  /// This effectively logs the user out of the device.
  Future<void> logOut() async {
    debugPrint("[AuthService] Logging out...");
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      debugPrint("[AuthService] Token removed successfully.");
    } catch (e) {
      debugPrint("[AuthService] An error occurred during logout: $e");
      // Depending on the app's needs, you might want to rethrow or handle this.
    }
  }

  Future<void> checkEmailExists(String email) async {
    debugPrint("[AuthService] Checking email availability: $email");
    final url = Uri.parse('$_backendUrl/api/auth/check-email');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      if (response.statusCode == 409) {
        throw Exception('This email is already registered.');
      } else if (response.statusCode != 200) {
        throw Exception('Failed to verify email availability (Status: ${response.statusCode})');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Requests a One-Time Password (OTP) for the given email.
  Future<void> requestOtp({String? email, String? phoneNumber, String lang = 'en'}) async {
    final url = Uri.parse('$_backendUrl/api/auth/request-otp');

    Map<String, dynamic> body = {'lang': lang};
    if (email != null) {
      body['email'] = email;
    } else if (phoneNumber != null) {
      body['phone_number'] = phoneNumber;
    } else {
      throw Exception('Either email or phone number must be provided for OTP request.');
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        // Return the translation key from 'detail'
        throw Exception(errorData['detail'] is String ? errorData['detail'] : 'dialog.error_title');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verifies the One-Time Password (OTP) for the given email.
  ///
  /// Returns a map containing 'is_registered' (bool) and optionally 'access_token' (String).
  Future<Map<String, dynamic>> verifyOtp({String? email, String? phoneNumber, required String otpCode}) async {
    debugPrint("[AuthService] Verifying OTP for: ${email ?? phoneNumber} with code: $otpCode");
    final url = Uri.parse('$_backendUrl/api/auth/verify-otp');

    Map<String, dynamic> body = {'code': otpCode};
    if (email != null) {
      body['email'] = email;
    } else if (phoneNumber != null) {
      body['phone_number'] = phoneNumber;
    } else {
      throw Exception('Either email or phone number must be provided for OTP verification.');
    }

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool isRegistered = data['is_registered'] ?? false;
        final String? accessToken = data['access_token'];

        if (accessToken != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', accessToken);
        }
        return {
          'is_registered': isRegistered, 
          'access_token': accessToken,
          'message': data['message'] ?? 'otp.success'
        };
      } else {
        final errorData = jsonDecode(response.body);
        // Return the translation key from 'detail' to the UI
        throw Exception(errorData['detail'] is String ? errorData['detail'] : 'otp.invalid_code');
      }
    } catch (e) {
      debugPrint("[AuthService] An error occurred during OTP verification: $e");
      rethrow;
    }
  }
}