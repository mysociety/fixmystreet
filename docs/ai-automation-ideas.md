---
title: AI and Automation Ideas for FixMyStreet
---

# AI and Automation Ideas for FixMyStreet

This document is a structured brainstorm about how a FixMyStreet installation could use real data, synthetic data, AI, and automation to improve real-world operations.

It is intentionally broader than "add a chatbot". The platform already has a rich operational model:

- public reports with location, category, body routing, photos, states, timestamps, and updates
- user accounts, tokens, moderation, alerts, and staff workflows
- waste-specific workflows with wizard forms, payments, and property lookups
- outbound integrations such as Open311, email, and council-specific APIs

That means the strongest AI opportunities are not generic marketing features. They are operational tools that reduce manual work, improve routing quality, detect risk earlier, and help staff make faster decisions with better context.

## Framing Principles

Any serious AI or automation work here should be guided by a few principles.

### 1. Start with operational leverage, not novelty

The best first projects are the ones that save staff time or reduce failure rates:

- better category suggestions
- duplicate detection
- triage assistance
- anomaly detection
- summarization for staff
- automated data quality checks

### 2. Use deterministic rules before AI where rules are enough

Many problems in this domain are partly solved with:

- existing report states
- body/category mappings
- metadata in contacts and extra fields
- known geographic boundaries
- form constraints

AI should sit on top of those systems, not replace them.

### 3. Separate low-risk assistive AI from high-risk autonomous AI

Reasonable:

- "suggested category: pothole"
- "possible duplicate of report 12345"
- "draft summary for staff"
- "reports likely to need inspection first"

Higher risk:

- auto-closing reports
- changing category without human review
- deciding abuse/moderation outcomes without a person
- sending legally or operationally meaningful external messages unaudited

### 4. Build on data provenance

Every model output used by staff should ideally preserve:

- input records used
- model version
- prompt or rules version
- confidence or supporting evidence
- whether a human accepted or overrode the suggestion

That feedback loop is essential if the system is to improve safely.

## What Real Data Exists in the Platform

The application already appears to store or derive a useful set of operational data.

### Core report data

From the `Problem` model and surrounding flows, a deployment can typically access:

- report ID
- title and detail text
- latitude and longitude
- postcode
- category and subcategory
- target body or bodies
- state and send state
- timestamps for creation, confirmation, sending, and updates
- extra metadata
- photo references
- cobrand and language
- response priority or defect type where configured

### Update and moderation data

The platform also has:

- user updates and staff updates
- moderation history
- admin logs
- questionnaires and state transitions
- duplicate relationships
- non-public and hidden report handling

This is valuable for downstream analytics and training labels.

### User and operational data

Potentially available, depending on deployment and permissions:

- reporter history
- body-user actions
- assigned users and planned reports
- alert subscriptions
- send failures and retry history
- payment and waste workflow state

### External enrichment possibilities

Some additional real data could be linked without changing the public workflow:

- weather history at report time
- traffic and road class data
- asset inventory data from councils
- deprivation or population density data
- streetworks schedules
- past maintenance activity
- ward, district, and constituency boundaries
- image embeddings generated from submitted photos

## How To Source Real Data Responsibly

There are several realistic ways to source data for experimentation and production use.

## 1. Historical production exports

The most valuable source is historical report data from a real deployment.

Use cases:

- training category suggestion models
- duplicate detection
- routing quality audits
- backlog forecasting
- identifying seasonal patterns

Recommended approach:

- create a controlled export pipeline from the database
- remove direct identifiers where not needed
- tokenize or pseudonymize user identifiers
- separate free text and image access into stricter review paths
- create task-specific derived tables rather than giving broad raw access

Examples of export tables:

- `report_facts`
- `report_updates`
- `triage_actions`
- `staff_decisions`
- `send_failures`
- `waste_payments`
- `duplicate_pairs`

## 2. Moderation and staff action logs as labels

Human decisions are often the best source of supervision.

Examples:

- category changes after initial submission
- state changes after inspection
- reports marked duplicate
- reports marked hidden or abusive
- priority changes
- location edits

These can produce high-value labels such as:

- initial category was wrong
- report needed manual rerouting
- report was likely duplicate
- report was low quality
- report needed urgent response

## 3. Integration logs

Outbound integration data is easy to overlook, but highly valuable.

Examples:

- Open311 request success and failure patterns
- send failure reason text
- external body IDs and resolution outcomes
- latency from report creation to external acceptance

