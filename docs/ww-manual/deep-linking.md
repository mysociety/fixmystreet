---
layout: wasteworks
title: Deep linking from your site
order: 5
user-guide: true
---

# WasteWorks deep linking

Residents will most likely be finding your WasteWorks service from your own website. That may be a generic waste services information page, or another landing page for search terms such as “report missed bin” or “green garden waste”.

### Important notice:
There may be small differences in how WasteWorks functions for different councils, depending on the integrations you have selected, and the individual processes reflected in your workflow. This manual provides a **general overview** of how WasteWorks works, but may not directly reflect your unique set up.

## Generic waste page

On a generic page, you can link directly to the WasteWorks front page with a normal link, or embed a WasteWorks search form into the page, taking the user straight to a “Your bin days” page.

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

## Specific waste type page

You may want to be able to direct residents directly to pages within your WasteWorks service.

#### Linking to ‘reporting a missed collection’ page

`<a href="https://your.wasteworks.example/waste?type=report">Report a missed collection</a>`

#### Linking to ‘request a new container’ page

`<a href="https://your.wasteworks.example/waste?type=request">Request a new container</a>`

#### Linking to ‘subscribe to green garden waste’ page

`<a href="https://your.wasteworks.example/waste?type=garden">Subscribe to a green waste collection</a>`

#### Linking to ‘subscribe to bulky waste’ page

`<a href="https://your.wasteworks.example/waste?type=bulky">Request a bulky waste collection</a>`


