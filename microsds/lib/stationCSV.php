<?php
class stationCSV {
  private $myStationData;

  function __construct($data)
  {
    $this->myStationData = $data;
  }

  // Hard coded conversion of the station data to CSV
  public function toCSV()
  {
    print "LON;LAT;STATUS\n";
    while ($row = pg_fetch_row($this->myStationData))
    {
      print $row[6].";".$row[5].";".$row[8]."\n";
    }
  }
}
?>
