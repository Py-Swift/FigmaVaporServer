async function doAction(action) {
  const log = document.getElementById('log');
  log.textContent = 'Sending: ' + action + '...';
  try {
    const res = await fetch('/lab/action', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ action: action })
    });
    log.textContent = '<- ' + await res.text();
  } catch (e) { log.textContent = 'Error: ' + e.message; }
}

async function sendJs() {
  const code = document.getElementById('jsInput').value.trim();
  if (!code) { document.getElementById('log').textContent = 'Nothing to send.'; return; }
  const log = document.getElementById('log');
  log.textContent = 'Sending JS...';
  try {
    const res = await fetch('/command', {
      method: 'POST',
      headers: { 'Content-Type': 'text/plain' },
      body: code
    });
    log.textContent = res.ok ? 'Sent to Figma.' : 'Error: ' + res.status;
  } catch (e) { log.textContent = 'Error: ' + e.message; }
}

function clearLog() { document.getElementById('log').textContent = 'Ready.'; }
