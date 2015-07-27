var db = require('../db.js');
var _ = require('underscore');
var utils = require('../utils/utils.js');
var NodeCache = require( "node-cache" );
var tripCache = require('memory-cache');
var simplify = require('simplify-geometry');

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
