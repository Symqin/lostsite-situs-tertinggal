extends Button

## Button whose tooltip_text is rendered as BBCode (styled info card).

func _make_custom_tooltip(for_text: String) -> Object:
	return GuideData.make_tooltip(for_text, 400.0)
