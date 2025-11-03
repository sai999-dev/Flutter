import 'dart:convert';
import 'package:http/http.dart' as http;

class ZipInfo {
  final String zipcode;
  final String? city;
  final String? state;

  const ZipInfo({required this.zipcode, this.city, this.state});
}

class ZipcodeLookupService {
  static Future<ZipInfo> lookup(String zip) async {
    final z = zip.trim();
    if (z.length != 5 || int.tryParse(z) == null) {
      return ZipInfo(zipcode: z);
    }
    try {
      final uri = Uri.parse('https://api.zippopotam.us/us/$z');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final places = (data['places'] as List?) ?? const [];
        if (places.isNotEmpty) {
          final p = places.first as Map<String, dynamic>;
          final city = p['place name']?.toString();
          final state = p['state abbreviation']?.toString();
          return ZipInfo(zipcode: z, city: city, state: state);
        }
      }
    } catch (_) {
      // ignore network errors; fallback to zip only
    }
    return ZipInfo(zipcode: z);
  }
}
