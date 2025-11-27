import 'dart:async';
import '../models/staff_user.dart';


class AuthService {
// Mock authentication
  Future<UserModel?> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (email == 'admin@glass.com' && password == '1234') {
      return UserModel(id: '1', name: 'Admin Glass', email: email, phone: '09171234567');
    }
// any email accepted for demo
    return UserModel(id: '2', name: 'Demo User', email: email, phone: '09170000000');
  }


  Future<UserModel> signup(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return UserModel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, email: email);
  }
}