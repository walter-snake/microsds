<?php
// all graphs on one page
class graphPage {
  private $myStationData;
  private $myDb;
  private $statuuid;
  private $period_hour;

  // function __construct($statuuid, $db)
  function __construct($statuuid, $period_hour)
  {
    //$this->myDb = $db;
    $this->statuuid = $statuuid;
    $this->period_hour = $period_hour;
  }

  // Generate a full HTML page
  public function toHtmlPage() {
    print "<!DOCTYPE html>";
    print "<html>";
    print "<head>";
    print "<title>Weather data service, educational project.</title>";
    print '<link rel="stylesheet" href="mystyle.css">';
    print "</head>";
    print "<body>";
    print "<h1>Weather data service - as an educational project</h1><br />";
    print '<a href="measurements.php?Operation=GetMeasurements">All measurement data (CSV)</a><br />';
    print '<a href="measurements.php?Operation=GetMeasurementStations">List of the measurement stations</a><br />';
    print '<a href="map.html">Map of the measurement stations</a><br />';
    print '<hr />';
    print '<h2>Graphs</h2>';
    print '<img src="measurements.php?Operation=GetGraph&MeasuredProperty=temp&UUID='.$this->statuuid.'&PeriodHour='.$this->period_hour.'"/>';
    print '<br />';
    print '<img src="measurements.php?Operation=GetGraph&MeasuredProperty=humid&UUID='.$this->statuuid.'&PeriodHour='.$this->period_hour.'"/>';
    print '<br />';
    print '<img src="measurements.php?Operation=GetGraph&MeasuredProperty=baro&UUID='.$this->statuuid.'&PeriodHour='.$this->period_hour.'"/>';
    print '<br />';
    print "</body>";
    print "</html>";
  }
}
?>
