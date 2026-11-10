"""Recompute crate's receipt test vectors in Python (crate#43).

An implementation independent of crate's R code: Python's `rfc8785` for canonical JSON and
a separate implementation, below, of the table canonical form as research/provenance_receipt.md
specifies it. Every expected value in inst/extdata/receipt/vectors/<version>/ must come out
byte for byte. It doubles as a reference for stacs' `stacs.receipt` (stacs#12).

    python -I data-raw/receipt_vectors_crosscheck.py inst/extdata/receipt/vectors/v1.0.0
    python -I data-raw/receipt_vectors_crosscheck.py inst/extdata/receipt/mapping/v1.1.0

It checks the vector files the directory holds: the hashing vectors, or a mapping version's
`stac.json`, which it recomputes with its own reading of the mapping's STAC rows (crate#59).

Needs `rfc8785` (stacs' environment has it). Exits 1 on any mismatch, or on a directory
holding no vector file it knows.
"""

import datetime
import hashlib
import json
import math
import re
import struct
import sys
from pathlib import Path

import rfc8785


def from_bits(h):
    return struct.unpack(">d", bytes.fromhex(h))[0]


def jcs(value):
    return rfc8785.dumps(value).decode("utf-8")


def shortest(x):
    # rfc8785 refuses integers outside +-(2^53 - 1); a double is spelled the same way
    # whatever its value, so hand it a float.
    return jcs(float(x))


def cell(col_type, v, decimals):
    if v is None:
        return None
    if col_type in ("character", "date"):
        return v
    if col_type == "datetime":
        # Already UTC with whole seconds in the vectors; check the shape rather than trust it.
        datetime.datetime.strptime(v, "%Y-%m-%dT%H:%M:%SZ")
        return v
    if col_type == "integer":
        return str(int(v))
    if col_type == "logical":
        return "true" if v else "false"
    if col_type == "double":
        x = from_bits(v)
        if decimals is None:
            return shortest(x)
        s = format(x, f".{decimals}f")  # exact binary value, ties to even
        if s.startswith("-") and set(s[1:]) <= {"0", "."}:
            s = s[1:]
        return s
    raise ValueError(f"unknown column type {col_type}")


def decimals_of(tol):
    for k in range(16):
        if abs(tol / 10.0 ** -k - 1) < 1e-9:
            return k
    raise ValueError(f"tolerance {tol} is not a power of ten from 1 to 1e-15")


def table_canonical(table, tolerance):
    cols = table["columns"]
    names = sorted(cols, key=lambda n: n.encode("utf-8"))
    dec = {n: decimals_of(t) for n, t in tolerance.items()}
    n_rows = len(next(iter(cols.values()))["values"]) if cols else 0
    rows = []
    for i in range(n_rows):
        row = [cell(cols[n]["type"], cols[n]["values"][i], dec.get(n)) for n in names]
        rows.append(jcs(row))
    rows.sort(key=lambda r: r.encode("utf-8"))
    return '{"columns":' + jcs(names) + ',"rows":[' + ",".join(rows) + "]}"