These can support:

- failure prediction
- smart retry prioritization
- identifying brittle integrations
- detecting misconfigured categories or bodies

## 4. Public open data

Many councils publish useful data that can be joined with reports:

- road network and road class
- flood zones
- housing and land use
- cleansing schedules
- gritting routes
- asset inventories
- waste collection routes
- ward boundaries
- service performance statistics

This can enrich analysis without introducing personal data.

## 5. Manual annotation projects

If the deployment has a moderate amount of data but weak labels, a targeted annotation effort may be more useful than large-scale modeling.

Possible annotation tasks:

- "is this photo usable?"
- "is this clearly a duplicate candidate?"
- "does the text describe a safety-critical issue?"
- "is the category obvious from title + detail + image?"
- "would a summary save staff time here?"

This is especially useful for evaluation sets.

## How To Generate Synthetic Data

Synthetic data is useful here, but only when applied carefully. The goal is not to fake a production dataset and pretend it behaves like reality. The goal is to support development, testing, privacy-safe experimentation, and edge-case coverage.

## 1. Deterministic synthetic records from schema knowledge

Given the domain model, a generator can create synthetic reports with fields such as:

- realistic categories
- plausible titles and details
- coordinates constrained to selected areas
- matching body IDs and category mappings
- state progressions over time
- update sequences
- waste bookings, amendments, and cancellations

This is useful for:

- local development
- demo environments
- performance testing
- integration testing
- UI testing for staff tools

Best practice:

- generate relationally valid records, not just isolated rows
- model realistic transitions between states
- include malformed and edge-case records on purpose

## 2. LLM-generated narrative data constrained by templates

LLMs can generate plausible titles, descriptions, and staff updates if tightly constrained.

Examples:

- "Generate 50 pothole reports in plain UK English, each 1-2 sentences, with varying detail quality."
- "Generate a batch of noisy duplicate reports for the same underlying issue."
- "Generate waste enquiry texts involving missed bins, contamination claims, and replacement requests."

Important constraints:

- require structured JSON output
- attach known category/body labels from templates or seed rules
- prohibit personal names, addresses, and phone numbers unless synthetically templated
- validate outputs with deterministic checks

This produces useful NLP training and evaluation data, especially for summarization, classification, and duplicate detection prototypes.

## 3. Synthetic image data

Synthetic image generation could help in narrow cases:

- generating placeholder issue photos for UI demos
- augmenting training sets for photo quality classifiers
- simulating obstruction, lighting, blur, and distance conditions

Less reliable use:

- trying to replace real street-issue imagery for core detection models

Recommendation:

- use synthetic images for robustness testing and demos
- rely on real reviewed images for anything operational

## 4. Privacy-preserving derived synthetic datasets

A valuable middle ground is a synthetic dataset statistically shaped by real distributions.

Examples:

- report volume by hour, weekday, month, ward
- category mix by cobrand or authority
- proportion of duplicates
- distribution of title lengths and update counts
- send failure rates by body

This can support:

- load testing
- forecasting experiments
- dashboard development
- stakeholder demos

without exposing raw personal data.

## Candidate AI and Automation Use Cases

Below are the most plausible, high-value opportunities.

## 1. Category suggestion on report submission

### What it does

Suggest the most likely category or top three categories from:

- title
- detail
- location
- optional photo
- cobrand

### Why it matters

Mis-categorization causes downstream routing and staff workload problems. This is one of the clearest areas where assistive AI can improve the user journey and reduce correction work.

### Implementation shapes

- rules + keyword baseline
- text classifier over title/detail
- multimodal ranking using text plus image embedding
- area-aware re-ranking using what categories are valid for that point/body

### Human interaction pattern

- preselect top suggestion only when confidence is high
- otherwise show ranked suggestions
- always let user override

### Needed data

- historical reports
- category corrections by staff
- body/category availability by location

## 2. Duplicate detection and clustering

### What it does

Find:

- exact duplicates
- near duplicates
- repeated reports of the same physical issue over a short period

### Why it matters

Duplicate reports are common in civic reporting systems. Better detection can reduce user frustration, reduce unnecessary staff handling, and improve issue visibility.

### Signals

- text similarity
- spatial proximity
- temporal proximity
- category similarity
- image similarity
- same asset ID or same property

### Output styles

- show "possibly already reported nearby"
- suggest likely duplicate in staff triage
- cluster recurring issue hotspots

