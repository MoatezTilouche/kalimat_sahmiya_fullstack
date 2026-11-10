"""Arabic cleanup without conflating distinct letters (أ/ا, ى/ي, ة/ه)."""
import re
import unicodedata

DIACRITICS = re.compile(r'[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed\u0640]')
ARABIC_WORD = re.compile(r'^[\u0621-\u063a\u0641-\u064a]+$')
UNSUITABLE = re.compile(r'إباح|اباح|جماع|بورن|عاهر|اغتصاب|انتحار|قضيب|مهبل|خصية|بظر|مني\b')


def normalize_answer(value: str) -> str:
    return DIACRITICS.sub('', unicodedata.normalize('NFKC', value.strip()))


def normalize_clue(value: str) -> str:
    return ' '.join(normalize_answer(value).split())


def comparison_key(value: str) -> str:
    # Only for detecting leaked answers, never for the stored spelling.
    return re.sub('[أإآٱ]', 'ا', normalize_answer(value)).replace('ى', 'ي')


def valid_pair(answer: str, clue: str) -> bool:
    if not (2 <= len(answer) <= 10 and ARABIC_WORD.fullmatch(answer)
            and 7 <= len(clue) <= 190):
        return False
    if re.search(r'[A-Za-z<>\[\]{}]|https?://|\ufffd', clue):
        return False
    if len(re.findall(r'[\u0621-\u064a]', clue)) < 6:
        return False
    if UNSUITABLE.search(answer + ' ' + clue):
        return False
    # Detect inflected/prefixed occurrences and spelling variants conservatively.
    if comparison_key(answer) in comparison_key(clue):
        return False
    if re.search(r'(مرادف|جمع|مفرد|تصغير|مؤنث|مذكر)\s*[:：]?$|غير متوفر|لا يوجد تعريف', clue):
        return False
    return True
