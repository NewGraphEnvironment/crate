"""Recompute crate's receipt test vectors in Python (crate#43).

An implementation independent of crate's R code: Python's `rfc8785` for canonical JSON and
a separate implementation, below, of the table canonical form as research/provenance_receipt.md
specifies it. Every expected value in inst/extdata/receipt/vectors/<version>/ must come out
byte for byte. It doubles as a reference for stacs' `stacs.receipt` (stacs#12).

    python -I data-raw/receipt_vectors_crosscheck.py inst/extdata/receipt/vectors/v1.0.0

Needs `rfc8785` (stacs' environment has it). Exits 1 on any mismatch.
"""

import datetime
import hashlib
import json
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


def main(vdir):
    vdir = Path(vdir)
    load = lambda f: json.loads((vdir / f).read_text(encoding="utf-8"))
    bad = []

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

    counts = {f: len(load(f)) for f in ("numbers.json", "jcs.json", "recipe_id.json", "fingerprint.json")}
    print("cases:", counts)
    for b in bad:
        print("MISMATCH", *b, sep="\n  ")
    print(f"{len(bad)} mismatch(es)")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
