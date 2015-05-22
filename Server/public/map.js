_.templateSettings = {
interpolate: /\{\{(.+?)\}\}/g
};

	var tripLayerGroup = L.layerGroup().addTo(map);

  L.mapbox.accessToken = 'pk.eyJ1IjoicXVpY2tseXdpbGxpYW0iLCJhIjoibmZ3UkZpayJ9.8gNggPy6H5dpzf4Sph4-sA';
  // Replace 'examples.map-i87786ca' with your map id.
  var mapboxTiles = L.tileLayer('https://{s}.tiles.mapbox.com/v4/quicklywilliam.3939fb5f/{z}/{x}/{y}.png?access_token=' + L.mapbox.accessToken, {
      attribution: '<a href="http://www.mapbox.com/about/maps/" target="_blank">Terms &amp; Feedback</a>'
  });
  map.addLayer(mapboxTiles)

	function drawTripsOnMap(geojson){
	  var trips = geojson.features
		map.removeLayer(tripLayerGroup);
		var polylineArray = []

		for (var i = 0; i < trips.length; i++){
			trip = trips[i];

			// leaflet expects lat first.
      locs = trip.geometry.coordinates

			if (trip.properties.activity_type == 2) {
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

	var Incident = Backbone.Model.extend({
		get_type_string: function() {
			switch(this.get('type')) {
					case 0:
							return "Other"
					case 1:
							return "Road Hazard"
					case 2:
							return "Unsafe Intersection"
					case 3:
							return "Bike Lane Ends"
					case 4:
							return "Unsafe Speeds"
					case 5:
							return "Aggressive Motorist"
					case 6:
							return "Insufficient Parking"
					case 7:
							return "Suspected Stolen Bikes"
					}
		},

		get_icon: function() {
	    switch(this.get('type')) {
	        case 0:
	            // Other
	            return L.AwesomeMarkers.icon({
	                icon: 'flag',
	                prefix: 'ion',
	                markerColor: 'lightgray'
	              });
	        case 1:
	            // Road Hazard
	            return L.AwesomeMarkers.icon({
	                icon: 'alert',
	                prefix: 'ion',
	                markerColor: 'red'
	              });
	        case 2:
	            // Unsafe Intersection
	            return L.AwesomeMarkers.icon({
	                icon: 'network',
	                prefix: 'ion',
	                markerColor: 'red'
	              });
	        case 3:
	            // Bike Lane Ends
	            return L.AwesomeMarkers.icon({
	                icon: 'arrow-graph-down-right',
	                prefix: 'ion',
	                markerColor: 'red'
	              });
	        case 4:
	            // Unsafe Speeds
	            return L.AwesomeMarkers.icon({
	                icon: 'speedometer',
	                prefix: 'ion',
	                markerColor: 'red'
	              });
	        case 5:
	            // Aggressive Motirst
	            return L.AwesomeMarkers.icon({
	                icon: 'model-s',
	                prefix: 'ion',
	                markerColor: 'orange'
	              });
	        case 6:
	            // Insufficient Parking
	            return L.AwesomeMarkers.icon({
	                icon: 'code',
	                prefix: 'ion',
	                markerColor: 'darkpurple'
	              });
	        case 7:
	            // Suspected Stolen Bikes
	            return L.AwesomeMarkers.icon({
	                icon: 'eye',
	                prefix: 'ion',
	                markerColor: 'black'
	              });
	        }
		}
	});
  var Trip = Backbone.Model.extend({});

	var IncidentCollection = Backbone.Collection.extend({
			model: Incident
	});



  var IncidentsView = Backbone.View.extend({
		popup_contents: _.template($('script[name=incident-popup]').html()),

		popup_context: function(incident) {
			var ctx = { incident: incident.toJSON() }
			ctx.incident.type_string = incident.get_type_string();
			return ctx;
		},

		update_hash: function(ev) {
			var incident = ev.target.incident;
			window.router.navigate('/incident/' + incident.get('uuid'));
		},

    render: function() {
			var view = this;
      this.markers = this.collection.map(function(m) {
        var marker = L.marker(m.get('pos'), { icon: m.get_icon() });
				marker.bindPopup(view.popup_contents(view.popup_context(m)));
				marker.on('popupopen', view.update_hash);
				m.marker = marker;
				marker.incident = m;
				return marker;
      });

			this.layers = L.layerGroup(this.markers).addTo(map);
    }
  });

	var Router = Backbone.Router.extend({
		routes: {
			'incident/:incident_id': 'show_incident'
		},

		show_incident: function(incident_id) {
			var incident = this.incidentsView.collection.findWhere({ uuid: incident_id });
			incident.marker.openPopup();
		}
	});
