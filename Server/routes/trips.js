var db = require('../db.js');

exports.getAll = function(req, res){
  var trips = db.client.get('trips');
  var responseBody = {}
  
  trips.find({},function(error,trips) {
		if(error){
			res.status(404).send('Not found');
			console.error(error);    
		} else {
		  return res.json(trips);
		}
	});
};

exports.new = function(req, res){	
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
  
  console.log(req.body)
    
  trips.insert({
      activityType : req.body.activityType,
      creationDate : req.body.creationDate,
      rating : req.body.rating,
      locations : locations,
      id : req.body.uuid
    }), function(error){			
      if(error) {
				console.error("Error adding trip  : " + error);
				res.status(500).send('Error adding trip');
			} else {
			  console.error("Added trip: " + req.body.uuid);
			  res.status(201).send('Added trip');
			}
  };
};