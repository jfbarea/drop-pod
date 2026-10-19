#!/usr/bin/env python3
"""Valida un quiz generado por /quiz: estructura, balanceo de etiquetas y pistas por longitud.

Uso: python3 check.py <quiz.html>   (sale con 1 si hay errores)
"""
import html
import json
import math
import re
import sys
from html.parser import HTMLParser

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
# Por encima de esto, la correcta se distingue a simple vista de su distractor más largo.
LONGEST_MARGIN = 1.15
SHORTEST_MARGIN = 0.6
SPREAD_MAX = 2.0
SPREAD_MIN_CHARS = 40


class Balance(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.stack, self.errors = [], []

    def handle_starttag(self, tag, attrs):
        if tag not in VOID:
            self.stack.append((tag, self.getpos()[0]))

    def handle_endtag(self, tag):
        if tag in VOID:
            return
        if not self.stack or self.stack[-1][0] != tag:
            open_tag = self.stack[-1][0] if self.stack else "nada"
            self.errors.append(f"línea {self.getpos()[0]}: </{tag}> cierra {open_tag}")
            return
        self.stack.pop()

    def finish(self):
        self.close()
        self.errors += [f"<{t}> de la línea {ln} sin cerrar" for t, ln in self.stack]
        return self.errors


def balance(fragment):
    p = Balance()
    p.feed(fragment)
    return p.finish()


def plain(fragment):
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def main(path):
    src = open(path, encoding="utf-8").read()
    errors = []

    errors += [f"documento: {e}" for e in balance(src)]
    if "{{" in src:
        errors.append("quedan marcadores {{…}} de la plantilla sin rellenar")

    m = re.search(r'<script type="application/json" id="quiz-data">(.*?)</script>', src, re.S)
    if not m:
        sys.exit(f"{path}: no encuentro <script id=\"quiz-data\">")
    try:
        data = json.loads(m.group(1))
    except json.JSONDecodeError as e:
        sys.exit(f"{path}: el JSON de quiz-data no parsea: {e}")
    questions = data.get("questions", [])

    if not 10 <= len(questions) <= 12:
        errors.append(f"hay {len(questions)} preguntas; deben ser 10–12")

    longest = shortest = 0
    print(f"{'#':>3}  {'correcta':>8}  {'distractores':<18}  rango")
    for i, item in enumerate(questions, 1):
        tag = f"P{i:02d}"
        opts = item.get("opts", [])
        oks = [o for o in opts if o.get("ok")]
        if len(opts) != 4 or len(oks) != 1:
            errors.append(f"{tag}: {len(opts)} opciones y {len(oks)} correctas; deben ser 4 y 1")
            continue
        if not plain(item.get("why", "")):
            errors.append(f"{tag}: sin explicación")
        for field in [item["q"], item["why"], *(o["t"] for o in opts)]:
            errors += [f"{tag}: {e}" for e in balance(field)]
            if "<pre" in field:
                errors.append(f"{tag}: bloque <pre>; el código va inline con <code>")
        if any(re.search(r"(todas|ninguna) las anteriores", plain(o["t"]), re.I) for o in opts):
            errors.append(f"{tag}: «todas/ninguna las anteriores» no vale")

        ok_len = len(plain(oks[0]["t"]))
        others = sorted(len(plain(o["t"])) for o in opts if not o.get("ok"))
        lengths = sorted([ok_len, *others])
        rank = 1 + sum(o < ok_len for o in others)
        if ok_len > max(others):
            longest += 1
        if ok_len < min(others):
            shortest += 1
        print(f"{tag:>3}  {ok_len:>8}  {str(others):<18}  {rank}/4")

        if ok_len > LONGEST_MARGIN * max(others):
            errors.append(f"{tag}: la correcta ({ok_len}) supera en más de un {round((LONGEST_MARGIN - 1) * 100)}% al distractor más largo ({max(others)})")
        if ok_len < SHORTEST_MARGIN * min(others):
            errors.append(f"{tag}: la correcta ({ok_len}) es mucho más corta que todos los distractores (mín. {min(others)})")
        if max(lengths) > SPREAD_MIN_CHARS and max(lengths) > SPREAD_MAX * min(lengths):
            errors.append(f"{tag}: opciones desparejas, de {min(lengths)} a {max(lengths)} caracteres")

    n = len(questions)
    cap = math.ceil(n * 0.3)
    print(f"\ncorrecta más larga en {longest}/{n} (máx. {cap}); más corta en {shortest}/{n} (mín. 1)")
    if longest > cap:
        errors.append(f"la correcta es la más larga en {longest} de {n} preguntas; el máximo es {cap}")
    if n and shortest == 0:
        errors.append("la correcta no es la más corta en ninguna pregunta; el patrón se aprende igual")

    for e in errors:
        print(f"ERROR: {e}")
    print("OK" if not errors else f"\n{len(errors)} errores")
    return 1 if errors else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    sys.exit(main(sys.argv[1]))