### Required caution

Do not auto-merge or auto-hide purely from a model score unless the deployment has very strong safeguards.

## 3. Staff-facing triage summarization

### What it does

Generate concise summaries such as:

- "Resident reports a large pothole outside number 17, visible for two weeks, causing cyclists to swerve."
- "Two previous nearby reports appear related."
- "Photo quality low; location confidence moderate."

### Why it matters

Staff often need quick situational context. Summaries can reduce reading time, especially for long descriptions, repeated updates, or grouped waste interactions.

### Good use cases

- long free-text reports
- reports with many updates
- waste cases with multiple amendments and payment history
- handover between staff teams

### Better than naive summarization

Use structured prompts that include:

- current state
- latest update
- category
- timestamps
- prior duplicates
- body routing

Then instruct the model to avoid guessing beyond source data.

## 4. Intelligent report routing audit

### What it does

Check whether a submitted report was likely routed to the wrong body or category.

### Why it matters

This is operationally valuable and lower risk than fully automatic rerouting.

### Possible outputs

- "High probability of reroute needed"
- "This category historically goes to a different body in this polygon"
- "This location and category combination has an abnormal failure rate"

### Data needed

- historical successful sends
- send failures
- staff rerouting decisions
- area/body mappings

## 5. Quality scoring for incoming reports

### What it does

Assign a quality score based on:

- title/detail completeness
- category clarity
- location precision
- photo usability
- signs of spam or abuse

### Why it matters

Useful for:

- prompting the user to improve the report before submission
- prioritizing staff review
- suppressing low-value automations on poor-quality input

### Example actions

- "Please add a clearer description"
- "The photo is too dark or too distant"
- "This looks like it may belong to a different category"

## 6. Abuse, spam, and low-trust detection

### What it does

Flag likely abuse, nuisance submissions, repeated hostile text, or bot-like behavior.

### Why it matters

The platform already has abuse concepts. AI can help rank or flag suspicious content before manual moderation.

### Inputs

- text toxicity or abuse indicators
- repeated patterns across accounts or IPs
- image irrelevance
- unusual submission velocity

### Constraint

This should be advisory first. False positives here are politically and operationally expensive.

## 7. Photo analysis assistance

### What it does

Assess whether the photo:

- contains a visible issue
- is too blurry, dark, distant, or obstructed
- matches the reported category
- contains sensitive content requiring caution

### Practical benefits

- better user prompts at upload time
- fewer unusable reports
- improved staff triage

### Narrow and realistic first step

Start with quality and relevance classification, not "fully detect potholes".

## 8. Prioritization and backlog forecasting

### What it does

Predict which reports are most likely to:

- require manual intervention
- become overdue
- trigger complaints or escalations
- correspond to safety-critical issues

### Why it matters

This helps staff allocate limited inspection effort and spot backlogs before they worsen.

### Useful features

- category
- body
- area
- time of day or season
- prior send failures
- duplicate volume
- text urgency signals
- historic SLA outcomes

## 9. Automated drafting for staff updates

### What it does

Produce draft public updates from structured state changes.

Examples:

- "This report has been inspected and scheduled for repair."
- "A replacement bin request has been logged and is awaiting dispatch."

### Why it matters

This reduces repetitive writing and can improve communication consistency.

### Constraint

It should draft from known state and configured templates, not invent operational detail.

## 10. Waste-service assistants

Waste workflows look especially suited to automation because they are structured and repetitive.

### Potential uses

- detect likely duplicate missed-bin reports for the same service/date/property
- summarize booking, payment, amendment, and cancellation history
- suggest next best action for staff
- detect payment failure patterns
- route common enquiries to the right form or outcome
- identify properties repeatedly affected by the same service issue

### Strong value

Waste is often where large call volumes and process complexity meet. That usually means better ROI from operational automation than from public-facing generative features.

## 11. Geographic hotspot and trend detection

### What it does

Automatically identify:

- emerging clusters of similar issues
- seasonal hotspots
- repeated failures tied to specific roads, estates, or assets
- unusual spikes after storms or service disruptions

### Outputs

- internal maps
- scheduled alerts to operations teams
- suggested campaigns or maintenance sweeps

### This may not even need generative AI

Classical analytics and anomaly detection could do most of the work.

## 12. Knowledge extraction from historic reports

### What it does

Turn historic free text and outcomes into reusable operational knowledge.

