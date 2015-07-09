var db = require('../db.js');
var _ = require('underscore');
var utils = require('../utils/utils.js');
var NodeCache = require( "node-cache" );
var tripCache = require('memory-cache');
var simplify = require('simplify-geometry');

exports.getAll = function(req, res){
  var cachedTrips = tripCache.get("allTrips");

  if(cachedTrips){
    console.log("using cached response!");
    return res.json(cachedTrips);
  } else {
    var trips = db.mongo_client.get('trips');
    var geojson = { "type": "FeatureCollection",
      "features": []
    };

    trips.find({"activityType": 2},{w:1}).each(function(trip) {
      if (trip.locations.length == 0) {
        return;
      }
      var unsimplifiedLocs = trip.locations.map(function(loc) {return loc.pos})
      var locs = simplify(unsimplifiedLocs, .00005);
      geojson.features.push({
        "type": "Feature",
        "geometry": {
          "type": "LineString",
          "coordinates": locs
        },
        "properties": {
          "activity_type" : trip.activityType,
          "rating" : trip.rating,
          "incidents" : trip.incidents
        }
      });
    })
    .error(function(err) {
      res.status(404).send('Not found');
      console.error(err);
    })
    .success(function() {
      geojson.properties = {
        incidents: _.compact(_.flatten(_.pluck(_.pluck(geojson.features, 'properties'), 'incidents')))
      };

      console.log("caching response!");

      // cache for two hours
      tripCache.put("allTrips", geojson, 120*60*1000);

      return res.json(geojson);
    });
  }
};

exports.getRaw = function(req, res){
  var trips = db.mongo_client.get('trips');

  trips.find({"activityType": 2},{w:1}).each(function(trip) {
		if(error){
			res.status(404).send('Not found');
			console.error(error);
		} else {
		  var geojson = { "type": "FeatureCollection",
          "features": []
           };
		  for(i=0; i<trips.length; i++) {
        var trip = trips[i];
        geojson.features.push({
    			"type": "Feature",
    			"geometry": {
            "type": "LineString",
            "coordinates": trip.locations.map(function(loc) {return loc.pos})
          },
    			"properties": {
    				"activity_type" : trip.activityType,
    				"rating" : trip.rating,
    				"incidents" : trip.incidents
    			}
    		});
    	}
		  return res.json(geojson);
	  }
	});
};


exports.getTripsOnDate = function(req, res){
  var trips = db.mongo_client.get('trips');

  var todayString = req.params.date

  trips.find({"creationDate": { $regex: "^" + todayString}},{w:1},function(error,trips) {
		if(error){
			res.status(404).send('Not found');
			console.error(error);
		} else {
		  var geojson = { "type": "FeatureCollection",
          "features": []
           };
		  for(i=0; i<trips.length; i++) {
        var trip = trips[i];
        geojson.features.push({
    			"type": "Feature",
    			"geometry": {
            "type": "LineString",
            "coordinates": trip.locations.map(function(loc) {return loc.pos})
          },
    			"properties": {
    				"activity_type" : trip.activityType,
    				"rating" : trip.rating,
    				"incidents" : trip.incidents
    			}
    		});
    	}
		  return res.json(geojson);
	  }
	});
};

exports.save = function(req, res){
  var trips = db.mongo_client.get('trips');

  var reqLocations = req.body.locations
  var locations = []
  for(i=0; i<reqLocations.length;i++) {
    locations.push({
      "course" : reqLocations[i].course,
      "date" : reqLocations[i].date,
      "horizontalAccuracy" : reqLocations[i].horizontalAccuracy,
      "speed" : reqLocations[i].speed,
      "pos" : [reqLocations[i].latitude, reqLocations[i].longitude],
    })
  }

  var reqIncidents = req.body.incidents
  var incidents = []
  for(i=0; i<reqIncidents.length;i++) {
    incidents.push({
      "creationDate": reqIncidents[i].creationDate,
      "type": reqIncidents[i].incidentType,
      "body": reqIncidents[i].incidentBody,
      "uuid": reqIncidents[i].uuid,
      "pos" : [reqIncidents[i].latitude, reqIncidents[i].longitude]
    })
  }
  trips.update({uuid:req.body.uuid}, {
      original: req.body,
      activityType : req.body.activityType,
      creationDate : req.body.creationDate,
      rating : req.body.rating,
      locations : locations,
      incidents : incidents,
      uuid : req.body.uuid,
      owner : req.body.ownerId
    }, {w:1, upsert:true}, function(error, result){
      if(error) {
				console.error("Error adding trip  : " + error);
				return res.sendStatus(500);
			} else {
			  console.error("Added trip: " + req.body.uuid);
			  return res.sendStatus(201);
			}
  });
};
