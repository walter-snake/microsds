--
-- PostgreSQL database dump
--

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

--
-- Name: weather; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA weather;


SET search_path = weather, pg_catalog;

--
-- Name: insertmeasurement(uuid, uuid, timestamp without time zone, text, numeric); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION insertmeasurement(statuuid uuid, statkey uuid, mtime timestamp without time zone, mparam text, mvalue numeric) RETURNS bigint
    LANGUAGE plpgsql
    AS $$
DECLARE
  -- time timestamp without time zone;
  timeid bigint; -- timestamp id
  statid bigint; -- measurement station id
  measid bigint; -- measurement id
BEGIN
  -- get the measurement station id, break out if station not found or not active
  SELECT gid INTO statid FROM measurement_station WHERE station_uuid = statuuid AND station_key = statkey AND date_outofuse ISNULL;
  IF statid ISNULL THEN
    RETURN -1;
  END IF;

  -- try to find a suitable station/time entry, or create it
  SELECT id INTO timeid FROM measurement_timestamp WHERE measurement_station_gid = statid AND measurement_timestamp = mtime;
  IF timeid ISNULL THEN -- create a new entry
    -- select into doesn't work well with insert returning, so get  value for the id and use that, also transaction safe
    timeid := (select nextval('measurement_timestamp_id_seq'::regclass));
    INSERT INTO measurement_timestamp (id, measurement_station_gid, measurement_timestamp) VALUES (timeid, statid, mtime);
  END IF;

  -- insert the measurement, assuming that people usually do not try to upload things twice, just try to stuff it in,
  -- the unique index will block double entries
  measid := (select nextval('measurement_value_mid_seq'::regclass));
  INSERT INTO measurement_value (mid, measurement_timestamp_id, measured_property, measured_value) VALUES (measid, timeid, mparam, mvalue);

  RETURN measid;
EXCEPTION WHEN unique_violation THEN
  RETURN -2;
END;
$$;


SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: measured_property; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measured_property (
    pid integer NOT NULL,
    measured_property text,
    legend text
);


--
-- Name: measured_property_pid_seq; Type: SEQUENCE; Schema: weather; Owner: -
--

CREATE SEQUENCE measured_property_pid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measured_property_pid_seq; Type: SEQUENCE OWNED BY; Schema: weather; Owner: -
--

ALTER SEQUENCE measured_property_pid_seq OWNED BY measured_property.pid;


--
-- Name: measurement_station; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_station (
    gid bigint NOT NULL,
    date_inuse timestamp without time zone,
    date_outofuse timestamp without time zone,
    station_name text,
    geom public.geometry(Point,4326),
    station_uuid uuid,
    station_key uuid
);


--
-- Name: measurement_station_gid_seq; Type: SEQUENCE; Schema: weather; Owner: -
--

CREATE SEQUENCE measurement_station_gid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measurement_station_gid_seq; Type: SEQUENCE OWNED BY; Schema: weather; Owner: -
--

ALTER SEQUENCE measurement_station_gid_seq OWNED BY measurement_station.gid;


--
-- Name: measurement_timestamp; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_timestamp (
    id bigint NOT NULL,
    measurement_station_gid bigint,
    measurement_timestamp timestamp without time zone
);


--
-- Name: measurement_timestamp_id_seq; Type: SEQUENCE; Schema: weather; Owner: -
--

CREATE SEQUENCE measurement_timestamp_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measurement_timestamp_id_seq; Type: SEQUENCE OWNED BY; Schema: weather; Owner: -
--

ALTER SEQUENCE measurement_timestamp_id_seq OWNED BY measurement_timestamp.id;


--
-- Name: measurement_value; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_value (
    mid bigint NOT NULL,
    measurement_timestamp_id bigint,
    measured_property text,
    measured_value numeric(20,4)
);


--
-- Name: measurement_value_mid_seq; Type: SEQUENCE; Schema: weather; Owner: -
--

CREATE SEQUENCE measurement_value_mid_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measurement_value_mid_seq; Type: SEQUENCE OWNED BY; Schema: weather; Owner: -
--

ALTER SEQUENCE measurement_value_mid_seq OWNED BY measurement_value.mid;


--
-- Name: measurements; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurements (
    id bigint NOT NULL,
    measurement_station_gid bigint NOT NULL,
    measurement_time timestamp without time zone,
    measured_property text,
    measured_value numeric(20,4)
);


--
-- Name: measurements_id_seq; Type: SEQUENCE; Schema: weather; Owner: -
--

