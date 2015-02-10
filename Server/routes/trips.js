var db = require('../db.js');
var utils = require('../utils/utils.js');
var NodeCache = require( "node-cache" );
var tripCache = require('memory-cache');

exports.getAll = function(req, res){
  var cachedTrips = tripCache.get("allTrips");
  
  if(cachedTrips){
      console.log("using cached response!");
      return res.json(cachedTrips);
  } else {
      var trips = db.mongo_client.get('trips');

      trips.find({},{w:1},function(error,trips) {
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
                "coordinates": trip.locations.map(function(loc) {return loc.pos.reverse()})
              },
        			"properties": {
        				"id"					:trip._id,
        				"activity_type" : trip.activityType,
        				"creation_date" : trip.creationdate,
        				"rating" : trip.rating,
        				"uuid" : trip.uuid
        			}						
        		});
        	}	

          console.log("caching response!");
          
          // cache for two hours
        	tripCache.put("allTrips", geojson, 120*60*1000);

    		  return res.json(geojson);
    		}
    	});
  }
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
            "coordinates": trip.locations.map(function(loc) {return loc.pos.reverse()})
          },
    			"properties": {
    				"id"					:trip._id,
    				"activity_type" : trip.activityType,
    				"creation_date" : trip.creationdate,
    				"rating" : trip.rating,
    				"uuid" : trip.uuid
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
      "pos" : [reqLocations[i].latitude, reqLocations[i].longitude] 
    })
  }
    
  trips.update({uuid:req.body.uuid}, {
      activityType : req.body.activityType,
      creationDate : req.body.creationDate,
      rating : req.body.rating,
      locations : locations,
      uuid : req.body.uuid
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