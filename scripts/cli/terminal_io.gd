class_name TerminalIO
extends CliIO

## The only class that accesses process stdin/stdout.


func read_line() -> CliInputLine:
	var bytes := PackedByteArray()

	while true:
		var next_byte: PackedByteArray = OS.read_buffer_from_stdin(1)
		if next_byte.is_empty():
			if bytes.is_empty():
				return CliInputLine.eof()
			break

		if next_byte[0] == 10:
			break
		if next_byte[0] != 13:
			bytes.append(next_byte[0])

	return CliInputLine.new(bytes.get_string_from_utf8())


func write_text(text: String) -> void:
	printraw(text)


func write_line(text: String = "") -> void:
	print(text)
