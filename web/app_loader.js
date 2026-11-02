// Keep this loader independent of Flutter so cached HTML can discover a release.
(async function loadApplication() {
  const base = new URL('.', document.baseURI);
  try {
    // Unregister only this application's legacy worker. Other Pages projects
    // share this origin. Unknown, hashed asset URLs bypass its resource cache
    // even while it still controls the current document.
    if ('serviceWorker' in navigator) {
      const registration = await navigator.serviceWorker.getRegistration(base.href);
      if (registration?.scope === base.href) await registration.unregister();
    }
    const response = await fetch(new URL('release.json', base), { cache: 'no-store' });
    if (!response.ok) throw new Error(`Release lookup failed (${response.status})`);
    const release = await response.json();
    if (!/^flutter_bootstrap\.[0-9a-f]{64}\.js$/.test(release.bootstrap)) {
      throw new Error('Invalid release manifest');
    }
    const script = document.createElement('script');
    script.src = new URL(release.bootstrap, base).href;
    script.onerror = () => showRetry();
    document.head.append(script);
  } catch (_) {
    showRetry();
  }

  function showRetry() {
    const message = document.createElement('p');
    message.textContent = 'Le chargement a échoué. Vérifiez votre connexion puis réessayez.';
    const retry = document.createElement('button');
    retry.textContent = 'Réessayer';
    retry.onclick = () => {
      message.remove();
      retry.remove();
      return loadApplication();
    };
    document.body.append(message, retry);
  }
})();
