import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart';

/// Map Service for Oroquieta City
/// Handles location services, geocoding, and map bounds restriction
class MapService {
  // Oroquieta City center coordinates
  static const double oroquietaLatitude = 8.4853;
  static const double oroquietaLongitude = 123.8044;
  
  // Oroquieta City approximate bounds (restrict map to this area)
  static const double minLatitude = 8.4000;
  static const double maxLatitude = 8.6000;
  static const double minLongitude = 123.7000;
  static const double maxLongitude = 123.9000;
  
  // Default zoom level for Oroquieta City
  static const double defaultZoom = 15.0; // Zoom level 15 for barangay view

  /// Check if location services are enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  static Future<LocationPermission> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return permission;
  }

  /// Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      await requestPermission();
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  /// Check if coordinates are within Oroquieta City bounds
  static bool isWithinOroquietaBounds(double latitude, double longitude) {
    return latitude >= minLatitude &&
        latitude <= maxLatitude &&
        longitude >= minLongitude &&
        longitude <= maxLongitude;
  }

  /// Clamp coordinates to Oroquieta City bounds
  static LatLng clampToOroquietaBounds(double latitude, double longitude) {
    double clampedLat = latitude.clamp(minLatitude, maxLatitude);
    double clampedLng = longitude.clamp(minLongitude, maxLongitude);
    return LatLng(clampedLat, clampedLng);
  }

  /// Convert address to coordinates (geocoding)
  static Future<LatLng?> addressToCoordinates(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) {
        final lat = locations.first.latitude;
        final lng = locations.first.longitude;
        
        // Check if within bounds, if not, clamp it
        if (isWithinOroquietaBounds(lat, lng)) {
          return LatLng(lat, lng);
        } else {
          // Clamp to bounds
          return clampToOroquietaBounds(lat, lng);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error converting address to coordinates: $e');
      return null;
    }
  }

  /// Convert coordinates to address (reverse geocoding)
  static Future<String?> coordinatesToAddress(double latitude, double longitude) async {
    try {
      // Clamp coordinates to bounds first
      final clamped = clampToOroquietaBounds(latitude, longitude);
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        clamped.latitude,
        clamped.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        // Build address string with null safety
        List<String> addressParts = [];
        
        try {
          final street = place.street;
          if (street != null && street.isNotEmpty) {
            addressParts.add(street);
          }
        } catch (e) {
          debugPrint('Error accessing street: $e');
        }
        
        try {
          final subLocality = place.subLocality;
          if (subLocality != null && subLocality.isNotEmpty) {
            addressParts.add(subLocality);
          }
        } catch (e) {
          debugPrint('Error accessing subLocality: $e');
        }
        
        try {
          final locality = place.locality;
          if (locality != null && locality.isNotEmpty) {
            addressParts.add(locality);
          }
        } catch (e) {
          debugPrint('Error accessing locality: $e');
        }
        
        try {
          final administrativeArea = place.administrativeArea;
          if (administrativeArea != null && administrativeArea.isNotEmpty) {
            addressParts.add(administrativeArea);
          }
        } catch (e) {
          debugPrint('Error accessing administrativeArea: $e');
        }
        
        try {
          final postalCode = place.postalCode;
          if (postalCode != null && postalCode.isNotEmpty) {
            addressParts.add(postalCode);
          }
        } catch (e) {
          debugPrint('Error accessing postalCode: $e');
        }
        
        return addressParts.isNotEmpty ? addressParts.join(', ') : 'Oroquieta City';
      }
      return 'Oroquieta City';
    } catch (e) {
      debugPrint('Error converting coordinates to address: $e');
      // Return a default address instead of null
      return 'Oroquieta City';
    }
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  /// Get formatted address from coordinates (detailed)
  static Future<Map<String, String>> getDetailedAddress(
    double latitude,
    double longitude,
  ) async {
    try {
      final clamped = clampToOroquietaBounds(latitude, longitude);
      
      List<Placemark> placemarks = await placemarkFromCoordinates(
        clamped.latitude,
        clamped.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        
        // Safely extract address components with null checks
        String street = '';
        String subLocality = '';
        String locality = 'Oroquieta City';
        String administrativeArea = '';
        String postalCode = '';
        String country = 'Philippines';
        
        try {
          street = place.street ?? '';
        } catch (e) {
          debugPrint('Error accessing street in getDetailedAddress: $e');
        }
        
        try {
          subLocality = place.subLocality ?? '';
        } catch (e) {
          debugPrint('Error accessing subLocality in getDetailedAddress: $e');
        }
        
        try {
          locality = place.locality ?? 'Oroquieta City';
        } catch (e) {
          debugPrint('Error accessing locality in getDetailedAddress: $e');
        }
        
        try {
          administrativeArea = place.administrativeArea ?? '';
        } catch (e) {
          debugPrint('Error accessing administrativeArea in getDetailedAddress: $e');
        }
        
        try {
          postalCode = place.postalCode ?? '';
        } catch (e) {
          debugPrint('Error accessing postalCode in getDetailedAddress: $e');
        }
        
        try {
          country = place.country ?? 'Philippines';
        } catch (e) {
          debugPrint('Error accessing country in getDetailedAddress: $e');
        }
        
        return {
          'street': street,
          'subLocality': subLocality,
          'locality': locality,
          'administrativeArea': administrativeArea,
          'postalCode': postalCode,
          'country': country,
          'fullAddress': _buildFullAddressSafe(place),
        };
      }
      
      return {
        'locality': 'Oroquieta City',
        'country': 'Philippines',
        'fullAddress': 'Oroquieta City, Philippines',
      };
    } catch (e) {
      debugPrint('Error getting detailed address: $e');
      return {
        'locality': 'Oroquieta City',
        'country': 'Philippines',
        'fullAddress': 'Oroquieta City, Philippines',
      };
    }
  }

  static String _buildFullAddressSafe(Placemark place) {
    List<String> parts = [];
    
    try {
      final street = place.street;
      if (street != null && street.isNotEmpty) {
        parts.add(street);
      }
    } catch (e) {
      debugPrint('Error accessing street in _buildFullAddressSafe: $e');
    }
    
    try {
      final subLocality = place.subLocality;
      if (subLocality != null && subLocality.isNotEmpty) {
        parts.add(subLocality);
      }
    } catch (e) {
      debugPrint('Error accessing subLocality in _buildFullAddressSafe: $e');
    }
    
    try {
      final locality = place.locality;
      if (locality != null && locality.isNotEmpty) {
        parts.add(locality);
      } else {
        parts.add('Oroquieta City');
      }
    } catch (e) {
      debugPrint('Error accessing locality in _buildFullAddressSafe: $e');
      parts.add('Oroquieta City');
    }
    
    try {
      final administrativeArea = place.administrativeArea;
      if (administrativeArea != null && administrativeArea.isNotEmpty) {
        parts.add(administrativeArea);
      }
    } catch (e) {
      debugPrint('Error accessing administrativeArea in _buildFullAddressSafe: $e');
    }
    
    try {
      final postalCode = place.postalCode;
      if (postalCode != null && postalCode.isNotEmpty) {
        parts.add(postalCode);
      }
    } catch (e) {
      debugPrint('Error accessing postalCode in _buildFullAddressSafe: $e');
    }
    
    try {
      final country = place.country;
      if (country != null && country.isNotEmpty) {
        parts.add(country);
      } else {
        parts.add('Philippines');
      }
    } catch (e) {
      debugPrint('Error accessing country in _buildFullAddressSafe: $e');
      parts.add('Philippines');
    }
    
    return parts.isNotEmpty ? parts.join(', ') : 'Oroquieta City, Philippines';
  }

}

