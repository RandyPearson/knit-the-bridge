'use strict';

/* App Module */

angular.module('ktb',['ktb.controllers', 'ktb.filters', 'ktb.services']).
  config(['$routeProvider', '$locationProvider', function($routeProvider, $locationProvider) {
    // $locationProvider.html5Mode(true);
    $routeProvider.
      when('/', {templateUrl: 'partials/splash.html'}).
      when('/about', {templateUrl: 'partials/about.html'}).
      when('/panels', {templateUrl: 'partials/panel-list.html', controller: "PanelListCtrl"}).
      when('/panels/:panelId', {templateUrl: 'partials/panel-detail.html', controller: "PanelDetailCtrl"}).
      otherwise({ redirectTo: '/'});
}]);
