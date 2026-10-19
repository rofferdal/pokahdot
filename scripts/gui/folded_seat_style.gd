class_name FoldedSeatStyle
extends RefCounted

## Applies the presentation-only folded-seat privacy treatment.

static var _material: ShaderMaterial


static func apply(panel: PanelContainer) -> void:
	panel.material = _grayscale_material()
	for child: Node in panel.get_children():
		_apply_parent_material(child)


static func _grayscale_material() -> ShaderMaterial:
	if _material == null:
		var shader := Shader.new()
		shader.code = (
			"shader_type canvas_item;\n"
			+ "void fragment() {\n"
			+ "\tfloat luminance = dot(COLOR.rgb, vec3(0.2126, 0.7152, 0.0722));\n"
			+ "\tCOLOR.rgb = vec3(luminance);\n"
			+ "}\n"
		)
		_material = ShaderMaterial.new()
		_material.shader = shader
	return _material


static func _apply_parent_material(node: Node) -> void:
	if node is CanvasItem:
		node.use_parent_material = true
	for child: Node in node.get_children():
		_apply_parent_material(child)
