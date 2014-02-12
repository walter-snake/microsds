// key read from mapconfig.js file
var map, selectControl, selectedFeature, select, control;
var fromProj = new OpenLayers.Projection("EPSG:4326");   // Transform from WGS 1984
var toProj   = new OpenLayers.Projection("EPSG:3857"); // to Spherical Mercator Projection
var mapoptions = {
  units: 'm'
  , projection: "EPSG:3857"
};

var renderer = OpenLayers.Util.getParameters(window.location.href).renderer;
renderer = (renderer) ? [renderer] : OpenLayers.Layer.Vector.prototype.renderers;

//create a style object
var myStyle = new OpenLayers.Style();

//rule used for all points (works for polygons too)
var rule_as = new OpenLayers.Rule({
  filter:  new OpenLayers.Filter.Comparison({
    type: OpenLayers.Filter.Comparison.EQUAL_TO,
    property: "station_state",
    value: "A",
  }),
  symbolizer: {
    fillColor: "#44ff00",
    fillOpacity: 0.8,
    strokeColor: "#22bb00",
    strokeWidth: 2.0,
    strokeDashstyle: "solid",
    label: "${station_name}",
    labelAlign: "tr",
    labelXOffset: 7,
    labelYOffset: 7,
    fontColor: "#cc3300",
    fontOpacity: 1.0,
    fontFamily: "Arial",
    fontSize: 10,
    title: "${station_name}",
    pointRadius: 5
  }
});
var rule_ws = new OpenLayers.Rule({
  filter:  new OpenLayers.Filter.Comparison({
    type: OpenLayers.Filter.Comparison.EQUAL_TO,
    property: "station_state",
    value: "W",
  }),
  symbolizer: {
    fillColor: "#ffcc00",
    fillOpacity: 0.8,
    strokeColor: "#ff9900",
    strokeWidth: 2.0,
    strokeDashstyle: "solid",
    label: "${station_name}",
    labelAlign: "tr",
    labelXOffset: 7,
    labelYOffset: 7,
    fontColor: "#cc3300",
    fontOpacity: 1.0,
    fontFamily: "Arial",
    fontSize: 10,
    title: "${station_name}",
    pointRadius: 5
  }
});
var rule_es = new OpenLayers.Rule({
  filter:  new OpenLayers.Filter.Comparison({
    type: OpenLayers.Filter.Comparison.EQUAL_TO,
    property: "station_state",
    value: "E",
  }),
  symbolizer: {
    fillColor: "#ff5050",
    fillOpacity: 0.8,
    strokeColor: "#cc3300",
    strokeWidth: 2.0,
    strokeDashstyle: "solid",
    label: "${station_name}",
    labelAlign: "tr",
    labelXOffset: 7,
    labelYOffset: 7,
    fontColor: "#cc3300",
    fontOpacity: 1.0,
    fontFamily: "Arial",
    fontSize: 10,
    title: "${station_name}",
    pointRadius: 5
  }
});
var rule_is = new OpenLayers.Rule({
  filter:  new OpenLayers.Filter.Comparison({
    type: OpenLayers.Filter.Comparison.EQUAL_TO,
    property: "station_state",
    value: "I",
  }),
  symbolizer: {
    fillColor: "#888888",
    fillOpacity: 0.8,
    strokeColor: "#222222",
    strokeWidth: 2.0,
    strokeDashstyle: "solid",
    label: "${station_name}",
    labelAlign: "tr",
    labelXOffset: 7,
    labelYOffset: 7,
    fontColor: "#cc3300",
    fontOpacity: 1.0,
    fontFamily: "Arial",
    fontSize: 10,
    title: "${station_name}",
    pointRadius: 5
  }
});
myStyle.addRules([rule_as, rule_is, rule_ws, rule_es]);


