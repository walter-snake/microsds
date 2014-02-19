<?php
require "lib/dbconfig.php";

class db {
  private $dbconn;

  function __construct()
  {
    // Set up the db connection
    $dbconfig = new dbconfig();
    $this->dbconn = pg_connect("host=".$dbconfig->host." port=".$dbconfig->port." dbname=".$dbconfig->dbname.
      " user=".$dbconfig->user." password=".$dbconfig->password);

    // prepare some statements, these can be repeatedly called in one session
    // Inserting measurements uses a database function (AKA 'stored procedure')
    $sql = "select * from insertmeasurement($1::uuid, $2::uuid, $3, $4, $5);";
    $result = pg_prepare($this->dbconn, "add_measurement_value", $sql);

    $sql = "select count(*) from measurement_timestamp where measurement_timestamp >= (now() - interval '24 hours') AND measurement_station_gid = $1;";
    $result = pg_prepare($this->dbconn, "is_up_to_date", $sql);

    $sql = "SELECT count(*) FROM measurement_station WHERE station_uuid  = $1 AND date_outofuse IS NULL;";
    $result = pg_prepare($this->dbconn, "is_active", $sql);
    
    $sql = "SELECT max(measurement_timestamp) as last_insert FROM measurement_timestamp WHERE measurement_station_gid = $1;";
    $result = pg_prepare($this->dbconn, "get_last_seen", $sql);
  }
  
  // Test: part of a special test request, which can be used a cheap 'system is up and running' test
  // for monitoring purposes (http://yourserver/yourinstallation/measurements.php?Operation=Test)
  public function ConnectTest($apiversion)
  {
    $result = pg_prepare($this->dbconn, "test_dbconn", "SELECT $1::text as conntest;");
    $result = pg_execute($this->dbconn, "test_dbconn", array($apiversion));
    $row = pg_fetch_row($result);
    return $row[0];
  }

  // Add a measurement station
  public function AddMeasurementStation($uuid, $key, $name, $x, $y) {
    // With PHP, the return type changes: on error False, and otherwise an
    // integer. You may test False as an integer (0), but that renders 0 unusable.
    // Options for error trapping:
    // 1) Use an extra select query (should do this within a transaction block).
    // 2) Write a database function to make things clean.
    // 3) Deal with the multiple return types.
    // 1 and 2 are good for a more detailed error explanation, 1 produces ugly code to
    // deal with the transaction properly under any code path
    // So, the bad way.
        $result = pg_prepare($this->dbconn, "add_measurement_station"
          , "INSERT INTO measurement_station (station_name, date_inuse, geom, station_uuid, station_key) 
          VALUES ($1, now(), ST_SetSRID(ST_MakePoint($2, $3), 4326), $4, $5)
          RETURNING gid;"
          );
        $result = pg_execute($this->dbconn, "add_measurement_station", array($name, $x, $y, $uuid, $key));
        $row = pg_fetch_row($result);
        return $row[0];
  }

  // Drop a measurement station, this includes all data (database handles this with fk constraints)
  public function DropMeasurementStation($uuid, $key) {
    // Error trapping: well, none, but we do test if it does not exist after the delete operation.
    $result = pg_prepare($this->dbconn, "drop_measurement_station"
        , "DELETE FROM measurement_station WHERE station_uuid = $1 AND station_key = $2;");
    $result = pg_execute($this->dbconn, "drop_measurement_station", array($uuid, $key));
    $result = pg_prepare($this->dbconn, "test_measurement_station"
        , "SELECT COUNT(*) FROM measurement_station WHERE station_uuid = $1;");
    $result = pg_execute($this->dbconn, "test_measurement_station", array($uuid));
    $row = pg_fetch_row($result);
    return $row[0];
  }

  // Produce a default list of the measurement stations, without the key!!!
  public function GetMeasurementStations() {
    $result = pg_query($this->dbconn
        , "SELECT gid, station_uuid, station_name, date_inuse, date_outofuse, st_y(geom) as lat, st_x(geom) as lon, measurement_time_last, station_state FROM vw_measurement_station_stat
        ORDER BY date_outofuse DESC, station_name;"
        );
    return $result;
  }

  // Enable meas. station: removes date out of use
  public function EnableMeasurementStation($uuid, $key) {
    $result = pg_prepare($this->dbconn, "enable_measurement_station"
        , "UPDATE measurement_station SET date_outofuse = null WHERE station_uuid = $1 AND station_key = $2;"
        );
    $result = pg_execute($this->dbconn, "enable_measurement_station", array($uuid, $key));
    return $result;
  }

