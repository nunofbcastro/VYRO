/// Separate whole dishes in one photo, from the region classifier's 4×4 grid.
///
/// Heuristic, not measured on real photos: two plates of the same dish should
/// show as two separate blobs of matching cells with a gap between them. One
/// plate, or two touching blobs, stays one dish. The result is only a proposal
/// the user confirms in the review.
library;

/// Row-major 4×4 grid (16 cells) of the region classifier.
const int dishGridSide = 4;

/// Smallest blob, in cells, that counts as a plate. Real-photo eval
/// (19 Wikimedia Commons photos, 14 single-plate francesinha photos): blobs of 2
/// cells produced one false "2 plates"; a plate covers at least 3 cells.
const int minBlobCells = 3;

/// Counts the 4-connected blobs of marked cells that have at least
/// [minBlobCells] cells. Returns that count (2 or 3) when it is exactly 2 or 3
/// blobs; otherwise 1. Smaller blobs (1 or 2 cells) are noise and are ignored.
/// Blobs that touch (share an edge) are one blob, so they count once.
int separatePlateCount(List<List<bool>> marked, {int maxCount = 3}) {
  final rows = marked.length;
  if (rows == 0) return 1;
  final cols = marked.first.length;
  final seen = [for (var r = 0; r < rows; r++) List.filled(cols, false)];
  var blobs = 0;
  for (var r = 0; r < rows; r++) {
    for (var c = 0; c < cols; c++) {
      if (!marked[r][c] || seen[r][c]) continue;
      var size = 0;
      final stack = <(int, int)>[(r, c)];
      seen[r][c] = true;
      while (stack.isNotEmpty) {
        final (y, x) = stack.removeLast();
        size++;
        for (final (dy, dx) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final ny = y + dy;
          final nx = x + dx;
          if (ny < 0 || nx < 0 || ny >= rows || nx >= cols) continue;
          if (!marked[ny][nx] || seen[ny][nx]) continue;
          seen[ny][nx] = true;
          stack.add((ny, nx));
        }
      }
      if (size >= minBlobCells) blobs++;
    }
  }
  return blobs >= 2 && blobs <= maxCount ? blobs : 1;
}

/// Marks the cells where the candidate dish is the top food of that cell.
///
/// [cells] is row-major, each entry the ranked `(label, probability)` list of
/// one region, with [backgroundLabel] first. A cell is marked when one of
/// [foodLabels] (the dish's vision labels) is its most probable food label,
/// at least [minProbability], and the background does not win the cell.
List<List<bool>> markCellsForFood({
  required List<List<(int, double)>> cells,
  required Map<int, String> labels,
  required Set<String> foodLabels,
  required int backgroundLabel,
  required double minProbability,
  int side = dishGridSide,
}) {
  final grid = [for (var r = 0; r < side; r++) List.filled(side, false)];
  final count = cells.length < side * side ? cells.length : side * side;
  for (var i = 0; i < count; i++) {
    var background = 0.0;
    (int, double)? top;
    for (final (k, p) in cells[i]) {
      if (k == backgroundLabel) {
        background = p;
      } else if (top == null || p > top.$2) {
        top = (k, p);
      }
    }
    if (top == null) continue;
    final (k, p) = top;
    if (p < minProbability || background > p) continue;
    final label = labels[k];
    if (label == null || !foodLabels.contains(label)) continue;
    grid[i ~/ side][i % side] = true;
  }
  return grid;
}
