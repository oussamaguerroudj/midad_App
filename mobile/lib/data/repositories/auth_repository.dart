import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TeacherInfo {
  const TeacherInfo({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.schoolName,
    this.teacherId,
    this.schoolId,
  });

  final String userId;
  final String email;
  final String fullName;
  final String schoolName;
  final String? teacherId;
  final String? schoolId;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'email': email,
        'fullName': fullName,
        'schoolName': schoolName,
        'teacherId': teacherId,
        'schoolId': schoolId,
      };

  factory TeacherInfo.fromJson(Map<String, dynamic> json) => TeacherInfo(
        userId: json['userId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        schoolName: json['schoolName'] as String? ?? '',
        teacherId: json['teacherId'] as String?,
        schoolId: json['schoolId'] as String?,
      );
}

class AuthRepository {
  AuthRepository({
    required this.dio,
    required this.storage,
    required this.prefs,
  });

  final Dio dio;
  final FlutterSecureStorage storage;
  final SharedPreferences prefs;

  static const _kAccessToken = 'midad_access_token';
  static const _kRefreshToken = 'midad_refresh_token';
  static const _kTeacherInfo = 'midad_teacher_info';
  static const _kPinCode = 'midad_pin_code';
  static const _kPinEnabled = 'midad_pin_enabled';

  Future<TeacherInfo> login({required String email, required String password}) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email.trim(), 'password': password},
    );

    final data = res.data!;
    final tokens = data['tokens'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    final teacher = user['teacher'] as Map<String, dynamic>?;

    await storage.write(key: _kAccessToken, value: tokens['access_token'] as String);
    await storage.write(key: _kRefreshToken, value: tokens['refresh_token'] as String);

    final info = TeacherInfo(
      userId: user['id'] as String,
      email: user['email'] as String,
      fullName: teacher?['full_name'] as String? ?? 'أستاذ',
      schoolName: teacher?['school_name'] as String? ?? '',
      teacherId: teacher?['id'] as String?,
      schoolId: teacher?['school_id'] as String?,
    );

    await storage.write(key: _kTeacherInfo, value: jsonEncode(info.toJson()));
    return info;
  }

  Future<TeacherInfo> register({
    required String email,
    required String password,
    required String fullName,
    String? schoolName,
    String locale = 'ar',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'email': email.trim(),
        'password': password,
        'full_name': fullName.trim(),
        'school_name': schoolName?.trim(),
        'locale': locale,
      },
    );

    final data = res.data!;
    final tokens = data['tokens'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    final teacher = user['teacher'] as Map<String, dynamic>?;

    await storage.write(key: _kAccessToken, value: tokens['access_token'] as String);
    await storage.write(key: _kRefreshToken, value: tokens['refresh_token'] as String);

    final info = TeacherInfo(
      userId: user['id'] as String,
      email: user['email'] as String,
      fullName: teacher?['full_name'] as String? ?? fullName,
      schoolName: teacher?['school_name'] as String? ?? schoolName ?? '',
      teacherId: teacher?['id'] as String?,
      schoolId: teacher?['school_id'] as String?,
    );

    await storage.write(key: _kTeacherInfo, value: jsonEncode(info.toJson()));
    return info;
  }

  Future<TeacherInfo?> getSavedTeacher() async {
    final jsonStr = await storage.read(key: _kTeacherInfo);
    if (jsonStr == null) return null;
    try {
      return TeacherInfo.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasValidToken() async {
    final token = await storage.read(key: _kRefreshToken);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    final refresh = await storage.read(key: _kRefreshToken);
    if (refresh != null) {
      try {
        await dio.post<void>('/auth/logout', data: {'refresh_token': refresh});
      } catch (_) {
        // Best effort logout on network failure
      }
    }
    await storage.delete(key: _kAccessToken);
    await storage.delete(key: _kRefreshToken);
    await storage.delete(key: _kTeacherInfo);
  }

  bool isPinEnabled() => prefs.getBool(_kPinEnabled) ?? false;

  Future<void> setPin(String pin) async {
    await storage.write(key: _kPinCode, value: pin);
    await prefs.setBool(_kPinEnabled, true);
  }

  Future<bool> verifyPin(String pin) async {
    final savedPin = await storage.read(key: _kPinCode);
    return savedPin == pin;
  }

  Future<void> clearPin() async {
    await storage.delete(key: _kPinCode);
    await prefs.setBool(_kPinEnabled, false);
  }
}
