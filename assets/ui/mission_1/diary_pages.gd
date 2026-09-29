extends RefCounted
## Lay out plain notebook text with the same font as the visible pages.
var pages: Array[String] = []
var spread := 0

func rebuild(text: String, font: Font, font_size: int, width: float, height: float, final_text := "") -> void:
	pages.clear()
	var rest := text.strip_edges()
	while not rest.is_empty():
		var low := 1
		var high := rest.length()
		var fit := 1
		while low <= high:
			var middle := (low+high)/2
			var measured := font.get_multiline_string_size(rest.left(middle),HORIZONTAL_ALIGNMENT_LEFT,width,font_size)
			if measured.y <= height and measured.x <= width:
				fit = middle
				low = middle+1
			else: high = middle-1
		if fit < rest.length():
			var boundary := maxi(rest.left(fit).rfind(" "),rest.left(fit).rfind("\n"))
			if boundary > 0: fit = boundary
		pages.append(rest.left(fit).strip_edges())
		rest = rest.substr(fit).strip_edges()
	if pages.is_empty() and final_text.is_empty(): pages.append("Observations are recorded here as you explore.")
	# Reserve the final right-hand page for the magic and actions. Balance the
	# last text page into two when needed, instead of inserting a blank spread.
	if not pages.is_empty() and pages.size()%2 == (0 if final_text.is_empty() else 1):
		var last := pages.pop_back() as String
		var split := last.find("\n\n",last.length()/3)
		if split < 0: split = last.find(" ",last.length()/2)
		if split < 0: split = maxi(1,last.length()/2)
		pages.append(last.left(split).strip_edges())
		pages.append(last.substr(split).strip_edges())
	if not final_text.is_empty(): pages.append(final_text)
	spread = mini(spread,last_spread())

func last_spread() -> int:
	return pages.size()/2

func turn(delta: int) -> void:
	spread = clampi(spread+delta,0,last_spread())

func left_text() -> String:
	return pages[spread*2] if not pages.is_empty() else ""

func right_text() -> String:
	return pages[spread*2+1] if spread < last_spread() else ""