CREATE SEQUENCE measurements_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: measurements_id_seq; Type: SEQUENCE OWNED BY; Schema: weather; Owner: -
--

ALTER SEQUENCE measurements_id_seq OWNED BY measurements.id;


--
-- Name: vw_allseries; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_allseries AS
    SELECT s.station_uuid, s.station_name, public.st_y(s.geom) AS lat, public.st_x(s.geom) AS lon, t.measurement_timestamp AS measurement_time, vt.measured_value AS temp, vh.measured_value AS rh, vb.measured_value AS bp FROM ((((measurement_station s JOIN measurement_timestamp t ON ((t.measurement_station_gid = s.gid))) LEFT JOIN (SELECT measurement_value.mid, measurement_value.measurement_timestamp_id, measurement_value.measured_property, measurement_value.measured_value FROM measurement_value WHERE (measurement_value.measured_property = 'temp'::text)) vt ON ((vt.measurement_timestamp_id = t.id))) LEFT JOIN (SELECT measurement_value.mid, measurement_value.measurement_timestamp_id, measurement_value.measured_property, measurement_value.measured_value FROM measurement_value WHERE (measurement_value.measured_property = 'humid'::text)) vh ON ((vh.measurement_timestamp_id = t.id))) LEFT JOIN (SELECT measurement_value.mid, measurement_value.measurement_timestamp_id, measurement_value.measured_property, measurement_value.measured_value FROM measurement_value WHERE (measurement_value.measured_property = 'baro'::text)) vb ON ((vb.measurement_timestamp_id = t.id)));


--
-- Name: vw_baro_series; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_baro_series AS
    SELECT m.id, m.measured_property, m.measurement_time, m.measured_value, s.station_uuid, s.station_name, s.geom FROM (measurement_station s JOIN measurements m ON ((s.gid = m.measurement_station_gid))) WHERE (m.measured_property = 'baro'::text);


--
-- Name: vw_humid_series; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_humid_series AS
    SELECT m.id, m.measured_property, m.measurement_time, m.measured_value, s.station_uuid, s.station_name, s.geom FROM (measurement_station s JOIN measurements m ON ((s.gid = m.measurement_station_gid))) WHERE (m.measured_property = 'humid'::text);


--
-- Name: vw_temp_series; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_temp_series AS
    SELECT m.id, m.measured_property, m.measurement_time, m.measured_value, s.station_uuid, s.station_name, s.geom FROM (measurement_station s JOIN measurements m ON ((s.gid = m.measurement_station_gid))) WHERE (m.measured_property = 'temp'::text);


--
-- Name: vw_allseries_old; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_allseries_old AS
    SELECT t.station_uuid, s.station_name, public.st_y(s.geom) AS lat, public.st_x(s.geom) AS lon, t.measurement_time, t.measured_value AS temp, h.measured_value AS rh, b.measured_value AS bp FROM (((vw_temp_series t LEFT JOIN vw_humid_series h ON (((t.station_uuid = h.station_uuid) AND (t.measurement_time = h.measurement_time)))) LEFT JOIN vw_baro_series b ON (((t.station_uuid = b.station_uuid) AND (t.measurement_time = b.measurement_time)))) JOIN measurement_station s ON ((t.station_uuid = s.station_uuid)));


--
-- Name: vw_baro_series2; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_baro_series2 AS
    SELECT t.id AS measurement_timestamp_id, v.mid AS measurement_id, v.measured_property, t.measurement_timestamp AS measurement_time, v.measured_value, s.station_uuid, s.station_name, s.geom FROM ((measurement_station s JOIN measurement_timestamp t ON ((s.gid = t.measurement_station_gid))) JOIN measurement_value v ON ((t.id = v.measurement_timestamp_id))) WHERE (v.measured_property = 'baro'::text);


--
-- Name: vw_humid_series2; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_humid_series2 AS
    SELECT t.id AS measurement_timestamp_id, v.mid AS measurement_id, v.measured_property, t.measurement_timestamp AS measurement_time, v.measured_value, s.station_uuid, s.station_name, s.geom FROM ((measurement_station s JOIN measurement_timestamp t ON ((s.gid = t.measurement_station_gid))) JOIN measurement_value v ON ((t.id = v.measurement_timestamp_id))) WHERE (v.measured_property = 'humid'::text);


