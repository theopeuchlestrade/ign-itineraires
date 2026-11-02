# Mise à jour de l’application web

GitHub Pages fixe ses propres en-têtes de cache. Les exécutables Flutter ne
doivent donc pas dépendre du remplacement de `main.dart.js` sous la même URL.

Le chargeur `app_loader.js` récupère `release.json` avec `cache: no-store`, puis
charge un bootstrap et un programme Dart dont les noms contiennent leur SHA-256.
Les contrôles de publication vérifient que ces empreintes correspondent au
contenu. Le bootstrap ne réactive pas le cache hors ligne de Flutter.

La migration désinscrit uniquement le service worker de ce projet. Le fichier
historique `flutter_service_worker.js` reste publié pour que les anciens
chargeurs puissent activer un worker sans interception et le désinscrire. Il
ne recharge pas les onglets et ne supprime pas les caches partagés par les
autres projets du même domaine GitHub Pages. Les favoris ne sont pas touchés.

Un onglet qui exécutait déjà une ancienne application avant cette migration
ne peut pas remplacer rétroactivement son code en mémoire : il faut le rouvrir
une fois pour recevoir ce correctif. Les ouvertures suivantes découvrent la
version publiée sans demander un second rechargement pour actualiser le code.

Le 2 novembre 2026, le calcul a échoué avant un rechargement puis réussi après.
L’ancien moteur `bdtopo-osrm` renvoie HTTP 400 (ressource inexistante), tandis
que `bdtopo-valhalla` renvoie un itinéraire valide. L’onglet avait été ouvert
pendant le déploiement. Une ancienne application en mémoire/cache est donc
l’explication la plus probable ; la réponse réseau initiale n’a pas été
conservée, ce qui empêche de l’établir rétrospectivement avec certitude.

Validation : `node --test tool/web_loader_test.mjs`, construction via
`scripts/build_web_release.sh`, puis `scripts/check_web_release.rb` et essai
du calcul sur le site publié dès sa première ouverture.

Voir la [documentation Flutter sur le cache web](https://docs.flutter.dev/platform-integration/web/faq).
