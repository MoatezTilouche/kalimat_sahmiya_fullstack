"""Download official vocabulary resources atomically, validate, then import."""
import argparse
import gzip
import json
from pathlib import Path
from urllib.request import urlopen, Request
import zipfile
from import_wordnet import import_wordnet

WORDNET_URL = 'https://raw.githubusercontent.com/Salah-Sal/arabic-wordnet-v4/main/output/awn4.xml.gz'
FREQUENCY_URL = 'https://github.com/CAMeL-Lab/Camel_Arabic_Frequency_Lists/releases/download/v1.0/MSA_freq_lists.tsv.zip'


def download(url: str, target: Path):
    target.parent.mkdir(parents=True, exist_ok=True)
    partial = target.with_suffix(target.suffix + '.part')
    try:
        with urlopen(Request(url, headers={'User-Agent': 'ArabicArrowwords/2.0'}), timeout=60) as response:
            with partial.open('wb') as out:
                while chunk := response.read(1024 * 1024):
                    out.write(chunk)
        if target.suffix == '.gz':
            with gzip.open(partial, 'rb') as stream:
                if b'<?xml' not in stream.read(256):
                    raise ValueError('Download is not compressed XML')
        elif target.suffix == '.zip' and not zipfile.is_zipfile(partial):
            raise ValueError('Download is not a ZIP archive')
        partial.replace(target)
    finally:
        partial.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--with-frequency', action='store_true', help='Download optional 69 MB CAMeL MSA list')
    parser.add_argument('--data-dir', type=Path, default=Path(__file__).parent / 'data')
    parser.add_argument('--db', type=Path)
    args = parser.parse_args()
    source = args.data_dir / 'awn4.xml.gz'
    frequency = args.data_dir / 'MSA_freq_lists.tsv.zip'
    try:
        if not source.exists():
            print('Downloading Arabic WordNet 4.0...', flush=True)
            download(WORDNET_URL, source)
        if args.with_frequency and not frequency.exists():
            print('Downloading CAMeL MSA frequencies...', flush=True)
            download(FREQUENCY_URL, frequency)
        print('Importing validated pairs...', flush=True)
        report = import_wordnet(source, args.db, frequency if args.with_frequency else None)
    except Exception as exc:
        parser.exit(1, f'Download/import failed: {exc}\nCheck connectivity or supply a local file to import_wordnet.py.\n')
    print(json.dumps(report, indent=2, ensure_ascii=True))


if __name__ == '__main__':
    main()