--
-- Name: vw_measurement_series; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_measurement_series AS
    SELECT t.id AS measurement_timestamp_id, t.measurement_timestamp, v.mid AS measurement_id, v.measured_property, v.measured_value, s.station_uuid, s.station_name, public.st_y(s.geom) AS lat, public.st_x(s.geom) AS lon FROM ((measurement_station s JOIN measurement_timestamp t ON ((s.gid = t.measurement_station_gid))) JOIN measurement_value v ON ((t.id = v.measurement_timestamp_id))) ORDER BY s.gid, v.measured_property, t.measurement_timestamp;


--
-- Name: vw_temp_series2; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_temp_series2 AS
    SELECT t.id AS measurement_timestamp_id, v.mid AS measurement_id, v.measured_property, t.measurement_timestamp AS measurement_time, v.measured_value, s.station_uuid, s.station_name, s.geom FROM ((measurement_station s JOIN measurement_timestamp t ON ((s.gid = t.measurement_station_gid))) JOIN measurement_value v ON ((t.id = v.measurement_timestamp_id))) WHERE (v.measured_property = 'temp'::text);


--
-- Name: pid; Type: DEFAULT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measured_property ALTER COLUMN pid SET DEFAULT nextval('measured_property_pid_seq'::regclass);


--
-- Name: gid; Type: DEFAULT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_station ALTER COLUMN gid SET DEFAULT nextval('measurement_station_gid_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_timestamp ALTER COLUMN id SET DEFAULT nextval('measurement_timestamp_id_seq'::regclass);


--
-- Name: mid; Type: DEFAULT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_value ALTER COLUMN mid SET DEFAULT nextval('measurement_value_mid_seq'::regclass);


--
-- Name: id; Type: DEFAULT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurements ALTER COLUMN id SET DEFAULT nextval('measurements_id_seq'::regclass);


--
-- Name: measured_property_measured_property_key; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measured_property
    ADD CONSTRAINT measured_property_measured_property_key UNIQUE (measured_property);


--
-- Name: measured_property_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measured_property
    ADD CONSTRAINT measured_property_pkey PRIMARY KEY (pid);


--
-- Name: measurement_station_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_station
    ADD CONSTRAINT measurement_station_pkey PRIMARY KEY (gid);


--
-- Name: measurement_timestamp_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_timestamp
    ADD CONSTRAINT measurement_timestamp_pkey PRIMARY KEY (id);


--
-- Name: measurement_value_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_value
    ADD CONSTRAINT measurement_value_pkey PRIMARY KEY (mid);


--
-- Name: measurements_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurements
    ADD CONSTRAINT measurements_pkey PRIMARY KEY (id);


--
-- Name: uuid_unique; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_station
    ADD CONSTRAINT uuid_unique UNIQUE (station_uuid);


--
-- Name: idx_measurement_station_unique; Type: INDEX; Schema: weather; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_measurement_station_unique ON measurement_station USING btree (station_name, public.st_astext(geom));


--
-- Name: idx_measurement_time; Type: INDEX; Schema: weather; Owner: -; Tablespace: 
--

CREATE INDEX idx_measurement_time ON measurements USING btree (measurement_time);


--
-- Name: idx_measurement_timestamp_unique; Type: INDEX; Schema: weather; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_measurement_timestamp_unique ON measurement_timestamp USING btree (measurement_station_gid, measurement_timestamp);


--
-- Name: idx_measurement_value_unique; Type: INDEX; Schema: weather; Owner: -; Tablespace: 
--

CREATE UNIQUE INDEX idx_measurement_value_unique ON measurement_value USING btree (measurement_timestamp_id, measured_property);


--
-- Name: measured_property_pid_fkey; Type: FK CONSTRAINT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_value
    ADD CONSTRAINT measured_property_pid_fkey FOREIGN KEY (measured_property) REFERENCES measured_property(measured_property);


--
-- Name: measurement_timestamp_measurement_station_gid_fkey; Type: FK CONSTRAINT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_timestamp
    ADD CONSTRAINT measurement_timestamp_measurement_station_gid_fkey FOREIGN KEY (measurement_station_gid) REFERENCES measurement_station(gid) ON DELETE CASCADE;


--
-- Name: measurement_value_timestamp_id_fkey; Type: FK CONSTRAINT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurement_value
    ADD CONSTRAINT measurement_value_timestamp_id_fkey FOREIGN KEY (measurement_timestamp_id) REFERENCES measurement_timestamp(id) ON DELETE CASCADE;


--
-- Name: measurements_measurement_station_gid_fkey; Type: FK CONSTRAINT; Schema: weather; Owner: -
--

ALTER TABLE ONLY measurements
    ADD CONSTRAINT measurements_measurement_station_gid_fkey FOREIGN KEY (measurement_station_gid) REFERENCES measurement_station(gid) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

