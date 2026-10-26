## JSON helpers shared by the content loader, saves and tests.
## Godot parses every JSON number as a float; normalize() turns whole floats
## back into ints so logic and comparisons stay exact.
extends RefCounted


static func normalize(v: Variant) -> Variant:
	match typeof(v):
		TYPE_FLOAT:
			if v == floorf(v) and absf(v) < 9.0e15:
				return int(v)
			return v
		TYPE_ARRAY:
			var out := []
			for x in v:
				out.append(normalize(x))
			return out
		TYPE_DICTIONARY:
			var d := {}
			for k in v:
				d[k] = normalize(v[k])
			return d
	return v


## Stable text form (sorted keys) for comparing runs and logs.
static func canonical(v: Variant) -> String:
	return JSON.stringify(normalize(v), "", true)


## Reads and parses a JSON file. Returns null (and pushes an error) on failure.
static func load_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("missing JSON file: " + path)
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("%s:%d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return normalize(json.data)
