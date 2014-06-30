<?php
class stationKML {
  private $myStationData;

  function __construct($data)
  {
    $this->myStationData = $data;
  }

  // Hard coded conversion of the station data toKML 
  public function toKML()
  {
    print $this->getHeader();
    while ($row = pg_fetch_row($this->myStationData))
    {
      print $this->getPlaceMark($row[6], $row[5], $row[8])."\n";
    }
    print "</Folder>";
    print $this->getSchema();
    print $this->getFooter();
  }

  private function getPlaceMark($lon, $lat, $status)
  {
    $pm = '<Placemark>';
    $pm = $pm.'<ExtendedData><SchemaData schemaUrl="#sensor-station">';
    $pm = $pm.'<SimpleData name="status">'.$status.'</SimpleData>';
    $pm = $pm.'</SchemaData></ExtendedData>';
    $pm = $pm.$this->getPoint($lon, $lat);
    $pm = $pm.'</Placemark>';

    return $pm;
  }

  private function getPoint($lon, $lat)
  {
    return '<Point><coordinates>'.$lon.','.$lat.'</coordinates></Point>';
  }

  private function getHeader()
  {
    return '<?xml version="1.0" encoding="utf-8" ?>'
      .'<kml xmlns="http://www.opengis.net/kml/2.2">'
      .'<Document><Folder><name>sensor-station</name>';
  }

  private function getSchema()
  {
    return '<Schema name="sensor-station" id="sensor-station">'
      .'<SimpleField name="status" type="string"></SimpleField>'
      .'</Schema>';
  }

  private function getFooter()
  {
    return '</Document></kml>';
  }
}
?>
