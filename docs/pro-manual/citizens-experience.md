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

This guide provides a **general overview** of each of FixMyStreet Pro's standard features. There may be small differences in how the software functions for different authorities, depending on how you use the service, the integration(s) you have selected, and the individual processes reflected in your workflow.

Please speak to your Administrator if you have questions about functionality not covered specifically in the below guidance. If you are the Administrator and you need extra help, please open a ticket on Freshdesk.

***

## Making a report

### Where to report
When a citizen sees a problem and wishes to report it, they can do so in one of three places:

- Through your authority's website, using your branded FixMyStreet Pro instance
- On [FixMyStreet.com](https://www.fixmystreet.com), the UK-wide site
- Via the FixMyStreet app

<img loading="lazy" alt="Make a report on an authority's website, fixmystreet.com, or via the FixMyStreet app" src="/assets/img/pro-user-guide/all-the-sites.png" />

No matter which of these channels they use, the report will be visible in all three places. All FixMyStreet instances draw from the same database of reports.

The FixMyStreet website, and the authority’s branded version, can also be installed as a ‘web app’ – providing a logo on their homescreen that users can treat like a native app without the hassle of app stores. Instructions for how to do this are provided by us as standard and can be found from the 'Help' page of your FixMyStreet Pro site, or by adding about/web-app to the end of your unique FixMyStreet Pro URL.

<div class="boxout" markdown="1">

<h4 class="boxout__title">What if a user makes a report on our site, but it’s the responsibility of a different authority?</h4>

That’s fine: FixMyStreet Pro will simply divert it to the correct authority. If it’s within your boundary (so, if you are within a two- or three-tier area, and the report category is handled by a different authority) the report will still show on the map, but it won’t go into your workflow.

In some cases, depending on the type of plan you have opted for and the data available, users may be able to report problems that are within your boundary but are the responsibility of a highways authority or housing association directly via your branded version of FixMyStreet Pro. These reports will not enter your workflow, and the user will be made aware of where their report has been sent.

In all other instances where a user is attempting to report a problem in a location that falls outside of your remit, they're guided to the main FixMyStreet website.

<img loading="lazy" alt="Automated report triaging" src="/assets/img/pro-user-guide/Red-routes-automated-triaging.png" />

</div>

### Logging in

<strong>Note:</strong> it is not obligatory for users to log in or create an account if they do not wish to, but if they don't they will need to confirm their reports via email before they are submitted. 

Users can sign in to their account by selecting 'Sign in' from the main site menu, or via the app. If a user already has an account on fixmystreet.com, they can use the same details on your FixMyStreet Pro site.

Depending on your FixMyStreet Pro plan and the integrations you have selected, existing single sign-on accounts can be synced up, meaning users who are residents within your area can use their existing credentials to sign in to your FixMyStreet Pro service.

<img loading="lazy" alt="The start page invites the resident to search for the location of their issue" src="/assets/img/pro-user-guide/signing-in-sso.jpeg" class="admin-screenshot" />

When logged in, users will be able to view all of their previous reports and they won't be required to manually confirm each new report via email.

### Identifying the report location 

<img loading="lazy" alt="The start page invites the resident to search for the location of their issue" src="/assets/img/pro-user-guide/home.jpeg" class="admin-screenshot" />

FixMyStreet’s start page invites the user to search for the location of their issue, by entering any part of an address, for example a street name or postcode. Alternatively they can allow the site to identify their location automatically via GPS.

They’re then taken to a map, centred on this location. The user can pan and zoom the map until they find the exact position of the issue they are reporting. Should the user pan too far, they can re-centre the map using the arrow button.

<img loading="lazy" alt="Clicking the arrow button re-centres the map" src="/assets/img/pro-user-guide/re-centre-the-map.jpeg" class="admin-screenshot" />

Depending on your FixMyStreet Pro plan and the availability of GIS data, users may be able to select individual assets from the map, such as streetlights or trees, which enable further report accuracy. They may also be able to select an aerial view of the map, which, if available, can be toggled to by selecting the satellite icon. 

<img loading="lazy" alt="Selecting the satellite icon toggles to an aerial map view" src="/assets/img/pro-user-guide/Toggling to aerial map view.jpeg" class="admin-screenshot" />

When selected, the map will switch to the aerial view, displaying the map layers available from your server.
<img loading="lazy" alt="The aerial map view" src="/assets/img/pro-user-guide/Aerial map view.jpeg" class="admin-screenshot" />

### Avoiding duplicates

All reports are published online, so at this stage users can see if their issue has already been reported. FixMyStreet Pro suggests potential duplicates based on the location and category of the report.

<img loading="lazy" alt="Existing reports are visible to reduce the chance of duplicates" src="/assets/img/pro-user-guide/making-report-duplicates.png"  class="admin-screenshot"/>

If a report already exists for the same problem, the user can choose to subscribe to the report, which enables them to automatically receive updates on its progress at no extra work for you, the responsible authority.

<img loading="lazy" alt="Potential duplicates are actively suggested" src="/assets/img/pro-user-guide/Duplicate-reports.png"  class="admin-screenshot"/>

If not, they place a pin on the map and make their report.

<img loading="lazy" alt="When a report is made the details are added via a web form" src="/assets/img/pro-user-guide/making-report.png" class="admin-screenshot" />

### Choosing a category

Users are asked to select an appropriate category for their report, either by typing in the search bar or choosing from the list of all available categories and subcategories (these are managed by you, the authority, and reflect the issues you can deal with).

<img loading="lazy" alt="Choosing a category" src="/assets/img/pro-user-guide/choosing-a-category.jpeg" class="admin-screenshot" />

Upon selecting certain categories, users may be shown a message from you to provide further information about how a report in this category will be handled (eg to explain seasonal maintenance schedules for grass cutting) or to divert potential emergencies (eg oil spills, failed traffic lights or fallen trees). 

<img loading="lazy" alt="Messages can be displayed at various points within the reporting workflow" src="/assets/img/pro-user-guide/Displaying a message.png" class="admin-screenshot" />

### Providing necessary information

Users are also asked to provide:
- A title for their report
- A description of the problem
- Their contact details (if they are logged in, these do not need to be
    re-entered) except in instances where you have enabled anonymous reporting
- Any other information that you have stipulated as a requirement, eg for potholes you may add a field which asks for the dimensions, or for drains you may want to qualify whether the blockage is within or on top of the drain.

<img loading="lazy" alt="Answering extra questions" src="/assets/img/pro-user-guide/extra-questions-example.jpeg" class="admin-screenshot" />

<strong>Note:</strong> Unless you have enabled anonymous reporting on a category, it is obligatory for users to include a name and contact details with their report. 

By default, names are not shown on the public report. The user may opt for their name to be shown on the public report page if they wish. Of course, their other contact details are only sent to the authority and are never made public.

<img loading="lazy" alt="Checking the box will display the reporter name publicly" src="/assets/img/pro-user-guide/Option to show name publicly.png" class="admin-screenshot" />

### Submitting and confirming a report

Users are informed of which authority their report will be sent to, and have the chance to review the information provided before submitting the report.

If the user is not registered or logged in, they may confirm their report by email. If they are logged in, they won't need to do this.

Once a report is confirmed and submitted to the authority, a confirmation email is sent to the report-maker and that report will be published on the map for others to see.

### Making a report while offline

As a progressive web app, users can access FixMyStreet and your branded FixMyStreet Pro service even while offline. This is particularly beneficial for remote communities or frontline contractors who need to access services even in low-connectivity environments.

<img loading="lazy" alt="Using FixMyStreet while offline" src="/assets/img/pro-user-guide/Offline-reporting.jpg" class="admin-screenshot" />

If a user loads FixMyStreet while offline they will see the "You are currently offline" page. From here, the user will be able to start a report, save it as a draft (including being able to upload a photo and store the location of the problem) and come back to submit later when back online. Users can start and save multiple draft reports if needed.

<strong>Note:</strong> Draft reports are <strong>not</strong> submitted automatically when internet connection is restored. Once reconnected to the internet, users can find all of their draft reports from the homepage, and from here they must manually continue with each draft report and submit accordingly.

## Receiving a response

<img loading="lazy" alt="Reponses from the council via email and published on the report page" src="/assets/img/pro-user-guide/report-response.png" class="admin-screenshot" />

Responses from you, the authority, come directly back to the user via the email address they used to make the report. 

If an integration with Notify has been established, users may also receive responses via text message.

If required, and depending on how you manage responses, you can ask the user to specify their preference for how they would like to receive updates.

If you have opted for full integration with FixMyStreet Pro, responses may also be posted as automatic updates on the report. Responses may take the form of a request for further information or an update on the status of the issue.

### Updates from other users

FixMyStreet reports are public, and other users may also add updates <strong>unless you have disabled this functionality</strong>. 

Enabling other users to add updates creates an informal community forum, and also provides a useful way for the authority to monitor a problem’s priority without needing to carry out continuous inspections.

Any updates on a report are sent by email to the report maker, unless they opt out.

## Subscribing to alerts

<img loading="lazy" alt="Reponses from the council via email and published on the report page" src="/assets/img/pro-user-guide/local-alerts.png" class="admin-screenshot" />

FixMyStreet users can sign up to receive an email every time a report is made within a specified area. This can be useful for anyone who wants to keep an eye on issues within their neighbourhood: it’s often used by councillors, community groups, journalists and neighbourhood policing teams, as well as by residents.

To set up an email alert, users click on ‘Local alerts’ in the top menu bar, or from any map page. They then input a postcode or place name to be offered a range of options: subscribe to every report made within the entire area; every report made within a particular ward; or within an area roughly covering a population of 200,000 people (the size of this area varies with population density).

<strong>Note:</strong> Staff users need not normally do this, as they will be working in the reports interface daily, and will be aware of issues as they arise.
