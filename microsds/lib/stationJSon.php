<?php
class stationJSon {
  private $myStationData;

  function __construct($data)
  {
    $this->myStationData = $data;
  }

  // Hard coded conversion of the station data to GeoJSon
  public function toGeoJSon()
  {
    $i = 0;
    //print 'var measurementStations = {';
    print '{';
    print '"type": "FeatureCollection",';
    print '"features": [';
    while ($row = pg_fetch_row($this->myStationData))
    {
      if ($i > 0)
        print ',';
      print '{';
      print $this->pointToGeoJSon($row[6],$row[5]);
      print ', "type": "Feature"';
      print ', "properties": {';
      print '    "station_uuid": "'.$row[1].'"';
      print '    , "station_name": "'.$row[2].'"';
      print '    , "date_inuse": "'.$row[3].'"';
      print '    , "date_outofuse": "'.$row[4].'"';
      print '    , "measurement_time_last": "'.$row[7].'"';
      print '    , "station_state": "'.$row[8].'"';
      print '  },';
      print '"id":'.$row[0];
      print '}';
      $i++;
    }
    print ']}';
    //print ';';
  }

  function pointToGeoJSon($x, $y)
  {
    return '"geometry": {"type": "Point", "coordinates": ['.$x.','.$y.']}';
  }
}
?>
