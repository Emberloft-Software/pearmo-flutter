/// Broad regions used for `region_name`. Kept deliberately coarse (province
/// level, not city/town) — see the brainstorm doc's location-privacy notes:
/// matches are shown a general area, never a precise distance or location.
class SriLankaRegions {
  SriLankaRegions._();

  static const List<String> provinces = [
    'Western Province',
    'Central Province',
    'Southern Province',
    'Northern Province',
    'Eastern Province',
    'North Western Province',
    'North Central Province',
    'Uva Province',
    'Sabaragamuwa Province',
  ];
}
