import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🗺️ **USA Zipcode Service**
/// 
/// Uses FREE Zippopotam.us API to get city/state from zipcode
/// No API key required, unlimited requests
/// 
/// Example: 75033 → Frisco, Texas
class ZipcodeService {
  
  /// Get city and state from zipcode
  /// Returns: {'city': 'Frisco', 'state': 'Texas', 'state_abbr': 'TX'}
  static Future<Map<String, String>?> getCityFromZipcode(String zipcode) async {
    try {
      // Clean zipcode
      final cleanZip = zipcode.trim();
      if (cleanZip.length != 5) return null;
      
      // Call FREE Zippopotam API
      final response = await http.get(
        Uri.parse('http://api.zippopotam.us/us/$cleanZip'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse response
        final state = data['places'][0]['state'];
        final stateAbbr = data['places'][0]['state abbreviation'];
        final city = data['places'][0]['place name'];
        
        return {
          'city': city,
          'state': state,
          'state_abbr': stateAbbr,
        };
      }
      
      return null;
    } catch (e) {
      print('❌ Zipcode lookup failed: $e');
      return null;
    }
  }
  
  /// Get ALL zipcodes for a city
  /// This would require a different API or local database
  static Future<List<String>> getZipcodesForCity(String city, String state) async {
    // TODO: Implement with local database or paid API
    // For now, return empty list
    return [];
  }
  
  /// Validate if zipcode is valid USA format
  static bool isValidZipcode(String zipcode) {
    final cleaned = zipcode.trim();
    if (cleaned.length != 5) return false;
    return int.tryParse(cleaned) != null;
  }
}

/// 🗺️ **USA States List**
class USAStates {
  static const Map<String, String> states = {
    'AL': 'Alabama',
    'AK': 'Alaska',
    'AZ': 'Arizona',
    'AR': 'Arkansas',
    'CA': 'California',
    'CO': 'Colorado',
    'CT': 'Connecticut',
    'DE': 'Delaware',
    'FL': 'Florida',
    'GA': 'Georgia',
    'HI': 'Hawaii',
    'ID': 'Idaho',
    'IL': 'Illinois',
    'IN': 'Indiana',
    'IA': 'Iowa',
    'KS': 'Kansas',
    'KY': 'Kentucky',
    'LA': 'Louisiana',
    'ME': 'Maine',
    'MD': 'Maryland',
    'MA': 'Massachusetts',
    'MI': 'Michigan',
    'MN': 'Minnesota',
    'MS': 'Mississippi',
    'MO': 'Missouri',
    'MT': 'Montana',
    'NE': 'Nebraska',
    'NV': 'Nevada',
    'NH': 'New Hampshire',
    'NJ': 'New Jersey',
    'NM': 'New Mexico',
    'NY': 'New York',
    'NC': 'North Carolina',
    'ND': 'North Dakota',
    'OH': 'Ohio',
    'OK': 'Oklahoma',
    'OR': 'Oregon',
    'PA': 'Pennsylvania',
    'RI': 'Rhode Island',
    'SC': 'South Carolina',
    'SD': 'South Dakota',
    'TN': 'Tennessee',
    'TX': 'Texas',
    'UT': 'Utah',
    'VT': 'Vermont',
    'VA': 'Virginia',
    'WA': 'Washington',
    'WV': 'West Virginia',
    'WI': 'Wisconsin',
    'WY': 'Wyoming',
    'DC': 'District of Columbia',
  };
  
  /// Get full state name from abbreviation
  static String? getStateName(String abbr) {
    return states[abbr.toUpperCase()];
  }
  
  /// Get state abbreviation from full name
  static String? getStateAbbr(String name) {
    for (var entry in states.entries) {
      if (entry.value.toLowerCase() == name.toLowerCase()) {
        return entry.key;
      }
    }
    return null;
  }
  
  /// Get all states as list
  static List<Map<String, String>> getAllStates() {
    return states.entries.map((e) => {
      'abbr': e.key,
      'name': e.value,
    }).toList();
  }
}

