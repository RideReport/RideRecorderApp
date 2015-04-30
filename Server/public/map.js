	var tripLayerGroup = L.layerGroup().addTo(map);

  L.mapbox.accessToken = 'pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA';
  // Replace 'examples.map-i87786ca' with your map id.
  var mapboxTiles = L.tileLayer('https://{s}.tiles.mapbox.com/v4/quicklywilliam.3939fb5f/{z}/{x}/{y}.png?access_token=' + L.mapbox.accessToken, {
      attribution: '<a href="http://www.mapbox.com/about/maps/" target="_blank">Terms &amp; Feedback</a>'
  });
  map.addLayer(mapboxTiles)
  
	function drawTripsOnMap(geojson){
	  drawOnMap(geojson, false)
  }
  
  function drawTripsAndIncidentsOnMap(geojson){
	  drawOnMap(geojson, true)    
  }
  
	function drawOnMap(geojson, showIncidents){
	  var trips = geojson.features
		map.removeLayer(tripLayerGroup);	
		var polylineArray = []
		
		for (var i = 0; i < trips.length; i++){
			trip = trips[i];
			
			// leaflet expects lat first.
      locs = trip.geometry.coordinates
			  			  			
			if (trip.properties.activity_type == 2) {
			  if (showIncidents && trip.properties.incidents) {
  			  for (var v = 0; v < trip.properties.incidents.length; v++) {
  			    var incident = trip.properties.incidents[v];
  			    var marker = L.marker(incident.pos);
  			    marker.bindPopup("<b>Type: " + incident.type + "</b><br><i>" + incident.creationDate + "</i><br/>" + (incident.body ? incident.body : "")).openPopup();
  			    polylineArray.push(marker);
  			  }
		    }
			  
			  var polyline;
			  if (trip.properties.rating == 2) {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: 'red',
            weight: 3,
            opacity: 0.5,
            smoothFactor: 1}
          );
        } else if (trip.properties.rating == 1) {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: '#00CC00',
            weight: 3,
            opacity: 0.2,
            smoothFactor: 1}
          );
        } else {
          polyline = new L.Polyline(
    			  locs, 
    			  {color: '#EAFF00',
            weight: 3,
            opacity: 0.2,
            smoothFactor: 1}
          );
        }
        polylineArray.push(polyline);
			}
		}			
		
		tripLayerGroup = L.layerGroup(polylineArray).addTo(map);
	}