// Initialization
function init() {
  map = new OpenLayers.Map("map", mapoptions);

  var road = new OpenLayers.Layer.Bing({
    name: "Road",
    key: apiKey,
    type: "Road"
  });
  var hybrid = new OpenLayers.Layer.Bing({
    name: "Hybrid",
    key: apiKey,
    type: "AerialWithLabels"
  });
  var aerial = new OpenLayers.Layer.Bing({
    name: "Aerial",
    key: apiKey,
    type: "Aerial"
  });

  osm = new OpenLayers.Layer.OSM( "Plain good old OSM");

  // Add the baselayers
  map.addLayers([osm, aerial, road, hybrid]);

  // The station data (as GeoJSon)
  var measurementStations = new OpenLayers.Layer.Vector("Measurement stations", {
    strategies: [new OpenLayers.Strategy.BBOX(),
        new OpenLayers.Strategy.Refresh(
            {interval: refreshrate, force: true
        })
      ],
    protocol: new OpenLayers.Protocol.HTTP({
      url: "measurements.php?Operation=GetMeasurementStations&Format=GeoJSon",
      format: new OpenLayers.Format.GeoJSON({
      externalProjection: fromProj,
      internalProjection: toProj
      })
    }),
    styleMap: myStyle,
    format: new OpenLayers.Format.GeoJSON({
      externalProjection: fromProj,
      internalProjection: toProj
    })
  });
  map.addLayers([measurementStations]);

  // Selection control 
  selectControl = new OpenLayers.Control.SelectFeature(
    [measurementStations], 
    {onSelect: onFeatureSelect, onUnselect: onFeatureUnselect
  });

  // Extended selection control
  /*
  var selectControl = new OpenLayers.Control.SelectFeature(
    [measurementStations],
    {
      clickout: true, toggle: false,
      multiple: false, hover: false,
      toggleKey: "ctrlKey", // ctrl key removes from selection
      multipleKey: "shiftKey" // shift key adds to selection
    }
  );
  */

  /*
  // This actually works: create the function inside 
  measurementStations.events.on({
    "featureselected": function(e) {
      alert("selected feature " + e.feature.attributes.station_uuid);
    },
    "featureunselected": function(e) {
      alert("unselected feature " + e.feature.attributes.station_uuid);
    }
  });
  */

  map.addControl(selectControl);
  selectControl.activate();
  // -- selection control

  resetMap()
} // init

function resetMap()
{
  map.setCenter(new OpenLayers.LonLat(5.0, 52.0).transform(fromProj, toProj), 7);
}

// FeatureSelect functions
function onFeatureSelect(feature) {
  // alert(feature.attributes.station_name);
  displayGraphs(feature);
}

function onFeatureUnselect(feature) {
  // Do nothing, function is here just for documentational purposes
  // alert("");
}  

function displayGraphs(myStation)
{ 
  someImage = document.getElementById('temp');
  someImage.src = "measurements.php?Operation=GetGraph&MeasuredProperty=temp&UUID=" + myStation.attributes.station_uuid + "&PeriodHour=24&Format=micro";
  someImage = document.getElementById('humid');
  someImage.src = "measurements.php?Operation=GetGraph&MeasuredProperty=humid&UUID=" + myStation.attributes.station_uuid + "&PeriodHour=24&Format=micro";
  someImage = document.getElementById('baro');
  someImage.src = "measurements.php?Operation=GetGraph&MeasuredProperty=baro&UUID=" + myStation.attributes.station_uuid + "&PeriodHour=24&Format=micro";
  document.getElementById('station_name').innerHTML = 'station name: ' + myStation.attributes.station_name;
  document.getElementById('station_uuid').innerHTML = 'station uuid: ' + myStation.attributes.station_uuid;
  document.getElementById('date_inuse').innerHTML = 'date in use: ' + myStation.attributes.date_inuse;
  document.getElementById('date_outofuse').innerHTML = 'date out of use: ' + myStation.attributes.date_out_ofuse;
  document.getElementById('measurement_time_last').innerHTML = 'last measurement: ' + myStation.attributes.measurement_time_last;
  document.getElementById('station_state').innerHTML = 'station state: ' + myStation.attributes.station_state;
  // Need to clone the geometry before transformation, otherwise the original point will move to outer space
  pt_trans = myStation.clone().geometry.transform(toProj, fromProj);
  document.getElementById('coordinates').innerHTML = 'lat, lon: ' + pt_trans.y.toFixed(4) + ',' + pt_trans.x.toFixed(4);
}
