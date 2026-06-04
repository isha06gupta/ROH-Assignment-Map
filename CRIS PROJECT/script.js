  var globalOrgsData = [];
  var globalWagonsData = [];
  var globalOrgLookup = {};

  function shared_parseCoord(gis) {
    if (!gis) return null;
    const t = String(gis).replace(/[()]/g, '').trim();
    const parts = t.split(/[,\s]+/).filter(Boolean);
    const nums = parts.map(p => parseFloat(p)).filter(n => !isNaN(n));
    if (nums.length >= 2) {
      if (nums[0] > 60 && nums[1] < 40) return { lat: nums[1], lon: nums[0] };
      return { lat: nums[0], lon: nums[1] };
    }
    return null;
  }

  let bookedSpeedKmph = 20;

  function shared_getOrgByCode(code) {
    if (!code) return null;
    code = String(code).trim().toUpperCase();
    if (globalOrgLookup[code]) return globalOrgLookup[code];
    const codeBase = code.replace(/(REPFD|FD|RH|PH|REP)$/, '');
    if (globalOrgLookup[codeBase]) return globalOrgLookup[codeBase];
    for (let k in globalOrgLookup) {
      if (k.includes(codeBase) || codeBase.includes(k.replace(/RH$/, ''))) return globalOrgLookup[k];
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

  function switchTab(id) {
    document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
    const panel = document.getElementById('tab-' + id);
    if (panel) panel.classList.add('active');
    document.querySelectorAll('.tab').forEach(t => {
      const attr = t.getAttribute('onclick') || '';
      if (attr.includes("'" + id + "'") || attr.includes('"' + id + '"')) t.classList.add('active');
    });
    if (id === 'heatmap' && window.mapLive) setTimeout(() => window.mapLive.invalidateSize(), 150);
    if (id === 'booked' && window.initBookedMapSafe) window.initBookedMapSafe();
  }


(function () {
  const map = L.map('map', { center: [22.5, 80.0], zoom: 5 });
  window.mapLive = map;
  L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', {
    attribution: '&copy; Esri, Maxar, Earthstar Geographics, and the GIS community',
    maxZoom: 19
  }).addTo(map);

  const zoneLayer = L.layerGroup().addTo(map);
  const trackLayer = L.layerGroup().addTo(map);
  const depotLayer = L.layerGroup().addTo(map);
  const depotLabelLayer = L.layerGroup().addTo(map);
  const wagonMarkerLayer = L.layerGroup().addTo(map);
  const zoneLabelLayer = L.layerGroup().addTo(map);
  const depotMarkers = [];
  const depotLabelMarkers = [];

  function updateDepotMarkerSizes() {
    const zoom = map.getZoom();
    depotMarkers.forEach(marker => {
      if (marker && typeof marker.count === 'number' && marker.setRadius) {
        marker.setRadius(getRadius(marker.count, zoom));
      }
    });
    updateDepotLabelVisibility();
  }

  function updateDepotLabelVisibility() {
    const zoom = map.getZoom();
    depotLabelMarkers.forEach(label => {
      if (!label._icon) return;
      const count = label.count || 0;
      let visible = false;
      if (zoom >= 8) visible = true;
      else if (zoom >= 6) visible = count >= 5;
      else visible = count >= 14;
      label._icon.style.display = visible ? '' : 'none';
    });
  }

  map.on('zoomend', updateDepotMarkerSizes);

  L.control.layers(null, {
    'Depot Circles': depotLayer,
    'Depot Labels': depotLabelLayer,
    'Railway Zones': zoneLayer,
    'Track Lines': trackLayer
  }, { collapsed: false }).addTo(map);

  function getZoneFillColor(code) {
    const mapColors = {
      NR: '#60A5FA', NWR: '#A78BFA', WR: '#F59E0B', CR: '#F472B6', SCR: '#22C55E', SER: '#06B6D4', ER: '#FACC15', NFR: '#14B8A6', ECR: '#F97316', SECR: '#0EA5E9', SR: '#8B5CF6', WCR: '#38BDF8'
    };
    if (!code) return '#94a3b8';
    const key = String(code).trim().toUpperCase();
    if (mapColors[key]) return mapColors[key];
    const palette = ['#60A5FA', '#A78BFA', '#F59E0B', '#F472B6', '#22C55E', '#06B6D4', '#FACC15', '#14B8A6', '#F97316', '#0EA5E9', '#8B5CF6', '#38BDF8'];
    const hash = Array.from(key).reduce((sum, ch) => sum + ch.charCodeAt(0), 0);
    return palette[hash % palette.length];
  }

  function getZoneCode(feature) {
    if (!feature || !feature.properties) return '';
    return String(feature.properties.Code || feature.properties.zone || feature.properties.Name || feature.properties.name || '').trim().toUpperCase();
  }

  fetch('railway_track_cris.json').then(r => r.json()).then(data => {
    L.geoJSON(data, {
      style: () => ({ color: '#ffd166', weight: 1.5, opacity: 0.65, lineCap: 'round', lineJoin: 'round' }),
      onEachFeature: (feature, layer) => {
        if (feature.properties && feature.properties.tmssection)
          layer.bindPopup("<b>Section:</b> " + feature.properties.tmssection + "<br><b>Railway:</b> " + feature.properties.railway + "<br><b>Division:</b> " + feature.properties.division);
      }
    }).addTo(trackLayer);
  }).catch(() => {});

  fetch('railway_zone.json').then(r => r.json()).then(data => {
    L.geoJSON(data, {
      style: feature => {
        return {
          color: '#ffffff',
          weight: 2.2,
          opacity: 0.95,
          fillColor: getZoneFillColor(getZoneCode(feature)),
          fillOpacity: 0.26,
          dashArray: '3,5'
        };
      },
      onEachFeature: (feature, layer) => {
        const code = getZoneCode(feature);
        layer.bindPopup("<b>Zone:</b> " + (feature.properties.Name || code) + " (" + code + ")");
        if (code) {
          const center = layer.getBounds().getCenter();
          L.marker(center, {
            icon: L.divIcon({ className: 'zone-label', html: code, iconSize: [0, 0], iconAnchor: [0, 0] }),
            interactive: false
          }).addTo(zoneLabelLayer);
        }
      }
    }).addTo(zoneLayer);
  }).catch(() => {});

  function getColor(count) {
    if (count >= 28) return '#ef4444';  // top 25% — critical
    if (count >= 14) return '#f97316';  // 50–75th pct — elevated
    if (count >= 5)  return '#facc15';  // 25–50th pct — medium
    return '#22c55e';                   // bottom 25% — low
  }

  function getRadius(count, zoom = 5) {
    const base = 4 + Math.sqrt(count) * 0.7;
    const scale = 1 + (zoom - 5) * 0.06;
    return Math.max(4, Math.min(10, Math.round(base * scale * 10) / 10));
  }

  window.initLiveHeatmapModule = function () {
    depotLayer.clearLayers();
    depotLabelLayer.clearLayers();
    depotMarkers.length = 0;
    depotLabelMarkers.length = 0;

    // Group by ROH Depot
    const counts = {};
    const overdueCounts = {};
    const totalWagonsPerDepot = {};
    globalWagonsData.forEach(w => {
      const key = (w['ROH Depot'] || '').trim().toUpperCase();
      if (!key) return;
      counts[key] = (counts[key] || 0) + 1;
      totalWagonsPerDepot[key] = (totalWagonsPerDepot[key] || 0) + (parseInt(w['Number of Wagons']) || 0);
      if (parseFloat(w['Overdue Days']) > 0) overdueCounts[key] = (overdueCounts[key] || 0) + 1;
    });

    const sorted = Object.entries(counts).sort((a, b) => b[1] - a[1]);
    const tbody = document.getElementById('depot-tbody');
    if (tbody) tbody.innerHTML = '';
    const maxVal = sorted.length > 0 ? sorted[0][1] : 1;

    sorted.forEach(([depotCode, c], index) => {
      const org = shared_getOrgByCode(depotCode);
      const coords = org ? shared_parseCoord(org.gis_coord) : null;
      const latStr = coords ? coords.lat.toFixed(3) : '--';
      const lonStr = coords ? coords.lon.toFixed(3) : '--';
      const nameStr = org ? org.station_name : depotCode;
      const overdue = overdueCounts[depotCode] || 0;
      const pct = ((c / maxVal) * 100).toFixed(0);
      const cls = c >= 28 ? 'count-high' : c >= 5 ? 'count-med' : 'count-low';

      if (tbody) {
        tbody.innerHTML += `<tr>
          <td style="color:var(--muted)">${index + 1}</td>
          <td style="font-family:'IBM Plex Mono',monospace;font-size:18px;">${depotCode}</td>
          <td>${nameStr}</td>
          <td class="${cls}">${c}</td>
          <td style="color:${overdue > 0 ? '#ef4444' : 'var(--green)'};font-family:'IBM Plex Mono',monospace;font-weight:600">${overdue}</td>
          <td class="bar-cell"><div class="bar"><div class="bar-fill" style="width:${pct}%"></div></div></td>
          <td style="color:var(--muted);font-size:18px;">${latStr}</td>
          <td style="color:var(--muted);font-size:18px;">${lonStr}</td>
        </tr>`;
      }

      if (coords) {
        const wagonTotal = totalWagonsPerDepot[depotCode] || 0;
        const marker = L.circleMarker([coords.lat, coords.lon], {
          radius: getRadius(c, map.getZoom()),
          fillColor: getColor(c),
          color: '#fff',
          weight: 1,
          fillOpacity: 0.8
        }).addTo(depotLayer).bindPopup(`
          <div style="font-family:'Segoe UI',sans-serif;font-size:19px;min-width:190px;line-height:1.6;color:#111;">
            <div style="font-family:monospace;font-size:19px;font-weight:700;border-bottom:2px solid ${getColor(c)};padding-bottom:2px;margin-bottom:6px;">${depotCode}</div>
            <strong>ROH Depot:</strong> ${depotCode}<br/>
            <strong>Booked Rakes:</strong> ${c}<br/>
            <strong>Total Wagons:</strong> ${wagonTotal}<br/>
            <strong>Overdue Rakes:</strong> <span style="color:${overdue > 0 ? '#ef4444' : '#22c55e'};font-weight:700">${overdue}</span>
          </div>
        `);
        marker.count = c;
        marker.originalRadius = marker.options.radius;
        marker.on({
          mouseover: () => {
            marker.setStyle({ weight: 2, fillOpacity: 1 });
            marker.setRadius(Math.min(12, marker.options.radius + 2));
          },
          mouseout: () => {
            marker.setStyle({ weight: 1, fillOpacity: 0.8 });
            marker.setRadius(getRadius(c, map.getZoom()));
          }
        });
        depotMarkers.push(marker);

        const label = L.marker([coords.lat, coords.lon], {
          icon: L.divIcon({
            className: 'depot-label',
            html: depotCode,
            iconSize: [0, 0],
            iconAnchor: [0, -12]
          }),
          interactive: false
        }).addTo(depotLabelLayer);
        label.count = c;
        depotLabelMarkers.push(label);
      }
    });

    const totalRakes = globalWagonsData.length;

const totalOverdue =
    globalWagonsData.filter(
        w => parseFloat(w['Overdue Days']) > 0
    ).length;

const wagonsEl = document.getElementById('hero-stat-wagons');
const depotsEl = document.getElementById('hero-stat-depots');
const overdueEl = document.getElementById('hero-stat-overdue');
const statLblEl = document.getElementById('heatmap-stat-lbl');

if (wagonsEl) wagonsEl.textContent = totalRakes;
if (depotsEl) depotsEl.textContent = sorted.length;
if (overdueEl) overdueEl.textContent = totalOverdue;

if (statLblEl) {
    statLblEl.textContent =
        `${totalRakes} total rakes · ${sorted.length} active depots · ${totalOverdue} overdue`;
}
    updateDepotLabelVisibility();
  };
})();


