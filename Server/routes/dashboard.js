var db = require('../db.js');
var utils = require('../utils/utils.js');
var tripCache = require('memory-cache');
var simplify = require('simplify-geometry');
var geojsonTools = require('geojson-tools');

exports.show = function(req, res) {
  var cachedTrips = tripCache.get("allTrips");
  
  if(!cachedTrips){
    return res.redirect("/trips");
  }
  
  var bikeTotalDistance = 0
  var bikeTripsCount = 0
  var trips = cachedTrips.features
  var ratedTripsCount = 0
  var totalRatingMagnitude = 0
	for (var i = 0; i < trips.length; i++){
	  if (trips[i].properties.activity_type == 2) {
	    bikeTripsCount++
	    bikeTotalDistance += geojsonTools.getDistance(trips[i].geometry.coordinates, 2)
	    if (trips[i].properties.rating != 0) {
  	   ratedTripsCount++
  	   if (trips[i].properties.rating == 1) {
  	    totalRatingMagnitude++ 
  	   }
  	  }
    }
  }
  
  
  return res.render('dashboard', {bikeTotalDistance: bikeTotalDistance, bikeTripsCount: bikeTripsCount, ratedTripsCount: ratedTripsCount, totalRatingMagnitude: totalRatingMagnitude});
}