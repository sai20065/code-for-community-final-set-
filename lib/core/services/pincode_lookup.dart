/// Minimal static pincode → area-name lookup so Location Setup can show an
/// instant "resolved area name" without a network round-trip for common
/// pincodes. Replace/extend with a full CSV-backed dataset before launch;
/// unknown pincodes fall back to [LocationService]'s geocoding lookup.
class PincodeLookup {
  PincodeLookup._();

  static const Map<String, String> _table = {
    '110001': 'Connaught Place, New Delhi',
    '400001': 'Fort, Mumbai',
    '560001': 'Bengaluru GPO, Bengaluru',
    '600001': 'Parrys, Chennai',
    '700001': 'BBD Bagh, Kolkata',
    '500001': 'Hyderabad GPO, Hyderabad',
    '380001': 'Lal Darwaja, Ahmedabad',
    '411001': 'Pune GPO, Pune',
  };

  static String? areaFor(String pincode) => _table[pincode];
}
