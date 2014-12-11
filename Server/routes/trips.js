exports.getAll = function(req, res){

};

exports.new = function(req, res){
  var date = req.body.date;
  var rating = req.body.rating;
  
  var reqLocations = req.body.locations
  var locations = []
  for(i=0; i<reqLocations.length;i++) {
    locations.push({
      "course" : reqLocations[i].course,
      "date" : reqLocations[i].date,
      "horizontalAccuracy" : reqLocations[i].horizontalAccuracy,
      "speed" : reqLocations[i].speed,
      "pos" : [reqLocations[i].longitude, reqLocations[i].latitude] 
    })
  }

  console.log(req.body);

  db.client.insert({
      type : req.body.type,
      date : req.body.date,
      rating : req.body.rating,
      locations : location
    }), function(error){
      if(error) {
				console.error("Error adding trip  : " + error);
			} else {
		    res.end('success');
			}
  };
};