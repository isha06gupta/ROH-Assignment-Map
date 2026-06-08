var globalOrgsData = [];
var depotCoordLookup = {};
var globalWagonsData = [];
var globalOrgLookup = {};

// NEW: shared_parseCoord now takes the whole org object
// because mdms-station_master CSV has separate latitude/longitude columns
function shared_parseCoord(org) {
  if (!org) return null;
  const lat = parseFloat(org.latitude);
  const lon = parseFloat(org.longitude);
  if (!isNaN(lat) && !isNaN(lon) && lat !== 0 && lon !== 0) {
    return { lat, lon };
  }
  return null;
}

let bookedSpeedKmph = 20;

// Updated to handle stn_code style keys (no gis suffix stripping needed, but kept for safety)
function shared_getOrgByCode(code) {

    if (!code) return null;

    code = String(code).trim().toUpperCase();

    if (globalOrgLookup[code]) {
        return globalOrgLookup[code];
    }

    for (const key in globalOrgLookup) {

        if (
            code.includes(key) ||
            key.includes(code.replace(/RH$/,''))
        ) {
            return globalOrgLookup[key];
        }
    }

    return null;
}

function parseDateTime(value) {
  if (!value) return null;
  const s = String(value).trim();
  const normalized = s.replace(' ', 'T').replace(/\.\d+$/, '');
  const d = new Date(normalized);
  return Number.isNaN(d.getTime()) ? null : d;
}

function formatDateTime(dt) {
  if (!(dt instanceof Date) || Number.isNaN(dt.getTime())) return '';
  const pad = n => String(n).padStart(2, '0');
  return `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())} ${pad(dt.getHours())}:${pad(dt.getMinutes())}`;
}

function getBookedSpeed() {
  const input = document.getElementById('booked-speed-input');
  if (!input) return bookedSpeedKmph;
  const speed = parseFloat(input.value);
  if (speed > 0) {
    bookedSpeedKmph = speed;
    input.setCustomValidity('');
    return speed;
  }
  input.setCustomValidity('Speed must be greater than 0');
  input.reportValidity();
  return null;
}
function getDistanceFilter() {

    const el = document.getElementById('distance-filter');

    if (!el) return 500;

    return parseFloat(el.value) || 500;
}

function getDaysFilter() {

    const el = document.getElementById('days-filter');

    if (!el) return 20;

    return parseFloat(el.value) || 20;
}

// ─── BOOKED TO DEPOT ─────────────────────────────────────────────────────────
(function () {
  let mapB = null;
  let depotLayerB = null;
  let wagonLayerB = null;

  let zoneLayerB = null;
  let trackLayerB = null;
  let depotLabelLayerB = null;

  function initBookedMap() {
    const container = document.getElementById('map-booked');
    if (!container || mapB) return;
    try {
      mapB = L.map('map-booked', { center: [22.5, 80], zoom: 5 });
      window.mapBooked = mapB;
      L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
        attribution: '&copy; Esri, Maxar, Earthstar Geographics, and the GIS community',
        maxZoom: 19
      }).addTo(mapB);
      depotLayerB = L.layerGroup().addTo(mapB);
wagonLayerB = L.layerGroup().addTo(mapB);

zoneLayerB = L.layerGroup().addTo(mapB);
trackLayerB = L.layerGroup().addTo(mapB);
depotLabelLayerB = L.layerGroup().addTo(mapB);
fetch('railway_track_cris.json')
.then(r => r.json())
.then(data => {
    L.geoJSON(data,{
        style:{
            color:'#ffd166',
            weight:1.5,
            opacity:0.65
        }
    }).addTo(trackLayerB);
})
.catch(()=>{});

function getZoneColor(code){

    const colors = {
        NR:'#60A5FA',
        WR:'#F59E0B',
        CR:'#EC4899',
        ER:'#22C55E',
        ECR:'#F97316',
        NFR:'#06B6D4',
        NWR:'#A855F7',
        SCR:'#10B981',
        SECR:'#EAB308',
        SER:'#3B82F6',
        SR:'#8B5CF6',
        WCR:'#14B8A6'
    };

    return colors[code] || '#94A3B8';
}
fetch('railway_zone.json')
.then(r => r.json())
.then(data => {
    L.geoJSON(data, {
style: function(feature){

    const zoneCode =
        feature.properties.Code ||
        feature.properties.code ||
        feature.properties.NAME ||
        feature.properties.Name ||
        '';

    return {
        color:'#ffffff',
        weight:2,
        opacity:0.9,
        fillColor:getZoneColor(zoneCode),
        fillOpacity:0.08
    };
},
    onEachFeature:(feature, layer)=>{

        const code =
            feature.properties.Code ||
            feature.properties.code ||
            feature.properties.NAME ||
            feature.properties.Name ||
            '';

        if(code){

            const center = layer.getBounds().getCenter();

            L.marker(center,{
                icon:L.divIcon({
                    className:'zone-label',
                    html:code,
                    iconSize:[0,0]
                }),
                interactive:false
            }).addTo(zoneLayerB);

        }
    }

}).addTo(zoneLayerB);
})
.catch(()=>{});
L.control.layers(null, {
  'Depot Circles': depotLayerB,
  'Depot Labels': depotLabelLayerB,
  'Railway Zones': zoneLayerB,
  'Track Lines': trackLayerB
}, { collapsed:false }).addTo(mapB);

    } catch (e) { console.warn('Failed to init booked map:', e); }
  }
  
