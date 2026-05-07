import 'package:flutter_test/flutter_test.dart';
import 'package:daddies_app/models/venue_model.dart';

void main() {
  group('VenueModel', () {
    test('fromJson with complete data', () {
      final json = {
        'id': 'venue-1',
        'name': 'Padel Pro Court',
        'address': '123 Sports Ave, City',
        'bio': 'Premium padel venue with indoor courts',
        'imageUrl': 'https://example.com/image.jpg',
        'phone': '0812-3456-7890',
        'facilities': ['Parking', 'Cafe', 'Locker Room'],
        'mapUrl': 'https://maps.example.com/venue1',
        'courtCount': 6,
        'openHours': '07:00 - 23:00',
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.id, 'venue-1');
      expect(venue.name, 'Padel Pro Court');
      expect(venue.address, '123 Sports Ave, City');
      expect(venue.bio, 'Premium padel venue with indoor courts');
      expect(venue.imageUrl, 'https://example.com/image.jpg');
      expect(venue.phone, '0812-3456-7890');
      expect(venue.facilities, ['Parking', 'Cafe', 'Locker Room']);
      expect(venue.mapUrl, 'https://maps.example.com/venue1');
      expect(venue.courtCount, 6);
      expect(venue.openHours, '07:00 - 23:00');
    });

    test('fromJson with null/missing fields uses defaults', () {
      final json = <String, dynamic>{
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.courtCount, 1);
      expect(venue.openHours, '06:00 - 22:00');
      expect(venue.facilities, []);
      expect(venue.imageUrl, isNull);
      expect(venue.phone, isNull);
      expect(venue.mapUrl, isNull);
    });

    test('fromJson handles double courtCount', () {
      final json = {
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
        'courtCount': 4.0,
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.courtCount, 4);
      expect(venue.courtCount, isA<int>());
    });

    test('fromJson handles string courtCount', () {
      final json = {
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
        'courtCount': '5',
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.courtCount, 5);
    });

    test('fromJson with empty map uses all defaults', () {
      final venue = VenueModel.fromJson(<String, dynamic>{});
      expect(venue.id, '');
      expect(venue.name, '');
      expect(venue.address, '');
      expect(venue.bio, '');
      expect(venue.courtCount, 1);
      expect(venue.openHours, '06:00 - 22:00');
      expect(venue.facilities, []);
    });

    test('toJson produces correct output', () {
      final venue = VenueModel(
        id: 'venue-1',
        name: 'Test Venue',
        address: 'Test Address',
        bio: 'Test Bio',
        imageUrl: 'https://example.com/img.jpg',
        phone: '0812345678',
        facilities: ['Parking', 'WiFi'],
        mapUrl: 'https://maps.example.com',
        courtCount: 8,
        openHours: '08:00 - 20:00',
      );

      final json = venue.toJson();
      expect(json['id'], 'venue-1');
      expect(json['name'], 'Test Venue');
      expect(json['address'], 'Test Address');
      expect(json['bio'], 'Test Bio');
      expect(json['imageUrl'], 'https://example.com/img.jpg');
      expect(json['phone'], '0812345678');
      expect(json['facilities'], ['Parking', 'WiFi']);
      expect(json['mapUrl'], 'https://maps.example.com');
      expect(json['courtCount'], 8);
      expect(json['openHours'], '08:00 - 20:00');
    });

    test('toJson roundtrip', () {
      final original = VenueModel(
        id: 'venue-x',
        name: 'Roundtrip Venue',
        address: 'Roundtrip Address',
        bio: 'Roundtrip Bio',
        imageUrl: 'https://example.com/img.jpg',
        phone: '0812345678',
        facilities: ['Court', 'Cafe'],
        mapUrl: 'https://maps.example.com',
        courtCount: 4,
        openHours: '09:00 - 21:00',
      );

      final restored = VenueModel.fromJson(original.toJson());
      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.address, original.address);
      expect(restored.bio, original.bio);
      expect(restored.imageUrl, original.imageUrl);
      expect(restored.phone, original.phone);
      expect(restored.facilities, original.facilities);
      expect(restored.mapUrl, original.mapUrl);
      expect(restored.courtCount, original.courtCount);
      expect(restored.openHours, original.openHours);
    });

    test('toJson roundtrip with null optional fields', () {
      final original = VenueModel(
        id: 'venue-y',
        name: 'Minimal Venue',
        address: 'Minimal Address',
        bio: 'Minimal Bio',
      );

      final restored = VenueModel.fromJson(original.toJson());
      expect(restored.imageUrl, isNull);
      expect(restored.phone, isNull);
      expect(restored.mapUrl, isNull);
      expect(restored.facilities, []);
      expect(restored.courtCount, 1);
      expect(restored.openHours, '06:00 - 22:00');
    });

    test('copyWith creates modified copy', () {
      final venue = VenueModel(
        id: 'venue-1',
        name: 'Original Name',
        address: 'Original Address',
        bio: 'Original Bio',
        imageUrl: 'https://example.com/old.jpg',
        phone: '0811111111',
        facilities: ['Parking'],
        mapUrl: 'https://maps.example.com/old',
        courtCount: 2,
        openHours: '06:00 - 22:00',
      );

      final updated = venue.copyWith(
        name: 'Updated Name',
        courtCount: 5,
        facilities: ['Parking', 'Cafe', 'Locker'],
      );

      expect(updated.name, 'Updated Name');
      expect(updated.courtCount, 5);
      expect(updated.facilities, ['Parking', 'Cafe', 'Locker']);
      expect(updated.id, 'venue-1');
      expect(updated.address, 'Original Address');
      expect(updated.bio, 'Original Bio');
      expect(updated.imageUrl, 'https://example.com/old.jpg');
      expect(updated.phone, '0811111111');
      expect(updated.mapUrl, 'https://maps.example.com/old');
      expect(updated.openHours, '06:00 - 22:00');
    });

    test('copyWith preserves nullable fields when not specified', () {
      final venue = VenueModel(
        id: 'venue-1',
        name: 'Test',
        address: 'Test Address',
        bio: 'Test Bio',
        imageUrl: 'https://example.com/img.jpg',
        phone: '0812345678',
      );

      final updated = venue.copyWith(name: 'Updated');
      expect(updated.imageUrl, 'https://example.com/img.jpg');
      expect(updated.phone, '0812345678');
      expect(updated.name, 'Updated');
    });

    test('facilities list serialization/deserialization', () {
      final json = {
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
        'facilities': ['Air Conditioning', 'Professional Equipment', 'Pro Shop'],
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.facilities, ['Air Conditioning', 'Professional Equipment', 'Pro Shop']);

      final restored = VenueModel.fromJson(venue.toJson());
      expect(restored.facilities, ['Air Conditioning', 'Professional Equipment', 'Pro Shop']);
    });

    test('facilities handles empty list', () {
      final json = {
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
        'facilities': [],
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.facilities, []);
    });

    test('facilities with non-string values converts to string', () {
      final json = {
        'id': 'venue-1',
        'name': 'Test Venue',
        'address': 'Test Address',
        'bio': 'Test Bio',
        'facilities': ['Parking', 123, true],
      };

      final venue = VenueModel.fromJson(json);
      expect(venue.facilities, ['Parking', '123', 'true']);
    });
  });
}
