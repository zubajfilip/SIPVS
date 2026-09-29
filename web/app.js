'use strict';

// ===================== Lookup tables for pre-filling =====================

// IATA code → [city shown on the page, IANA time zone]
const AIRPORTS = {
    BTS: ['Bratislava', 'Europe/Bratislava'],
    KSC: ['Košice', 'Europe/Bratislava'],
    VIE: ['Viedeň', 'Europe/Vienna'],
    PRG: ['Praha', 'Europe/Prague'],
    BUD: ['Budapešť', 'Europe/Budapest'],
    WAW: ['Varšava', 'Europe/Warsaw'],
    LHR: ['Londýn', 'Europe/London'],
    STN: ['Londýn', 'Europe/London'],
    LTN: ['Londýn', 'Europe/London'],
    DUB: ['Dublin', 'Europe/Dublin'],
    FRA: ['Frankfurt', 'Europe/Berlin'],
    MUC: ['Mníchov', 'Europe/Berlin'],
    CDG: ['Paríž', 'Europe/Paris'],
    AMS: ['Amsterdam', 'Europe/Amsterdam'],
    FCO: ['Rím', 'Europe/Rome'],
    BCN: ['Barcelona', 'Europe/Madrid'],
    IST: ['Istanbul', 'Europe/Istanbul'],
    DXB: ['Dubaj', 'Asia/Dubai'],
    JFK: ['New York', 'America/New_York'],
};

// flight number prefix → carrier name
const CARRIERS = {
    OS: 'Austrian Airlines',
    FR: 'Ryanair',
    W6: 'Wizz Air',
    OK: 'Czech Airlines',
    LH: 'Lufthansa',
    LO: 'LOT Polish Airlines',
    BA: 'British Airways',
    U2: 'easyJet',
    TK: 'Turkish Airlines',
    EK: 'Emirates',
};

const MAX_PASSENGERS = 9;           // maxOccurs in the XSD
const BOARDING_BEFORE_DEPARTURE = 40; // minutes
const DEFAULT_OFFSET = '+01:00';

// ===================== Helpers =====================

const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];

const form = $('#form');
const input = name => form.elements[name];
const passengerField = (card, name) => $(`[data-field="${name}"]`, card);

/** Pre-fills a field if it is empty or still holds a value the app put there (not the user). */
function prefill(el, value) {
    if (value == null) return;
    if (el.value === '' || el.dataset.auto === el.value) {
        if (el.tagName === 'SELECT' && ![...el.options].some(o => o.value === value)) {
            el.add(new Option('UTC' + value, value));
        }
        el.value = value;
        el.dataset.auto = value;
    }
}

function formatOffset(minutes) {
    const sign = minutes < 0 ? '-' : '+';
    const abs = Math.abs(minutes);
    return sign + String(Math.floor(abs / 60)).padStart(2, '0') + ':' + String(abs % 60).padStart(2, '0');
}

/** UTC offset of a time zone at the given local date (takes daylight saving time into account). */
function timeZoneOffset(timeZone, localDateTime) {
    const date = localDateTime ? new Date(localDateTime + 'Z') : new Date();
    if (isNaN(date)) return null;
    const name = new Intl.DateTimeFormat('en-US', { timeZone, timeZoneName: 'longOffset' })
        .formatToParts(date).find(p => p.type === 'timeZoneName').value; // "GMT+02:00" or "GMT"
    return name === 'GMT' ? '+00:00' : name.slice(3);
}

/** "2026-10-15T14:30" → "2026-10-15T14:30:00" */
const withSeconds = v => (v.length === 16 ? v + ':00' : v);

const pad2 = n => String(n).padStart(2, '0');

// ===================== Derived values =====================

/** place = "odlet" or "prilet" */
function updatePlace(place) {
    const airport = AIRPORTS[input(place + '.letisko').value];
    if (!airport) return;
    const [city, timeZone] = airport;
    prefill(input(place + '.mesto'), city);
    prefill(input(place + '.offset'), timeZoneOffset(timeZone, input(place + '.cas').value));
}

function updateBoardingTime() {
    const departure = input('odlet.cas').value;
    if (!departure) return;
    const [h, m] = departure.slice(11, 16).split(':').map(Number);
    const minutes = ((h * 60 + m - BOARDING_BEFORE_DEPARTURE) % 1440 + 1440) % 1440;
    prefill(input('nastup'), pad2(Math.floor(minutes / 60)) + ':' + pad2(minutes % 60));
}

