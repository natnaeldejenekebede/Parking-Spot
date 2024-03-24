import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:frontend/auth/data_provider/user_data_provider.dart';
import 'package:frontend/auth/repository/auth_repository.dart';
import 'package:frontend/reservation/models/reservation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:jwt_decoder/jwt_decoder.dart';

class ReservationDataProvider {
  final baseUrl = 'http://localhost:3000/reservations';
  final FlutterSecureStorage storage = new FlutterSecureStorage();
  final AuthRepository authRepository = AuthRepository(UserDataProvider());

  Future hasAvailableSpots(compoundId, startTime, endTime) async {
    String? token = await storage.read(key: 'token');

    int userId = JwtDecoder.decode(token!)['sub'];
    final http.Response response =
        await http.post(Uri.parse('$baseUrl/$compoundId'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
            },
            body: jsonEncode(<String, dynamic>{
              'user_id': userId,
              'start_time': startTime,
              'end_time': endTime,
            }));
    if (response.statusCode == 201) {
      final value = json.decode(response.body)['parkingSpots'];
      return value;
    } else {
      throw Exception('Can not get available spots data');
    }
  }

  Future calculatePrice(compoundId, startTime, endTime) async {
    final response = await http
        .get(Uri.parse('http://localhost:3000/parking-compounds/$compoundId'));

    if (response.statusCode == 200) {
      final price = double.parse(jsonDecode(response.body)['price']);
      DateTime time1 = DateTime.parse(startTime);
      DateTime time2 = DateTime.parse(endTime);

      Duration timeDifference = time2.difference(time1);

      double hoursDifference = timeDifference.inMinutes / 60;

      double totalPrice = hoursDifference * price;

      return totalPrice;
    } else {
      throw Exception(
          'Can not find compouond data of compoupnd with id: $compoundId');
    }
  }

  Future<List<dynamic>> getReservationsForUser() async {
    String? token = await storage.read(key: 'token');
    int user_id = JwtDecoder.decode(token!)['sub'];

    final response = await http.get(
        Uri.parse('http://localhost:3000/reservations/$user_id'),
        headers: <String, String>{'Authorization': 'Bearer $token'});
    print(response.statusCode);
    print(response.body);

    if (response.statusCode == 200) {
      final jsonData = jsonDecode(response.body);
      final reservations = jsonData
          .map((reservation) => Reservation.fromJson(reservation))
          .toList();
      return reservations;
    } else {
      throw Exception('Failed to fetch reservations.');
    }
  }

  Future<Reservation> createReservation(String startTime, String endTime,
      double price, String plateNo, int spotId) async {
    String? token = await storage.read(key: 'token');
    if (token != null) {
      int user_id = JwtDecoder.decode(token)['sub'];

      final response = await http.post(
        Uri.parse('http://localhost:3000/reservations/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(<String, dynamic>{
          'user_id': user_id,
          'spot_id': spotId,
          'start_time': startTime,
          'end_time': endTime,
          // 'plateNo': plateNo,
          // 'totalPrice': price
        }),
      );
      if (response.statusCode == 201) {
        return Reservation.fromJson(jsonDecode(response.body));
      } else {
        throw Exception(
            'Failed to create reservation. Status code: ${response.statusCode}');
      }
    } else {
      throw Exception('Failed to create reservation)');
    }
  }

  Future<void> updateReservation(Reservation reservation) async {
    final url = Uri.parse('$baseUrl/reservations/${reservation.id}');

    final response = await http.put(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode(reservation),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to update reservation. Status code: ${response.statusCode}');
    }
  }

  Future<void> deleteReservation(int reservationId) async {
    String? token = await storage.read(key: 'token');

    final response = await http.delete(
        Uri.parse('http://localhost:3000/reservations/$reservationId'),
        headers: <String, String>{'Authorization': 'Bearer $token'});

    print(response.statusCode);
    print(response.body);
    if (!(response.statusCode == 200 || response.statusCode == 204)) {
      throw Exception('Failed to delete compound');
    }
  }

  Future<List<Reservation>> getAllReservations() async {
    final url = Uri.parse('$baseUrl/reservations');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final jsonData = json.decode(response.body) as List<dynamic>;
      final reservations = jsonData
          .map((reservation) => Reservation.fromJson(reservation))
          .toList();

      return reservations;
    } else {
      throw Exception(
          'Failed to fetch all reservations. Status code: ${response.statusCode}');
    }
  }
}
