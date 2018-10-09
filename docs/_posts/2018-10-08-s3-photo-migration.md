---
layout: post
title: Migrating to S3 photo storage
author: davea
---

The [recent release of FixMyStreet v2.4.1](/2018/10/01/v2.4.1/) brought with
it the ability to store photos for reports & updates in a bucket on Amazon's
S3 instead of locally on disk.

Getting a new site configured to store newly uploaded photos in S3 is explained
in the [configuration pages](/customising/config/#photo_storage_backend), and
is a matter of tweaking a few keys in your `general.yml` file. But what about
if you have an existing FixMyStreet installation that you would like to
migrate to storing all photos in S3? This post outlines a process for
achieving just that - without any downtime.


## Prerequisites

 - A running FixMyStreet site with at least one report or update with a photo
 - An account on Amazon AWS, and access/secret keys for a role that can create/manage S3 buckets
 - The [AWS CLI](https://aws.amazon.com/cli/) tool installed on your FixMyStreet server, and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) with access credentials


## Creating the bucket

First off, we need to create a bucket to hold all the photos. If you've already done this, skip ahead to the **[Migrating photos](#migrating-photos)** section.

We'll show two ways to create a bucket: via the S3 web console and using the `aws` command line tool.

### Using the S3 web console

Log in to [S3 web console](https://s3.console.aws.amazon.com/s3/home), and click the 'Create Bucket' button

![](/assets/posts/s3-migration-create-bucket.png)

Enter a name for the bucket, e.g., `my-fixmystreet-photos`, and choose the region closest to your FixMyStreet server ([more about buckets and regions](https://docs.aws.amazon.com/AmazonS3/latest/dev/UsingBucket.html)):

![](/assets/posts/s3-migration-bucket-details.png)

Your newly created bucket should then appear in the list of buckets. Make sure public access isn't allowed (photos are served to users via your FixMyStreet server, not directly from S3):

![](/assets/posts/s3-migration-bucket-private.png)

If everything looks OK, skip to the **[Migrating photos](#migrating-photos)** section.

### Using the `aws` CLI tool

You can also create buckets from the command line using the `aws` tool.

If you've not already done so, now is the time to [install](https://aws.amazon.com/cli/) and [configure](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) the `aws` CLI tool.

To create a bucket named `my-fixmystreet-photos` in the `eu-west-1` region, run the following:

```bash
$ aws s3 mb s3://my-fixmystreet-photos --region eu-west-1
```

The following success message should be shown:

```
make_bucket: my-fixmystreet-photos
```

The bucket's region can be inspected:

```bash
$ aws s3api get-bucket-location --bucket my-fixmystreet-photos
{
    "LocationConstraint": "eu-west-1"
}
```

The bucket should be created as private by default, but you may wish to check its access policy
on the [S3 web console](https://s3.console.aws.amazon.com/s3/home).


## Migrating photos

Now that the bucket has been created, the next step is to fill it with all the photos
from your existing FixMyStreet installation. For this we'll need the `aws` CLI tool,
so make sure you've [installed](https://aws.amazon.com/cli/) and [configured](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-getting-started.html) it.

Existing photos are stored on disk in the directory specified by the `UPLOAD_DIR`
(or `PHOTO_STORAGE_OPTIONS.UPLOAD_DIR`) configuration key in `conf/general.yml`.
For this example, let's assume that's `/home/fixmystreet/photos`.

Running the following (with the path and bucket name altered to suit your configuration)
will make copy-pasting the subsequent commands a little easier:

```bash
$ export UPLOAD_DIR=/home/fixmystreet/photos
$ export S3_BUCKET=my-fixmystreet-photos
```

We'll use `aws s3 sync` to copy all photos to the new S3 bucket. To get a preview of
the operations it will perform without actually copying anything, run:

```bash
$ aws s3 sync $UPLOAD_DIR s3://$S3_BUCKET --dryrun
```

You should see output similar to the following, one line for each file:

```
(dryrun) upload: /home/fixmystreet/photos/069a5d216321061757fe30a6d7f862669eb46d7d.jpeg to s3://my-fixmystreet-photos/069a5d216321061757fe30a6d7f862669eb46d7d.jpeg
(dryrun) upload: /home/fixmystreet/photos/0d7db3b2cd615e27c50345c8144b6b9782d7ff4a.jpeg to s3://my-fixmystreet-photos/0d7db3b2cd615e27c50345c8144b6b9782d7ff4a.jpeg
(dryrun) upload: /home/fixmystreet/photos/137dfb5fe88c0207e2a339b02fcbc5e812b4e68b.jpeg to s3://my-fixmystreet-photos/137dfb5fe88c0207e2a339b02fcbc5e812b4e68b.jpeg
[...]
```

If the output looks correct, re-run without the `--dryrun` flag to actually copy
everything to the S3 bucket:

```bash
$ aws s3 sync $UPLOAD_DIR s3://$S3_BUCKET
upload: /home/fixmystreet/photos/069a5d216321061757fe30a6d7f862669eb46d7d.jpeg to s3://my-fixmystreet-photos/069a5d216321061757fe30a6d7f862669eb46d7d.jpeg
upload: /home/fixmystreet/photos/0d7db3b2cd615e27c50345c8144b6b9782d7ff4a.jpeg to s3://my-fixmystreet-photos/0d7db3b2cd615e27c50345c8144b6b9782d7ff4a.jpeg
upload: /home/fixmystreet/photos/137dfb5fe88c0207e2a339b02fcbc5e812b4e68b.jpeg to s3://my-fixmystreet-photos/137dfb5fe88c0207e2a339b02fcbc5e812b4e68b.jpeg
[...]
```

All your photos are now in S3, so the next step is to tell FixMyStreet about the new bucket.
(See the note in **[the final section](#final-steps--tidying-up)** for reports made between now
and when the FixMyStreet config has been updated to use S3.)


## Configuring FixMyStreet to use S3

We need to make a few changes to `conf/general.yml` to configure FixMyStreet to
use the new S3 bucket for photo storage.

Your `conf/general.yml` probably has a section similar to the following:

```yaml
PHOTO_STORAGE_BACKEND: 'FileSystem'
PHOTO_STORAGE_OPTIONS:
    UPLOAD_DIR: '../photos'
```

Or, if you set the site up before v2.4.1:

```yaml
UPLOAD_DIR: '../photos'
```

Either way, you need to replace that section with the following:

```yaml
PHOTO_STORAGE_BACKEND: 'S3'
PHOTO_STORAGE_OPTIONS:
    BUCKET: 'my-fixmystreet-photos'
    ACCESS_KEY: 'AKIA12345'
    SECRET_KEY: '1234/1234'
```

Make sure you set `BUCKET`, `ACCESS_KEY` and `SECRET_KEY` to the same values
as when you configured the `aws` CLI tool and created the bucket.

These changes are all that's needed to switch your FixMyStreet installation to using
S3 for photos. Once you're happy with the changes you've made to `conf/general.yml`,
restart the FixMyStreet app server ([example](/updating/#restart-the-server)) and
check the output for any errors.

Once the server has restarted, try making a new report and uploading a couple of photos.
You should see new files appear in the S3 bucket (you can view them via the S3 web console)
as soon as you've drag-dropped them into the new report (or update) form. Check that report
photos appear on the site for newly-created reports too. **NB** photos for existing reports
are likely already cached on disk by FixMyStreet, so do check a new report.


## Final steps & tidying up

Because there was a small window of time between syncing existing photos to the S3 bucket
and switching over the `conf/general.yml` config, there's a chance that a report with
photos was made whose photos weren't synced to S3.
Now that FixMyStreet is using S3, you may wish to re-run the `aws s3 sync` command from above
in order to make sure any such photos have been transferred to S3.

The old directory containing photos on disk isn't needed any more, so once you're happy
the S3 storage is working as expected, you can delete this.
