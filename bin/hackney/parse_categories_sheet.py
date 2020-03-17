#!/usr/bin/env python

from __future__ import print_function

import json
import os
import pickle
import sys
from collections import defaultdict
from email.utils import parseaddr

from google.auth.transport.requests import Request
from google_auth_oauthlib.flow import InstalledAppFlow
from googleapiclient.discovery import build

import click
import yaml
from dotenv import load_dotenv

load_dotenv()

# If modifying these scopes, delete the file token.pickle.
SCOPES = ["https://www.googleapis.com/auth/spreadsheets.readonly"]


@click.group()
@click.pass_context
def cli(ctx):
    """
    Parses the Hackney master categories spreadsheet and
    either produces categories.json which can be loaded by import_categories,
    or an layers.js file which sets up the mapping between categories and
    WFS layers and can be copy/pasted into Hackney's assets.js
    """
    creds = None
    # The file token.pickle stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    if os.path.exists("token.pickle"):
        with open("token.pickle", "rb") as token:
            creds = pickle.load(token)
    # If there are no (valid) credentials available, let the user log in.
    if not creds or not creds.valid:
        if creds and creds.expired and creds.refresh_token:
            creds.refresh(Request())
        else:
            flow = InstalledAppFlow.from_client_secrets_file("credentials.json", SCOPES)
            creds = flow.run_console()
        # Save the credentials for the next run
        with open("token.pickle", "wb") as token:
            pickle.dump(creds, token)

    service = build("sheets", "v4", credentials=creds)

    # Call the Sheets API
    sheet = service.spreadsheets()
    result = (
        sheet.values()
        .get(
            spreadsheetId=os.environ["SPREADSHEET_ID"], range=os.environ["SHEET_RANGE"]
        )
        .execute()
    )
    values = result.get("values", [])

    if not values:
        print("No data found.", file=sys.stderr)
        sys.exit(1)

    ctx.obj["values"] = values


@cli.command()
@click.pass_context
def categories(ctx):
    with open("config.yml") as f:
        config = yaml.safe_load(f)
    groups = defaultdict(list)
    for row in ctx.obj["values"]:
        try:
            email = parse_email(row)
        except IndexError:
            # Row might not have been the required width, if there were
            # trailing NULLs.
            continue
        if not email:
            continue
        group, category = row[0], row[1]
        cat_obj = {"category": category, "email": email}
        if config["categories"].get(category, {}).get("extra_fields"):
            cat_obj["extra_fields"] = config["categories"][category]["extra_fields"]
        groups[group].append(cat_obj)
    with open("categories.json", "w") as f:
        json.dump(
            {"disabled_message": os.environ["DISABLED_MESSAGE"], "groups": groups},
            f,
            indent=2,
            sort_keys=True,
        )


@cli.command()
@click.pass_context
def assets(ctx):
    TEMPLATE = """
fixmystreet.assets.add(wfs_defaults, {{
    wfs_feature: "{wfs_layer}",
    asset_category: "{category}",
    attributes: {attributes}
}});
"""
    with open("config.yml") as f:
        config = yaml.safe_load(f)
    with open("layers.js", "w") as layers:
        for row in ctx.obj["values"]:
            try:
                group, category, wfs_layer = row[0], row[1], row[15]
            except IndexError:
                # The Sheets API doesn't return a full row if it's got trailing NULLS?!
                continue
            if not parse_email(row):
                print(
                    f"No email category for WFS layer {row[15]}, skipping.",
                    file=sys.stderr,
                )
                continue
            if wfs_layer:
                attributes = json.dumps(
                    config["categories"].get(category, {}).get("wfs_attributes", {})
                )
                print(
                    TEMPLATE.format(
                        wfs_layer=wfs_layer,
                        category=category,
                        group=group,
                        attributes=attributes,
                    ),
                    file=layers,
                )


def parse_email(row):
    if row[3] == "Alloy":
        # Skip this row entirely if it's going in to Alloy.
        return None
    emails = [row[col] for col in (3, 6, 9) if "@" in row[col]]
    if not emails:
        # Might be an Alloy-only category, or awaiting an email address from Hackney
        return None
    # TODO: Figure out what to do if multiple columns have emails
    if len(emails) > 1:
        print(
            f"WARNING: {row[0]} - {row[1]} has {len(emails)} addresses; using the first one"
        )
    # for now just take the first column that has an @
    email = emails[0]
    if " " in email:
        # need a better way to handle these residential/commercial split categories
        email = email.split(" ", 1)[0]
    if os.getenv("EMAIL_REPLACEMENT"):
        email = email.translate(str.maketrans(".@", "__"))
        email = os.environ['EMAIL_REPLACEMENT'].format(email=email)
    return email


if __name__ == "__main__":
    cli(obj={})