FILE_EXT = "https://stac-extensions.github.io/file/v2.1.0/schema.json"
PROCESSING_EXT = "https://stac-extensions.github.io/processing/v1.2.0/schema.json"
RECEIPT_EXT = "https://newgraphenvironment.github.io/crate/stac/receipt/v1.0.0/schema.json"
# fullmatch, never match: `$` also matches before a trailing newline
SHA256 = re.compile(r"[0-9a-f]{64}")
UTC = re.compile(r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?Z")


class Refused(Exception):
    pass


def block(d, k):
    """A block or entry: absent is empty, and anything present must be an object, null included."""
    if k not in d:
        return {}
    if not isinstance(d[k], dict):
        raise Refused("block_not_object")
    return d[k]


def stac_fields(receipt, assets, receipt_asset, receipt_sha256):
    """The mapping's STAC rows, read from mapping.csv's notes, not from crate's R code."""
    if receipt_asset is not None:
        if receipt_asset == "":
            raise Refused("receipt_asset_empty")
        if receipt_asset in assets:
            raise Refused("receipt_asset_in_assets")
        if receipt_sha256 is None:
            raise Refused("receipt_asset_without_digest")
    elif receipt_sha256 is not None:
        raise Refused("digest_without_receipt_asset")
    if receipt_sha256 is not None and not (isinstance(receipt_sha256, str) and SHA256.fullmatch(receipt_sha256)):
        raise Refused("digest_not_sha256")
    if not isinstance(receipt, dict):
        raise Refused("block_not_object")
    output, recipe, result, context = (block(receipt, k) for k in ("output", "recipe", "result", "context"))
    props = {}
    # A value the item publishes is checked first: the field schema or a reader would refuse it
    # Only a migrated receipt has no recipe identity, and it never has one
    migrated = "migrated_from" in output
    rid = recipe.get("recipe_id")
    if rid is None:
        if not migrated:
            raise Refused("recipe_id_missing")
    else:
        if migrated:
            raise Refused("recipe_id_on_migrated")
        if not (isinstance(rid, str) and SHA256.fullmatch(rid)):
            raise Refused("recipe_id_not_sha256")
        props["receipt:recipe_id"] = rid
    time = context.get("time")
    if not (isinstance(time, str) and UTC.fullmatch(time)):
        raise Refused("time_not_utc")
    props["processing:datetime"] = time
    software = {}
    code = block(recipe, "code")
    for repo in code:
        if repo == "":
            raise Refused("repo_name_empty")
        v = block(code, repo).get("version")
        if v is None:
            continue
        if not (isinstance(v, str) and v):
            raise Refused("version_not_string")
        software[repo] = v
    if software:
        props["processing:software"] = software
    parts = block(result, "parts")
    out = {}
    for key, href in assets.items():
        if href not in parts:
            raise Refused("href_not_a_part")
        part = block(parts, href)
        sha, size = part.get("sha256"), part.get("bytes")
        if not (isinstance(sha, str) and SHA256.fullmatch(sha)):
            raise Refused("part_sha256_not_sha256")
        if isinstance(size, bool) or not isinstance(size, (int, float)) or not math.isfinite(size) \
                or size < 0 or size != int(size):
            raise Refused("bytes_not_whole")
        out[key] = {"file:checksum": "1220" + sha, "file:size": size}
    if receipt_asset is not None:
        out[receipt_asset] = {"file:checksum": "1220" + receipt_sha256}
    ext = ([FILE_EXT] if out else []) + \
          ([PROCESSING_EXT] if {"processing:datetime", "processing:software"} & props.keys() else []) + \
          ([RECEIPT_EXT] if "receipt:recipe_id" in props else [])
    return {"stac_extensions": ext, "properties": props, "assets": out}


def check_stac(cases, bad):
    for c in cases:
        r = c["receipt"]
        # Every case's recipe_id matches its recipe, so only the mapping decides it, and a case
        # refused for a value is invalid in that value alone. recipe_id_not_sha256's recipe_id
        # is itself the bad value, so it cannot match
        recipe = dict(r["recipe"]) if isinstance(r, dict) and isinstance(r.get("recipe"), dict) else {}
        rid = recipe.pop("recipe_id", None)
        if rid is not None and c["error"] not in ("recipe_id_not_sha256", "recipe_id_on_migrated") and hashlib.sha256(jcs(recipe).encode("utf-8")).hexdigest() != rid:
            bad.append(("stac recipe_id", c["name"], rid, "does not match its recipe"))
        try:
            got = stac_fields(r, c["assets"], c["receipt_asset"], c["receipt_sha256"])
            refused = None
        except Refused as e:
            got, refused = None, str(e)
        if refused != c["error"]:
            bad.append(("stac refusal", c["name"], refused, c["error"]))
        elif got is not None and jcs(got) != jcs(c["expected"]):
            bad.append(("stac", c["name"], jcs(got), jcs(c["expected"])))


def main(vdir):
    vdir = Path(vdir)
    # parse_int=float: JSON has one number type, so read every number as a double
    load = lambda f: json.loads((vdir / f).read_text(encoding="utf-8"), parse_int=float)
    bad = []
    counts = {}

    if (vdir / "numbers.json").exists():
        hashing(load, bad)
        counts.update({f: len(load(f)) for f in ("numbers.json", "jcs.json", "recipe_id.json", "fingerprint.json")})
    if (vdir / "stac.json").exists():
        check_stac(load("stac.json"), bad)
        counts["stac.json"] = len(load("stac.json"))
    if not counts:
        print(f"no vector file this script knows in {vdir}")
        return 1
    print("cases:", counts)
    for b in bad:
        print("MISMATCH", *b, sep="\n  ")
    print(f"{len(bad)} mismatch(es)")
    return 1 if bad else 0


def hashing(load, bad):
    for c in load("numbers.json"):
        got = shortest(from_bits(c["bits"]))
        if got != c["expected"]:
            bad.append(("numbers", c["name"], got, c["expected"]))

    for c in load("jcs.json"):
        # Python reads 1152921504606846976 as an int, which rfc8785 refuses past 2^53; JSON
        # has one number type, so read every number as a double, as JavaScript does.
        value = json.loads(c["input_json"], parse_int=float)
        got = jcs(value)
        if got != c["expected"]:
            bad.append(("jcs", c["name"], got, c["expected"]))

    for c in load("recipe_id.json"):
        r = json.loads(c["recipe_json"], parse_int=float)
        r.pop("recipe_id", None)
        got_jcs = jcs(r)
        got_id = hashlib.sha256(got_jcs.encode("utf-8")).hexdigest()
        if got_jcs != c["jcs"]:
            bad.append(("recipe_id jcs", c["name"], got_jcs, c["jcs"]))
        if got_id != c["recipe_id"]:
            bad.append(("recipe_id", c["name"], got_id, c["recipe_id"]))

    for c in load("fingerprint.json"):
        got = table_canonical(c["table"], c["tolerance"])
        got_sha = hashlib.sha256(got.encode("utf-8")).hexdigest()
        if got != c["canonical"]:
            bad.append(("fingerprint canonical", c["name"], got, c["canonical"]))
        if got_sha != c["sha256"]:
            bad.append(("fingerprint", c["name"], got_sha, c["sha256"]))


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
