'use strict';

/* filters */

angular.module('ktb.filters', [])
  .filter('strip_panel_id', function() {
    return function(input) {
      if ( input !== undefined ) { return input.slice(-3); };
    }
  });
