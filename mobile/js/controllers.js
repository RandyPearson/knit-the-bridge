'use strict';

/* Controllers */

angular.module('ktb.controllers', []).
  controller('PanelListCtrl', ['$scope', 'Panels', function($scope, Panels) {
    $scope.panels = Panels.query(function() {
      $scope.panels.installed_panel_set.map(function(panel) {
        delete panel.pnl_pk;
        panel.image = panelImageUrl(panel.pnl_id);
        panel.loc_side = panel.loc_side == "Down" ? "downriver" : "upriver";
        panel.orientation = panel.orientation == "Outer" ? "outside" : "inside";
        panel.artists = panel.artist_set.map(function(artist) {
          return artist.name;
        }).join(', ');
        return panel;
      });
    });
  }]).
  controller('PanelDetailCtrl', ['$scope', '$location', '$routeParams', 'Panel', function($scope, $location, $routeParams, Panel) {
    Panel.get({panelId:$routeParams.panelId}, function(panel) {
      panel.image = panelImageUrl(panel.pnl_id);
      if (panel.story == null) { panel.story = defaultStory(panel.pnl_id.slice(-3)); }
      $scope.panel = panel;
    });

    $scope.loadDisqus = function() {
      window.disqus_shortname = 'knitthebridge'; // required: replace example with your forum shortname
      window.disqus_identifier = $location.path();
      window.disqus_url = 'http://mobile.knitthebridge.com/#' + $location.path();
      window.disqus_title = 'Panel ' + $location.path().slice(-3);
      console.log('Title: ' + window.disqus_title);
      console.log('Url: ' +window.disqus_url);

      // * * DON'T EDIT BELOW THIS LINE * *
      (function() {
          var dsq = document.createElement('script'); dsq.type = 'text/javascript'; dsq.async = true;
          dsq.src = '//knitthebridge.disqus.com/embed.js';
          (document.getElementsByTagName('head')[0] || document.getElementsByTagName('body')[0]).appendChild(dsq);
      })();
    };
  }]).
  controller('AppCtrl', ['$scope', '$location', function($scope, $location) {
    $scope.submit = function () {
      $scope.search = this.search;
      $location.url('panels');
    };

    $scope.updateScope = function () {
      $scope.search = this.search;
    };
  }]);

// private

function panelImageUrl(id) {
  return "http://www.knitthebridge.com/ktb-photos/panels/0/" + id + "/" + id + "_main.jpeg";
}

function defaultStory(panelId) {
  var story = "<p>Are you the artist of this panel? Do you have a story you want to tell?</p>";
  story += "<p><a href=\"mailto:knitthebridge+story@gmail.com?subject=Story for Panel " + panelId + "\">Email Us</a></p>";
  return story;
}
