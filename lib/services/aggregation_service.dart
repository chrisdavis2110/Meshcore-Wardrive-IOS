import '../models/models.dart';
import '../utils/geohash_utils.dart';

class AggregationService {
  /// Build indexes from samples and repeaters
  static AggregationResult buildIndexes(List<Sample> samples, List<Repeater> repeaters) {
    final Map<String, Coverage> hashToCoverage = {};
    final Map<String, Map<String, dynamic>> idToRepeaters = {};
    final List<Edge> edgeList = [];

    // Build repeaters map
    for (final repeater in repeaters) {
      idToRepeaters[repeater.id] = {
        'pos': repeater.position,
        'elevation': repeater.elevation,
        'repeater': repeater,
      };
    }

    // Aggregate samples into coverage areas
    for (final sample in samples) {
      final coverageHash = GeohashUtils.coverageKey(
        sample.position.latitude,
        sample.position.longitude,
      );

      // Get or create coverage
      if (!hashToCoverage.containsKey(coverageHash)) {
        final pos = GeohashUtils.posFromHash(coverageHash);
        hashToCoverage[coverageHash] = Coverage(
          id: coverageHash,
          position: pos,
        );
      }

      final coverage = hashToCoverage[coverageHash]!;

      // Update coverage stats based on ping success
      if (sample.pingSuccess == true) {
        coverage.received += 1; // Successful ping (observer heard us)
        
        // Track which repeater actually responded (from sample.path = nodeId)
        if (sample.path != null && sample.path!.isNotEmpty) {
          if (!coverage.repeaters.contains(sample.path!)) {
            coverage.repeaters.add(sample.path!);
          }
        }
      } else if (sample.pingSuccess == false) {
        coverage.lost += 1; // Failed ping (dead zone)
      }
      // If pingSuccess is null, it means no ping was attempted (just GPS tracking)
      
      if (sample.pingSuccess == true && 
          (coverage.lastReceived == null || sample.timestamp.isAfter(coverage.lastReceived!))) {
        coverage.lastReceived = sample.timestamp;
      }
      
      if (coverage.updated == null || 
          sample.timestamp.isAfter(coverage.updated!)) {
        coverage.updated = sample.timestamp;
      }
    }

    // Build edges from coverage to repeaters
    for (final coverage in hashToCoverage.values) {
      if (idToRepeaters.isNotEmpty) {
        final bestRepeaterId = GeohashUtils.getBestRepeater(
          coverage.position,
          idToRepeaters,
        );

        if (bestRepeaterId != null) {
          final repeaterData = idToRepeaters[bestRepeaterId];
          if (repeaterData != null) {
            edgeList.add(Edge(
              coverage: coverage,
              repeater: repeaterData['repeater'] as Repeater,
            ));
          }
        }
      }
    }

    // Calculate top repeaters by connection count
    final Map<String, int> repeaterConnections = {};
    for (final edge in edgeList) {
      final id = edge.repeater.id;
      repeaterConnections[id] = (repeaterConnections[id] ?? 0) + 1;
    }

    final topRepeaters = repeaterConnections.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    return AggregationResult(
      coverages: hashToCoverage.values.toList(),
      edges: edgeList,
      topRepeaters: topRepeaters.take(15).toList(),
      repeaters: repeaters,
    );
  }

  /// Get coverage color based on received count
  static int getCoverageColor(Coverage coverage, String colorMode) {
    if (colorMode == 'age') {
      if (coverage.lastReceived == null) return 0xFF808080;
      
      final age = GeohashUtils.ageInDays(coverage.lastReceived!);
      if (age < 1) return 0xFF00FF00; // Green - fresh
      if (age < 7) return 0xFF88FF00; // Yellow-green
      if (age < 30) return 0xFFFFFF00; // Yellow
      if (age < 90) return 0xFFFF8800; // Orange
      return 0xFFFF0000; // Red - old
    } else {
      // Default: coverage based on ping success rate
      final received = coverage.received; // Successful pings
      final lost = coverage.lost;         // Failed pings
      final total = received + lost;
      
      // No pings attempted here (just GPS tracking)
      if (total == 0) {
        return 0xFFCCCCCC; // Gray
      }
      
      // Calculate success rate
      final successRate = received / total;
      
      // Color based on success rate thresholds
      if (successRate >= 0.80) {
        return 0xFF00FF00; // Bright green - very reliable (80%+)
      } else if (successRate >= 0.50) {
        return 0xFF88FF00; // Yellow-green - usually works (50-80%)
      } else if (successRate >= 0.30) {
        return 0xFFFFFF00; // Yellow - spotty (30-50%)
      } else if (successRate >= 0.10) {
        return 0xFFFFAA00; // Orange - rarely works (10-30%)
      } else {
        return 0xFFFF0000; // Red - dead zone (<10%)
      }
    }
  }

  /// Get opacity based on coverage stats
  static double getCoverageOpacity(Coverage coverage) {
    final received = coverage.received;
    if (received >= 20) return 0.7;
    if (received >= 10) return 0.5;
    if (received >= 5) return 0.4;
    return 0.3;
  }
}

class AggregationResult {
  final List<Coverage> coverages;
  final List<Edge> edges;
  final List<MapEntry<String, int>> topRepeaters;
  final List<Repeater> repeaters;

  AggregationResult({
    required this.coverages,
    required this.edges,
    required this.topRepeaters,
    required this.repeaters,
  });
}
