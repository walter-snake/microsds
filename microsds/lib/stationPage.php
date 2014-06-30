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
    print '<meta HTTP-EQUIV="REFRESH" content="60">';
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
    print '<li>The data download options deliver data from the database limited to 100,000 records (this might not be enough for your data, or too much for the system). The database is not limited however, so on request more data could be made available.</li>';
    print '</ul>';
    print '<strong>Station status</strong>';
    print '<table><tr><td class="active">&lt; 30 min</td></tr><tr><td class="warning">&gt; 30 min, &lt; 1 day</td></tr><tr><td class="error">&gt; 1 day</td></tr></table><br />';
    print '<table>';
    print '<tr><th>name</th><th>activated</th><th>de-activated</th><th>lat</th><th>lon</th><th>last measurement</th>';
    print '<th>graphs</th><th>download</th></tr>';
    while ($row = pg_fetch_row($this->myStationData))
    {
      // 8 activity code: I (inactive), A (active), W (warning), E (error)
      print "<tr>";
      if ($row[8] == "I") // this is an INactive station
        $active = 0;
      else
        $active = 1;

      // print td elements with appropriate class, according to state; print data
      for ($i = 2; $i <= 7; $i++) 
      {
        // set table class for colors etc
        if ($active == 0)
          print '<td class="inactive">';
        else // active: active/warning/error
        {
          if ($row[8] == 'A') // ok
            print '<td class="active">';
          elseif ($row[8] == 'W') // between 30 minutes and 24 hours -> warning
            print '<td class="warning">';
          else // error
            print '<td class="error">';
        }

        // print data, with special treatment for some fields
        if ($i == 3)
        {
          $myDate = new DateTime($row[$i]);
          print $myDate->format('Y-m-d H:i');
        }
        elseif ($i == 4 || $i == 7) // datetime fields:  null/empty value leads to current date when formatting...
        {
          if ($row[$i] != "") 
          {
            $myDate = new DateTime($row[$i]);
            print $myDate->format('Y-m-d H:i');
          }
          else
            print "";
        }
        else // other fields (name, lat, lon, ...)
          print $row[$i];
        print "</td>";
      }
      
      // Depending on active status: graph links and downloads, or only download
      if ($active == 1) 
      {
        print '<td class="download"><a href="measurements.php?Operation=GetGraphPage&UUID='.$row[1].'&PeriodHour=24">24h</a>
         <a href="measurements.php?Operation=GetGraphPage&UUID='.$row[1].'&PeriodHour=168">week</a>
         <a href="measurements.php?Operation=GetGraphPage&UUID='.$row[1].'&PeriodHour=0.16667&RefreshRate=15">10 min</a></td>';
        print '<td class="download"><a href="measurements.php?Operation=GetMeasurements&UUID='.$row[1].'">Data download (CSV)</a></td>';
      }
      else
      {
        print '<td class="inactive"></td>';
        print '<td class="download"><a href="measurements.php?Operation=GetMeasurements&MeasuredProperty=data&UUID='.$row[1].'">Data download (CSV)</a></td>';
      }

      // close table row
      print "</tr>";
    }
    print "</table>";
    print "</body>";
    print "</html>";
  }
}
?>
