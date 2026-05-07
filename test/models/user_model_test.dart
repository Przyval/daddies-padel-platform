import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/user_model.dart';

void main() {
  group('UserModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'user-1',
        'name': 'Reza Rahadian',
        'phone': '08119990001',
        'role': 'superAdmin',
        'createdAt': '2025-01-15T10:00:00.000',
      };

      final user = UserModel.fromJson(json);
      expect(user.id, 'user-1');
      expect(user.name, 'Reza Rahadian');
      expect(user.phone, '08119990001');
      expect(user.role, UserRole.superAdmin);
      expect(user.createdAt, DateTime(2025, 1, 15, 10, 0, 0));
    });

    test('fromJson with null fields uses defaults', () {
      final json = <String, dynamic>{
        'id': null,
        'name': null,
        'phone': null,
        'role': null,
        'createdAt': null,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, '');
      expect(user.name, 'Unknown');
      expect(user.phone, '');
      expect(user.role, UserRole.member);
      expect(user.createdAt, isA<DateTime>());
    });

    test('fromJson with missing fields uses defaults', () {
      final user = UserModel.fromJson(<String, dynamic>{});
      expect(user.id, '');
      expect(user.name, 'Unknown');
      expect(user.role, UserRole.member);
    });

    test('fromJson with invalid role falls back to member', () {
      final json = {
        'id': 'user-1',
        'name': 'Test',
        'phone': '123',
        'role': 'invalidRole',
        'createdAt': '2025-01-15T10:00:00.000',
      };

      final user = UserModel.fromJson(json);
      expect(user.role, UserRole.member);
    });

    test('fromJson with invalid date falls back to now', () {
      final before = DateTime.now();
      final json = {
        'id': 'user-1',
        'name': 'Test',
        'phone': '123',
        'role': 'mimin',
        'createdAt': 'not-a-date',
      };

      final user = UserModel.fromJson(json);
      expect(user.createdAt.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('toJson produces correct output', () {
      final user = UserModel(
        id: 'user-1',
        name: 'Test User',
        phone: '08119990001',
        role: UserRole.bendahara,
        createdAt: DateTime(2025, 6, 1),
      );

      final json = user.toJson();
      expect(json['id'], 'user-1');
      expect(json['name'], 'Test User');
      expect(json['phone'], '08119990001');
      expect(json['role'], 'bendahara');
      expect(json['createdAt'], '2025-06-01T00:00:00.000');
    });

    test('toJson roundtrip', () {
      final original = UserModel(
        id: 'user-x',
        name: 'Roundtrip',
        phone: '081234',
        role: UserRole.mimin,
        createdAt: DateTime(2025, 3, 15, 14, 30),
      );

      final restored = UserModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.phone, original.phone);
      expect(restored.role, original.role);
      expect(restored.createdAt, original.createdAt);
    });

    test('copyWith creates modified copy', () {
      final user = UserModel(
        id: 'user-1',
        name: 'Old Name',
        phone: '123',
        role: UserRole.member,
        createdAt: DateTime(2025, 1, 1),
      );

      final updated = user.copyWith(name: 'New Name', role: UserRole.mimin);
      expect(updated.name, 'New Name');
      expect(updated.role, UserRole.mimin);
      expect(updated.id, 'user-1');
      expect(updated.phone, '123');
    });

    test('roleLabel returns correct labels', () {
      expect(
        UserModel(id: '', name: '', phone: '', role: UserRole.superAdmin, createdAt: DateTime.now()).roleLabel,
        'Super Admin',
      );
      expect(
        UserModel(id: '', name: '', phone: '', role: UserRole.mimin, createdAt: DateTime.now()).roleLabel,
        'Mimin',
      );
      expect(
        UserModel(id: '', name: '', phone: '', role: UserRole.bendahara, createdAt: DateTime.now()).roleLabel,
        'Bendahara',
      );
      expect(
        UserModel(id: '', name: '', phone: '', role: UserRole.member, createdAt: DateTime.now()).roleLabel,
        'Member',
      );
    });
  });
}