function booked_builddepotsList() {
  const set = new Set();
    globalWagonsData.forEach(r => {
      const v = (r['ROH Depot'] || '').trim().toUpperCase();
      if (v) set.add(v);
    });
    const depotsList = Array.from(set).sort();
    const container = document.getElementById('booked-depots');
    if (!container) return;
    container.innerHTML = '';
    depotsList.forEach(code => {
      const id  = 'booked_s_' + code.replace(/[\W]/g, '_');
      const div = document.createElement('div');
      div.className = 'depot-item';
      div.innerHTML = `<input type="checkbox" id="${id}" data-code="${code}" checked> <label for="${id}" style="flex:1">${code}</label>`;
      container.appendChild(div);
    });
  }

function booked_update() {
    if (!globalWagonsData || !globalOrgsData) return;
    initBookedMap();

    const selected = Array.from(
  document.querySelectorAll('#booked-depots input[type=checkbox]:checked')
).map(cb => cb.dataset.code.toUpperCase());

document.getElementById('booked-kpi-depots').textContent = selected.length;

let rows = selected.length === 0 ? [] : globalWagonsData.filter(r => {

    const depot =
        (r['ROH Depot'] || '').trim().toUpperCase();

    return selected.includes(depot);

});

const speed = getBookedSpeed();
if (speed === null) return;

const selectedDistance = getDistanceFilter();
const selectedDays = getDaysFilter();

/*
  Reachable distance based on:
  Speed × 24 hrs × Days
*/
rows = rows.filter(r => {

    const wagonDistance =
        parseFloat(r['Distance (km)']) || 0;

    const recalculatedEtaDays =
        (wagonDistance / speed) / 24;

    return (
        wagonDistance <= selectedDistance &&
        recalculatedEtaDays <= selectedDays
    );
});

document.getElementById('booked-kpi-total').textContent = rows.length;

const totalWagons = rows.reduce(
    (s, r) => s + (parseInt(r['Number of Wagons']) || 0),
    0
);

document.getElementById('booked-kpi-wagons').textContent = totalWagons;

const overdueCount = rows.filter(
    r => parseFloat(r['Overdue Days']) > 0
).length;

document.getElementById('booked-kpi-overdue').textContent = overdueCount;

console.log({
    speed,
    selectedDistance,
    selectedDays,
    filteredRows: rows.length,
    sampleRow: rows[0]

});
    // Depot-wise counts
    const counts = {};
    rows.forEach(r => {
      const key = (r['ROH Depot'] || 'UNKNOWN').trim().toUpperCase();
      if (!counts[key]) counts[key] = { rakes: 0, wagons: 0, overdue: 0 };
      counts[key].rakes++;
      counts[key].wagons += parseInt(r['Number of Wagons']) || 0;
      if (parseFloat(r['Overdue Days']) > 0) counts[key].overdue++;
    });

    const tbody = document.querySelector('#booked-depot-counts tbody');
    if (tbody) {
      tbody.innerHTML = '';
      Object.entries(counts).sort((a, b) => b[1].rakes - a[1].rakes).forEach(([depot, d]) => {
        const tr = document.createElement('tr');
        tr.innerHTML = `<td>${depot}</td><td>${d.rakes}</td><td>${d.wagons}</td><td style="color:${d.overdue > 0 ? '#ef4444' : '#22c55e'}">${d.overdue}</td>`;
        tbody.appendChild(tr);
      });
    }

    // Rake details table
    const wtbody = document.querySelector('#booked-wagon-table tbody');
    if (wtbody) {
      wtbody.innerHTML = '';
      rows.forEach(r => {
        const overdue    = parseFloat(r['Overdue Days']) || 0;
        const distance   = parseFloat(r['Distance (km)']);
        const etaHrs     = !Number.isNaN(distance) && distance >= 0 ? distance / speed : null;
        const etaDisplay = etaHrs !== null ? etaHrs.toFixed(2) : '—';
        const baseDate   = parseDateTime(r['Last Updated']);
        const arrivalDate= (etaHrs !== null && baseDate) ? new Date(baseDate.getTime() + etaHrs * 3600 * 1000) : null;
        const arrivalLabel = arrivalDate ? formatDateTime(arrivalDate) : (r['Expected Arrival'] || '—');
        const tr = document.createElement('tr');
        tr.innerHTML = `
          <td style="font-family:'IBM Plex Mono',monospace;font-size:18px">${r['Rake ID'] || ''}</td>
          <td>${r['Number of Wagons'] || ''}</td>
          <td>${r['Current Station'] || ''}</td>
          <td>${r['Destination'] || ''}</td>
          <td>${r['ROH Depot'] || ''}</td>
          <td style="color:${overdue > 0 ? '#ef4444' : '#22c55e'};font-weight:600">${overdue > 0 ? overdue + ' days' : '—'}</td>
          <td>${r['Distance (km)'] || ''}</td>
          <td>${etaDisplay}</td>
          <td style="font-size:18px">${arrivalLabel}</td>`;
        wtbody.appendChild(tr);
      });
    }

    if (!mapB) return;
  if (depotLayerB) depotLayerB.clearLayers();
if (wagonLayerB) wagonLayerB.clearLayers();
if (depotLabelLayerB) depotLabelLayerB.clearLayers();

    const bounds = [];

    //Depot Circle
    Object.entries(counts).forEach(([depot, d]) => {

    if (!selected.includes(depot)) return;
const org = depotCoordLookup[depot];

if (!org) return;

    const coords = shared_parseCoord(org);
    if (!coords) return;

    bounds.push([coords.lat, coords.lon]);

    const color =
        d.rakes >= 28 ? '#ef4444' :
        d.rakes >= 14 ? '#f97316' :
        d.rakes >= 5  ? '#facc15' :
                         '#22c55e';

    const radius =
        d.rakes >= 28 ? 18 :
        d.rakes >= 14 ? 15 :
        d.rakes >= 5  ? 12 :
                         10;

    L.circleMarker([coords.lat, coords.lon], {
    radius: 25,
    fillColor: color,
    color: '#ffffff',
    weight: 4,
    fillOpacity: 1
})
.addTo(depotLayerB)
.bindPopup(depot);
    L.marker([coords.lat, coords.lon], {
        icon: L.divIcon({
            className: 'depot-label',
            html: depot,
            iconSize: [0,0],
            iconAnchor: [0,-14]
        }),
        interactive: false
    }).addTo(depotLabelLayerB);

});

    // Individual rake markers — positioned at Current Station, fallback to Depot
    rows.forEach(r => {
      const depotKey   = (r['ROH Depot']        || '').trim().toUpperCase();
      const currentStn = (r['Current Station']  || '').trim().toUpperCase();

      const stnOrg      = shared_getOrgByCode(currentStn);
      const fallbackOrg = depotCoordLookup[depotKey];
      const resolvedOrg = stnOrg || fallbackOrg;
      if (!resolvedOrg) return;

      // CHANGED: pass resolvedOrg object directly
      const coords = shared_parseCoord(resolvedOrg);
      if (!coords) return;

      // Tiny jitter (~50–100 m) so stacked markers remain distinguishable
      const jLat = 0.001 * (Math.random() - 0.5);
      const jLon = 0.001 * (Math.random() - 0.5);

      const overdue     = parseFloat(r['Overdue Days']) || 0;
      const distance    = parseFloat(r['Distance (km)']);
      const etaHrs      = !Number.isNaN(distance) && distance >= 0 ? distance / speed : null;
      const etaDisplay  = etaHrs !== null ? etaHrs.toFixed(2) : '—';
      const baseDate    = parseDateTime(r['Last Updated']);
      const arrivalDate = (etaHrs !== null && baseDate) ? new Date(baseDate.getTime() + etaHrs * 3600 * 1000) : null;
      const arrivalLabel= arrivalDate ? formatDateTime(arrivalDate) : (r['Expected Arrival'] || '—');

      L.circleMarker([coords.lat + jLat, coords.lon + jLon], {
  radius: 6,
  fillColor: '#009dff',
  color: '#ffffff',
  weight: 1,
  fillOpacity: 1,
  opacity: 1
}).addTo(wagonLayerB).bindPopup(`
        <strong>Rake: ${r['Rake ID'] || ''}</strong><br/>
        Wagons: ${r['Number of Wagons'] || ''}<br/>
        Current: ${r['Current Station'] || ''}<br/>
        Dest: ${r['Destination'] || ''}<br/>
        ETA: ${etaDisplay} hrs<br/>
        Expected Arrival: ${arrivalLabel}<br/>
        Overdue: <span style="color:${overdue > 0 ? '#ef4444' : '#22c55e'};font-weight:700">${overdue > 0 ? overdue + ' days' : 'On time'}</span>
      `);
      bounds.push([coords.lat + jLat, coords.lon + jLon]);
    });

    if (bounds.length > 0) {
      try { mapB.fitBounds(bounds, {
    maxZoom: 9,
    padding:[80,80]
}); } catch (e) {}
    }
  }

  window.booked_update = booked_update;

  function booked_selectAll(flag) {
    document.querySelectorAll('#booked-depots input[type=checkbox]').forEach(cb => cb.checked = !!flag);
    booked_update();
  }

  window.initBookedTodepotModule = function () {
    booked_builddepotsList();
    document.getElementById('booked-depot-search').addEventListener('input', function () {
      const q = this.value.trim().toLowerCase();
      document.querySelectorAll('#booked-depots .depot-item').forEach(div => {
        div.style.display = div.textContent.toLowerCase().includes(q) ? 'flex' : 'none';
      });
    });
    document
.getElementById('distance-filter')
.addEventListener('change', booked_update);

document
.getElementById('days-filter')
.addEventListener('change', booked_update);

    initBookedMap();
    booked_update();
  };

  document.getElementById('booked-select-all').addEventListener('click', () => booked_selectAll(true));
  document.getElementById('booked-clear-all').addEventListener('click',  () => booked_selectAll(false));
  document.getElementById('booked-refresh').addEventListener('click',    () => booked_update());
  document.getElementById('booked-recalc').addEventListener('click',     () => booked_update());
  document.getElementById('booked-depots').addEventListener('change',    () => booked_update());
})();


