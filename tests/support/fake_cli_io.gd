class_name FakeCliIO
extends CliIO

## Deterministic CLI I/O for startup-prompt tests.

var writes: Array[String] = []
var _queued_inputs: Array[CliInputLine] = []


func queue_line(text: String) -> FakeCliIO:
	_queued_inputs.append(CliInputLine.new(text))
	return self


func queue_blank_line() -> FakeCliIO:
	return queue_line("")


func queue_eof() -> FakeCliIO:
	_queued_inputs.append(CliInputLine.eof())
	return self


func read_line() -> CliInputLine:
	if _queued_inputs.is_empty():
		return CliInputLine.eof()
	return _queued_inputs.pop_front()


func write_text(text: String) -> void:
	writes.append(text)


func write_line(text: String = "") -> void:
	writes.append(text)


func contains_write(text: String) -> bool:
	return text in writes


func count_writes_containing(text: String) -> int:
	var count: int = 0
	for write: String in writes:
		if text in write:
			count += 1
	return count
