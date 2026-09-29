# SIPVS – Palubný lístok

Semestrálny projekt z predmetu SIPVS: formulár **palubného lístka** (boarding pass) popísaný pomocou XML Schema a transformovaný cez XSL do HTML, ktoré vizuálne pripomína papierový palubný lístok.

Jedna rezervácia = jeden let + 1 až 9 pasažierov. Každý pasažier dostane vo výstupe vlastný palubný lístok.

## Štruktúra projektu

```
SIPVS/
├── README.md               ← tento súbor
├── palubnyListok.xsd       ← XML Schema – definícia štruktúry a dátových typov   ✅ hotové
├── palubnyListok.xml       ← vzorový palubný lístok (dáta)                        ⬜ TODO
├── palubnyListok.xsl       ← transformácia XML → HTML                             ⬜ TODO
└── palubnyListok.html      ← vygenerovaný výstup (xsltproc)                       ⬜ TODO
```

Ako súbory spolu súvisia:

```
                 validácia (xmllint --schema)
  palubnyListok.xsd ─────────────────────────┐
                                             ▼
                                  palubnyListok.xml
                                             │
  palubnyListok.xsl ─────────────────────────┤  transformácia (xsltproc)
                                             ▼
                                  palubnyListok.html
```

## Menný priestor

```
http://www.stuba.sk/sipvs/palubny-listok
```

Nastavený ako `targetNamespace` v XSD. XML dokument ho musí mať na root elemente (`xmlns="..."`) a XSL si ho musí deklarovať s prefixom, aby vedelo matchovať elementy.

## Štruktúra XML dokumentu

```
palubneListky                    @rezervacia : pnrType          (povinný)
├── let                          letType
│   ├── cisloLetu                cisloLetuType
│   ├── dopravca                 xsd:string
│   ├── odlet                    miestoType
│   │   ├── letisko              kodLetiskaType
│   │   ├── mesto                xsd:string
│   │   ├── cas                  xsd:dateTime
│   │   └── terminal             xsd:string                     (nepovinný)
│   ├── prilet                   miestoType                     (rovnaký typ ako odlet)
│   │   └── …
│   ├── dlzkaLetu                xsd:duration
│   ├── gate                     gateType
│   └── nastup                   xsd:time
└── pasazieri                    pasazieriType
    └── pasazier  [1..9]         pasazierType   @trieda : triedaType  (povinný)
        ├── titul                titulType
        ├── meno                 xsd:string
        ├── priezvisko           xsd:string
        ├── datumNarodenia       xsd:date
        ├── sedadlo              sedadloType
        ├── batozinaKg           batozinaKgType
        └── prednostnyNastup     xsd:boolean
```

`[1..9]` = opakujúca sa sekcia (`minOccurs="1" maxOccurs="9"`), `@` = atribút.

## Vlastné dátové typy

| Typ | Technika | Pravidlo | Príklad |
|---|---|---|---|
| `pnrType` | pattern | `[A-Z0-9]{6}` | `X7K2QB` |
| `cisloLetuType` | pattern | `[A-Z0-9]{2}\d{1,4}` | `FR1234`, `OK7` |
| `kodLetiskaType` | pattern | `[A-Z]{3}` | `BTS`, `VIE` |
| `gateType` | pattern | `[A-Z]\d{1,2}` | `A12` |
| `sedadloType` | pattern | `\d{1,2}[A-K]` | `14C` |
| `triedaType` | enumeration | `economy` / `business` / `first` | `economy` |
| `titulType` | enumeration | `MR` / `MRS` / `MS` | `MS` |
| `batozinaKgType` | rozsah čísla | `xsd:decimal`, 0–32, max 1 desatinné miesto | `23.5` |

Komplexné typy: `miestoType`, `letType`, `pasazierType`, `pasazieriType`, `palubneListkyType`.

## Použité vstavané typy

| Typ | Formát v XML | Príklad |
|---|---|---|
| `xsd:dateTime` | `RRRR-MM-DDThh:mm:ss` | `2026-10-15T14:30:00` |
| `xsd:date` | `RRRR-MM-DD` | `2002-05-14` |
| `xsd:time` | `hh:mm:ss` | `13:50:00` |
| `xsd:duration` | ISO 8601 | `PT2H35M` (2 h 35 min) |
| `xsd:boolean` | `true` / `false` | `true` |
| `xsd:decimal` | desatinné číslo s bodkou | `23.5` |
| `xsd:string` | ľubovoľný text | `Bratislava` |

## Príkazy

Kontrola syntaxe XSD:
```bash
xmllint --noout palubnyListok.xsd
```

Validácia XML voči schéme:
```bash
xmllint --noout --schema palubnyListok.xsd palubnyListok.xml
```

Transformácia do HTML:
```bash
xsltproc palubnyListok.xsl palubnyListok.xml > palubnyListok.html
```