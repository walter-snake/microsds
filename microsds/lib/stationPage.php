<?php

class stationPage {
  private $myStationData;
  private $myDb;

  function __construct($data, $db)
  {
    $this->myStationData = $data;
    $this->myDb = $db;
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
    print '<a href="map.html">Map of the measurement stations</a>';
    print '<hr />';
    print '<h2>Station details, graphs and data</h2>';
    print '<ul>';
    print '<li>The graphs contain data from the past 24 hours by default.</li>';
    print '<li>The data download options deliver data from the database with a theoretical maximum of 100,000 records (this might not be enough for your data, or too much for the system). The database is not limited however, so on request more data could be made available.</li>';
    print '</ul>';
    print '<strong>Station status</strong>';
    print '<table><tr><td class="active">&lt; 30 min</td></tr><tr><td class="warning">&gt; 30 min, &lt; 1 day</td></tr><tr><td class="error">&gt; 1 day</td></tr></table><br />';
    print '<table>';
    print '<tr><th>name</th><th>activated</th><th>de-activated</th><th>lat</th><th>lon</th><th>last measurement</th>';
    print '<th>graphs</th><th>download</th></tr>';
    while ($row = pg_fetch_row($this->myStationData))
    {
      print "<tr>";
      if ($row[3] == "") // this is an active station, get status
      {
        $active = 1;
        // here figure out the status based on last seen
        $lastseen = new DateTime($this->myDb->GetLastSeen($row[0]));
        $now = new DateTime("now");
        $age_seconds = abs($now->getTimestamp()-$lastseen->getTimestamp());
      } 
      else  // not an active station, we don't care about status
      {
        $active = 0;
      }

      // print td elements with appropriate class, according to state; print data
      for ($i = 1; $i <= 5; $i++) 
      {
        if ($active == 0) // set table class for colors etc
          print '<td class="inactive">';
        else // determine age of last measurement and color accordingly
        {
          if ($age_seconds < 1800) // ok
            print '<td class="active">';
          elseif ($age_seconds < 86400) // between 30 minutes and 24 hours -> warning
            print '<td class="warning">';
          else // 1 day -> error
            print '<td class="error">';
        }
        if ($i == 2) // activated field (always show)
        {
          $myDate = new DateTime($row[$i]);
          print $myDate->format('Y-m-d H:i');
        }
        elseif ($i == 3 && $active == 0) // deactivated field, only show when deactivated (otherwise null value leads to current date when formatting)
        {
          $myDate = new DateTime($row[$i]);
          print $myDate->format('Y-m-d H:i');
        }
        else // other fields (name, lat, lon, ...)
          print $row[$i];
        print "</td>";
      }

      // Depending on active status, show last data, graph links and download, or only download
      if ($active == 1) 
      {
        print '<td class="download">';
        print $lastseen->format('Y-m-d H:i:s');
        print "</td>";
        print '<td class="download"><a href="measurements.php?Operation=GetGraphPage&UUID='.$row[6].'&PeriodHour=24">Graphs</a></td>';
        print '<td class="download"><a href="measurements.php?Operation=GetMeasurements&UUID='.$row[6].'">Data download (CSV)</a></td>';
      }
      else
      {
        print '<td class="inactive">';
        print "</td>";
        print '<td class="inactive"></td>';
        print '<td class="download"><a href="measurements.php?Operation=GetMeasurements&MeasuredProperty=data&UUID='.$row[6].'">Data download (CSV)</a></td>';
      }

      print "</tr>";
    }
    print "</table>";
    print "</body>";
    print "</html>";
  }
}
?>
