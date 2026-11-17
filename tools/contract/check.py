#!/usr/bin/env python3
"""Validates every sample in docs/contract/samples against its schema, with the
schema subset in docs/contract/README.md (no dependencies). The game's
tests/support/schema_check.gd is the same checker in GDScript.

    python3 -I tools/contract/check.py
"""
import json
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "contract")

# sample file -> schema file (a .jsonl sample checks every line)
SAMPLES = {
    "samples/event-answer.v2.json": "schemas/event.v2.schema.json",
    "samples/event-run.v2.json": "schemas/event.v2.schema.json",
    "samples/play_log.v2.jsonl": "schemas/event.v2.schema.json",
    "samples/device.json": "schemas/device.v1.schema.json",
    "samples/profiles.json": "schemas/profiles.v1.schema.json",
    "samples/snapshot.json": "schemas/snapshot.v1.schema.json",
    "samples/settings.json": "schemas/settings.v1.schema.json",
    "samples/manifest.json": "schemas/manifest.v1.schema.json",
    "samples/acorn-save.v2.json": "games/acorn-math/save.v2.schema.json",
}


def is_type(v, t):
    if t == "object":
        return isinstance(v, dict)
    if t == "array":
        return isinstance(v, list)
    if t == "string":
        return isinstance(v, str)
    if t == "integer":
        return isinstance(v, int) and not isinstance(v, bool) or (isinstance(v, float) and v.is_integer())
    if t == "number":
        return isinstance(v, (int, float)) and not isinstance(v, bool)
    if t == "boolean":
        return isinstance(v, bool)
    if t == "null":
        return v is None
    return False


def same(a, b):
    if isinstance(a, bool) or isinstance(b, bool):
        return type(a) is type(b) and a == b
    return a == b


def errors(value, schema, root=None, at="$"):
    root = root or schema
    if "$ref" in schema:
        return errors(value, root["$defs"][schema["$ref"].split("/")[-1]], root, at)
    out = []
    if "const" in schema and not same(value, schema["const"]):
        out.append(f"{at}: expected {schema['const']!r}")
    if "enum" in schema and not any(same(value, e) for e in schema["enum"]):
        out.append(f"{at}: {value!r} not in {schema['enum']}")
    if "type" in schema:
        types = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(is_type(value, t) for t in types):
            return out + [f"{at}: not {types}"]
    if isinstance(value, str) and "pattern" in schema and not re.search(schema["pattern"], value):
        out.append(f"{at}: {value!r} does not match {schema['pattern']}")
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            out.append(f"{at}: below {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            out.append(f"{at}: above {schema['maximum']}")
    if isinstance(value, dict):
        for k in schema.get("required", []):
            if k not in value:
                out.append(f"{at}: missing {k}")
        props = schema.get("properties", {})
        for k, v in value.items():
            if k in props:
                out += errors(v, props[k], root, f"{at}.{k}")
            elif isinstance(schema.get("additionalProperties"), dict):
                out += errors(v, schema["additionalProperties"], root, f"{at}.{k}")
    if isinstance(value, list) and "items" in schema:
        for i, v in enumerate(value):
            out += errors(v, schema["items"], root, f"{at}[{i}]")
    if "oneOf" in schema:
        n = sum(1 for sub in schema["oneOf"] if not errors(value, sub, root, at))
        if n != 1:
            out.append(f"{at}: matches {n} of oneOf, not 1")
    return out


def load(rel):
    with open(os.path.join(ROOT, rel), encoding="utf-8") as f:
        if rel.endswith(".jsonl"):
            return [json.loads(line) for line in f if line.strip()]
        return [json.load(f)]


def main():
    failed = 0
    skills = {s["id"] for s in load("skills.json")[0]["skills"]}
    for sample, schema_rel in SAMPLES.items():
        schema = load(schema_rel)[0]
        for i, doc in enumerate(load(sample)):
            errs = errors(doc, schema)
            if isinstance(doc, dict) and "skill" in doc and doc["skill"] not in skills:
                errs.append(f"$.skill: {doc['skill']} not in skills.json")
            for s in doc.get("skills", []) if isinstance(doc, dict) else []:
                if s not in skills:
                    errs.append(f"$.skills: {s} not in skills.json")
            name = sample if len(load(sample)) == 1 else f"{sample} line {i + 1}"
            if errs:
                failed += 1
                print("FAIL", name)
                for e in errs[:10]:
                    print("    ", e)
            else:
                print("ok  ", name)
    # every schema must reject an empty object (catches a schema with no required)
    for schema_rel in sorted(set(SAMPLES.values())):
        if not errors({}, load(schema_rel)[0]):
            failed += 1
            print("FAIL", schema_rel, "accepts {}")
    print(f"{len(SAMPLES)} samples, {failed} failed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
