  $(document).ready(function(){
  	navigator.geolocation.getCurrentPosition(gotPosition);
  })
	
	var tripLayerGroup = L.layerGroup().addTo(map);

  var googleLayer = new L.Google('ROADMAP');
  map.addLayer(googleLayer);
  
  function gotPosition(position) {
    map.setView([position.coords.latitude, position.coords.longitude], 14);
  }

	function getTrips(e){			
		bounds = map.getBounds();
		url = "trips";
		$.get(url, drawTripsOnMap, "json");
	}
	
	function drawTripsOnMap(geojson){
	  var trips = geojson.features
		map.removeLayer(tripLayerGroup);  		
		var polylineArray = []
		
		for (var i = 0; i < trips.length; i++){
			trip = trips[i];
			
			// leaflet expects lat first.
			locs = trip.geometry.coordinates.map(function(loc) {return loc.reverse()});
			  			  			
			if (trip.properties.activity_type == 2) {
			  var polyline;
			  if (trip.properties.rating == 2) {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: 'red',
            weight: 3,
            opacity: 0.4,
            smoothFactor: 1}
          );
        } else if (trip.properties.rating == 1) {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: '#00CC00',
            weight: 3,
            opacity: 0.5,
            smoothFactor: 1}
          );
        } else {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: 'grey',
            weight: 3,
            opacity: 0.4,
            smoothFactor: 1}
          );
        }
        polylineArray.push(polyline);
			}
		}			
		
		tripLayerGroup = L.layerGroup(polylineArray).addTo(map);
	}
	map.whenReady(getTrips)