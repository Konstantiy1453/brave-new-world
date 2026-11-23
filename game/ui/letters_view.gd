extends RefCounted
## The company's letters on the company page (1.11), newest first: the sending department, the
## subject and date, the departments copied in, the body, and the liaison's handwritten note when
## there is one. Letters come from company.gd `letter` (templates in letters.json).

const D = preload("res://ui/design.gd")
const Labels = preload("res://ui/labels.gd")
const SHOWN: int = 12
const NOTE_COLOR: Color = Color("e8d6a8")


static func list(_g, b, letters: Array) -> void:
	D.heading(b, "公司来信")
	if letters.is_empty():
		D.label(b, "还没有收到公司的来信。", 16, D.MUTED)
		return
	var newest: Array = letters.slice(-SHOWN)
	newest.reverse()
	for entry: Dictionary in newest:
		letter(b, entry)


static func letter(b, entry: Dictionary) -> void:
	var card: VBoxContainer = D.card(b, "card_quiet")
	var line: HBoxContainer = D.row(card)
	var department: String = str(entry.get("department", ""))
	if department != "":
		D.tag(line, department, D.TEAL, 15)
	var subject: Label = D.label(
		line, str(entry.get("subject", entry.get("reason", ""))), 18, D.GOLD, true
	)
	subject.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	D.label(line, Labels.short_date(int(entry.get("day", 0))), 14, D.MUTED, false)
	var copied: Array = entry.get("cc", [])
	if not copied.is_empty():
		D.label(card, "抄送：" + "、".join(PackedStringArray(copied)), 14, D.MUTED)
	var body: String = str(entry.get("body", ""))
	if body != "" and body != str(entry.get("subject", "")):
		D.label(card, body, 16)
	var note: String = str(entry.get("note", ""))
	if note == "":
		return
	var aside: HBoxContainer = D.row(card)
	D.portrait(aside, "liaison", 44, 58)
	var text: Label = D.label(aside, "联络人附言：" + note, 15, NOTE_COLOR)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
