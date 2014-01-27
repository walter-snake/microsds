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
    print 'var measurementStations = {';
    print '"type": "FeatureCollection",';
    print '"features": [';
    while ($row = pg_fetch_row($this->myStationData))
    {
      if ($i > 0)
        print ',';
      print '{';
      print $this->pointToGeoJSon($row[5],$row[4]);
      print ', "type": "Feature"';
      print ', "properties": {';
      print '    "station_uuid": "'.$row[6].'"';
      print '    , "station_name": "'.$row[1].'"';
      print '    , "date_inuse": "'.$row[2].'"';
      print '    , "date_outofuse": "'.$row[3].'"';
      print '  },';
      print '"id":'.$row[0];
      print '}';
      $i++;
    }
    print ']}';
    print ';';
  }

  function pointToGeoJSon($x, $y)
  {
    return '"geometry": {"type": "Point", "coordinates": ['.$x.','.$y.']}';
  }
}
?>