/** Flight duration in minutes from the local times and their UTC offsets, or null if data is missing. */
function flightDurationMinutes() {
    const departure = input('odlet.cas').value, arrival = input('prilet.cas').value;
    if (!departure || !arrival) return null;
    const start = Date.parse(withSeconds(departure) + input('odlet.offset').value);
    const end = Date.parse(withSeconds(arrival) + input('prilet.offset').value);
    return (end - start) / 60000;
}

/** Flight duration as xsd:duration, e.g. "PT2H35M" */
function flightDurationIso() {
    const minutes = flightDurationMinutes();
    if (minutes == null || !(minutes > 0)) return '';
    const h = Math.floor(minutes / 60), m = minutes % 60;
    return 'PT' + (h ? h + 'H' : '') + (m ? m + 'M' : '');
}

function showFlightDuration() {
    const output = $('#flightDuration');
    const minutes = flightDurationMinutes();
    output.classList.remove('invalid');
    if (minutes == null || isNaN(minutes)) {
        output.textContent = '—';
    } else if (minutes <= 0) {
        output.textContent = 'Prílet musí byť po odlete';
        output.classList.add('invalid');
    } else {
        const h = Math.floor(minutes / 60), m = minutes % 60;
        output.textContent = (h ? h + ' h ' : '') + (m ? m + ' min' : '');
    }
    // arrival before departure blocks saving the same way an invalid field does
    input('prilet.cas').setCustomValidity(minutes != null && minutes <= 0 ? 'Prílet musí byť po odlete' : '');
}

/** Two passengers must not have the same seat (xsd:unique in the schema). */
function checkDuplicateSeats() {
    const seats = $$('[data-field="sedadlo"]');
    const counts = {};
    seats.forEach(s => { if (s.value) counts[s.value] = (counts[s.value] || 0) + 1; });
    seats.forEach(s => s.setCustomValidity(counts[s.value] > 1 ? 'Sedadlo má už iný pasažier' : ''));
}

// ===================== Passengers =====================

function addPassenger() {
    const container = $('#passengers');
    if (container.children.length >= MAX_PASSENGERS) return null;
    const card = $('#passengerTemplate').content.firstElementChild.cloneNode(true);
    passengerField(card, 'datumNarodenia').max = new Date().toISOString().slice(0, 10);
    $('.remove', card).addEventListener('click', () => {
        card.remove();
        renumberPassengers();
        markChanged();
    });
    container.append(card);
    renumberPassengers();
    return card;
}

function renumberPassengers() {
    const cards = $$('#passengers .passenger');
    cards.forEach((card, i) => {
        $('.number', card).textContent = i + 1;
        $('.remove', card).disabled = cards.length === 1;
    });
    $('#passengerCount').textContent = cards.length + ' / ' + MAX_PASSENGERS;
    $('#addPassenger').disabled = cards.length >= MAX_PASSENGERS;
    checkDuplicateSeats();
}

// ===================== Reacting to input =====================

form.addEventListener('input', e => {
    const el = e.target;

    if (el.classList.contains('uppercase')) {
        const caret = el.selectionStart;
        el.value = el.value.toUpperCase().replace(/\s/g, '');
        el.setSelectionRange(caret, caret);
    }

    const name = el.name || '';
    if (name === 'cisloLetu') {
        prefill(input('dopravca'), CARRIERS[el.value.slice(0, 2)]);
    }
    if (name.endsWith('.letisko') || name.endsWith('.cas')) {
        updatePlace(name.split('.')[0]);
    }
    if (name === 'odlet.cas') {
        updateBoardingTime();
    }

    // business / first → priority boarding, until the user changes the checkbox themselves
    if (el.dataset.field === 'trieda') {
        const checkbox = passengerField(el.closest('.passenger'), 'prednostnyNastup');
        if (!checkbox.dataset.touched) checkbox.checked = el.value !== 'economy';
    }
    if (el.dataset.field === 'prednostnyNastup') {
        el.dataset.touched = '1';
    }

    showFlightDuration();
    checkDuplicateSeats();
    markChanged();
});

$('#addPassenger').addEventListener('click', () => {
    const card = addPassenger();
    if (card) passengerField(card, 'meno').focus();
    markChanged();
});

$('#generatePnr').addEventListener('click', () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    const random = crypto.getRandomValues(new Uint32Array(6));
    input('rezervacia').value = [...random].map(n => chars[n % chars.length]).join('');
    markChanged();
});