Examples:

- common reasons for send failures by body
- top phrases associated with incorrect categories
- most common follow-up questions by service
- typical resolution times by issue type

This can support documentation, staff training, and better form design.

## High-Value Non-Generative Automation

Not everything useful here needs a model. Some strong opportunities are plain automation.

## 1. Data quality dashboards

Track:

- reports missing usable photos
- categories with high correction rates
- bodies with high send failure rates
- forms with abandonment spikes
- waste journeys with payment drop-off

## 2. Continuous routing audits

Nightly jobs could detect:

- categories with abnormal reroute frequency
- categories mostly producing send failures
- contacts with stale metadata
- bodies with drifting response template usage

## 3. Auto-generated evaluation sets

Use live data pipelines to continuously assemble:

- new labeled duplicate pairs
- new corrected-category examples
- send-failure cases
- low-quality photo examples

This keeps model evaluation grounded in current operational reality.

## 4. Staff queue ranking

Even without ML, heuristic ranking can prioritize:

- safety-related categories
- reports with many duplicates
- reports near schools or major roads
- reports with repeated send failures
- waste bookings with payment anomalies

## What Synthetic Data Should Be Used For

Synthetic data is especially appropriate for the following.

## 1. Demo and sales environments

Create realistic but safe environments with:

- active maps
- staff backlogs
- routed reports
- waste bookings
- duplicate clusters
- sample photos

This is better than blank environments or obviously fake lorem ipsum.

## 2. Development and integration tests

Generate:

- large volumes of reports
- multi-body routing edge cases
- weird state transitions
- moderation histories
- grouped waste reports
- send failures and retries

## 3. Safety testing for AI features

Create adversarial sets:

- vague descriptions
- conflicting text and image
- joke reports
- abuse content
- borderline duplicates
- malformed coordinates

## 4. Early modeling before real-data access is approved

This allows building pipelines, interfaces, and evaluation harnesses in advance, while waiting for proper governance around real exports.

## Practical Architecture for AI Work in This Codebase

Given the platform shape, an AI layer should probably not be embedded deeply in request handlers at first.

A better pattern is:

## 1. Derived data warehouse or feature store

Export selected data from the application database into derived tables:

- normalized report facts
- text embeddings
- image embeddings
- duplicate candidates
- decision labels

This keeps operational queries separate from experimentation.

## 2. Batch enrichment jobs

Nightly or hourly jobs can add:

- embeddings
- quality scores
- duplicate candidates
- category predictions
- summarizations

These results can be written back to:

- a sidecar analytics store
- new AI-specific tables
- report extra metadata for selected low-risk outputs

## 3. Human-in-the-loop UI surfaces

Staff interfaces could show:

- ranked category suggestions
- probable duplicates
- AI summary
- quality issues
- routing warning

with clear controls:

- accept
- reject
- not relevant
- mark harmful or wrong

## 4. Evaluation pipeline before production automation

Every use case should have:

- offline evaluation set
- baseline heuristic comparison
- threshold tuning
- shadow mode period
- staff acceptance measurement

## Specific Real-World Scenarios

Here are concrete scenarios where this could help.

## Scenario 1: High-volume pothole season

Problem:

- many overlapping reports arrive after freeze-thaw weather
- staff must triage quickly
- duplicates and vague locations slow everything down

AI/automation response:

- cluster nearby reports by similarity and location
- summarize each cluster
- highlight likely road-safety severity
- recommend inspection route ordering

## Scenario 2: Waste service disruption

Problem:

- a depot issue creates a wave of missed-bin and replacement-container reports
- staff and residents submit repeated cases

AI/automation response:

- detect spike by service and area
- auto-suggest known incident banner for user journey
- cluster repeated reports by round/property/service date
- summarize backlog for staff and managers

## Scenario 3: Persistent misrouting for a category

Problem:

- a certain category is frequently corrected after submission
- send failures increase

AI/automation response:

- nightly routing audit flags the category
- model or rules identify the likely better body mapping
- staff review suggested config fixes

## Scenario 4: Moderation overload

Problem:

- staff face a queue of mixed genuine reports, nuisance submissions, and poor-quality content

AI/automation response:

- quality score and abuse-risk ranking
- photo relevance checks
- summarize top indicators for moderator

## Scenario 5: Performance reporting to council leadership

Problem:

- managers want trend and service insight, not raw records

AI/automation response:

