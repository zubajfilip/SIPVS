# SIPVS – Palubný lístok

Semestrálny projekt z predmetu SIPVS: formulár **palubného lístka** (boarding pass) popísaný pomocou XML Schema a transformovaný cez XSL do HTML, ktoré vizuálne pripomína papierový palubný lístok.

Jedna rezervácia = jeden let + 1 až 9 pasažierov. Každý pasažier dostane vo výstupe vlastný palubný lístok.

## Štruktúra projektu

```
SIPVS/
├── README.md               ← tento súbor
├── palubnyListok.xsd       ← XML Schema – definícia štruktúry a dátových typov   ✅ hotové
├── palubnyListok.xml       ← vzorový palubný lístok (dáta)                        ✅ hotové
├── palubnyListok.xsl       ← transformácia XML → HTML                             ✅ hotové
├── palubnyListok.html      ← vygenerovaný výstup (xsltproc)                       ✅ hotové
├── src/sk/stuba/sipvs/     ← webová aplikácia – server (Java 21, bez knižníc)     ✅ hotové
│   ├── App.java            ← HTTP server, API endpointy, statické súbory
│   ├── XmlService.java     ← Ulož XML / Over voči XSD / Transformuj do HTML
│   └── Json.java           ← zápis JSON odpovedí
├── web/                    ← webová aplikácia – formulár (HTML + CSS + JS)
└── output/                 ← sem aplikácia ukladá XML a HTML (nie je v gite)
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
│   ├── dopravca                 textType
│   ├── odlet                    miestoType
│   │   ├── letisko              kodLetiskaType
│   │   ├── mesto                textType
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
        ├── meno                 textType
        ├── priezvisko           textType
        ├── datumNarodenia       xsd:date
        ├── sedadlo              sedadloType
        ├── batozinaKg           batozinaKgType
        └── prednostnyNastup     xsd:boolean
```

`[1..9]` = opakujúca sa sekcia (`minOccurs="1" maxOccurs="9"`), `@` = atribút.

Obmedzenie `xsd:unique` (`unikatneSedadlo`) na root elemente zabezpečuje, že dvaja pasažieri v jednej rezervácii nemôžu mať rovnaké sedadlo.

V patternoch sa používa `[0-9]` namiesto `\d`, pretože `\d` v XSD matchuje aj iné Unicode číslice (napr. arabské).

## Vlastné dátové typy

| Typ | Technika | Pravidlo | Príklad |
|---|---|---|---|
| `pnrType` | pattern | `[A-Z0-9]{6}` | `X7K2QB` |
| `cisloLetuType` | pattern | `[A-Z0-9]{2}[0-9]{1,4}` | `FR1234`, `OK7` |
| `kodLetiskaType` | pattern | `[A-Z]{3}` | `BTS`, `VIE` |
| `gateType` | pattern | `[A-Z][0-9]{1,2}` | `A12` |
| `sedadloType` | pattern | `[0-9]{1,2}[A-K]` | `14C` |
| `triedaType` | enumeration | `economy` / `business` / `first` | `economy` |
| `titulType` | enumeration | `MR` / `MRS` / `MS` | `MS` |
| `textType` | dĺžka | `xsd:string`, 1–50 znakov (nesmie byť prázdny) | `Bratislava` |
| `batozinaKgType` | rozsah čísla | `xsd:decimal`, 0–32, max 1 desatinné miesto | `23.5` |

Komplexné typy: `miestoType`, `letType`, `pasazierType`, `pasazieriType`, `palubneListkyType`.

## Použité vstavané typy

| Typ | Formát v XML | Príklad |
|---|---|---|
| `xsd:dateTime` | `RRRR-MM-DDThh:mm:ss[±hh:mm]` | `2026-10-15T14:30:00+02:00` |
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
## Webová aplikácia

Jednoduchá webová aplikácia v Jave 21 bez externých knižníc (`com.sun.net.httpserver` + `javax.xml`). Slúži na vyplnenie formulára a má tri tlačidlá podľa zadania:

| Tlačidlo | Čo robí | Použité triedy |
|---|---|---|
| **Ulož XML** | poskladá XML z formulára (DOM) a uloží ho do `output/palubnyListok.xml` | `DocumentBuilder`, `Transformer` |
| **Over XML voči XSD** | zvaliduje uložené XML voči `palubnyListok.xsd`, vypíše všetky chyby s riadkom a stĺpcom a zvýrazní ich v náhľade | `SchemaFactory`, `Validator`, `ErrorHandler` |
| **Transformuj XML do HTML** | transformuje uložené XML cez `palubnyListok.xsl`, uloží `output/palubnyListok.html` a zobrazí náhľad | `TransformerFactory` |

Výhody elektronického formulára, ktoré aplikácia využíva:

- **kontrola** – pravidlá z XSD priamo vo formulári (patterny, dĺžky, rozsah batožiny, max. 9 pasažierov, rovnaké sedadlo u dvoch pasažierov); pri uložení s chybami sa aplikácia opýta, či uložiť aj tak – chyby potom odhalí validácia voči XSD
- **výber namiesto písania** – trieda a titul z rozbaľovacieho zoznamu, dátumy a časy cez kalendár
- **predvypĺňanie** – dopravca podľa kódu letu (`OS` → Austrian Airlines), mesto a časové pásmo podľa kódu letiska (vrátane letného času), začiatok nástupu 40 min pred odletom, prednostný nástup pre business/first, generovanie PNR
- **dopočítavanie** – dĺžka letu (`xsd:duration`) sa vypočíta z času odletu a príletu v ich časových pásmach
- **komfort** – automatické veľké písmená v kódoch, pridávanie/odoberanie pasažierov, tlačidlo *Vyplniť vzorové údaje*

### Spustenie

Z koreňa projektu (tam, kde je `palubnyListok.xsd`):

```bash
javac -encoding UTF-8 -d out src/sk/stuba/sipvs/*.java
java -cp out sk.stuba.sipvs.App
```

Potom otvoriť http://localhost:8080. Voliteľne sa dá zadať iný port: `java -cp out sk.stuba.sipvs.App 9090`.

V IntelliJ stačí spustiť `App.main` – working directory musí byť koreň projektu.