// ===================== Collecting data for the server =====================

/** Form values in the format the XSD expects; keys are the XML element names. */
function collectFormData() {
    const data = new URLSearchParams();
    data.set('rezervacia', input('rezervacia').value);
    data.set('cisloLetu', input('cisloLetu').value);
    data.set('dopravca', input('dopravca').value);
    for (const place of ['odlet', 'prilet']) {
        const time = input(place + '.cas').value;
        data.set(place + '.letisko', input(place + '.letisko').value);
        data.set(place + '.mesto', input(place + '.mesto').value);
        data.set(place + '.cas', time ? withSeconds(time) + input(place + '.offset').value : '');
        data.set(place + '.terminal', input(place + '.terminal').value);
    }
    data.set('dlzkaLetu', flightDurationIso());
    data.set('gate', input('gate').value);
    const boarding = input('nastup').value;
    data.set('nastup', boarding ? (boarding.length === 5 ? boarding + ':00' : boarding) : '');

    $$('#passengers .passenger').forEach((card, i) => {
        for (const name of ['trieda', 'titul', 'meno', 'priezvisko', 'datumNarodenia', 'sedadlo', 'batozinaKg']) {
            data.set(`p.${i}.${name}`, passengerField(card, name).value);
        }
        data.set(`p.${i}.prednostnyNastup`, passengerField(card, 'prednostnyNastup').checked ? 'true' : 'false');
    });
    return data;
}

// ===================== Status and results =====================

let hasSaved = false;

function markChanged() {
    if (!hasSaved) return;
    const status = $('#status');
    status.textContent = 'Formulár bol zmenený od posledného uloženia';
    status.className = 'status changed';
}

function markSaved() {
    hasSaved = true;
    const status = $('#status');
    status.textContent = 'XML uložené o ' + new Date().toLocaleTimeString('sk-SK', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    status.className = 'status saved';
}

/** kind = undefined | "success" | "failure" */
function showMessage(html, kind) {
    $('#result').hidden = false;
    const message = $('#message');
    message.className = 'message' + (kind ? ' ' + kind : '');
    message.innerHTML = html;
    $('#errors').innerHTML = '';
    $('#xmlPreview').hidden = true;
    $('#htmlPreview').hidden = true;
}

function showXml(text, errorLines = new Set()) {
    const pre = $('#xmlPreview');
    pre.innerHTML = '';
    text.replace(/\n$/, '').split('\n').forEach((line, i) => {
        const span = document.createElement('span');
        span.className = 'line' + (errorLines.has(i + 1) ? ' has-error' : '');
        span.dataset.line = i + 1;
        span.textContent = line;
        pre.append(span);
    });
    pre.hidden = false;
}

const escapeHtml = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));

// Slovak plural forms: 1 chyba, 2–4 chyby, 5+ chýb
const plural = (n, one, few, many) => (n === 1 ? one : n < 5 ? few : many);

const SEVERITY_LABELS = { warning: 'varovanie', error: 'chyba', fatal: 'fatálna chyba' };

async function post(url, body) {
    try {
        const response = await fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
            body: body || '',
        });
        return await response.json();
    } catch (e) {
        return { ok: false, error: 'Server neodpovedá – beží aplikácia? (' + e.message + ')' };
    }
}

const invalidFields = () => $$('input, select', form).filter(el => !el.checkValidity());

// ===================== The three main buttons =====================

$('#save').addEventListener('click', async () => {
    form.classList.add('was-validated');
    const invalid = invalidFields();
    if (invalid.length > 0) {
        const n = invalid.length;
        const proceed = confirm(
            `Formulár obsahuje ${n} ${plural(n, 'chybné pole', 'chybné polia', 'chybných polí')}.\n\n` +
            'Uložiť XML aj tak? Chyby potom odhalí overenie voči XSD.');
        if (!proceed) {
            invalid[0].focus();
            return;
        }
    }

    const res = await post('/api/save', collectFormData());
    if (!res.ok) {
        showMessage('Uloženie zlyhalo: ' + escapeHtml(res.error), 'failure');
        return;
    }
    markSaved();
    showMessage(`XML uložené do <code>${escapeHtml(res.file)}</code>.`);
    showXml(res.xml);
    $('#result').scrollIntoView({ behavior: 'smooth' });
});

