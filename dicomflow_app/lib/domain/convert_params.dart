enum OutputFormat { mp4, gif }

enum Quality { low, medium, high }

class ConvertParams {
  const ConvertParams({
    this.format = OutputFormat.mp4,
    this.quality = Quality.high,
    this.merge = false,
    this.fps = 10,
  });

  final OutputFormat format;
  final Quality quality;
  final bool merge;
  final int fps;
}

class QualityProfile {
  const QualityProfile({
    required this.scale,
    required this.maxSide,
    required this.mp4Crf,
    required this.gifMaxSide,
    required this.gifMaxFrames,
    required this.gifColors,
    required this.fpsCap,
  });

  final double scale;
  final int? maxSide;
  final int mp4Crf;
  final int gifMaxSide;
  final int gifMaxFrames;
  final int gifColors;
  final int? fpsCap;
}

const qualityProfiles = <Quality, QualityProfile>{
  Quality.low: QualityProfile(
    scale: 0.5,
    maxSide: null,
    mp4Crf: 28,
    gifMaxSide: 256,
    gifMaxFrames: 80,
    gifColors: 64,
    fpsCap: 8,
  ),
  Quality.medium: QualityProfile(
    scale: 1.0,
    maxSide: 1024,
    mp4Crf: 23,
    gifMaxSide: 480,
    gifMaxFrames: 120,
    gifColors: 128,
    fpsCap: null,
  ),
  Quality.high: QualityProfile(
    scale: 1.0,
    maxSide: null,
    mp4Crf: 18,
    gifMaxSide: 640,
    gifMaxFrames: 150,
    gifColors: 256,
    fpsCap: null,
  ),
};

QualityProfile profileFor(Quality quality) => qualityProfiles[quality]!;