(function () {
  let mapB = null, depotLayerB = null, wagonLayerB = null;

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
    } catch (e) { console.warn('Failed to init booked map:', e); }
  }

  window.initBookedMapSafe = function () {
    initBookedMap();
    if (mapB) setTimeout(() => mapB.invalidateSize(true), 50);
    booked_update();
  };

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
      const id = 'booked_s_' + code.replace(/[\W]/g, '_');
      const div = document.createElement('div'); div.className = 'depot-item';
      div.innerHTML = `<input type="checkbox" id="${id}" data-code="${code}" checked> <label for="${id}" style="flex:1">${code}</label>`;
      container.appendChild(div);
    });
  }

  function booked_update() {
    if (!globalWagonsData || !globalOrgsData) return;
    initBookedMap();

    const selected = Array.from(document.querySelectorAll('#booked-depots input[type=checkbox]:checked')).map(cb => cb.dataset.code.toUpperCase());
    document.getElementById('booked-kpi-depots').textContent = selected.length;

    const rows = selected.length === 0 ? [] : globalWagonsData.filter(r => {
      const val = (r['ROH Depot'] || '').trim().toUpperCase();
      return selected.includes(val);
    });

    document.getElementById('booked-kpi-total').textContent = rows.length;

    const totalWagons = rows.reduce((s, r) => s + (parseInt(r['Number of Wagons']) || 0), 0);
    document.getElementById('booked-kpi-wagons').textContent = totalWagons;

    const overdueCount = rows.filter(r => parseFloat(r['Overdue Days']) > 0).length;
    document.getElementById('booked-kpi-overdue').textContent = overdueCount;

    const speed = getBookedSpeed();
    if (speed === null) return;

    // depot-wise counts
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
        const overdue = parseFloat(r['Overdue Days']) || 0;
        const distance = parseFloat(r['Distance (km)']);
        const etaHrs = !Number.isNaN(distance) && distance >= 0 ? distance / speed : null;
        const etaDisplay = etaHrs !== null ? etaHrs.toFixed(2) : '—';
        const baseDate = parseDateTime(r['Last Updated']);
        const arrivalDate = (etaHrs !== null && baseDate) ? new Date(baseDate.getTime() + etaHrs * 3600 * 1000) : null;
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

    const bounds = [];

    Object.entries(counts).forEach(([depot, d]) => {
      const org = shared_getOrgByCode(depot);
      if (!org) return;
      const coords = shared_parseCoord(org.gis_coord);
      if (!coords) return;
      bounds.push([coords.lat, coords.lon]);
      const radius = 6 + Math.sqrt(d.rakes) * 6;
      const color = d.rakes >= 28 ? '#ef4444' : d.rakes >= 14 ? '#f97316' : d.rakes >= 5 ? '#facc15' : '#22c55e';
      L.circleMarker([coords.lat, coords.lon], { radius, fillColor: color, color: '#fff', weight: 1.2, fillOpacity: 0.4 })
        .addTo(depotLayerB)
        .bindPopup(`<strong>${depot}</strong><br/>Rakes: ${d.rakes}<br/>Wagons: ${d.wagons}<br/>Overdue: <span style="color:${d.overdue > 0 ? '#ef4444' : '#22c55e'}">${d.overdue}</span>`);
    });

    rows.forEach(r => {
      const key = (r['ROH Depot'] || '').trim().toUpperCase();
      const org = shared_getOrgByCode(key);
      if (!org) return;
      const coords = shared_parseCoord(org.gis_coord);
      if (!coords) return;
      const jLat = 0.12 * (Math.random() - 0.5);
      const jLon = 0.12 * (Math.random() - 0.5);
      const overdue = parseFloat(r['Overdue Days']) || 0;
      const distance = parseFloat(r['Distance (km)']);
      const etaHrs = !Number.isNaN(distance) && distance >= 0 ? distance / speed : null;
      const etaDisplay = etaHrs !== null ? etaHrs.toFixed(2) : '—';
      const baseDate = parseDateTime(r['Last Updated']);
      const arrivalDate = (etaHrs !== null && baseDate) ? new Date(baseDate.getTime() + etaHrs * 3600 * 1000) : null;
      const arrivalLabel = arrivalDate ? formatDateTime(arrivalDate) : (r['Expected Arrival'] || '—');
      L.circleMarker([coords.lat + jLat, coords.lon + jLon], {
        radius: 9, fillColor: '#00E5FF',
        color: '#04121b', weight: 1.2, fillOpacity: 0.98,
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
      try { mapB.fitBounds(bounds, { maxZoom: 7, padding: [40, 40] }); } catch (e) {}
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
    initBookedMap();
    booked_update();
  };

  document.getElementById('booked-select-all').addEventListener('click', () => booked_selectAll(true));
  document.getElementById('booked-clear-all').addEventListener('click', () => booked_selectAll(false));
  document.getElementById('booked-refresh').addEventListener('click', () => booked_update());
  document.getElementById('booked-recalc').addEventListener('click', () => booked_update());
  document.getElementById('booked-depots').addEventListener('change', () => booked_update());
})();

async function initDashboardCorePipeline() {
  const parseCSV = (path) => new Promise((res, rej) => {
    Papa.parse(path, { download: true, header: true, skipEmptyLines: true, complete: res, error: rej });
  });

  try {
    const [orgsRes, wagonsRes] = await Promise.all([
      parseCSV('fmm_org_m.csv'),
      parseCSV('NKJRH_ROH_20260603_152610.csv')   // ← updated filename
    ]);

    globalOrgsData = orgsRes.data;
    globalWagonsData = wagonsRes.data;

    globalOrgsData.forEach(item => {
      if (item.org_slno) globalOrgLookup[item.org_slno.trim().toUpperCase()] = item;
      if (item.org_code) globalOrgLookup[item.org_code.trim().toUpperCase()] = item;
    });

    if (window.initLiveHeatmapModule) window.initLiveHeatmapModule();
    if (window.initBookedTodepotModule) window.initBookedTodepotModule();

  } catch (err) {
    console.error('Core dynamic load exception:', err);
  }
}

window.addEventListener('DOMContentLoaded', initDashboardCorePipeline);
const distanceLimit =
    parseInt(document.getElementById('distance-filter').value);