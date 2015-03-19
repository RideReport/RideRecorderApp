var db = require('../db.js');
var utils = require('../utils/utils.js');
var tripCache = require('memory-cache');
var simplify = require('simplify-geometry');
var geojsonTools = require('geojson-tools');

exports.show = function(req, res) {
  var trips = db.mongo_client.get('trips');
  
  trips.find({"activityType": 2},{w:1},function(error,trips) {
		if(error){
			res.status(404).send('Not found');
			console.error(error);    
		} else {
		  var tripsData = [];
		  var bikeTotalDistance = 0
      var bikeTripsCount = 0
      var ratedTripsCount = 0
      var totalRatingMagnitude = 0
      
      var today = new Date; // get current date
      var weekAgo = today - 1000 * 60 * 60 * 24 * 31;
      var weekData = {};
      
		  for(i=0; i<trips.length; i++) {
		    var trip = trips[i];
		    var creationDate = new Date(trip.creationDate);
		    if (creationDate > weekAgo) {
		      var dateThing = creationDate.getMonth() + "-" +creationDate.getDate()
		      if (!weekData.hasOwnProperty(dateThing)) {
		        weekData[dateThing] = 1
		      } else {
		        weekData[dateThing] = weekData[dateThing] + 1
		      }
		    }
		    
		    if (trip.locations.length == 0) {
		      continue;
		    }
		    
		     if (trip.activityType == 2) {
      	    bikeTripsCount++
      	    bikeTotalDistance += geojsonTools.getDistance(trip.locations.map(function(loc) {return loc.pos}), 2)
      	    if (trip.rating != 0) {
        	   ratedTripsCount++
        	   if (trip.rating == 1) {
        	    totalRatingMagnitude++ 
        	   }
        	  }
          }

    	}	
    	
    	console.log(weekData)

      return res.render('dashboard', {bikeTotalDistance: bikeTotalDistance, bikeTripsCount: bikeTripsCount, ratedTripsCount: ratedTripsCount, totalRatingMagnitude: totalRatingMagnitude, weekData: weekData});
		}
	});

}