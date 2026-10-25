"""Parses Table 1 (centesimal composition) of TACO 4th edition (NEPA/UNICAMP).

TACO allows reproduction with citation of the source. The PDF text layer is
imperfect (some numbers are split across tokens), so every row is validated:
kJ ≈ 4.184 × kcal and energy close to the Atwater estimate. Rows that fail
are reported, never guessed. Requires `pypdf` at build time only.
"""
import re

NUM = re.compile(r'^(\d+(?:,\d+)?|Tr|NA|\*)$')
ROW = re.compile(r'^(\d{1,3})\s+(.*)$')


def _value(token):
    if token in ('Tr', '*'):
        return 0.0
    if token == 'NA':
        return None
    return float(token.replace(',', '.'))


def parse(pdf_path, first_page=20, last_page=80):
    """Returns {taco_number: row} for rows that pass validation, plus a list
    of rejected (number, description, reason)."""
    from pypdf import PdfReader  # build-time dependency

    reader = PdfReader(pdf_path)
    rows, rejected = {}, []
    for index in range(first_page, min(last_page, len(reader.pages))):
        text = reader.pages[index].extract_text() or ''
        if 'Umidade' not in text or 'Energia' not in text:
            continue
        for line in text.splitlines():
            m = ROW.match(line.strip())
            if not m:
                continue
            number = int(m.group(1))
            tokens = m.group(2).split()
            # Description = leading tokens until the numeric columns start.
            split = next((i for i, t in enumerate(tokens) if NUM.match(t) and i > 0), None)
            if split is None:
                continue
            description = ' '.join(tokens[:split]).strip(' ,')
            values = [_value(t) for t in tokens[split:] if NUM.match(t)]
            if len(values) < 9:
                rejected.append((number, description, 'too few columns'))
                continue
            moisture, kcal, kj, protein, fat, _chol, carbs, fiber, _ash = values[:9]
            if None in (kcal, kj, protein, fat, carbs):
                rejected.append((number, description, 'missing value'))
                continue
            if kcal > 0 and not 4.0 <= kj / kcal <= 4.4:
                rejected.append((number, description, f'kJ/kcal {kj}/{kcal}'))
                continue
            fib = fiber or 0.0
            atwater = 4 * protein + 4 * max(carbs - fib, 0) + 9 * fat + 2 * fib
            if kcal > 20 and abs(atwater - kcal) / kcal > 0.25:
                rejected.append((number, description, f'Atwater {atwater:.0f} vs {kcal}'))
                continue
            rows[number] = {
                'description': description,
                'kcal': kcal,
                'protein': protein,
                'carbs': carbs,
                'fat': fat,
                'fiber': fib,
            }
    return rows, rejected
