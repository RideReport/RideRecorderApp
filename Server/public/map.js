  $(document).ready(function(){
  	navigator.geolocation.getCurrentPosition(gotPosition);
  })
	
	var tripLayerGroup = L.layerGroup().addTo(map);

  L.mapbox.accessToken = 'pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA';
  // Replace 'examples.map-i87786ca' with your map id.
  var mapboxTiles = L.tileLayer('https://{s}.tiles.mapbox.com/v4/quicklywilliam.l4imi65m/{z}/{x}/{y}.png?access_token=' + L.mapbox.accessToken, {
      attribution: '<a href="http://www.mapbox.com/about/maps/" target="_blank">Terms &amp; Feedback</a>'
  });
  map.addLayer(mapboxTiles)
  
  function gotPosition(position) {
    map.setView([position.coords.latitude, position.coords.longitude], 14);
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
            opacity: 0.6,
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