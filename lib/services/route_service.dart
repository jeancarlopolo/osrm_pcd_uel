import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:osrm_pcd_uel/services/polyline_utility.dart';

Future<List<Map<String, dynamic>>> getSegmentsFromCoordinates({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
}) async {
  final response = await http.post(
      Uri.parse(
          'https://api.openrouteservice.org/v2/directions/foot-walking/json'),
      headers: {
        'Authorization':
            '5b3ce3597851110001cf62484942e00b12fb4c938844d27489afdd96',
        'Content-Type': 'application/json'
      },
      body: '''{
          "coordinates": [
            [$lon1,$lat1],
            [$lon2,$lat2]
          ],
          "geometry_simplify": "false",
          "instructions": "false",
          "geometry": "true"
        }''');
  final data = json.decode(response.body);
  final segments = getSegmentsFromPolyline(data['routes'][0]['geometry']);
  final distanceFirstPoint = haversineDistance(lat1, lon1,
      segments.first['start_point'].lat, segments.first['start_point'].lon);
  if (distanceFirstPoint > 10) {
    segments.insert(0, {
      "start_point": (lat1, lon1),
      "end_point": segments.first['start_point'],
      "distance_meters": distanceFirstPoint,
      "bearing_degrees": calculateBearing(lat1, lon1,
          segments.first['start_point'].lat, segments.first['start_point'].lon)
    });
  }
  return segments;
}
