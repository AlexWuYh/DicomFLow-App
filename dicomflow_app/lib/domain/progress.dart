class ProgressEvent {
  const ProgressEvent({
    required this.phase,
    required this.percent,
    this.message = '',
    this.seriesIndex,
    this.seriesTotal,
    this.frameIndex,
    this.frameTotal,
  });

  final String phase;
  final int percent;
  final String message;
  final int? seriesIndex;
  final int? seriesTotal;
  final int? frameIndex;
  final int? frameTotal;
}

typedef ProgressCallback = void Function(ProgressEvent event);
