'use strict';

/* Services */

angular.module('ktb.services', ['ngResource']).
  factory('Panels', function($resource) {
    return $resource('ktb-pub/installedPanels.json', {}, {
      query: { method: 'GET', isArray: false }
    });
  }).
  factory('Panel', function($resource) {
    return $resource('ktb-pub/PanelInfo.:panelId.json');
  });
