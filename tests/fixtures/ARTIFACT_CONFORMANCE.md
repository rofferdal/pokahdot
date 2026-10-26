# Shared artifact conformance corpus

`artifact_conformance_v1.json` is a synthetic, completed two-seat, two-tournament
schema-4 report and its candidate generation. It is regression input, not
promotion evidence or a published performance measurement.

Both Godot report validation/CLI inspection and Python fitness/confirmation
ingestion consume the same cases. Each case deep-copies `base_report`, applies
`patches` in order, and expects `valid`. A patch replaces the leaf selected by
its `path` array; string elements select object keys and integers select array
indexes. Cases changing the manifest include precomputed checksum and roster
patches so a semantic failure is not masked by stale identity metadata.
Known integer fields accept exactly whole finite JSON values (`2` or `2.0`),
while booleans and fractional values remain invalid. Manifest/roster identities
use canonical typed integer values; report evidence checksums use unchanged
source bytes. Continuous metrics are not coerced.

The corpus covers supported strategy/legacy parameter schemas, nested types,
lossless signed nonzero JSON seeds (±9,007,199,254,740,991) and range arithmetic,
duplicate identities, terminal chip
ownership/conservation, derived metrics, and estimator support. Valid sparse
reports remain exploratory; selection still enforces its parent-count policy.
Python tests additionally exercise successful selection from an expanded
candidate catalog and public confirmation without granting promotion to these
tiny samples. Historical schema-2 fixtures remain unchanged.
