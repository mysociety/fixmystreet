---
layout: wasteworks
title: Deep linking from your site
order: 5
user-guide: true
---

# WasteWorks deep linking

Residents will most likely be directed to your WasteWorks service from your own website, either from a generic waste services information page, or another landing page for search terms such as “report missed bin” or “green garden waste”.

This section of the manual provides guidance on different ways to deep link to WasteWorks from your website. 

***

## Linking from a generic waste page

On a generic page about your waste services, you can link directly to the WasteWorks front page with a normal link, or embed a WasteWorks search form into the page, taking the user straight to a “Your bin days” page.

#### Direct Link

Your website will have its own way of adding links.

`<a href="https://your.wasteworks.example/">Check your bin days</a>`

#### Embedded form
An embedded form should be a normal HTML form whose action is `https://your.wasteworks.example/waste` and contains a text input with name `postcode`.

```html <form action="https://your.wasteworks.example/waste">
<label for="postcode">Search term:</label>
<input type="text" id="postcode" name="postcode" value="">
<input type="submit" value="Go">
</form>
```

## Linking from a specific waste type page

You may also want to link to WasteWorks from pages about specific waste services, such as a landing page about reporting a missed collection, or one about green waste subscriptions (if included in your WasteWorks package). 

In these instances, you can link directly to the corresponding page on WasteWorks to create a seamless user journey for residents, and for staff operating on behalf of residents who require extra support. See examples below:

#### Linking to ‘reporting a missed collection’ page

`<a href="https://your.wasteworks.example/waste?type=report">Report a missed collection</a>`

#### Linking to ‘request a new container’ page

`<a href="https://your.wasteworks.example/waste?type=request">Request a new container</a>`

#### Linking to ‘subscribe to green garden waste’ page

`<a href="https://your.wasteworks.example/waste?type=garden">Subscribe to a green waste collection</a>`

#### Linking to ‘subscribe to bulky waste’ page

`<a href="https://your.wasteworks.example/waste?type=bulky">Request a bulky waste collection</a>`

## Linking directly to a property page

Each property page on WasteWorks has its own ID. What that ID is can depend upon the
backend waste system used, sometimes for performance reasons. If you hold the UPRN for a property,
say because a user has already looked up their address in a form on your website, then you can
always get directly to a property page by linking to a URL of the form:

`https://your.wasteworks.example/property/UPRN`
