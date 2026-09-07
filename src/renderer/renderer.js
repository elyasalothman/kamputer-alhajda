'use strict';

const AR_DIGITS = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

function toArabicDigits(input) {
  return String(input).replace(/[0-9]/g, (d) => AR_DIGITS[Number(d)]);
}

function formatUptime(totalSeconds) {
  const days = Math.floor(totalSeconds / 86400);
  const hours = Math.floor((totalSeconds % 86400) / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const parts = [];
  if (days) parts.push(`${toArabicDigits(days)} يوم`);
  if (hours) parts.push(`${toArabicDigits(hours)} ساعة`);
  parts.push(`${toArabicDigits(minutes)} دقيقة`);
  return parts.join(' و');
}

function set(id, value) {
  const el = document.getElementById(id);
  if (el) el.textContent = value;
}

function tickClock() {
  const now = new Date();
  const hh = String(now.getHours()).padStart(2, '0');
  const mm = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');
  set('clock', toArabicDigits(`${hh}:${mm}:${ss}`));
}

async function loadSystemInfo() {
  try {
    const info = await window.kamputer.getSystemInfo();
    set('owner', info.owner);
    set('platform', info.platform);
    set('cpu', info.cpuModel);
    set('cores', toArabicDigits(info.cpuCount));
    set('mem', `${toArabicDigits(info.totalMemGib)} غيغابايت`);
    set('freemem', `${toArabicDigits(info.freeMemGib)} غيغابايت`);
    set('host', info.hostname);
    set('uptime', formatUptime(info.uptimeSeconds));
    set('arch', info.arch);
    set('appver', toArabicDigits(info.appVersion));
    set('ever', toArabicDigits(info.electron));
    set('cver', toArabicDigits(info.chrome));
    set('nver', toArabicDigits(info.node));
  } catch (err) {
    set('welcome', 'تعذّر تحميل معلومات النظام.');
    console.error(err);
  }
}

document.getElementById('refresh').addEventListener('click', loadSystemInfo);

tickClock();
setInterval(tickClock, 1000);
loadSystemInfo();
