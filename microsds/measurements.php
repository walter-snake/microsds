<?php
// includes
require "lib/db.php";
require "lib/graph.php";
require 'lib/graphPage.php';
require "lib/stationPage.php";
require "lib/stationJSon.php";

// Instantiate my database class
$myDb = new db;

// Get some variables, needed in multiple Operation modes
$operation = $_GET["Operation"]; // no default, won't do anything without anyway
$uuid = "";
$period_hour = 0;
$format = "";
$mproperty = "";
if (isset($_GET["PeriodHour"]))
  $period_hour = $_GET["PeriodHour"];
if (isset($_GET["UUID"]))
  $uuid = $_GET["UUID"];
if (isset($_GET["Key"]))
  $key = $_GET["Key"];
if (isset($_GET["Format"]))
  $format = $_GET["Format"];
if (isset($_GET["MeasuredProperty"]))
  $mproperty = $_GET["MeasuredProperty"];

# What operation to perform
switch ($operation)
{
  case "Test":
    print $myDb->ConnectTest();
    break;
  case "AddStation":
    print "AddStation:";
    $name = $_GET["Name"];
    $x = $_GET["Lon"];
    $y = $_GET["Lat"];
    $id = $myDb->AddMeasureMentStation($uuid, $key, $name, $x, $y);
    if ($id == False) // False: something is wrong, you don't know what. 
      print "ERROR Station probably already exists";
    else
      print "OK ".$id;
    break;
  case "DropStation":
    print "DropStation:";
    $exists = $myDb->DropMeasureMentStation($uuid, $key);
    if ($exists == 1) // Test only for success or failure
      print "ERROR";
    else
      print "Ok";
    break;
  case "DisableStation":
    print "DisableStation:";
    if ($myDb->DisableMeasureMentStation($uuid, $key))
      print "OK";
    else
      print "ERROR";
    break;
  case "EnableStation":
    print "EnableStation:";
    if ($myDb->EnableMeasureMentStation($uuid, $key))
      print "OK";
    else
      print "ERROR";
    break;
  case "InsertMeasurement":
    print "InsertMeasurement:";
    $mvalue = $_GET["MeasuredValue"];
    $mtime = $_GET["MeasurementTime"];
    // test in multiple phases, try to catch a few common problems in advance
    // uses a stored procedure in the database to store the data, way easier to
    // trap errors and deal with inserting transactionally safe in multiple tables
    // and faster, save round trips to the database
    if ($myDb->IsActive($uuid) == 0)
    {
      print "ERROR";
    }
    else
    { 
      $id = $myDb->InsertMeasurement($uuid, $key, $mtime, $mproperty, $mvalue);
      if ($id >= 0)
        print "OK ".$id;
      else if ($id == -1)
        print "ERROR No (active) station found";
      else if ($id == -2)
        print "WARNING Already present";
      else
        print "ERROR";
    }
    break;
  case "GetMeasurements":
    header("Content-type: text/csv");
    if ($uuid == "")
      header("Content-Disposition: attachment; filename=all-stations.csv");
    else
      header("Content-Disposition: attachment; filename=".$uuid.".csv");
    header("Pragma: no-cache");
    header("Expires: 0");
    print "station_uuid;station_name;lat;lon;measurement_time;temp;humid;baro;mtime_floor\n";
    $result = $myDb->GetMeasurements($uuid,$period_hour);
    while ($row = pg_fetch_row($result))
    {
      for ($i = 0; $i <= 8; $i++)
      {
        if ($i == 1)
          echo "\"".$row[$i]."\";";
        elseif ($i == 8)
          echo $row[$i]."\n";
        else
          echo $row[$i].";";
      }
    }
    break;
  case "GetGraph":
    $result = $myDb->GetMeasurementSerie($uuid, $period_hour, $mproperty);
    $legend = $myDb->GetPropertyMeta($mproperty);
    $myGraph = new graph($result, $uuid);
    $myGraph->getGraph($mproperty, $format, $legend[2]);
    break;
  case "GetGraphPage":
    $myGraphPage = new graphPage($uuid);
    $myGraphPage->toHtmlPage();
    break;
  case "GetMeasurementStations":
    // must be possible to extract geojson, e.g. for a map, default produces an html page
    if ($format == "GeoJSon")
    {
      $result = $myDb->GetMeasurementStations($uuid);
      $myStationJSon = new stationJSon($result);
      $myStationJSon->toGeoJSon();
    }
    else
    {
      $result = $myDb->GetMeasurementStations($uuid);
      $myStationPage = new stationPage($result, $myDb);
      $myStationPage->toHtmlPage();
    }
    break;
  case "InsertAsXml":
    if ( $_SERVER['REQUEST_METHOD'] === 'POST' )
    { 
      $myXml = file_get_contents('php://input');
      // Parse XML and insert measurements, pretty ugly through JSon: first hit on Google :-)
      $xml = simplexml_load_string($myXml);
      $json = json_encode($xml);
      $array = json_decode($json,TRUE);

      $startid = -1;
      $count = count($array['sample']); 

      print "InsertMeasurements:";
      foreach ($array['sample'] as $r)
      {
        $statuuid = trim($r['@attributes']['statuuid']);
        $mtime = trim($r['@attributes']['mtime']);
        $mproperty = trim($r['param']);
        $mvalue = trim($r['value']);
        if ($myDb->IsActive($statuuid) == 0)
        {
          print "ERROR";
        }
        else
        {
          $id = $myDb->InsertMeasurement($statuuid, $key, $mtime, $mproperty, $mvalue);
          // $id = 0; // debug
          // print $mproperty."=".$mvalue." "; // debug
          if ($id >= 0)
            if ($startid == -1) $startid = $id;
            $count -= 1;
        }
      }
      if ($count == 0)
        print "OK ".$startid."-".$id;
      else
        print "ERROR";
    }
  break;
}
?>
