class_name GuiLayoutSweepRegistry
extends RefCounted

## Exact characterization, never a layout acceptance waiver.
const SCHEMA_VERSION: int = 1


static func create(cases: Array[Dictionary], source_sha: String) -> Dictionary:
	var groups: Dictionary[String, Dictionary] = {}
	var failed_cases: int = 0
	for case: Dictionary in cases:
		var failures: Array[String] = _signatures(case)
		if failures.is_empty():
			continue
		failed_cases += 1
		var key: String = JSON.stringify(failures)
		if not groups.has(key):
			groups[key] = {"failures": failures, "inputs": []}
		groups[key].inputs.append(case.id)
	return {
		"schema_version": SCHEMA_VERSION,
		"scope": "Reference characterization only; recorded defects are not accepted behavior.",
		"source_sha": source_sha,
		"step": 80,
		"case_count": cases.size(),
		"failed_case_count": failed_cases,
		"case_matrix_sha256": _matrix_signature(cases),
		"known_failures": groups.values(),
	}


static func compare(cases: Array[Dictionary], registry: Dictionary) -> PackedStringArray:
	var failures := PackedStringArray()
	if registry.get("schema_version", 0) != SCHEMA_VERSION or registry.get("step", 0) != 80:
		failures.append("registry: unsupported schema or step")
		return failures
	var expected: Dictionary[String, Array] = {}
	for group: Dictionary in registry.get("known_failures", []):
		var signatures: Array = group.get("failures", [])
		if signatures.is_empty():
			failures.append("registry: empty failure group")
		for id: String in group.get("inputs", []):
			if expected.has(id):
				failures.append("registry: duplicate expected input %s" % id)
			expected[id] = signatures
	var seen: Dictionary[String, bool] = {}
	for case: Dictionary in cases:
		var id: String = case.id
		if seen.has(id):
			failures.append("registry: duplicate observed input %s" % id)
		seen[id] = true
		var actual: Array[String] = _signatures(case)
		var known: Array = expected.get(id, [])
		if actual != known:
			failures.append("characterization: %s expected %s, observed %s" % [id, known, actual])
		# Expected failures that disappear are deliberately rejected too.
		expected.erase(id)
	for id: String in expected:
		failures.append("registry: missing observed input %s" % id)
	if registry.get("case_count", -1) != cases.size():
		failures.append("registry: case count changed")
	if registry.get("case_matrix_sha256", "") != _matrix_signature(cases):
		failures.append("registry: ordered input matrix changed")
	return failures


static func _signatures(case: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for failure: String in case.failures:
		if failure not in result:
			result.append(failure)
	result.sort()
	return result


static func _matrix_signature(cases: Array[Dictionary]) -> String:
	var inputs: Array[Dictionary] = []
	for case: Dictionary in cases:
		(
			inputs
			. append(
				{
					"id": case.id,
					"scope": case.get("scope", ""),
					"input": case.get("input", {}),
					"observations": case.get("observations", {}),
				}
			)
		)
	return JSON.stringify(inputs).sha256_text()
