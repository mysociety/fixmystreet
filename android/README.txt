FixMyStreet Android application
==============================

The Fix My Street directory contains a complete application that should open
directly in Eclipse.

However, to compile it as an .apk, you will need to add the following JAR files 
to your build path - these make the multipart messages work.

- commons-httpclient.jar
- httpcomponents-client-4.0-alpha4.lib 

Hopefully these will no longer be needed in future versions of Android. 

I've compiled it against version 1.5 (Cupcake).

Note that the app has to be signed to go onto the Android Market, contact
anna@mysociety.org to do this.

TODO (if you're an Android developer and wish to help mySociety,
----      feel free to volunteer for any of these)

* Improve flow - when you start the app, there should really be a 
welcome message explaning what FMS is, and a "Click here to take 
a photo" button, then after the photo a "Now add your details" screen. 
At the moment the opening screen doesn't really make sense unless you
already know what FixMyStreet is - it should be more welcoming.
