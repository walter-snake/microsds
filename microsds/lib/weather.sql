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


--
-- Name: measurement_station_delete(); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION measurement_station_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            INSERT INTO measurement_station_hist SELECT OLD.*;
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$;


--
-- Name: measurement_station_timetracker(); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION measurement_station_timetracker() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            INSERT INTO measurement_timestamp_track
              (measurement_station_gid)
              VALUES (NEW.gid);
            RETURN NEW;
        ELSIF (TG_OP = 'DELETE') THEN
            DELETE FROM measurement_timestamp_track
              WHERE measurement_station_gid = OLD.gid;
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$;


--
-- Name: measurement_timestamp_delete(); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION measurement_timestamp_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            INSERT INTO measurement_timestamp_hist SELECT OLD.*;
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$;


--
-- Name: measurement_timestamp_tracker(); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION measurement_timestamp_tracker() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            UPDATE measurement_timestamp_track
              SET measurement_time_last = NEW.measurement_timestamp
              WHERE measurement_station_gid = NEW.measurement_station_gid;
            RETURN NEW;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
    END;
$$;


--
-- Name: measurement_value_delete(); Type: FUNCTION; Schema: weather; Owner: -
--

CREATE FUNCTION measurement_value_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
    BEGIN
        IF (TG_OP = 'DELETE') THEN
            INSERT INTO measurement_value_hist SELECT OLD.*;
            RETURN OLD;
        END IF;
        RETURN NULL; -- result is ignored since this is an AFTER trigger
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
-- Name: measurement_station_hist; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_station_hist (
    gid bigint NOT NULL,
    date_inuse timestamp without time zone,
    date_outofuse timestamp without time zone,
    station_name text,
    geom public.geometry(Point,4326),
    station_uuid uuid,
    station_key uuid,
    timestamp_removed timestamp without time zone DEFAULT now()
);


--
-- Name: measurement_timestamp; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_timestamp (
    id bigint NOT NULL,
    measurement_station_gid bigint,
    measurement_timestamp timestamp without time zone
);


