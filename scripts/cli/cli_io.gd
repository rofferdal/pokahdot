@abstract class_name CliIO
extends RefCounted

## Injectable text I/O boundary for the headless adapter.

@abstract func read_line() -> CliInputLine

@abstract func write_text(text: String) -> void

@abstract func write_line(text: String = "") -> void