// ─── DATA PIPELINE ───────────────────────────────────────────────────────────
async function initDashboardCorePipeline() {
  const parseCSV = (path) => new Promise((res, rej) => {
    Papa.parse(path, { download: true, header: true, skipEmptyLines: true, complete: res, error: rej });
  });

  try {
    const [orgsRes, wagonsRes] = await Promise.all([
      // CHANGED: new station master CSV
      parseCSV('mdms_station_master_202606051548.csv'),
      parseCSV('NKJRH_ROH_20260603_152610.csv')
    ]);

    globalOrgsData   = orgsRes.data;
    globalWagonsData = wagonsRes.data;

    // CHANGED: index by stn_code only (new CSV has no org_slno/org_code)
    globalOrgsData.forEach(item => {
    if (item.stn_code) {
        globalOrgLookup[item.stn_code.trim().toUpperCase()] = item;
    }
});

depotCoordLookup = {};

globalWagonsData.forEach(r => {

    const depot =
        (r['ROH Depot'] || '').trim().toUpperCase();

    const currentStation =
        (r['Current Station'] || '').trim().toUpperCase();

    if (
        depot &&
        currentStation &&
        !depotCoordLookup[depot] &&
        globalOrgLookup[currentStation]
    ) {
        depotCoordLookup[depot] =
            globalOrgLookup[currentStation];
    }

});
console.log(
    "Depot mappings:",
    Object.keys(depotCoordLookup).length
);

console.log(depotCoordLookup);
    if (window.initBookedTodepotModule)  window.initBookedTodepotModule();

  } catch (err) {
    console.error('Core dynamic load exception:', err);
  }
}

window.addEventListener('DOMContentLoaded', initDashboardCorePipeline);