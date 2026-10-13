<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:pl="http://www.stuba.sk/sipvs/palubny-listok"
    exclude-result-prefixes="pl">

    <xsl:output method="xml" encoding="UTF-8" indent="yes" omit-xml-declaration="yes"/>

    <xsl:variable name="lowercase" select="'aáäbcčdďeéfghiíjklĺľmnňoóôpqrŕsštťuúvwxyýzž'"/>
    <xsl:variable name="uppercase" select="'AÁÄBCČDĎEÉFGHIÍJKLĹĽMNŇOÓÔPQRŔSŠTŤUÚVWXYÝZŽ'"/>
    <xsl:variable name="months" select="'JANFEBMARAPRMÁJJÚNJÚLAUGSEPOKTNOVDEC'"/>
    <xsl:variable name="barcodeChars" select="'0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ/ '"/>

    <xsl:template match="/pl:palubneListky">
        <html lang="sk">
            <head>
                <title>Palubné lístky – <xsl:value-of select="@rezervacia"/></title>
                <style>
                    @page {
                        size: A4 portrait;
                        margin: 8mm;
                    }
                    * { box-sizing: border-box; margin: 0; padding: 0; }
                    body {
                        background: #f0f2f5;
                        color: #1b1f24;
                        font-family: Arial, Helvetica, sans-serif;
                        padding: 10px 0;
                    }

                    .page-header-table {
                        width: 100%;
                        margin-bottom: 12px;
                        color: #4a5260;
                        font-size: 10pt;
                    }

                    .pass-card {
                        width: 100%;
                        margin-bottom: 16px;
                        background: #ffffff;
                        border: 1px solid #c9c3b6;
                        border-radius: 6px;
                        border-collapse: separate;
                        border-spacing: 0;
                        page-break-inside: avoid;
                    }

                    .main-cell {
                        vertical-align: top;
                        padding: 0;
                    }
                    .stub-cell {
                        width: 210px;
                        vertical-align: top;
                        border-left: 2px dashed #b9b4a8;
                        padding: 0;
                        background-color: #faf9f6;
                    }

                    .band-table {
                        width: 100%;
                        background: #0d2b4e;
                        color: #ffffff;
                        padding: 8px 12px;
                        border-collapse: collapse;
                    }
                    .band-carrier { font-weight: bold; font-size: 12pt; text-align: left; }
                    .band-title { font-weight: bold; font-size: 9pt; text-align: right; letter-spacing: 1px; }
                    .band-title small { display: block; font-size: 6.5pt; font-weight: normal; opacity: 0.8; letter-spacing: 0; }

                    .content-box { padding: 10px 12px; }

                    .field-label {
                        font-size: 6.5pt;
                        text-transform: uppercase;
                        color: #6b7280;
                        font-weight: bold;
                    }
                    .field-value {
                        font-family: "Courier New", Courier, monospace;
                        font-size: 11pt;
                        font-weight: bold;
                        color: #1b1f24;
                    }
                    .field-value.large { font-size: 14pt; }
                    .field-value.name { font-size: 12pt; }

                    .grid-table {
                        width: 100%;
                        border-top: 1px solid #e2ddd0;
                        border-bottom: 1px solid #e2ddd0;
                        border-collapse: collapse;
                        margin: 8px 0;
                    }
                    .grid-td {
                        width: 20%;
                        padding: 5px 4px;
                        vertical-align: top;
                        border-right: 1px solid #e2ddd0;
                    }
                    .grid-td:last-child { border-right: none; }

                    .priority-tag {
                        background: #c9a13b;
                        color: #1b1f24;
                        font-size: 7.5pt;
                        font-weight: bold;
                        padding: 2px 5px;
                        border-radius: 3px;
                        display: inline-block;
                    }

                    .seat-box {
                        border: 2px solid #0d2b4e;
                        border-radius: 4px;
                        text-align: center;
                        padding: 4px;
                        background: #ffffff;
                    }

                    @media print {
                        body { background: #fff; padding: 0; }
                    }
                </style>
            </head>
            <body>
                <table class="page-header-table">
                    <tr>
                        <td style="text-align: left;">
                            <h1 style="font-size: 13pt; color: #1b1f24;">Palubné lístky</h1>
                        </td>
                        <td style="text-align: right;">
                            Rezervácia <strong><xsl:value-of select="@rezervacia"/></strong>
                            · <xsl:value-of select="count(pl:pasazieri/pl:pasazier)"/> pasažier(i)
                        </td>
                    </tr>
                </table>

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

    <xsl:template name="boarding-pass">
        <xsl:param name="flight"/>
        <xsl:param name="pnr"/>
        <xsl:param name="sequence"/>

        <xsl:variable name="displayName">
            <xsl:value-of select="translate(pl:priezvisko, $lowercase, $uppercase)"/>
            <xsl:text>/</xsl:text>
            <xsl:value-of select="translate(pl:meno, $lowercase, $uppercase)"/>
            <xsl:if test="pl:titul">
                <xsl:text> </xsl:text>
                <xsl:value-of select="pl:titul"/>
            </xsl:if>
        </xsl:variable>

        <xsl:variable name="flightDate">
            <xsl:call-template name="format-date">
                <xsl:with-param name="date" select="$flight/pl:odlet/pl:cas"/>
            </xsl:call-template>
        </xsl:variable>

        <xsl:variable name="barcodeCode" select="concat($pnr, $flight/pl:cisloLetu, pl:sedadlo, $sequence)"/>
        <xsl:variable name="hasPriority" select="pl:prednostnyNastup = 'true' or pl:prednostnyNastup = '1'"/>

        <table class="pass-card">
            <tr>
                <!-- Hlavná časť -->
                <td class="main-cell">
                    <table class="band-table">
                        <tr>
                            <td class="band-carrier"><xsl:value-of select="$flight/pl:dopravca"/></td>
                            <td class="band-title">
                                PALUBNÝ LÍSTOK
                                <small>BOARDING PASS · <xsl:call-template name="class-name"/></small>
                            </td>
                        </tr>
                    </table>

                    <div class="content-box">
                        <table style="width: 100%; margin-bottom: 6px;">
                            <tr>
                                <td style="width: 70%;">
                                    <div class="field-label">Meno pasažiera / Passenger name</div>
                                    <div class="field-value name"><xsl:value-of select="$displayName"/></div>
                                </td>
                                <td style="width: 30%;">
                                    <div class="field-label">Rezervácia / PNR</div>
                                    <div class="field-value name"><xsl:value-of select="$pnr"/></div>
                                </td>
                            </tr>
                        </table>

                        <table style="width: 100%; margin: 6px 0;">
                            <tr>
                                <td style="width: 35%;">
                                    <div style="font-family: 'Courier New', monospace; font-size: 22pt; font-weight: bold; line-height: 1;"><xsl:value-of select="$flight/pl:odlet/pl:letisko"/></div>
                                    <div style="font-size: 8.5pt; color: #4a5260; margin-top: 2px;"><xsl:value-of select="$flight/pl:odlet/pl:mesto"/></div>
                                    <div style="font-family: 'Courier New', monospace; font-size: 10pt; font-weight: bold; margin-top: 2px;"><xsl:value-of select="substring($flight/pl:odlet/pl:cas, 12, 5)"/></div>
                                </td>
                                <td style="width: 30%; text-align: center; color: #6b7280; vertical-align: middle;">
                                    <div style="font-size: 12pt; color: #0d2b4e;">✈</div>
                                    <div style="font-size: 7.5pt; margin-top: 2px;">
                                        <xsl:call-template name="format-duration">
                                            <xsl:with-param name="duration" select="$flight/pl:dlzkaLetu"/>
                                        </xsl:call-template>
                                    </div>
                                </td>
                                <td style="width: 35%; text-align: right;">
                                    <div style="font-family: 'Courier New', monospace; font-size: 22pt; font-weight: bold; line-height: 1;"><xsl:value-of select="$flight/pl:prilet/pl:letisko"/></div>
                                    <div style="font-size: 8.5pt; color: #4a5260; margin-top: 2px;"><xsl:value-of select="$flight/pl:prilet/pl:mesto"/></div>
                                    <div style="font-family: 'Courier New', monospace; font-size: 10pt; font-weight: bold; margin-top: 2px;"><xsl:value-of select="substring($flight/pl:prilet/pl:cas, 12, 5)"/></div>
                                </td>
                            </tr>
                        </table>

                        <table class="grid-table">
                            <tr>
                                <td class="grid-td">
                                    <div class="field-label">Let / Flight</div>
                                    <div class="field-value large"><xsl:value-of select="$flight/pl:cisloLetu"/></div>
                                </td>
                                <td class="grid-td">
                                    <div class="field-label">Dátum / Date</div>
                                    <div class="field-value large"><xsl:value-of select="$flightDate"/></div>
                                </td>
                                <td class="grid-td">
                                    <div class="field-label">Nástup / Boarding</div>
                                    <div class="field-value large"><xsl:value-of select="substring($flight/pl:nastup, 1, 5)"/></div>
                                </td>
                                <td class="grid-td">
                                    <div class="field-label">Brána / Gate</div>
                                    <div class="field-value large"><xsl:value-of select="$flight/pl:gate"/></div>
                                </td>
                                <td class="grid-td">
                                    <div class="field-label">Sedadlo / Seat</div>
                                    <div class="field-value large"><xsl:value-of select="pl:sedadlo"/></div>
                                </td>
                            </tr>
                        </table>

                        <table style="width: 100%;">
                            <tr>
                                <td style="width: 25%; vertical-align: top;">
                                    <div class="field-label">Trieda / Class</div>
                                    <div class="field-value"><xsl:call-template name="class-name"/></div>
                                </td>
                                <td style="width: 25%; vertical-align: top;">
                                    <div class="field-label">Batožina / Baggage</div>
                                    <div class="field-value"><xsl:call-template name="baggage"/></div>
                                </td>
                                <td style="width: 25%; vertical-align: top;">
                                    <div class="field-label">Dátum nar.</div>
                                    <div class="field-value">
                                        <xsl:value-of select="concat(substring(pl:datumNarodenia, 9, 2), '.', substring(pl:datumNarodenia, 6, 2), '.', substring(pl:datumNarodenia, 1, 4))"/>
                                    </div>
                                </td>
                                <td style="width: 25%; vertical-align: top;">
                                    <div class="field-label">Prednostný nástup</div>
                                    <div class="field-value">
                                        <xsl:choose>
                                            <xsl:when test="$hasPriority"><span class="priority-tag">PRIORITY</span></xsl:when>
                                            <xsl:otherwise>—</xsl:otherwise>
                                        </xsl:choose>
                                    </div>
                                </td>
                            </tr>
                        </table>

                        <xsl:call-template name="render-barcode">
                            <xsl:with-param name="text" select="$barcodeCode"/>
                        </xsl:call-template>
                    </div>
                </td>

                <!-- Ústrižok (STUB) -->
                <td class="stub-cell">
                    <table class="band-table">
                        <tr>
                            <td class="band-carrier" style="font-size: 8.5pt;"><xsl:value-of select="$flight/pl:dopravca"/></td>
                            <td class="band-title">SEQ <xsl:value-of select="$sequence"/></td>
                        </tr>
                    </table>
                    <div class="content-box">
                        <div style="margin-bottom: 5px;">
                            <div class="field-label">Meno / Name</div>
                            <div class="field-value" style="font-size: 9.5pt;"><xsl:value-of select="$displayName"/></div>
                        </div>
                        <div style="font-family: 'Courier New', monospace; font-size: 12pt; font-weight: bold; margin-bottom: 5px;">
                            <xsl:value-of select="$flight/pl:odlet/pl:letisko"/> → <xsl:value-of select="$flight/pl:prilet/pl:letisko"/>
                        </div>
                        <table style="width: 100%; margin-bottom: 5px;">
                            <tr>
                                <td>
                                    <div class="field-label">Let</div>
                                    <div class="field-value"><xsl:value-of select="$flight/pl:cisloLetu"/></div>
                                </td>
                                <td>
                                    <div class="field-label">Dátum</div>
                                    <div class="field-value"><xsl:value-of select="$flightDate"/></div>
                                </td>
                            </tr>
                        </table>
                        <table style="width: 100%; margin-bottom: 5px;">
                            <tr>
                                <td class="seat-box" style="width: 50%;">
                                    <div class="field-label">Sedadlo</div>
                                    <div style="font-size: 15pt; font-weight: bold;"><xsl:value-of select="pl:sedadlo"/></div>
                                </td>
                                <td style="padding-left: 6px; vertical-align: top;">
                                    <div class="field-label">PNR</div>
                                    <div class="field-value"><xsl:value-of select="$pnr"/></div>
                                </td>
                            </tr>
                        </table>

                        <xsl:call-template name="render-barcode">
                            <xsl:with-param name="text" select="$barcodeCode"/>
                        </xsl:call-template>
                    </div>
                </td>
            </tr>
        </table>
    </xsl:template>

    <!-- Vektorový SVG čiarový kód bez akýchkoľvek externých fontov -->
        <!-- Vektorový SVG čiarový kód bez bezdôvodnej medzery -->
        <!-- Vektorový SVG čiarový kód s dynamicky dopočítanou šírkou -->
        <!-- Vektorový SVG čiarový kód plne vycentrovaný pre HTML aj PDF -->
    <xsl:template name="render-barcode">
        <xsl:param name="text"/>

        <xsl:variable name="exactWidth">
            <xsl:call-template name="calc-barcode-width">
                <xsl:with-param name="code" select="$text"/>
            </xsl:call-template>
        </xsl:variable>

        <div style="width: 100%; margin-top: 6px;">
            <table align="center" style="margin: 0 auto; border-collapse: collapse; border: none;">
                <tr>
                    <td style="text-align: center; padding: 0; border: none;">
                        <svg xmlns="http://www.w3.org/2000/svg" width="{$exactWidth}" height="32" viewBox="0 0 {$exactWidth} 32" style="display: block; margin: 0 auto;">
                            <!-- Štartovacie paličky -->
                            <rect x="2" y="0" width="2" height="32" fill="#1b1f24"/>
                            <rect x="5" y="0" width="1" height="32" fill="#1b1f24"/>

                            <!-- Vykreslenie znakov + stop paličiek -->
                            <xsl:call-template name="barcode-bars">
                                <xsl:with-param name="code" select="$text"/>
                                <xsl:with-param name="i" select="1"/>
                                <xsl:with-param name="x" select="8"/>
                            </xsl:call-template>
                        </svg>
                        <div style="font-family: 'Courier New', Courier, monospace; font-size: 7.5pt; color: #4a5260; margin-top: 1px; text-align: center;">
                            <xsl:value-of select="$text"/>
                        </div>
                    </td>
                </tr>
            </table>
        </div>
    </xsl:template>

    <xsl:template name="barcode-bars">
        <xsl:param name="code"/>
        <xsl:param name="i" select="1"/>
        <xsl:param name="x" select="8"/>

        <xsl:choose>
            <xsl:when test="$i &lt;= string-length($code)">
                <xsl:variable name="char" select="substring($code, $i, 1)"/>
                <xsl:variable name="pos" select="string-length(substring-before($barcodeChars, $char))"/>

                <xsl:variable name="w1" select="($pos mod 2) + 1"/>
                <xsl:variable name="gap" select="(floor($pos div 2) mod 2) + 1"/>
                <xsl:variable name="w2" select="(floor($pos div 4) mod 2) + 1"/>

                <rect x="{$x}" y="0" width="{$w1}" height="32" fill="#1b1f24"/>
                <rect x="{$x + $w1 + $gap}" y="0" width="{$w2}" height="32" fill="#1b1f24"/>

                <xsl:call-template name="barcode-bars">
                    <xsl:with-param name="code" select="$code"/>
                    <xsl:with-param name="i" select="$i + 1"/>
                    <xsl:with-param name="x" select="$x + $w1 + $gap + $w2 + 2"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <!-- Ukončovacie (stop) paličky -->
                <rect x="{$x}" y="0" width="1" height="32" fill="#1b1f24"/>
                <rect x="{$x + 2}" y="0" width="3" height="32" fill="#1b1f24"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <!-- Pomocná šablóna pre kalkuláciu finálnej šírky SVG -->
    <xsl:template name="calc-barcode-width">
        <xsl:param name="code"/>
        <xsl:param name="i" select="1"/>
        <xsl:param name="x" select="8"/>

        <xsl:choose>
            <xsl:when test="$i &lt;= string-length($code)">
                <xsl:variable name="char" select="substring($code, $i, 1)"/>
                <xsl:variable name="pos" select="string-length(substring-before($barcodeChars, $char))"/>

                <xsl:variable name="w1" select="($pos mod 2) + 1"/>
                <xsl:variable name="gap" select="(floor($pos div 2) mod 2) + 1"/>
                <xsl:variable name="w2" select="(floor($pos div 4) mod 2) + 1"/>

                <xsl:call-template name="calc-barcode-width">
                    <xsl:with-param name="code" select="$code"/>
                    <xsl:with-param name="i" select="$i + 1"/>
                    <xsl:with-param name="x" select="$x + $w1 + $gap + $w2 + 2"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$x + 6"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>



    <xsl:template name="format-date">
        <xsl:param name="date"/>
        <xsl:value-of select="substring($date, 9, 2)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="substring($months, (number(substring($date, 6, 2)) - 1) * 3 + 1, 3)"/>
        <xsl:text> </xsl:text>
        <xsl:value-of select="substring($date, 1, 4)"/>
    </xsl:template>

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
        <xsl:if test="$hours != ''"><xsl:value-of select="$hours"/> h </xsl:if>
        <xsl:if test="$minutes != ''"><xsl:value-of select="$minutes"/> min</xsl:if>
    </xsl:template>

    <xsl:template name="class-name">
        <xsl:choose>
            <xsl:when test="@trieda = 'first'">FIRST</xsl:when>
            <xsl:when test="@trieda = 'business'">BUSINESS</xsl:when>
            <xsl:otherwise>ECONOMY</xsl:otherwise>
        </xsl:choose>
    </xsl:template>

    <xsl:template name="baggage">
        <xsl:choose>
            <xsl:when test="number(pl:batozinaKg) = 0">Len príručná</xsl:when>
            <xsl:otherwise><xsl:value-of select="format-number(pl:batozinaKg, '0.#')"/> kg</xsl:otherwise>
        </xsl:choose>
    </xsl:template>

</xsl:stylesheet>
