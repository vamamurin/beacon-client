import 'package:beacon_client/domain/models/artifact_info.dart';
import 'package:beacon_client/domain/models/beacon_reading.dart';
import 'package:beacon_client/domain/models/floor_info.dart';

enum ProximityZone {
  outOfRange, // > 5 m
  near5m, // <= 5 m
  near3m, // <= 3 m
  near2m, // <= 2 m
}

class ProximityInfo {
  final BeaconReading reading;
  final double smoothedDistance;
  final ProximityZone zone;
  final ArtifactInfo? artifact;
  final FloorInfo? floor;

  const ProximityInfo({
    required this.reading,
    required this.smoothedDistance,
    required this.zone,
    this.artifact,
    this.floor,
  });
}
