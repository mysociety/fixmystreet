#!/usr/bin/env python
import os
from itertools import groupby

import yaml
import sodapy
import psycopg2
import psycopg2.extras
import rabx


yml_path = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "conf", "general.yml"
))
with open(yml_path) as f:
    config = yaml.load(f)


PHOTO_URL = "http://collideosco.pe/photo/{id}.full.jpeg?{photo}"

def get_cursor():
    db = psycopg2.connect( "host='{host}' dbname='{name}' user='{user}' password='{password}'".format(
        host=config['FMS_DB_HOST'],
        name=config['FMS_DB_NAME'],
        user=config['FMS_DB_USER'],
        password=config['FMS_DB_PASS']
    ))
    cursor = db.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    return cursor

def socrata_connect():
    return sodapy.Socrata(
        "opendata.socrata.com",
        config['SOCRATA_APP_TOKEN'],
        username=config['SOCRATA_USERNAME'],
        password=config['SOCRATA_PASSWORD']
    )

def query_recent_reports(cursor, limit=100):
    """
    Performs a query on the cursor to get
    the most recent `limit` reports from the DB, ordered
    by ascending order of confirmation date.
    """
    query = "SELECT id, latitude, longitude, category, title, extra, " \
            "detail, confirmed as reported, lastupdate, whensent, " \
            "bodies_str as body, photo " \
            "FROM problem " \
            "WHERE state = 'confirmed' " \
            "ORDER BY reported DESC"
    params = []
    if limit:
        query = "{query} LIMIT %s".format(query=query)
        params = [limit]
    cursor.execute(query, params)

def transform_results(cursor):
    """
    Returns an iterable of dicts suitable for uploading to Socrata.
    This must be called immediately after query_recent_reports because
    it operates on results held in the cursor.
    """
    for row in cursor:
        row['url'] = "http://collideosco.pe/report/{id}".format(id=row['id'])
        # Convert the raw lat/lon columns into a dict as expected by SODA
        row['location'] = {'longitude': row['longitude'], 'latitude': row['latitude']}
        del row['longitude']
        del row['latitude']
        # Date fields aren't handled by the JSON encoder, so do it manually
        row['reported'] = row['reported'].isoformat()
        row['lastupdate'] = row['lastupdate'].isoformat()
        if row['whensent']:
            row['whensent'] = row['whensent'].isoformat()
        # Photo is stored as a 40-byte ID which needs appending to a URL base
        if row.get("photo"):
            row['photo_url'] = PHOTO_URL.format(id=row['id'], photo=row['photo'])
        del row['photo']
        # Make sure only one receiving body is included
        if row.get("body"):
            row['body'] = row['body'].split(",")[0]
        # Collideoscope stores details about the incident in the 'extra' field
        extra = rabx.unserialise(row['extra'])
        del row['extra']
        row['severity'] = extra.get("severity")
        row['road_type'] = extra.get("road_type")
        row['injury_detail'] = extra.get("injury_detail")
        row['participants'] = extra.get("participants")
        row['media_url'] = extra.get("media_url")
        row['incident_date'] = " ".join((extra.get("incident_date", ""), extra.get("incident_time", "")))
        yield row

def upload_reports(socrata, reports):
    """
    The API chokes if you send too many items at once, so split the
    reports we want to send into smaller batches
    """
    batch_size = 50
    for k, group in groupby(enumerate(reports), lambda x: x[0] // batch_size):
        reports_batch = [i[1] for i in group]
        print socrata.upsert(config['SOCRATA_DATASET_URL'], reports_batch)

def main():
    socrata = socrata_connect()
    cursor = get_cursor()
    query_recent_reports(cursor, limit=None)
    reports = transform_results(cursor)
    upload_reports(socrata, reports)


if __name__ == '__main__':
    main()
