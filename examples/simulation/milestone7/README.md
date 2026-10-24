# Milestone 7 Curated-Roster Export Smoke Artifact

`curated_roster_manifest.json` is a schema-2 export of the active
`PlayableBotRoster` created by `export-roster-manifest`.

- Schema version: `2`
- Batch ID: `milestone7_curated_roster_smoke`
- SHA-256 checksum: `952d6723f103ec40c71ee005c9e66d4c887fb5e19f8d0f9cc3f76b92f04b844f`
- Seed start: `71001`
- Tournament count: `800`

It is a smoke input, not promotion evidence. Its profile and parameter
Resources were deep-copied during generation; it retains no live reference to
the playable catalog. Verify it with:

```bash
godot --headless --path . --script res://scripts/simulation/simulation_cli_app.gd -- \
  validate --config examples/simulation/milestone7/curated_roster_manifest.json
```
