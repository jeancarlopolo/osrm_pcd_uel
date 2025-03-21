import 'dart:math';

// Função para decodificar a polyline
List<({double lat, double lon})> decodePolyline(String encoded) {
  List<({double lat, double lon})> coordinates = [];
  int index = 0;
  int lat = 0;
  int lon = 0;

  while (index < encoded.length) {
    int shift = 0;
    int result = 0;

    while (true) {
      int byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }

    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    shift = 0;
    result = 0;

    while (true) {
      int byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }

    int dlon = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lon += dlon;

    coordinates.add((lat: lat / 1e5, lon: lon / 1e5));
  }

  return coordinates;
}

// Função para calcular a distância entre dois pontos (em metros)
double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // raio da Terra em metros
  double phi1 = radians(lat1);
  double phi2 = radians(lat2);
  double deltaPhi = radians(lat2 - lat1);
  double deltaLambda = radians(lon2 - lon1);

  double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) + cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
  double c = 2 * asin(sqrt(a));

  return R * c;
}

// Função para calcular o ângulo entre dois pontos
double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
  double phi1 = radians(lat1);
  double phi2 = radians(lat2);
  double deltaLambda = radians(lon2 - lon1);

  double y = sin(deltaLambda) * cos(phi2);
  double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);

  double theta = atan2(y, x);
  double bearing = (degrees(theta) + 360) % 360;
  return bearing;
}

double radians(double degrees) {
  return degrees * pi / 180;
}

double degrees(double radians) {
  return radians * 180 / pi;
}

List<Map<String, dynamic>> getSegmentsFromPolyline(String polylineStr) {
  // Decodificar polyline
  List<({double lat, double lon})> coordinates = decodePolyline(polylineStr);

  // Defina os limiares
  double minBearingChange = 15.0; // em graus

  // Lista para armazenar os resultados
  List<Map<String, dynamic>> segments = [];

  // Variáveis para acumular distância e calcular ângulo médio
  double? previousBearing;
  double accumulatedDistance = 0.0;
  double weightedBearingSum = 0.0;
  ({double lat, double lon}) startPoint = coordinates[0];

  // Calcular tamanho e ângulo de cada segmento
  for (int i = 0; i < coordinates.length - 1; i++) {
    double lat1 = coordinates[i].lat;
    double lon1 = coordinates[i].lon;
    double lat2 = coordinates[i + 1].lat;
    double lon2 = coordinates[i + 1].lon;

    // Distância entre os dois pontos
    double distance = haversineDistance(lat1, lon1, lat2, lon2);

    // Ângulo entre os dois pontos
    double bearing = calculateBearing(lat1, lon1, lat2, lon2);

    // Verifique se a distância e a mudança de ângulo são significativas
    if (previousBearing == null ||
        (bearing - previousBearing).abs() < minBearingChange) {
      // Acumula distância e calcula soma ponderada do ângulo
      accumulatedDistance += distance;
      weightedBearingSum += bearing * distance;
    } else {
      // Finaliza o segmento anterior
      segments.add({
        "start_point": startPoint,
        "end_point": (lat: lat1, lon: lon1),
        "distance_meters": accumulatedDistance,
        "bearing_degrees": weightedBearingSum / accumulatedDistance
      });

      // Reseta as variáveis para o próximo segmento
      startPoint = (lat: lat1, lon: lon1);
      accumulatedDistance = distance;
      weightedBearingSum = bearing * distance;
    }

    previousBearing = bearing;
  }

  // Adiciona o último segmento acumulado
  if (accumulatedDistance > 0) {
    segments.add({
      "start_point": startPoint,
      "end_point": coordinates.last,
      "distance_meters": accumulatedDistance,
      "bearing_degrees": weightedBearingSum / accumulatedDistance
    });
  }

  return segments;
}

// List<({double lat, double lon})> encodeMap(List<Map<String, dynamic>> map) {
//   List<({double lat, double lon})> list = [];
//   for (var coordinate in map) {
//     list.add((
//       lat: (coordinate['start_point'] as ({double lat, double lon})).lat,
//       lon: (coordinate['start_point'] as ({double lat, double lon})).lon
//     ));
//   }
//   list.add((
//     lat: (map.last['end_point'] as ({double lat, double lon})).lat,
//     lon: (map.last['end_point'] as ({double lat, double lon})).lon
//   ));
//   return list;
// }

// String encodePolyline(List<({double lat, double lon})> coordinates) {
//   int lastLat = 0;
//   int lastLon = 0;
//   StringBuffer result = StringBuffer();

//   for (var point in coordinates) {
//     int lat = (point.lat * 1e5).round();
//     int lon = (point.lon * 1e5).round();

//     int dLat = lat - lastLat;
//     int dLon = lon - lastLon;

//     result.write(_encodeValue(dLat));
//     result.write(_encodeValue(dLon));

//     lastLat = lat;
//     lastLon = lon;
//   }

//   return result.toString();
// }

// String _encodeValue(int value) {
//   value = value < 0 ? ~(value << 1) : (value << 1);
//   StringBuffer encoded = StringBuffer();

//   while (value >= 0x20) {
//     encoded.writeCharCode((0x20 | (value & 0x1f)) + 63);
//     value >>= 5;
//   }
//   encoded.writeCharCode(value + 63);

//   return encoded.toString();
// }

// void main() {
//   final segments = getSegmentsFromPolyline(
//       'tzjmCfgpwH?CFkEEA@aA@K@{@?C@]DmC@e@DoC@W?OFIDqB@m@@w@BiAMU@e@@}@@WBuAHgFJqGq@_@WU@s@{@AAe@@i@?C');
//   for (var segment in segments) {
//     print(segment);
//   }
//   print(encodePolyline(encodeMap(segments)));
// }
