# Third-Party Notices

This repository contains source code and references to third-party software,
services, data, fonts, and marks used by IGN Itinéraires.

## Packages and Tooling

Flutter, Dart, `flutter_map`, Geolocator, shared_preferences,
url_launcher, wakelock_plus, and other dependencies are licensed by their
respective authors. See `pubspec.lock` and upstream package metadata for exact
versions and licence information.

## Manrope Font

The bundled Manrope font is copyright The Manrope Project Authors and licensed
under the SIL Open Font License 1.1. Its copyright notice and complete licence
are provided in [`assets/fonts/OFL.txt`](assets/fonts/OFL.txt).

## Map and Routing Services

The application uses services exposed through cartes.gouv.fr and the French
Géoplateforme, including address autocomplete, route calculation, and IGN Plan
map tiles. Data, tiles, service names, and required attribution remain subject
to their respective providers' terms and intellectual-property rights.

Service quotas and fair-use rules are controlled by the provider and can
change independently of this project. Consult the current Géoplateforme limits
before operating or distributing a build; WMTS tile delivery is documented as
a notable exception to the per-IP rate-limiting mechanism. See:

- <https://cartes.gouv.fr/aide/fr/guides-utilisateur/utiliser-les-services-de-la-geoplateforme/limites-d-usage/>
- <https://cartes.gouv.fr/cgu/>

The visible `© IGN – cartes.gouv.fr` attribution must be retained. Data licences
remain those declared in the metadata of each Géoplateforme resource.

## External Navigation

Google Maps, Apple Maps, Android navigation applications, Flutter, Dart,
GitHub, Google, Apple, IGN, cartes.gouv.fr, and other third-party names and
service marks remain the property of their respective owners. Their mention is
for interoperability or attribution and does not imply endorsement.

## IGN Itinéraires Brand Assets

IGN Itinéraires names, logos, app icons, screenshots, product copy, domains, and other
brand assets are governed by `TRADEMARKS.md`, not by the source-code licence.
