@tool
extends SceneTree

func _format_number(val: int) -> String:
	var s := str(val)
	var res := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "," + res
	return res

func _init() -> void:
	print("0 -> ", _format_number(0))
	print("123 -> ", _format_number(123))
	print("1234 -> ", _format_number(1234))
	print("1234567 -> ", _format_number(1234567))
	quit(0)
