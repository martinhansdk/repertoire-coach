/// Helpers for fetching *complete* result sets from PostgREST.
///
/// Two silent truncation hazards exist when querying Supabase:
///
///  1. **Row cap**: PostgREST caps every response at `max-rows` rows
///     (Supabase default: 1000) and reports no error — a plain select simply
///     returns the first 1000 rows. For sync, a truncated `getAllRemote`
///     means the tail of the data never reaches the device.
///  2. **URL length**: `.inFilter(column, ids)` encodes every id into the
///     request URL. A few hundred UUIDs exceed typical gateway URL limits
///     and the request fails outright.
///
/// [fetchAllRows] solves (1) by paging with `.range()` until a short page is
/// returned. [fetchAllRowsChunkedIn] solves (2) by splitting an id list into
/// chunks and merging the results; combine it with [fetchAllRows] so each
/// chunk is itself fully paged.
///
/// **Callers must include a total (unique) `.order()`** in the query they
/// build — without a deterministic order, rows can repeat or vanish across
/// page boundaries when the table changes between requests.
library;

/// Fetches one page of rows for the inclusive range [from]..[to].
///
/// Implementations are expected to be of the form:
/// `(from, to) => supabase.from(...).select(...).order(...).range(from, to)`.
typedef PageFetcher = Future<List<dynamic>> Function(int from, int to);

/// Fetches every row of a query by paging past PostgREST's response-row cap.
///
/// [pageSize] must not exceed the server's `max-rows` setting (Supabase
/// default 1000): the loop stops at the first page shorter than [pageSize],
/// so a server cap below [pageSize] would end the loop early and truncate.
Future<List<Map<String, dynamic>>> fetchAllRows(
  PageFetcher fetchPage, {
  int pageSize = 1000,
}) async {
  assert(pageSize > 0);
  final rows = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final page = await fetchPage(from, from + pageSize - 1);
    rows.addAll(page.cast<Map<String, dynamic>>());
    if (page.length < pageSize) {
      return rows;
    }
    from += pageSize;
  }
}

/// Runs [fetchChunk] over [values] in slices of [chunkSize] and merges the
/// results, keeping `IN (...)` URLs bounded regardless of how many ids the
/// membership chain produces.
///
/// [chunkSize] of 100 keeps a UUID `in` filter around 4 KB of URL — safely
/// under common 8-16 KB gateway limits.
Future<List<Map<String, dynamic>>> fetchAllRowsChunkedIn(
  List<String> values,
  Future<List<Map<String, dynamic>>> Function(List<String> chunk) fetchChunk, {
  int chunkSize = 100,
}) async {
  assert(chunkSize > 0);
  final rows = <Map<String, dynamic>>[];
  for (var i = 0; i < values.length; i += chunkSize) {
    final end = (i + chunkSize) > values.length ? values.length : i + chunkSize;
    rows.addAll(await fetchChunk(values.sublist(i, end)));
  }
  return rows;
}
