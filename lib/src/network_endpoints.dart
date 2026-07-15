abstract final class NetworkEndpoints {
  static const geoplateformeHost = 'data.geopf.fr';
  static const googleMapsHost = 'www.google.com';
  static const appleMapsHost = 'maps.apple.com';
  static const officialMapHost = 'theopeuchlestrade.github.io';
  static const officialMapPath = '/ign-itineraires/';
  static final officialLegalNoticeUri = Uri.https(
    officialMapHost,
    '${officialMapPath}legal.html',
  );

  static const applicationHttpHosts = <String>{geoplateformeHost};
  static const explicitExternalNavigationHosts = <String>{
    googleMapsHost,
    appleMapsHost,
  };
  static const explicitPolicyHosts = <String>{officialMapHost};
  static const registeredHosts = <String>{
    ...applicationHttpHosts,
    ...explicitExternalNavigationHosts,
    ...explicitPolicyHosts,
  };
}