$('#validate').addEventListener('click', async () => {
    const res = await post('/api/validate');
    if (!res.ok) {
        showMessage(escapeHtml(res.error), 'failure');
        return;
    }
    const staleNote = $('#status').classList.contains('changed')
        ? '<br><small>Pozn.: overuje sa naposledy uložené XML – formulár bol odvtedy zmenený.</small>' : '';

    if (res.valid) {
        showMessage('✔ XML je platné voči schéme <code>palubnyListok.xsd</code>.' + staleNote, 'success');
        showXml(res.xml);
    } else {
        const n = res.errors.length;
        showMessage(`✘ XML nie je platné voči schéme – ${n} ${plural(n, 'chyba', 'chyby', 'chýb')}.` + staleNote, 'failure');
        $('#errors').innerHTML = '<ol>' + res.errors.map(e =>
            `<li><b>Riadok ${e.line}, stĺpec ${e.column}</b> (${SEVERITY_LABELS[e.severity] || e.severity}): ${escapeHtml(e.message)}</li>`).join('') + '</ol>';
        showXml(res.xml, new Set(res.errors.map(e => e.line)));
    }
    $('#result').scrollIntoView({ behavior: 'smooth' });
});

$('#transform').addEventListener('click', async () => {
    const res = await post('/api/transform');
    if (!res.ok) {
        showMessage('Transformácia zlyhala: ' + escapeHtml(res.error), 'failure');
        return;
    }
    showMessage(`HTML uložené do <code>${escapeHtml(res.file)}</code> · <a href="${escapeHtml(res.url)}" target="_blank" rel="noopener">otvoriť v novom okne</a>`, 'success');
    const iframe = $('#htmlPreview');
    iframe.src = res.url + '?t=' + Date.now();
    iframe.hidden = false;
    $('#result').scrollIntoView({ behavior: 'smooth' });
});

// ===================== Sample data =====================

function resetTimeZones() {
    for (const select of $$('select.timezone')) {
        select.value = DEFAULT_OFFSET;
        select.dataset.auto = DEFAULT_OFFSET;
    }
}

$('#fillSample').addEventListener('click', () => {
    $$('input, select', form).forEach(el => delete el.dataset.auto);
    form.reset();
    $('#passengers').innerHTML = '';
    resetTimeZones();

    const set = (name, value) => { input(name).value = value; };
    set('rezervacia', 'X7K2QB');
    set('cisloLetu', 'OS451');
    set('odlet.letisko', 'VIE');
    set('odlet.cas', '2026-10-15T14:30');
    set('odlet.terminal', '3');
    set('prilet.letisko', 'LHR');
    set('prilet.cas', '2026-10-15T16:05');
    set('prilet.terminal', '2');
    set('gate', 'F24');
    prefill(input('dopravca'), CARRIERS.OS);
    updatePlace('odlet');
    updatePlace('prilet');
    updateBoardingTime();

    [
        ['MR', 'Ján', 'Kováč', '1985-03-22', 'business', '2A', '28', true],
        ['MS', 'Petra', 'Horváthová', '2002-05-14', 'economy', '14C', '23.5', false],
        ['MRS', 'Mária', 'Kováčová', '1987-11-03', 'economy', '14D', '0', false],
    ].forEach(([title, firstName, lastName, birthDate, travelClass, seat, baggageKg, priority]) => {
        const card = addPassenger();
        passengerField(card, 'titul').value = title;
        passengerField(card, 'meno').value = firstName;
        passengerField(card, 'priezvisko').value = lastName;
        passengerField(card, 'datumNarodenia').value = birthDate;
        passengerField(card, 'trieda').value = travelClass;
        passengerField(card, 'sedadlo').value = seat;
        passengerField(card, 'batozinaKg').value = baggageKg;
        passengerField(card, 'prednostnyNastup').checked = priority;
    });

    form.classList.remove('was-validated');
    showFlightDuration();
    checkDuplicateSeats();
    markChanged();
});

// ===================== Initialisation =====================

(function init() {
    for (const select of $$('select.timezone')) {
        for (let h = -12; h <= 14; h++) {
            const offset = formatOffset(h * 60);
            select.add(new Option('UTC' + offset, offset));
        }
    }
    resetTimeZones();
    const datalist = $('#airports');
    for (const [code, [city]] of Object.entries(AIRPORTS)) {
        datalist.append(new Option(city, code));
    }
    addPassenger();
})();
