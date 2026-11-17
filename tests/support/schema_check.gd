## The JSON Schema subset the contract uses (docs/contract/README.md, "The
## schema subset"), with no dependencies. errors() lists what is wrong.
## tools/contract/check.py is the same checker in Python.
extends RefCounted


static func errors(value: Variant, schema: Dictionary, root := {}, at := "$") -> Array:
	if root.is_empty():
		root = schema
	var out := []
	if schema.has("$ref"):
		var name := str(schema["$ref"]).trim_prefix("#/$defs/")
		return errors(value, root["$defs"][name], root, at)
	if schema.has("const") and not _same(value, schema["const"]):
		out.append("%s: expected %s" % [at, JSON.stringify(schema["const"])])
	if schema.has("enum"):
		var hit := false
		for e in schema["enum"]:
			hit = hit or _same(value, e)
		if not hit:
			out.append("%s: %s not in %s" % [at, JSON.stringify(value), JSON.stringify(schema["enum"])])
	if schema.has("type"):
		var types: Array = schema["type"] if schema["type"] is Array else [schema["type"]]
		var ok := false
		for t in types:
			ok = ok or _is_type(value, str(t))
		if not ok:
			out.append("%s: not %s" % [at, JSON.stringify(types)])
			return out
	if value is String and schema.has("pattern"):
		var re := RegEx.new()
		re.compile(str(schema["pattern"]))
		if re.search(value) == null:
			out.append("%s: %s does not match %s" % [at, value, schema["pattern"]])
	if (value is int or value is float):
		if schema.has("minimum") and value < schema["minimum"]:
			out.append("%s: below %s" % [at, schema["minimum"]])
		if schema.has("maximum") and value > schema["maximum"]:
			out.append("%s: above %s" % [at, schema["maximum"]])
	if value is Dictionary:
		for k in schema.get("required", []):
			if not value.has(k):
				out.append("%s: missing %s" % [at, k])
		var props: Dictionary = schema.get("properties", {})
		for k in value:
			if props.has(k):
				out.append_array(errors(value[k], props[k], root, "%s.%s" % [at, k]))
			elif schema.get("additionalProperties") is Dictionary:
				out.append_array(errors(value[k], schema["additionalProperties"], root, "%s.%s" % [at, k]))
	if value is Array and schema.has("items"):
		for i in value.size():
			out.append_array(errors(value[i], schema["items"], root, "%s[%d]" % [at, i]))
	if schema.has("oneOf"):
		var passing := 0
		for sub in schema["oneOf"]:
			if errors(value, sub, root, at).is_empty():
				passing += 1
		if passing != 1:
			out.append("%s: matches %d of oneOf, not 1" % [at, passing])
	return out


static func _is_type(v: Variant, t: String) -> bool:
	match t:
		"object":
			return v is Dictionary
		"array":
			return v is Array
		"string":
			return v is String
		"integer":
			return v is int or (v is float and v == floorf(v))
		"number":
			return v is int or v is float
		"boolean":
			return v is bool
		"null":
			return v == null
	return false


static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return float(a) == float(b)
	return typeof(a) == typeof(b) and a == b
