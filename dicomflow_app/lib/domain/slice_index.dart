/// Map video timeline ↔ 1-based slice index using the encode fps.
int sliceFromPosition({
  required Duration position,
  required int fps,
  required int total,
}) {
  if (total <= 0 || fps <= 0) return 0;
  final index = (position.inMicroseconds / 1000000.0 * fps).floor() + 1;
  if (index < 1) return 1;
  if (index > total) return total;
  return index;
}

Duration positionForSlice({required int slice, required int fps}) {
  if (fps <= 0 || slice <= 0) return Duration.zero;
  final seconds = (slice - 1) / fps;
  return Duration(microseconds: (seconds * 1000000).round());
}
