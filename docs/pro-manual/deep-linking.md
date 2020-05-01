---
layout: pro
title: FixMyStreet Pro deep linking
order: 3
user-guide: true
categories: user-guide
---

# FixMyStreet Pro deep linking

Your user will most likely be starting their journey of reporting an issue on
your own website. That may be a generic report an issue page, but could be a
page on a particular type of issue, such as Graffiti or Potholes.

## Generic reporting page

On a generic page, you can link directly to the FixMyStreet Pro front page with
a normal link, or embed a FixMyStreet Pro search form into the page, taking the
user straight to a map page.

### Direct link

Your website will have its own way of adding links.

`<a href="https://your.fixmystreet.example/">Report a problem</a>`

### Embedded form

An embedded form should be a normal HTML form
whose action is `https://your.fixmystreet.example/around` and contains a text
input with name `pc`. Ideally it would also have a hidden field called `js`
that is set to 1 if the user has JavaScript enabled (this can speed the response up).
If you want to get really fancy and add geolocation to your own site, you can
also link to an `/around` page with parameters `latitude` and `longitude`.

```html
<form action="https://your.fixmystreet.example/around">
<label for="pc">Search term:</label>
<input type="text" id="pc" name="pc" value="">
<input type="submit" value="Go">
</form>
```

## Specific category page

On a category page, you can also do either of the above things, but also
include an extra parameter that will restrict the default map view and
reporting to a particular category, categories, or parent category if you use
subcategories.

### Direct link

To link to one category, add a `filter_category` parameter with the
category/subcategory you wish to pre-filter, or provide multiple categories
separated by a comma (if one of your categories contains a comma, surround it
with double quotes). If you use subcategories in your installation and wish to
restrict the map to a particular top-level category, not an individual
subcategory, you should use a `filter_group` parameter with the name of the
top-level category.

* https://your.fixmystreet.example/?filter_category=Graffiti

* https://your.fixmystreet.example/?filter_category="A,+B,+and+C"

* https://your.fixmystreet.example/?filter_category=Graffiti,Flyposting

* https://your.fixmystreet.example/?filter_group=Road+defects

### Embedded form

Within a web form, specify the `filter_category` or `filter_group` as a hidden
field for equivalent behaviour to the link.

Using `filter_category` will restrict the map pins to that category, and
automatically use that category when a report is begun; if you use multiple
categories, the map is filtered but no category is selected when a report is
begun.  Using `filter_group` will restrict the map pins to all subcategories in
that category, preselect that category when a report is begun and the user will
still need to pick the correct subcategory.

```html
<form action="https://your.fixmystreet.example/around">
<input type="hidden" name="filter_category" value="Graffiti">
<label for="pc">Search term:</label>
<input type="text" id="pc" name="pc" value="">
<input type="submit" value="Go">
</form>
```

* `<input type="hidden" name="filter_group" value="Trees">`

* `<input type="hidden" name="filter_category" value='Trees,"Cars, bikes, trains"'>`