- generate weekly narrative summaries from structured KPIs
- identify hotspots, backlog changes, and anomaly categories
- produce draft internal briefings with evidence links

## Data Governance, Privacy, and Safety

This area matters more than the model choice.

## 1. Minimize personal data in training and prompts

Avoid using:

- full names
- exact email addresses
- phone numbers
- exact street addresses where unnecessary

Prefer:

- pseudonymous user IDs
- coarsened geography
- redacted free text
- derived features

## 2. Be careful with free text and images

Report text and photos may contain:

- personal data
- bystanders
- vehicle registrations
- children
- abuse content
- sensitive health or vulnerability details

Any AI pipeline touching these should be explicitly reviewed.

## 3. Keep public-facing outputs conservative

Never let the system:

- invent authority decisions
- imply action has been taken when it has not
- make legal or safety claims without source grounding

## 4. Preserve human accountability

Staff should be able to see:

- why something was suggested
- what evidence supported it
- how to override it

## 5. Separate experimentation from production

There should be a clear line between:

- sandbox or research datasets
- shadow-mode outputs
- staff-visible suggestions
- automated production actions

## Suggested Roadmap

If I were prioritizing this for practical value, I would stage it like this.

## Phase 1: Foundations

- build controlled data export tables
- define task-specific labels
- create evaluation datasets
- generate synthetic demo and test data
- build dashboards for category corrections, duplicates, and send failures

## Phase 2: Low-risk assistive features

- category suggestion
- duplicate candidate detection
- report quality scoring
- staff summarization

All in staff-facing or user-assistive modes, with no autonomous actions.

## Phase 3: Operational intelligence

- routing audits
- backlog forecasting
- hotspot detection
- waste incident clustering
- management summary generation

## Phase 4: Narrow autonomy with explicit guardrails

Only after strong evidence:

- auto-apply low-risk draft text
- prefill staff update templates
- auto-rank queues
- auto-suppress obvious duplicate suggestions in the public flow

Not:

- full autonomous moderation
- autonomous closures
- unsupervised external messaging

## Concrete Datasets Worth Building First

If the aim is to make progress quickly, these are the first derived datasets I would build.

## 1. Report Classification Dataset

Columns:

- report_id
- cobrand
- area/body
- category_submitted
- category_final
- title
- detail
- image_present
- image_embedding
- coordinates
- timestamp features

Targets:

- final category
- whether category was later changed

## 2. Duplicate Detection Dataset

Columns:

- report_id_a
- report_id_b
- time_delta
- distance_meters
- category_match
- text_similarity
- image_similarity
- human_duplicate_label

Target:

- duplicate or not

## 3. Quality Dataset

Columns:

- report_id
- title/detail lengths
- missing fields
- photo quality features
- later moderation outcomes
- whether staff requested more information
- whether report was hidden or rerouted

Targets:

- low quality
- needs clarification

## 4. Routing Audit Dataset

Columns:

- report_id
- category
- location
- initial body
- final body
- send success/failure
- manual correction events

Targets:

- likely misrouted

## 5. Waste Operations Dataset

Columns:

- report_id
- property_id or UPRN
- service type
- booking date
- payment method
- payment success
- amendment count
- cancellation count
- final outcome

Targets:

- duplicate request
- likely payment failure
- likely staff escalation

## Ideas for Synthetic Dataset Packs

Useful packs to generate and keep in version-controlled or reproducible form:

- `small_demo_city`
- `high_volume_pothole_surge`
- `waste_disruption_week`
- `moderation_edge_cases`
- `duplicate_dense_neighbourhood`
- `send_failure_regression_pack`

Each pack could include:

- seeded report rows
- updates
- users
- photos or photo placeholders
- expected evaluation outputs

## Final Recommendations

If the goal is real-world impact rather than speculative AI theater, the best bets are:

1. Category suggestion with human override
2. Duplicate detection for both public and staff workflows
3. Staff summarization and queue assistance
4. Routing and send-failure analytics
5. Waste-service clustering and operational summaries

And the best enabling work is:

1. Controlled real-data exports
2. Strong synthetic data generation for safe development and demos
3. Evaluation sets from real staff decisions
4. Human-in-the-loop feedback capture

The main risk is not "the model is bad". The main risk is building AI on top of weak data provenance, unclear governance, or workflows that do not preserve human accountability. If those foundations are handled properly, this platform has unusually good structure for high-value operational AI.
