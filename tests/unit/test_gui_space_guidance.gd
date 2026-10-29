extends GutTest

const Guidance := preload("res://scenes/gui/components/SpaceGuidance.tscn")


func test_guidance_reflows_with_real_text_at_readable_sizes() -> void:
	for size: Vector2i in [Vector2i(390, 844), Vector2i(844, 330), Vector2i(360, 640)]:
		var viewport := SubViewport.new()
		viewport.size = size
		add_child_autofree(viewport)
		var guidance: GuiSpaceGuidance = Guidance.instantiate()
		viewport.add_child(guidance)
		var ids := PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7, 8])
		var policy: GuiFitPolicy = GuiFitPolicy.resolve(
			GuiViewportGeometry.injected(size), ids, 0, []
		)
		guidance.render(policy)
		await wait_process_frames(4)
		assert_true(guidance.visible)
		var bounds := Rect2(Vector2.ZERO, Vector2(size))
		for path: String in ["Center/Heading", "Center/Message"]:
			var label: Label = guidance.get_node(path)
			assert_true(bounds.encloses(label.get_global_rect()), path)
			assert_gte(label.get_theme_font_size("font_size"), 20)
			assert_gte(label.size.y, label.get_minimum_size().y)
			assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
		assert_eq(guidance.get_node("Center/Message").text, policy.guidance)
		assert_eq(ids.size(), 9)
		assert_eq(policy.status, GuiFitPolicy.Status.PHONE_CAPACITY)
		var fitted := GuiFitPolicy.new()
		fitted.status = GuiFitPolicy.Status.FIT
		guidance.render(fitted)
		assert_false(guidance.visible)
		guidance.render(policy)
		assert_true(guidance.visible)
