# Data and font attribution

The application does not call any language model. Its vocabulary pipeline uses
downloaded XML, measured corpus frequencies, and deterministic Python algorithms.

## Arabic WordNet 4.0

Copyright (c) 2026 Salah Abdo. [Repository](https://github.com/Salah-Sal/arabic-wordnet-v4),
[source notice](https://github.com/Salah-Sal/arabic-wordnet-v4/blob/main/NOTICE),
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Abdo, S. (2026). Arabic WordNet 4.0 (v4.1.0). Zenodo.
https://doi.org/10.5281/zenodo.18872077

Derived from Open English WordNet, copyright (c) 2019-present The Open English
WordNet Team, https://en-word.net/, CC BY 4.0. Open English WordNet is based on
Princeton WordNet 3.0, copyright 2006 Princeton University. Its terms are at
https://github.com/Salah-Sal/arabic-wordnet-v4/blob/main/LICENSES/Princeton-WordNet-License.txt.

Changes made here: Arabic presentation-form and diacritic cleanup, filtering of
invalid or revealing clues, deduplication, difficulty classification, and merging
with the original starter and reviewed fallback vocabulary. Row-level origin and
synset references remain in SQLite. The upstream authors disclose AI-assisted
translation; no translation or generation service is invoked by this project.

The educational knowledge table and `flutter_app/assets/knowledge/cards.json`
reuse these existing definitions with word/synset IDs, source URLs and licenses.
They do not add generated facts, translations or encyclopedia summaries. Imported
definitions retain their dictionary-import review status. Export changes include
word selection, categorization as language content, and an offline JSON format.

## CAMeL Arabic Frequency Lists

Khalifa, Salam; Inoue, Go; Alhafni, Bashar; Baimukan, Nurpeiis; Bouamor, Houda;
Habash, Nizar (2021). Camel Arabic Frequency Lists.
https://github.com/CAMeL-Lab/Camel_Arabic_Frequency_Lists

Inoue, Go; Alhafni, Bashar; Baimukan, Nurpeiis; Bouamor, Houda; Habash, Nizar
(2021). *The Interplay of Variant, Size, and Task Type in Arabic Pre-trained
Language Models*. Proceedings of the Sixth Arabic Natural Language Processing
Workshop, pp. 92–104. Association for Computational Linguistics.
https://aclanthology.org/2021.wanlp-1.10/

The frequency lists are [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/).
The included dictionary database and exported corpus-derived frequency and
classification metadata are distributed under that license, with the WordNet
attributions above retained. Frequency metadata retains exact normalized matches,
original row ranks, counts, and a SHA-256 source identifier. The source archive is
not required on devices. These data licenses do not assign a new license to the
application source code.

## Noto Sans Arabic

The bundled font is from https://github.com/google/fonts/tree/main/ofl/notosansarabic.
Copyright and SIL Open Font License 1.1 are preserved verbatim in
`flutter_app/assets/fonts/OFL.txt`. The font is bundled for offline rendering.

Flutter and Dart package licenses are available through their respective packages
and Flutter's license registry.
