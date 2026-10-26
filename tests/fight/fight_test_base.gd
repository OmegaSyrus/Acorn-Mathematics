extends RefCounted
## Shared bits for the fight tests. A test file extends this, defines
## func test_*() -> bool methods that end with `return true`, and calls
## check(). Failures collect in `failures`. A script error aborts the method
## and it returns null instead of true, which the runner counts as a failure.

var failures: Array[String] = []
## Lines worth printing even when everything passes (bot win rates).
var notes: Array[String] = []


func check(cond: bool, msg: String) -> bool:
	if not cond:
		failures.append(msg)
	return cond
