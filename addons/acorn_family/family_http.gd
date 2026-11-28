## The network under family.gd: one HTTPRequest per call, a timeout, and
## an answer that never throws. status 0 means no answer (offline, DNS, TLS,
## timeout). Nothing here waits on the main thread; callers await send().
##
## Tests and tools swap in any object with the same send() (a fake that
## answers at once makes the whole sync run without a network).
extends Node

const TIMEOUT := 20.0


## -> {status: int, body: PackedByteArray, result: int}
func send(method: String, url: String, headers: PackedStringArray, body := PackedByteArray()) -> Dictionary:
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT
	req.use_threads = false
	add_child(req)
	var m := HTTPClient.METHOD_GET
	match method:
		"POST":
			m = HTTPClient.METHOD_POST
		"PUT":
			m = HTTPClient.METHOD_PUT
		"PATCH":
			m = HTTPClient.METHOD_PATCH
		"DELETE":
			m = HTTPClient.METHOD_DELETE
	var err := req.request_raw(url, headers, m, body)
	if err != OK:
		req.queue_free()
		return {"status": 0, "body": PackedByteArray(), "result": err}
	var out: Array = await req.request_completed
	req.queue_free()
	var result: int = out[0]
	var status: int = out[1] if result == HTTPRequest.RESULT_SUCCESS else 0
	return {"status": status, "body": out[3], "result": result}
