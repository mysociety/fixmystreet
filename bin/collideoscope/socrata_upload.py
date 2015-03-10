#!/usr/bin/env python
import os

import yaml
import sodapy
import psycopg2
import psycopg2.extras

yml_path = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "..", "..", "conf", "general.yml"
))
with open(yml_path) as f:
    config = yaml.load(f)

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
    query = "SELECT id, latitude, longitude, confirmed, category, title " \
            "FROM problem " \
            "WHERE state = 'confirmed' " \
            "ORDER BY confirmed ASC " \
            "LIMIT %s"
    cursor.execute(query, (limit, ))

def transform_results(cursor):
    """
    Returns an iterable of dicts suitable for uploading to Socrata.
    This must be called immediately after query_recent_reports because
    it operates on results held in the cursor.
    """
    for row in cursor:
        # Turn the date into a string ourselves as the JSON encoder can't
        # TODO: Parse the problem 'extra' field to get actual incident date
        row['occurred'] = row['confirmed'].isoformat()
        del row['confirmed']
        row['url'] = "http://collideosco.pe/report/{id}".format(id=row['id'])
        # Convert the raw lat/lon columns into a dict as expected by SODA
        row['location'] = {'longitude': row['longitude'], 'latitude': row['latitude']}
        del row['longitude']
        del row['latitude']
        yield row

def upload_reports(socrata, reports):
    print socrata.upsert(config['SOCRATA_DATASET_URL'], list(reports))

def main():
    socrata = socrata_connect()
    cursor = get_cursor()
    query_recent_reports(cursor, limit=5)
    reports = transform_results(cursor)
    upload_reports(socrata, reports)


if __name__ == '__main__':
    main()