--
-- Name: measurement_timestamp_hist; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_timestamp_hist (
    id bigint NOT NULL,
    measurement_station_gid bigint,
    measurement_timestamp timestamp without time zone,
    timestamp_removed timestamp without time zone DEFAULT now()
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
-- Name: measurement_timestamp_track; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_timestamp_track (
    measurement_station_gid bigint,
    measurement_time_last timestamp without time zone
);


--
-- Name: measurement_value; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_value (
    mid bigint NOT NULL,
    measurement_timestamp_id bigint,
    measured_property text,
    measured_value numeric(20,4),
    inserted_timestamp timestamp without time zone DEFAULT now()
);


--
-- Name: measurement_value_hist; Type: TABLE; Schema: weather; Owner: -; Tablespace: 
--

CREATE TABLE measurement_value_hist (
    mid bigint NOT NULL,
    measurement_timestamp_id bigint,
    measured_property text,
    measured_value numeric(20,4),
    inserted_timestamp timestamp without time zone DEFAULT now(),
    timestamp_removed timestamp without time zone DEFAULT now()
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
-- Name: vw_measurement_station_stat; Type: VIEW; Schema: weather; Owner: -
--

CREATE VIEW vw_measurement_station_stat AS
    SELECT statinfo.gid, statinfo.date_inuse, statinfo.date_outofuse, statinfo.station_name, statinfo.geom, statinfo.station_uuid, statinfo.station_key, statinfo.measurement_time_last, CASE WHEN (NOT (statinfo.date_outofuse IS NULL)) THEN 'I'::text WHEN ((statinfo.measurement_time_last)::timestamp with time zone IS NULL) THEN 'E'::text WHEN ((now() - (statinfo.measurement_time_last)::timestamp with time zone) < '00:30:00'::interval) THEN 'A'::text WHEN ((now() - (statinfo.measurement_time_last)::timestamp with time zone) < '24:00:00'::interval) THEN 'W'::text WHEN ((now() - (statinfo.measurement_time_last)::timestamp with time zone) >= '24:00:00'::interval) THEN 'E'::text ELSE NULL::text END AS station_state FROM (SELECT s.gid, s.date_inuse, s.date_outofuse, s.station_name, s.geom, s.station_uuid, s.station_key, t.measurement_time_last FROM (measurement_station s JOIN measurement_timestamp_track t ON ((s.gid = t.measurement_station_gid)))) statinfo;


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
-- Name: measurement_station_hist_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_station_hist
    ADD CONSTRAINT measurement_station_hist_pkey PRIMARY KEY (gid);


--
-- Name: measurement_station_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_station
    ADD CONSTRAINT measurement_station_pkey PRIMARY KEY (gid);


--
-- Name: measurement_timestamp_hist_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_timestamp_hist
    ADD CONSTRAINT measurement_timestamp_hist_pkey PRIMARY KEY (id);


--
-- Name: measurement_timestamp_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_timestamp
    ADD CONSTRAINT measurement_timestamp_pkey PRIMARY KEY (id);


--
-- Name: measurement_value_hist_pkey; Type: CONSTRAINT; Schema: weather; Owner: -; Tablespace: 
--

ALTER TABLE ONLY measurement_value_hist
    ADD CONSTRAINT measurement_value_hist_pkey PRIMARY KEY (mid);


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
-- Name: stat_delete; Type: TRIGGER; Schema: weather; Owner: -
--

CREATE TRIGGER stat_delete AFTER DELETE ON measurement_station FOR EACH ROW EXECUTE PROCEDURE measurement_station_delete();


--
-- Name: station_time_tracker; Type: TRIGGER; Schema: weather; Owner: -
--

CREATE TRIGGER station_time_tracker AFTER INSERT OR DELETE ON measurement_station FOR EACH ROW EXECUTE PROCEDURE measurement_station_timetracker();


--
-- Name: timestamp_delete; Type: TRIGGER; Schema: weather; Owner: -
--

CREATE TRIGGER timestamp_delete AFTER DELETE ON measurement_timestamp FOR EACH ROW EXECUTE PROCEDURE measurement_timestamp_delete();


--
-- Name: timestamp_insert; Type: TRIGGER; Schema: weather; Owner: -
--

CREATE TRIGGER timestamp_insert AFTER INSERT ON measurement_timestamp FOR EACH ROW EXECUTE PROCEDURE measurement_timestamp_tracker();


--
-- Name: value_delete; Type: TRIGGER; Schema: weather; Owner: -
--

CREATE TRIGGER value_delete AFTER DELETE ON measurement_value FOR EACH ROW EXECUTE PROCEDURE measurement_value_delete();


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
-- Name: weather; Type: ACL; Schema: -; Owner: -
--

REVOKE ALL ON SCHEMA weather FROM PUBLIC;
REVOKE ALL ON SCHEMA weather FROM geodata;
GRANT ALL ON SCHEMA weather TO geodata;
GRANT USAGE ON SCHEMA weather TO geodata_web;
GRANT USAGE ON SCHEMA weather TO weather;


--
-- Name: measured_property; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measured_property FROM PUBLIC;
REVOKE ALL ON TABLE measured_property FROM webmaster;
GRANT ALL ON TABLE measured_property TO webmaster;
GRANT SELECT ON TABLE measured_property TO weather;


--
-- Name: measurement_station; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_station FROM PUBLIC;
REVOKE ALL ON TABLE measurement_station FROM webmaster;
GRANT ALL ON TABLE measurement_station TO webmaster;
GRANT SELECT,INSERT,UPDATE ON TABLE measurement_station TO geodata;
GRANT SELECT ON TABLE measurement_station TO geodata_web;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE measurement_station TO weather;


--
-- Name: measurement_station_gid_seq; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON SEQUENCE measurement_station_gid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE measurement_station_gid_seq FROM webmaster;
GRANT ALL ON SEQUENCE measurement_station_gid_seq TO webmaster;
GRANT SELECT,USAGE ON SEQUENCE measurement_station_gid_seq TO geodata;
GRANT SELECT,USAGE ON SEQUENCE measurement_station_gid_seq TO weather;


--
-- Name: measurement_station_hist; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_station_hist FROM PUBLIC;
REVOKE ALL ON TABLE measurement_station_hist FROM webmaster;
GRANT ALL ON TABLE measurement_station_hist TO webmaster;
GRANT SELECT ON TABLE measurement_station_hist TO geodata_web;
GRANT SELECT,INSERT ON TABLE measurement_station_hist TO weather;


--
-- Name: measurement_timestamp; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_timestamp FROM PUBLIC;
REVOKE ALL ON TABLE measurement_timestamp FROM webmaster;
GRANT ALL ON TABLE measurement_timestamp TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE measurement_timestamp TO weather;


--
-- Name: measurement_timestamp_hist; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_timestamp_hist FROM PUBLIC;
REVOKE ALL ON TABLE measurement_timestamp_hist FROM webmaster;
GRANT ALL ON TABLE measurement_timestamp_hist TO webmaster;
GRANT SELECT,INSERT ON TABLE measurement_timestamp_hist TO weather;


--
-- Name: measurement_timestamp_id_seq; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON SEQUENCE measurement_timestamp_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE measurement_timestamp_id_seq FROM webmaster;
GRANT ALL ON SEQUENCE measurement_timestamp_id_seq TO webmaster;
GRANT SELECT,USAGE ON SEQUENCE measurement_timestamp_id_seq TO weather;


--
-- Name: measurement_timestamp_track; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_timestamp_track FROM PUBLIC;
REVOKE ALL ON TABLE measurement_timestamp_track FROM webmaster;
GRANT ALL ON TABLE measurement_timestamp_track TO webmaster;
GRANT SELECT,INSERT,DELETE,UPDATE ON TABLE measurement_timestamp_track TO weather;


--
-- Name: measurement_value; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_value FROM PUBLIC;
REVOKE ALL ON TABLE measurement_value FROM webmaster;
GRANT ALL ON TABLE measurement_value TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE measurement_value TO weather;


--
-- Name: measurement_value_hist; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurement_value_hist FROM PUBLIC;
REVOKE ALL ON TABLE measurement_value_hist FROM webmaster;
GRANT ALL ON TABLE measurement_value_hist TO webmaster;
GRANT SELECT,INSERT ON TABLE measurement_value_hist TO weather;


--
-- Name: measurement_value_mid_seq; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON SEQUENCE measurement_value_mid_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE measurement_value_mid_seq FROM webmaster;
GRANT ALL ON SEQUENCE measurement_value_mid_seq TO webmaster;
GRANT SELECT,USAGE ON SEQUENCE measurement_value_mid_seq TO weather;


--
-- Name: measurements; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE measurements FROM PUBLIC;
REVOKE ALL ON TABLE measurements FROM webmaster;
GRANT ALL ON TABLE measurements TO webmaster;
GRANT SELECT,INSERT ON TABLE measurements TO geodata;
GRANT SELECT,INSERT,DELETE ON TABLE measurements TO weather;
GRANT SELECT ON TABLE measurements TO geodata_web;


--
-- Name: measurements_id_seq; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON SEQUENCE measurements_id_seq FROM PUBLIC;
REVOKE ALL ON SEQUENCE measurements_id_seq FROM webmaster;
GRANT ALL ON SEQUENCE measurements_id_seq TO webmaster;
GRANT SELECT,USAGE ON SEQUENCE measurements_id_seq TO geodata;
GRANT SELECT,USAGE ON SEQUENCE measurements_id_seq TO weather;


--
-- Name: vw_allseries; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_allseries FROM PUBLIC;
REVOKE ALL ON TABLE vw_allseries FROM webmaster;
GRANT ALL ON TABLE vw_allseries TO webmaster;
GRANT SELECT ON TABLE vw_allseries TO weather;


--
-- Name: vw_baro_series; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_baro_series FROM PUBLIC;
REVOKE ALL ON TABLE vw_baro_series FROM webmaster;
GRANT ALL ON TABLE vw_baro_series TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE vw_baro_series TO weather;


--
-- Name: vw_humid_series; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_humid_series FROM PUBLIC;
REVOKE ALL ON TABLE vw_humid_series FROM webmaster;
GRANT ALL ON TABLE vw_humid_series TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE vw_humid_series TO weather;


--
-- Name: vw_temp_series; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_temp_series FROM PUBLIC;
REVOKE ALL ON TABLE vw_temp_series FROM webmaster;
GRANT ALL ON TABLE vw_temp_series TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE vw_temp_series TO weather;


--
-- Name: vw_allseries_old; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_allseries_old FROM PUBLIC;
REVOKE ALL ON TABLE vw_allseries_old FROM webmaster;
GRANT ALL ON TABLE vw_allseries_old TO webmaster;
GRANT SELECT,INSERT,DELETE ON TABLE vw_allseries_old TO weather;


--
-- Name: vw_baro_series2; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_baro_series2 FROM PUBLIC;
REVOKE ALL ON TABLE vw_baro_series2 FROM webmaster;
GRANT ALL ON TABLE vw_baro_series2 TO webmaster;
GRANT SELECT ON TABLE vw_baro_series2 TO weather;


--
-- Name: vw_humid_series2; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_humid_series2 FROM PUBLIC;
REVOKE ALL ON TABLE vw_humid_series2 FROM webmaster;
GRANT ALL ON TABLE vw_humid_series2 TO webmaster;
GRANT SELECT ON TABLE vw_humid_series2 TO weather;


--
-- Name: vw_measurement_series; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_measurement_series FROM PUBLIC;
REVOKE ALL ON TABLE vw_measurement_series FROM webmaster;
GRANT ALL ON TABLE vw_measurement_series TO webmaster;
GRANT SELECT ON TABLE vw_measurement_series TO weather;


--
-- Name: vw_measurement_station_stat; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_measurement_station_stat FROM PUBLIC;
REVOKE ALL ON TABLE vw_measurement_station_stat FROM webmaster;
GRANT ALL ON TABLE vw_measurement_station_stat TO webmaster;
GRANT SELECT ON TABLE vw_measurement_station_stat TO weather;


--
-- Name: vw_temp_series2; Type: ACL; Schema: weather; Owner: -
--

REVOKE ALL ON TABLE vw_temp_series2 FROM PUBLIC;
REVOKE ALL ON TABLE vw_temp_series2 FROM webmaster;
GRANT ALL ON TABLE vw_temp_series2 TO webmaster;
GRANT SELECT ON TABLE vw_temp_series2 TO weather;


--
-- PostgreSQL database dump complete
--

