## Random ids and hashes for the family contract (docs/contract/README.md):
## device d_ + 16 hex, profile p_ + 12 hex. Random bytes come from the
## system's secure source, so two tablets never make the same id.
extends RefCounted


static func hex(n_bytes: int) -> String:
	return Crypto.new().generate_random_bytes(n_bytes).hex_encode()


static func device_id() -> String:
	return "d_" + hex(8)


static func profile_id() -> String:
	return "p_" + hex(6)


static func sha256_hex(text: String) -> String:
	var h := HashingContext.new()
	h.start(HashingContext.HASH_SHA256)
	h.update(text.to_utf8_buffer())
	return h.finish().hex_encode()


static func is_device_id(s: String) -> bool:
	return _is(s, "d_", 16)


static func is_profile_id(s: String) -> bool:
	return _is(s, "p_", 12)


static func _is(s: String, prefix: String, n: int) -> bool:
	if not s.begins_with(prefix) or s.length() != prefix.length() + n:
		return false
	for c in s.substr(prefix.length()):
		if not "0123456789abcdef".contains(c):
			return false
	return true
