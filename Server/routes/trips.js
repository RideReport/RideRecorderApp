var db = require('../db.js');

exports.getAll = function(req, res){
  var trips = db.client.get('trips');
  var responseBody = {}
  
  trips.find({},{w:1},function(error,trips) {
		if(error){
			res.status(404).send('Not found');
			console.error(error);    
		} else {
		  return res.json(trips);
		}
	});
};

exports.save = function(req, res){	
  var trips = db.client.get('trips');

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