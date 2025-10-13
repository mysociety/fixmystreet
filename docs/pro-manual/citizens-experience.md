---
layout: pro
title: What is FixMyStreet Pro?
order: 2
user-guide: true
category: user-guide
---

# The citizen’s experience

Before we can fully explore how FixMyStreet Pro works for an admin user, it’s important to understand
the report-making process from the citizen’s point of view.

Here’s a brief look at the user experience for members of the public when reporting an issue located within the
boundaries of a council or other authority using FixMyStreet Pro.

## Important notice

This guide provides a **general overview** of each of FixMyStreet Pro's standard features. There may be small differences in how the software functions for different councils, depending on how you use the service, the integration(s) you have selected, and the individual processes reflected in your workflow.

Please speak to your Administrator if you have questions about functionality not covered specifically in the below guidance. If you are the Administrator and you need extra help, please open a ticket on Freshdesk.

***

## Making a report

### Where to report
When a citizen sees a problem and wishes to report it, they can do so in one of three places:

- Through the council website, on the council’s branded FixMyStreet Pro instance
- On [FixMyStreet.com](https://www.fixmystreet.com), the UK-wide site
- Via the FixMyStreet app

<img alt="Make a report on a council website, fixmystreet.com, or via the FixMyStreet app" src="/assets/img/pro-user-guide/all-the-sites.png" />

No matter which of these channels they use, the report will be visible in all three places. All
FixMyStreet instances draw from the same database of reports.

The FixMyStreet website, and the council’s branded version, can also be
installed as a ‘web app’ – providing a logo on their homescreen that users can
treat like a native app without the hassle of app stores. Instructions for how to do this are provided by us as standard and can be found from the 'Help' page of your FixMyStreet Pro site, or by adding about/web-app to the end of your unique FixMyStreet Pro URL.

<div class="boxout" markdown="1">

<h4 class="boxout__title">What if a user makes a report on the council site, but it’s the responsibility of a different authority?</h4>

That’s fine: FixMyStreet Pro will simply divert it to the correct authority. If it’s within your council boundaries (so, if you are within a two- or three-tier area, and the report category is handled by a different council) the report will still show on the map, but it won’t go into your workflow.

In some cases, depending on the type of plan you have opted for and the data available, users may be able to report problems that are within your boundary but are the responsibility of a highways authority or housing association directly via your branded version of FixMyStreet Pro. These reports will not enter your workflow, and the user will be made aware of where their report has been sent.

In all other instances where a user is attempting to report a problem in a location that falls outside of your remit, they're guided to the main FixMyStreet website.

<img alt="Automated report triaging" src="/assets/img/pro-user-guide/Red-routes-automated-triaging.png" />

</div>

### Identifying the report location 

<img alt="The start page invites the resident to search for the location of their issue" src="/assets/img/pro-user-guide/home.png" class="admin-screenshot" />

FixMyStreet’s start page invites the user to search for the location of their issue, by entering any part of an address, for example a street name or postcode. Alternatively they can allow the site to identify their location automatically via GPS.

They’re then taken to a map, centred on this location. The user can pan and zoom the map until they find the exact position of the issue they are reporting. Councils on the Premium plan may choose to include GIS data showing assets such as streetlights or trees which enable further accuracy.

<img alt="Existing reports are visible to reduce the chance of duplicates" src="/assets/img/pro-user-guide/making-report-duplicates.png"  class="admin-screenshot"/>

All reports are published online, so at this stage, citizens can see if their issue has already been reported. FixMyStreet Pro suggests potential duplicates to users based on the location and category of the report.

<img alt="Potential duplicates are actively suggested" src="/assets/img/pro-user-guide/Duplicate-reports.png"  class="admin-screenshot"/>

If a report already exists for the same problem, the user can choose to subscribe to the report, which enables them to automatically receive updates on its progress at not extra work for you, the responsible authority.

If not, they place a pin on the map and make their report.

<img alt="When a report is made the details are added via a web form" src="/assets/img/pro-user-guide/making-report.png" class="admin-screenshot" />

They are asked for:

- A category, selected from those provided by the council
- A title
- A description
- Their contact details (if they have previously registered, these do not need to be
    re-entered)
- Any other information that the council has stipulated as a requirement, eg for potholes
    you may add a field which asks for the dimensions.

If the user is not registered or logged in, they may confirm their report by email.
Note that although it is obligatory to include a name and contact details, the user may opt for their
name not to be shown on the public report page. Of course, their other contact details are only
sent to the council and are never made public.

### Making a report while offline

As a progressive web app, users can access FixMyStreet and your branded FixMyStreet Pro service even while offline. This is particularly beneficial for remote communities or frontline contractors who need to access services even in low-connectivity environments.

<img alt="Using FixMyStreet while offline" src="/assets/img/pro-user-guide/Offline-reporting.jpg" class="admin-screenshot" />

If a user loads FixMyStreet while offline they will see the "You are currently offline" page. From here, the user will be able to start a report, save it as a draft (including being able to upload a photo and store the location of the problem) and come back to submit later when back online. Users can start and save multiple draft reports if needed.

<strong>Draft reports are not submitted automatically when internet connection is restored</strong>. Once reconnected to the internet, users can find all of their draft reports from the homepage, and from here they must manually continue with each draft report and submit accordingly.

## Receiving a response

<img alt="Reponses from the council via email and published on the report page" src="/assets/img/pro-user-guide/report-response.png" class="admin-screenshot" />

Responses from the council come directly back to the user, via the email address they used to
make the report.

Where councils have opted for full integration with FixMyStreet Pro, responses
may also be posted as automatic updates on the report. Responses may take the form of a request
for further information or an update on the status of the issue.

If an integration with Notify has been established, users may also receive responses via text message.

### Updates from other users

FixMyStreet reports are public, and other users may also add updates. This creates an informal
community forum, and also provides a useful way for the council to understand which issues have
the highest visibility or create the most dissatisfaction among residents. Any updates on a report
are sent by email to the report maker, unless they opt out.

## Subscribing to alerts

<img alt="Reponses from the council via email and published on the report page" src="/assets/img/pro-user-guide/local-alerts.png" class="admin-screenshot" />

FixMyStreet users can sign up to receive an email every time a report is made within a specified
area. This can be useful for anyone who wants to keep an eye on issues within their
neighbourhood: it’s often used by councillors, community groups, journalists and neighbourhood
policing teams, as well as by residents.

To set up an email alert, click on ‘Local alerts’ in the top menu bar. Input a postcode or place name
and you’ll be offered a range of options: you can subscribe to every report made within the entire
council area; every report made within a particular ward; or within an area roughly covering a
population of 200,000 people (the size of this area varies with population density).
Staff need not normally do this, as they will be working in the reports interface daily, and will be
aware of issues as they arise.