  // Disables a meas. station by inserting the current date into the out of use field
  public function DisableMeasurementStation($uuid, $key) {
    $result = pg_prepare($this->dbconn, "disable_measurement_station"
        , "UPDATE measurement_station SET date_outofuse = now() WHERE station_uuid = $1 AND station_key = $2;"
        );
    $result = pg_execute($this->dbconn, "disable_measurement_station", array($uuid, $key));
    return $result;
  }

  // Inserts a meas. value, actually executes a database functions
  public function InsertMeasurement($uuid, $key, $mtime, $mproperty, $mvalue)
  {
    $result = pg_execute($this->dbconn, "add_measurement_value", array($uuid, $key, $mtime, $mproperty, $mvalue));
    if (pg_num_rows($result) == 0)
      return -3; // one or another weird error
    else
    {
      $row = pg_fetch_row($result);
      return $row[0];
    }
  }

  // Various simple tests for monitoring
  public function IsActive($gid)
  {
    $result = pg_execute($this->dbconn, "is_active", array($gid));
    $row = pg_fetch_row($result);
    return $row[0];
  }

  public function IsUpToDate($gid)
  {  
    $result = pg_execute($this->dbconn, "is_up_to_date", array($gid));
    $row = pg_fetch_row($result);
    return $row[0];
  }

  public function GetLastSeen($gid)
  {
    $result = pg_execute($this->dbconn, "get_last_seen", array($gid));
    
      $row = pg_fetch_row($result);
      if ($row[0] == "")
        return '1900-01-01 00:00:00';
      else
        return $row[0];
  }

  // Get a measurement serie, for one or all stations, dating back from now to this many hours,
  // for the given property (e.g. to draw graphs)
  public function GetMeasurementSerie($uuid, $period_hour, $mproperty)
  {
    if ($uuid == "") // all stations, one property
    {
      $sql = "SELECT station_uuid, station_name, measurement_timestamp, measured_property, measured_value FROM vw_measurement_series WHERE measured_property = $1 LIMIT 100000";
      // get the data: prep and exe
      $result = pg_prepare($this->dbconn, "get_all_measurements", $sql);
      $result = pg_execute($this->dbconn, "get_all_measurements", $sql, array($mproperty));
    }
    else // a specific station
    {
      if ($period_hour == 0) // no time limit
        $sql = "SELECT station_uuid, station_name, measurement_timestamp, measured_property, measured_value FROM vw_measurement_series WHERE station_uuid = $1 AND measured_property = $2 ORDER BY measurement_timestamp ASC LIMIT 100000";
      else // a specified amount of time (in hours)
        $sql = "SELECT station_uuid, station_name, measurement_timestamp, measured_property, measured_value  FROM vw_measurement_series WHERE station_uuid = $1 AND measured_property = $2 AND measurement_timestamp > (now() - ($3::text || ' H')::interval) ORDER BY measurement_timestamp ASC LIMIT 100000";

      // get the data: prep and exe
      $result = pg_prepare($this->dbconn, "get_all_measurements", $sql);
      if ($period_hour == 0)
        $result = pg_execute($this->dbconn, "get_all_measurements", array($uuid, $mproperty));
      else
        $result = pg_execute($this->dbconn, "get_all_measurements", array($uuid, $mproperty, $period_hour));
    }
    return $result;
  }

  // Metadata about the properties (currently only the legend/title)
  public function GetPropertyMeta($mproperty)
  {
    $sql = "SELECT * FROM measured_property WHERE measured_property = $1;";
    $result = pg_prepare($this->dbconn, "get_serie_meta", $sql);
    $result = pg_execute($this->dbconn, "get_serie_meta", array($mproperty));
    $row = pg_fetch_row($result);
    return $row;
  }

  // Get all measurements (all series), possibly restricted for one station
  public function GetMeasurements($uuid)
  {
    if ($uuid == "")
    {
      $sql = "SELECT measurement_timestamp_id, measurement_id, station_uuid, station_name, lat, lon, measurement_timestamp, floor_minutes(measurement_timestamp, 15) as mtime_floor, measured_property, measured_value FROM vw_measurement_series ORDER BY station_uuid, measurement_timestamp ASC LIMIT 100000";
      $result = pg_query($this->dbconn, $sql);
    }
    else
    {
      $sql = "SELECT measurement_timestamp_id, measurement_id, station_uuid, station_name, lat, lon, measurement_timestamp, floor_minutes(measurement_timestamp, 15) as mtime_floor, measured_property, measured_value FROM vw_measurement_series WHERE station_uuid = $1 ORDER BY measurement_timestamp ASC LIMIT 100000";
      $result = pg_prepare($this->dbconn, "get_all_measurements", $sql);
      $result = pg_execute($this->dbconn, "get_all_measurements", array($uuid));
    }
    return $result;
  }
}
?>
