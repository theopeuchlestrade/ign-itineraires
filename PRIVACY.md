# Privacy

IGN Itinéraires is designed to work without accounts, advertisements, analytics
tools, or an application API operated by IGN Itinéraires.

This document describes the data flows of version `1.0.0`. The project is
unofficial and is not affiliated with IGN or the French administration.

## Data Sent Over the Network

| Service | Data | When |
| --- | --- | --- |
| `data.geopf.fr/geocodage/completion/` | text entered in search | after three characters, with debounce |
| `data.geopf.fr/navigation/itineraire` | start and end coordinates, mode, and calculation options | initial calculation and off-route recalculation |
| `data.geopf.fr/wmts` | visible tile coordinates | map display and movement |
| `www.google.com`, `maps.apple.com`, or an Android navigation application | start, end, and mode | only after an explicit external-navigation action |
| legal notices on GitHub Pages | no route data; ordinary connection metadata only | when the legal notice is opened from a native build |
| system or browser voice engine | instruction text | only when voice is enabled; local or remote processing depends on the installed engine |

As with any Internet connection, the contacted service also receives the IP
address and technical metadata necessary for the request. The application does
not transmit GPS position to an IGN Itinéraires application API.

Continuous GPS data is processed locally. A position is sent to the
Géoplateforme to calculate the actual departure when guidance starts and when an
off-route recalculation is necessary.

Search does not transmit the current position to rank results. Route calculation uses a `POST` request so that coordinates do not appear in the URL.

## Data Stored on Device

- Up to twenty favorite destinations;
- Voice activation preference;
- History activation;
- Maximum ten recent trips if history is enabled.

History is disabled by default. Disabling it or using the clear-history action
deletes locally stored trips.

Flutter uses `shared_preferences`: application storage on Android and iOS, and browser storage on the web. This data is not synchronized.

Deleting the application, clearing its storage, or clearing the website data
also deletes these values. No server-side copy of favorites or route history is
kept by IGN Itinéraires.

## Official Web Hosting Logs

The application (deployed on GitHub Pages) is served through a static hosting service. These systems may process the IP address,
request date, user agent, requested asset path, and response status to operate
the service. Search text, route coordinates, GPS fixes, favorites, and route
history are not sent to this static host.

**Legal basis:** Processing is based on the legitimate interest of the editor to
operate and secure the service (Article 6(1)(f) GDPR).

**Recipients:** Access logs are processed by the hosting provider (GitHub, Inc.)
according to their privacy policy.

**Retention period:** Log data retention is governed by the hosting provider's
policy. For GitHub Pages, see:
https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement

**Private requests concerning GitHub hosting data:** Do not publish a data-rights
request, IP address, home address, or route in a repository issue. The maintainer
cannot access or erase GitHub Pages access logs. Requests concerning personal
data processed by GitHub must be sent to `privacy@github.com`; privacy feedback
or concerns may be sent to its Data Protection Officer at `dpo@github.com`, as
documented in the GitHub General Privacy Statement linked above.

Public repository issues may be used only for non-sensitive questions about the
application's documented behavior. IGN Itinéraires has no account database or
server-side copy of searches, routes, favorites, or GPS fixes on which the
maintainer could perform an access, rectification, or erasure operation.

## Fonts and Resources

The Manrope font is included in the application. It is not downloaded from Google Fonts at startup. Its OFL license is provided in `assets/fonts/OFL.txt`.

## Permissions

Location is requested only while the application is in use. No background
location permission is requested. When the application enters the background,
GPS tracking, voice, and the screen wake lock are suspended.

On Android and recent iOS versions, users can grant approximate rather than
precise location. Approximate fixes can still select a rough departure, but
built-in mobile guidance is suspended until precise location is available.

## Application Endpoint Registry

Application-owned HTTP traffic is built only for `data.geopf.fr`. Google and
Apple URLs are created only after an explicit external-navigation action, and
the configured Map host only when a native user opens the legal notice.
The endpoint registry is centralized in the source code and covered by tests.
On the GitHub Pages deployment, a static Content Security Policy meta tag
limits web image and connection targets to the documented boundary. The
container deployment also sends HTTP security headers, including the same
network boundary. An installed system or browser speech engine can process
spoken instruction text locally or remotely.

## Development Guarantees

Any new network dependency, audience measurement, or data collection must be
documented here and reviewed before release. The project aims to keep a short,
testable domain list and not to integrate trackers by default.
