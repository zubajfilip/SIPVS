<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pl="http://www.stuba.sk/sipvs/palubny-listok"
    exclude-result-prefixes="pl">

    <xsl:output method="html" encoding="UTF-8" indent="yes" doctype-system="about:legacy-compat"/>

    <!-- Alphabets for upper-casing and stripping diacritics (XSLT 1.0 has no upper-case()) -->
    <xsl:variable name="lowercase" select="'aáäbcčdďeéfghiíjklĺľmnňoóôpqrŕsštťuúvwxyýzž'"/>
    <xsl:variable name="uppercase" select="'AÁÄBCČDĎEÉFGHIÍJKLĹĽMNŇOÓÔPQRŔSŠTŤUÚVWXYÝZŽ'"/>
    <xsl:variable name="ascii"     select="'AAABCCDDEEFGHIIJKLLLMNNOOOPQRRSSTTUUVWXYYZZ'"/>
    <xsl:variable name="months" select="'JANFEBMARAPRMÁJJÚNJÚLAUGSEPOKTNOVDEC'"/>
    <xsl:variable name="barcodeChars" select="'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/ '"/>

    <!-- ===================== Page ===================== -->
    <xsl:template match="/pl:palubneListky">
        <html lang="sk">
            <head>
                <title>Palubné lístky – <xsl:value-of select="@rezervacia"/></title>
                <style>
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        background: #e6e8eb;
                        color: #1b1f24;
                        font-family: "Segoe UI", Arial, Helvetica, sans-serif;
                        padding: 10mm 0;
                    }
                    .page-header {
                        width: 200mm; margin: 0 auto 6mm;
                        display: flex; justify-content: space-between; align-items: baseline;
                        color: #4a5260; font-size: 10pt;
                    }
                    .page-header h1 { font-size: 14pt; color: #1b1f24; }

                    /* ---------- boarding pass ---------- */
                    .pass {
                        width: 200mm; min-height: 82mm; margin: 0 auto 8mm;
                        display: flex;
                        background: #fffdf7;
                        border-radius: 3mm;
                        box-shadow: 0 1px 2px rgba(0,0,0,.12), 0 4px 14px rgba(0,0,0,.08);
                        overflow: hidden;
                        page-break-inside: avoid; break-inside: avoid;
                    }
                    .main { flex: 1; display: flex; flex-direction: column; }
                    .stub {
                        width: 58mm; position: relative;
                        border-left: 0.6mm dashed #b9b4a8;
                        display: flex; flex-direction: column;
                    }
                    /* perforation notches */
                    .stub::before, .stub::after {
                        content: ""; position: absolute; left: -3.3mm;
                        width: 6mm; height: 6mm; border-radius: 50%;
                        background: #e6e8eb;
                    }
                    .stub::before { top: -3mm; }
                    .stub::after  { bottom: -3mm; }

                    .band {
                        background: #0d2b4e; color: #fff;
                        display: flex; justify-content: space-between; align-items: center;
                        padding: 2.5mm 5mm; min-height: 11mm;
                    }
                    .band .carrier { font-weight: 700; font-size: 12pt; letter-spacing: .02em; }
                    .band .title { font-size: 10pt; font-weight: 600; letter-spacing: .12em; text-align: right; }
                    .band .title small { display: block; font-size: 7pt; font-weight: 400; opacity: .75; }
                    .class-business .band, .class-first .band { border-bottom: 1.2mm solid #c9a13b; }

                    .content { padding: 3.5mm 5mm 3mm; display: flex; flex-direction: column; gap: 3mm; flex: 1; }
                    .row { display: flex; gap: 4mm; }
                    .row > .field { flex: 1; }
                    .field .label {
                        font-size: 6.5pt; text-transform: uppercase; letter-spacing: .06em;
                        color: #6b7280; white-space: nowrap;
                    }
                    .field .label i { font-style: normal; color: #9aa0a8; }
                    .field .value {
                        font-family: Consolas, "Courier New", monospace;
                        font-size: 12pt; font-weight: 700; margin-top: .5mm; white-space: nowrap;
                    }
                    .field .value.large { font-size: 15pt; }
                    .field .value.name { font-size: 14pt; }

                    .route { display: flex; align-items: center; gap: 4mm; }
                    .airport .code { font-family: Consolas, "Courier New", monospace; font-size: 26pt; font-weight: 700; line-height: 1; }
                    .airport .city { font-size: 9pt; color: #4a5260; margin-top: .8mm; }
                    .airport .time { font-family: Consolas, "Courier New", monospace; font-size: 11pt; font-weight: 700; margin-top: .8mm; }
                    .airport .time small { font-size: 7.5pt; font-weight: 400; color: #6b7280; }
                    .airport.right { text-align: right; }
                    .flight-path { flex: 1; text-align: center; color: #6b7280; font-size: 8pt; }
                    .flight-path .line { display: flex; align-items: center; gap: 2mm; color: #0d2b4e; font-size: 13pt; }
                    .flight-path .line::before, .flight-path .line::after {
                        content: ""; flex: 1; border-top: 0.4mm dotted #9aa0a8;
                    }

                    .grid {
                        display: grid; grid-template-columns: repeat(5, 1fr);
                        border-top: 0.3mm solid #e2ddd0; border-bottom: 0.3mm solid #e2ddd0;
                        padding: 2mm 0;
                    }
                    .grid .field + .field { border-left: 0.3mm solid #e2ddd0; padding-left: 3mm; }

                    .footer { display: flex; justify-content: space-between; align-items: flex-end; gap: 4mm; margin-top: auto; }

                    .priority {
                        display: inline-block; background: #c9a13b; color: #1b1f24;
                        font-size: 8pt; font-weight: 700; letter-spacing: .1em;
                        padding: .5mm 2mm; border-radius: 1mm;
                    }

                    /* barcode – generated from the data, decorative only */
                    .barcode { display: flex; align-items: stretch; height: 11mm; }
                    .barcode span { display: block; }
                    .barcode .bar { background: #1b1f24; }
                    .barcode-text { font-family: Consolas, "Courier New", monospace; font-size: 6pt; color: #6b7280; margin-top: .6mm; letter-spacing: .05em; }

                    /* stub */
                    .stub .band { padding: 2.5mm 4mm; }
                    .stub .content { padding: 3mm 4mm; gap: 2.2mm; }
                    .stub .field .value { font-size: 10pt; }
                    .stub .route-short { font-family: Consolas, "Courier New", monospace; font-size: 15pt; font-weight: 700; }
                    .stub .route-short span { color: #9aa0a8; font-size: 11pt; padding: 0 1mm; }
                    .stub .seat-box {
                        border: 0.4mm solid #0d2b4e; border-radius: 1.5mm; text-align: center; padding: 1.5mm;
                    }
                    .stub .seat-box .value { font-size: 20pt; line-height: 1.1; }

                    @media print {
                        body { background: #fff; padding: 0; }
                        .page-header { display: none; }
                        .pass { box-shadow: none; border: 0.3mm solid #b9b4a8; }
                        .stub::before, .stub::after { background: #fff; }
                        * { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
                    }
                </style>
            </head>
            <body>
                <div class="page-header">
                    <h1>Palubné lístky</h1>
                    <span>
                        Rezervácia <strong><xsl:value-of select="@rezervacia"/></strong>
                        · <xsl:value-of select="count(pl:pasazieri/pl:pasazier)"/>
                        <xsl:choose>
                            <xsl:when test="count(pl:pasazieri/pl:pasazier) = 1"> pasažier</xsl:when>
                            <xsl:when test="count(pl:pasazieri/pl:pasazier) &lt; 5"> pasažieri</xsl:when>
                            <xsl:otherwise> pasažierov</xsl:otherwise>
                        </xsl:choose>
                    </span>
                </div>

                <xsl:for-each select="pl:pasazieri/pl:pasazier">
                    <xsl:call-template name="boarding-pass">
                        <xsl:with-param name="flight" select="/pl:palubneListky/pl:let"/>
                        <xsl:with-param name="pnr" select="/pl:palubneListky/@rezervacia"/>
                        <xsl:with-param name="sequence" select="format-number(position(), '000')"/>
                    </xsl:call-template>
                </xsl:for-each>
            </body>
        </html>
    </xsl:template>

    <!-- ===================== One boarding pass (context = pasazier) ===================== -->
    <xsl:template name="boarding-pass">
        <xsl:param name="flight"/>
        <xsl:param name="pnr"/>
        <xsl:param name="sequence"/>

        <xsl:variable name="displayName">
            <xsl:value-of select="translate(pl:priezvisko, $lowercase, $uppercase)"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="translate(pl:meno, $lowercase, $uppercase)"/>
            <xsl:text> </xsl:text>
            <xsl:value-of select="pl:titul"/>
        </xsl:variable>

        <xsl:variable name="flightDate">
            <xsl:call-template name="format-date">
                <xsl:with-param name="date" select="$flight/pl:odlet/pl:cas"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:variable name="barcodeData" select="concat('M1',
            translate(translate(pl:priezvisko, $lowercase, $uppercase), $uppercase, $ascii), '/',
            translate(translate(pl:meno, $lowercase, $uppercase), $uppercase, $ascii), ' ',
            $pnr, ' ', $flight/pl:odlet/pl:letisko, $flight/pl:prilet/pl:letisko, $flight/pl:cisloLetu, ' ',
            pl:sedadlo, ' ', $sequence)"/>

        <xsl:variable name="hasPriority" select="pl:prednostnyNastup = 'true' or pl:prednostnyNastup = '1'"/>

        <section class="pass class-{@trieda}">
            <!-- ========== main part ========== -->
            <div class="main">
                <div class="band">
                    <span class="carrier"><xsl:value-of select="$flight/pl:dopravca"/></span>
                    <span class="title">
                        PALUBNÝ LÍSTOK
                        <small>BOARDING PASS · <xsl:call-template name="class-name"/></small>
                    </span>
                </div>

                <div class="content">
                    <div class="row">
                        <div class="field" style="flex: 3">
                            <div class="label">Meno pasažiera <i>/ Passenger name</i></div>
                            <div class="value name"><xsl:value-of select="$displayName"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Rezervácia <i>/ PNR</i></div>
                            <div class="value name"><xsl:value-of select="$pnr"/></div>
                        </div>
                    </div>

                    <div class="route">
                        <xsl:call-template name="airport">
                            <xsl:with-param name="place" select="$flight/pl:odlet"/>
                        </xsl:call-template>
                        <div class="flight-path">
                            <div class="line">✈</div>
                            <div>
                                <xsl:call-template name="format-duration">
                                    <xsl:with-param name="duration" select="$flight/pl:dlzkaLetu"/>
                                </xsl:call-template>
                            </div>
                        </div>
                        <xsl:call-template name="airport">
                            <xsl:with-param name="place" select="$flight/pl:prilet"/>
                            <xsl:with-param name="cssClass" select="'airport right'"/>
                            <xsl:with-param name="compareWith" select="$flight/pl:odlet/pl:cas"/>
                        </xsl:call-template>
                    </div>

                    <div class="grid">
                        <div class="field">
                            <div class="label">Let <i>/ Flight</i></div>
                            <div class="value large"><xsl:value-of select="$flight/pl:cisloLetu"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Dátum <i>/ Date</i></div>
                            <div class="value large"><xsl:value-of select="$flightDate"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Nástup <i>/ Boarding</i></div>
                            <div class="value large"><xsl:value-of select="substring($flight/pl:nastup, 1, 5)"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Brána <i>/ Gate</i></div>
                            <div class="value large"><xsl:value-of select="$flight/pl:gate"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Sedadlo <i>/ Seat</i></div>
                            <div class="value large"><xsl:value-of select="pl:sedadlo"/></div>
                        </div>
                    </div>

                    <div class="row">
                        <div class="field">
                            <div class="label">Trieda <i>/ Class</i></div>
                            <div class="value"><xsl:call-template name="class-name"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Batožina <i>/ Baggage</i></div>
                            <div class="value"><xsl:call-template name="baggage"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Dátum narodenia <i>/ Date of birth</i></div>
                            <div class="value">
                                <xsl:value-of select="concat(substring(pl:datumNarodenia, 9, 2), '.',
                                    substring(pl:datumNarodenia, 6, 2), '.', substring(pl:datumNarodenia, 1, 4))"/>
                            </div>
                        </div>
                        <div class="field">
                            <div class="label">Prednostný nástup <i>/ Priority</i></div>
                            <div class="value">
                                <xsl:choose>
                                    <xsl:when test="$hasPriority">
                                        <span class="priority">PRIORITY</span>
                                    </xsl:when>
                                    <xsl:otherwise>—</xsl:otherwise>
                                </xsl:choose>
                            </div>
                        </div>
                    </div>

                    <div class="footer">
                        <div>
                            <xsl:call-template name="barcode">
                                <xsl:with-param name="data" select="$barcodeData"/>
                            </xsl:call-template>
                        </div>
                    </div>
                </div>
            </div>

            <!-- ========== tear-off stub ========== -->
            <aside class="stub">
                <div class="band">
                    <span class="carrier" style="font-size: 9pt"><xsl:value-of select="$flight/pl:dopravca"/></span>
                    <span class="title">SEQ <xsl:value-of select="$sequence"/></span>
                </div>
                <div class="content">
                    <div class="field">
                        <div class="label">Meno <i>/ Name</i></div>
                        <div class="value"><xsl:value-of select="$displayName"/></div>
                    </div>
                    <div class="route-short">
                        <xsl:value-of select="$flight/pl:odlet/pl:letisko"/>
                        <span>→</span>
                        <xsl:value-of select="$flight/pl:prilet/pl:letisko"/>
                    </div>
                    <div class="row">
                        <div class="field">
                            <div class="label">Let</div>
                            <div class="value"><xsl:value-of select="$flight/pl:cisloLetu"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Dátum</div>
                            <div class="value"><xsl:value-of select="$flightDate"/></div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="field">
                            <div class="label">Brána</div>
                            <div class="value"><xsl:value-of select="$flight/pl:gate"/></div>
                        </div>
                        <div class="field">
                            <div class="label">Nástup</div>
                            <div class="value"><xsl:value-of select="substring($flight/pl:nastup, 1, 5)"/></div>
                        </div>
                    </div>
                    <div class="row">
                        <div class="field seat-box">
                            <div class="label">Sedadlo / Seat</div>
                            <div class="value"><xsl:value-of select="pl:sedadlo"/></div>
                        </div>
                        <div class="field">
                            <div class="label">PNR</div>
                            <div class="value"><xsl:value-of select="$pnr"/></div>
                            <xsl:if test="$hasPriority">
                                <div style="margin-top: 1.5mm"><span class="priority">PRIORITY</span></div>
                            </xsl:if>
                        </div>
                    </div>
                </div>
            </aside>
        </section>
    </xsl:template>

    <!-- ===================== Helper templates ===================== -->

    <!-- Departure / arrival airport -->
    <xsl:template name="airport">
        <xsl:param name="place"/>
        <xsl:param name="cssClass" select="'airport'"/>
        <xsl:param name="compareWith"/>
        <div class="{$cssClass}">
            <div class="code"><xsl:value-of select="$place/pl:letisko"/></div>
            <div class="city">
                <xsl:value-of select="$place/pl:mesto"/>
                <xsl:if test="$place/pl:terminal">
                    <xsl:text> · Terminál </xsl:text>
                    <xsl:value-of select="$place/pl:terminal"/>
                </xsl:if>
            </div>
            <div class="time">
                <xsl:value-of select="substring($place/pl:cas, 12, 5)"/>
                <!-- arrival on a different day than departure -->
                <xsl:if test="$compareWith and substring($place/pl:cas, 1, 10) != substring($compareWith, 1, 10)">
                    <small>
                        <xsl:text> (</xsl:text>
                        <xsl:call-template name="format-date">
                            <xsl:with-param name="date" select="$place/pl:cas"/>
                        </xsl:call-template>
                        <xsl:text>)</xsl:text>
                    </small>
                </xsl:if>
            </div>
        </div>
    </xsl:template>

    <!-- 2026-10-15T14:30:00+02:00 → 15 OKT 2026 -->
    <xsl:template name="format-date">
        <xsl:param name="date"/>
        <xsl:value-of select="substring($date, 9, 2)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="substring($months, (number(substring($date, 6, 2)) - 1) * 3 + 1, 3)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="substring($date, 1, 4)"/>
    </xsl:template>

    <!-- PT2H35M → 2 h 35 min -->
    <xsl:template name="format-duration">
        <xsl:param name="duration"/>
        <xsl:variable name="time" select="substring-after($duration, 'T')"/>
        <xsl:variable name="hours" select="substring-before($time, 'H')"/>
        <xsl:variable name="rest">
            <xsl:choose>
                <xsl:when test="contains($time, 'H')"><xsl:value-of select="substring-after($time, 'H')"/></xsl:when>
                <xsl:otherwise><xsl:value-of select="$time"/></xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:variable name="minutes" select="substring-before($rest, 'M')"/>
        <xsl:if test="$hours != ''"><xsl:value-of select="$hours"/> h</xsl:if>
        <xsl:if test="$hours != '' and $minutes != ''"><xsl:text> </xsl:text></xsl:if>
        <xsl:if test="$minutes != ''"><xsl:value-of select="$minutes"/> min</xsl:if>
    </xsl:template>

    <!-- context = pasazier -->
    <xsl:template name="class-name">
        <xsl:choose>
            <xsl:when test="@trieda = 'first'">FIRST</xsl:when>
            <xsl:when test="@trieda = 'business'">BUSINESS</xsl:when>
            <xsl:otherwise>ECONOMY</xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- context = pasazier -->
    <xsl:template name="baggage">
        <xsl:choose>
            <xsl:when test="number(pl:batozinaKg) = 0">Len príručná</xsl:when>
            <xsl:otherwise><xsl:value-of select="format-number(pl:batozinaKg, '0.#')"/> kg</xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Barcode: bar widths are derived from the data characters (decorative only, not scannable) -->
    <xsl:template name="barcode">
        <xsl:param name="data"/>
        <div class="barcode">
            <span class="bar" style="width: 2px"></span><span style="width: 1px"></span>
            <span class="bar" style="width: 1px"></span><span style="width: 2px"></span>
            <xsl:call-template name="barcode-bars">
                <xsl:with-param name="text" select="$data"/>
            </xsl:call-template>
            <span class="bar" style="width: 2px"></span><span style="width: 1px"></span>
            <span class="bar" style="width: 1px"></span>
        </div>
        <div class="barcode-text"><xsl:value-of select="$data"/></div>
    </xsl:template>

    <xsl:template name="barcode-bars">
        <xsl:param name="text"/>
        <xsl:if test="string-length($text) &gt; 0">
            <xsl:variable name="i" select="string-length(substring-before($barcodeChars, substring($text, 1, 1)))"/>
            <span class="bar" style="width: {$i mod 3 + 1}px"></span>
            <span style="width: {floor($i div 3) mod 3 + 1}px"></span>
            <span class="bar" style="width: {floor($i div 9) mod 2 + 1}px"></span>
            <span style="width: {($i + 1) mod 2 + 1}px"></span>
            <xsl:call-template name="barcode-bars">
                <xsl:with-param name="text" select="substring($text, 2)"/>
            </xsl:call-template>
        </xsl:if>
    </xsl:template>

</xsl:stylesheet>
