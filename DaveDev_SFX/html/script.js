// DaveDev SFX - NUI audio player.
// Sounds resolve to `sounds/<name>.ogg` in the resource named by the payload
// (served as https://cfx-nui-<resource>/sounds/...) or, without a resource,
// to this resource's own html/sounds folder.

const LOCAL_SOUNDS = './sounds/';

function fileName(name) {
  if (!name) return null;
  return name.includes('.') ? name : `${name}.ogg`;
}

function resolveSources(name, resource) {
  const file = fileName(name);
  if (!file) return [];
  const sources = [];
  if (resource) {
    sources.push(`https://cfx-nui-${resource}/sounds/${file}`);
  }
  // Fallback keeps older installs working where sounds were copied in here.
  sources.push(`${LOCAL_SOUNDS}${file}`);
  return sources;
}

function playFrom(sources, index, volume) {
  if (index >= sources.length) return;
  const audio = new Audio(sources[index]);
  audio.volume = Math.max(0, Math.min(1, volume));
  audio.addEventListener('error', () => playFrom(sources, index + 1, volume));
  audio.play().catch(() => playFrom(sources, index + 1, volume));
}

function playSound(name, volume = 0.1, resource = null) {
  playFrom(resolveSources(name, resource), 0, volume);
}

window.addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.action !== 'play') return;
  playSound(data.sound, data.volume, data.resource || null);
});
