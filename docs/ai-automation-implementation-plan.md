---
title: AI and Automation Implementation Plan
---

# AI and Automation Implementation Plan

This document explains how to incorporate AI and automation capabilities into the existing FixMyStreet software in a way that matches the current architecture and operational model.

It is a delivery plan, not just an idea list. It focuses on:

- where new code should live
- what new data structures are needed
- how the public and staff interfaces should change
- what should run synchronously versus in background jobs
- how to phase delivery safely

This plan assumes the current platform shape:

- Catalyst web application in `perllib/FixMyStreet/App`
- DBIx::Class models in `perllib/FixMyStreet/DB`
- background and cron-style processing in `perllib/FixMyStreet/Script` and `bin`
- web and email templates in `templates`
- static assets in `web`
- cobrand-specific behaviour in `perllib/FixMyStreet/Cobrand`, `templates/web/*`, and `web/cobrands/*`

## Objectives

The primary objectives are:

1. Reduce manual triage effort for staff.
2. Improve report quality and routing before errors reach downstream systems.
3. Surface operational insight from existing data.
4. Support safe experimentation with synthetic and real derived datasets.
5. Keep all higher-risk decisions under human control unless a deployment explicitly opts in later.

## Scope of Initial AI Features

The first wave should include:

- category suggestion on report submission
- duplicate detection for public submission and staff triage
- report quality scoring
- staff-facing triage summaries
- routing audit and anomaly detection
- waste-service summarization and duplicate detection
- synthetic data generation for testing, demos, and model development

The first wave should not include:

- autonomous moderation decisions
- automatic closure of reports
- unsupervised external messaging
- silent body rerouting without human review

## Design Principles

### Keep request-time AI minimal at first

The current software already has rich synchronous request handling in controllers such as:

- `FixMyStreet::App::Controller::Report::New`
- `FixMyStreet::App::Controller::Report::Update`
- `FixMyStreet::App::Controller::Report`
- `FixMyStreet::App::Controller::Waste`

We should avoid putting heavy model calls directly into those request paths early on. Instead:

- prefer deterministic heuristics in-request
- precompute embeddings and predictions in background jobs
- show cached AI suggestions when available
- only call real-time AI in narrow, latency-tolerant cases

### Treat AI as an assistive subsystem

AI outputs should initially be:

- suggestions
- rankings
- summaries
- warnings

not authoritative system state.

### Preserve cobrand flexibility

Any AI feature must be configurable per cobrand and preferably per body or feature flag, because:

- categories vary by cobrand
- public UX expectations vary
- operational tolerance for automation varies
- some deployments may have no legal basis to use certain data for model training

## Proposed Architecture

We should add an AI layer with four parts:

1. Derived data exports
2. Enrichment and modeling jobs
3. Application-side retrieval and UI integration
4. Evaluation and feedback capture

## 1. Derived Data Exports

### Purpose

Create controlled, task-specific datasets from the operational database without forcing modeling code to query production tables directly.

### Proposed location

Add export logic under a new namespace such as:

- `perllib/FixMyStreet/Script/AI`
- `perllib/FixMyStreet/AI`

with CLI entry points in `bin/` or `script/`.

### Suggested modules

- `FixMyStreet::AI::Export::Reports`
- `FixMyStreet::AI::Export::Duplicates`
- `FixMyStreet::AI::Export::Routing`
- `FixMyStreet::AI::Export::Waste`
- `FixMyStreet::AI::Export::Synthetic`

### Derived datasets to create first

- `report_facts`
- `report_text_features`
- `report_image_features`
- `report_decision_labels`
- `duplicate_candidate_pairs`
- `routing_audit_facts`
- `waste_operation_facts`

### Data handling rules

- drop or pseudonymize user identifiers
- exclude exact email and phone data from training exports
- use coarse geography where exact coordinates are not needed
- put raw text and image access behind explicit export flags

## 2. Enrichment and Modeling Jobs

### Purpose

Run scheduled processes that compute AI and automation outputs for later use by the app.

### Scheduling model

Use cron-style or daemon-style jobs similar to existing operational scripts.

Examples:

- nightly export and retraining jobs
- hourly enrichment jobs for new reports
- near-real-time duplicate candidate jobs for recent submissions
- periodic anomaly detection jobs

### Suggested scripts

- `bin/ai-export`
- `bin/ai-enrich-reports`
- `bin/ai-score-duplicates`
- `bin/ai-routing-audit`
- `bin/ai-generate-synthetic-data`
- `bin/ai-evaluate`

### Suggested result categories

The enrichments should generate:

- category predictions
- duplicate candidates
- quality scores
- summaries
- routing warnings
- photo quality results
- anomaly or hotspot signals

### Storage strategy

Do not put all AI output into generic `extra` JSON immediately.

Instead create dedicated AI tables so that:

- history can be retained
- model versions can be tracked
- feedback can be stored cleanly
- queries remain clear

## 3. Application-Side Retrieval and UI Integration

### Purpose

Expose AI outputs inside the existing request flows without coupling controllers directly to modeling logic.

### New service layer

Add a small application-side service namespace, for example:

- `perllib/FixMyStreet/AI`

Suggested modules:

- `FixMyStreet::AI::Predictions`
- `FixMyStreet::AI::Duplicates`
- `FixMyStreet::AI::Summaries`
- `FixMyStreet::AI::Quality`
- `FixMyStreet::AI::Routing`
- `FixMyStreet::AI::FeatureFlags`

These modules should:

- fetch cached AI results
- apply confidence thresholds
- combine AI and heuristic logic
- expose results in a controller-friendly form

### UI integration pattern

Controllers should call these service modules and stash structured results for templates.

Do not embed prompt logic or model-specific behaviour in controllers.

## 4. Evaluation and Feedback Capture

### Purpose

Track whether suggestions are useful and safe.

### Feedback types to capture

- accepted suggestion
- rejected suggestion
- overridden category
- duplicate suggestion marked correct or incorrect
- summary marked useful or not useful
- routing warning confirmed or dismissed

### Suggested storage

Create feedback tables keyed to:

- report or comment
- prediction record
- user or body user
- timestamp

This is necessary to move from one-off experiments to a sustainable product capability.

## Database Changes

The platform already keeps operational state in strongly structured tables. AI features should follow that model.

## New tables to add

### `ai_prediction`

Stores general prediction results.

Suggested columns:

- `id`
- `object_type` such as `problem`, `comment`, `property`, `body`
- `object_id`
- `prediction_type` such as `category_suggestion`, `quality_score`, `routing_warning`, `summary`
- `model_name`
- `model_version`
- `status`
- `score`
- `payload` as JSONB
- `created`
- `expires`

### `ai_duplicate_candidate`

Stores candidate duplicate relationships.

Suggested columns:

- `id`
- `problem_id`
- `candidate_problem_id`
- `model_name`
- `model_version`
- `score`
- `evidence` as JSONB
- `created`
- `reviewed_by_user_id`
- `review_outcome`

### `ai_feedback`

Stores human response to predictions.

Suggested columns:

- `id`
- `prediction_id`
- `user_id`
- `body_id`
- `feedback_type`
- `feedback_value`
- `notes`
- `created`

### `ai_export_run`

Tracks dataset generation and evaluation runs.

Suggested columns:

- `id`
- `run_type`
- `dataset_name`
- `model_name`
- `model_version`
- `status`
- `metadata` as JSONB
- `created`
- `completed`

### `ai_hotspot`

Optional table for anomaly and cluster outputs.

Suggested columns:

- `id`
- `hotspot_type`
- `body_id`
- `area_id`
- `latitude`
- `longitude`
- `radius_m`
- `score`
- `payload`
- `created`

## DBIx::Class additions

Add matching result classes under:

- `perllib/FixMyStreet/DB/Result`
- `perllib/FixMyStreet/DB/ResultSet`

These should mirror the platform’s existing model approach rather than bypassing it.

## Integration by Feature

## Category Suggestion

### Where it fits

Primary request path:

- `FixMyStreet::App::Controller::Report::New`

Supporting models:

- `Problem`
- `Contact`
- body/category availability logic already used in the reporting flow

### How to integrate

1. In the report form flow, once location and possible categories are known, generate or retrieve category suggestions.
2. Re-rank any model suggestions against allowed categories at that location.
3. Stash:
   - top suggestion
   - alternative suggestions
   - confidence bucket
4. Render suggestions in:
   - `templates/web/base/report/new/*`
   - relevant cobrand overrides where needed

### First implementation

Phase 1 version should be mostly heuristic:

- keyword matches
- prior category frequency by area/body
- optional cached text classifier score

### Feedback capture

If the user chooses a different category than the top suggestion, record that difference for future evaluation.

## Duplicate Detection

### Where it fits

Public flow:

- `Report::New`
- nearby report lookup and report creation path

Staff flow:

- `Report`
- inspection and moderation interfaces

### How to integrate

1. During or immediately after submission, query recent duplicate candidates for the report.
2. In the public flow, show a soft warning such as:
   - "This may already have been reported"
3. In staff inspection, show ranked duplicate candidates with evidence:
   - distance
   - category match
   - text similarity
   - image similarity if available

### First implementation

Start with:

- time window
- spatial threshold
- category proximity
- text similarity over title/detail

Image similarity can be added later.

### UI surface

Public templates:

- `templates/web/base/report/new/*`

Staff templates:

- `templates/web/base/report/inspect.html`
- admin triage templates where relevant

## Report Quality Scoring

### Where it fits

Primary path:

- `Report::New`
- photo handling
- validation and error feedback

### How to integrate

1. Compute lightweight in-request heuristics:
   - very short title/detail
   - missing photo when category usually benefits from a photo
   - location uncertainty
2. Optionally fetch cached or quick AI quality predictions.
3. Render user prompts before submission is finalized.

### Good first outputs

- clearer-description prompt
- blurry-or-dark photo warning
- low-confidence category warning

### Important constraint

This should improve the form, not block submissions unless the deployment explicitly enables stronger validation.

## Staff Summaries

### Where it fits

Primary staff view:

- `Report`
- staff inspection pages
- planned report queues
- waste staff forms and confirmation histories

### How to integrate

1. Nightly or near-real-time enrichment generates summaries for reports and complex waste journeys.
2. Staff templates show:
   - one-line summary
   - longer triage summary
   - last significant changes

### Best data inputs

- original report text
- updates
- current state
- duplicate candidates
- send failures
- assigned staff history

### Constraint

Summaries must be grounded in record data and should avoid invented operational outcomes.

## Routing Audit

### Where it fits

Primarily staff and admin tools.

Relevant surfaces:

- report inspection
- contact/body admin pages
- scheduled operational reports

### How to integrate

1. Batch jobs score historical and recent reports for misrouting risk.
2. Expose results to:
   - staff on a specific report
   - admins in aggregate dashboards
3. Use results to guide configuration cleanup, not silent changes at first.

### Key inputs

- category
- location
- initial body
- send outcome
- manual recategorization or reboding events

## Waste-Service Automation

### Where it fits

Primary path:

- `FixMyStreet::App::Controller::Waste`
- waste forms and confirmation views

### Candidate integrations

- duplicate missed-bin detection by property/service/date
- booking and amendment summary for staff
- payment failure pattern analysis
- "next best action" suggestions for staff

### First implementation

Start with deterministic grouping:

- same property
- same service
- same collection date or booking window
- same category

Then add summary and anomaly layers.

### Templates

Likely under:

- `templates/web/base/waste/*`
- cobrand-specific waste templates

## Hotspot and Anomaly Detection

### Where it fits

This is mostly a reporting and operations capability rather than a front-end submission feature.

### Delivery shape

1. Batch job computes hotspots and anomalies.
2. Internal dashboards or exported reports surface:
   - top clusters by category
   - unusual spikes by area
   - waste disruption indicators

### Optional UI

Could later appear on internal map views or management pages, but should not block the rest of the AI plan.

## Synthetic Data System

This is important enough to be its own workstream.

## Goals

- create demo environments
- populate development and staging with realistic records
- generate test packs for regression and model evaluation
- support AI work before real data export approval is complete

## Proposed implementation

Create a generator under:

- `perllib/FixMyStreet/AI/Generate`
- `bin/ai-generate-synthetic-data`

The generator should support:

- seed-based reproducible runs
- output to database fixtures
- output to JSON or CSV exports
- named scenarios

### Scenario packs to support

- small demo city
- pothole surge
- duplicate-heavy district
- moderation edge cases
- waste service disruption week
- send failure regression pack

### Data types to generate

- `Problem` rows
- `Comment` rows
- user accounts
- state transitions
- admin log records
- waste bookings and cancellations
- optional synthetic photo placeholders

### Validation rules

Synthetic data should be:

- relationally valid
- internally consistent
- geographically plausible for the selected cobrand
- intentionally able to include malformed edge-case packs when requested

## Application Configuration and Feature Flags

Because this is a multi-cobrand system, all AI capabilities should be feature-flagged.

## Proposed config structure

Add a config section such as:

```yaml
AI_FEATURES:
  category_suggestion: 1
  duplicate_detection: 1
  quality_scoring: 1
  staff_summary: 1
  routing_audit: 1
  waste_summary: 1
  hotspot_detection: 0
```

And optionally cobrand-specific overrides using existing cobrand feature patterns.

### Access control

Each feature should specify whether it is:

- public
- staff-only
- admin-only
- batch-only

## Rollout Plan

## Phase 0: Foundations and Safety

### Deliverables

- new AI tables and DBIx classes
- export framework
- synthetic data generator skeleton
- feature flags
- evaluation harness

### Success criteria

- exports can run repeatedly and safely
- AI outputs can be stored without changing user-facing behaviour
- synthetic datasets can populate staging

## Phase 1: Heuristic-first Assistive Features

### Deliverables

- category suggestion baseline
- duplicate candidate baseline
- report quality heuristics
- staff summary prototype for selected reports

### Integration points

- report submission templates
- report inspection templates
- waste staff views for summary prototype

### Success criteria

- latency impact on request flow remains small
- staff can see suggestions and ignore them safely
- feedback is captured

## Phase 2: Batch AI Enrichment

### Deliverables

- nightly or hourly enrichment jobs
- cached summaries
- cached quality scores
- cached duplicate rankings
- routing audit reports

### Success criteria

- enrichments are stable and observable
- model versions are tracked
- dashboards can be produced from derived data

## Phase 3: Waste and Operations Intelligence

### Deliverables

- waste duplicate and history summaries
- payment anomaly reporting
- hotspot detection
- management summary reports

### Success criteria

- staff save time in high-volume flows
- repeated service incidents become visible earlier

## Phase 4: Narrow Automation

### Deliverables

- optional auto-drafted staff update text
- optional queue ranking defaults
- optional stronger public duplicate prompts

### Guardrails

- human approval required
- per-cobrand opt-in
- metrics and kill switch available

## Observability and Safety Controls

Every new AI capability should have:

- logs for job runs and failures
- model version metadata
- confidence thresholds
- opt-out feature flags
- auditability of staff interaction with predictions

### Recommended metrics

- category suggestion acceptance rate
- duplicate suggestion precision
- summary usefulness feedback rate
- false positive rate for quality warnings
- routing warning confirmation rate
- time-to-triage before and after rollout

## Testing Strategy

## Unit and integration tests

Add tests under `t/` for:

- new DB tables and resultsets
- export jobs
- AI service modules
- controller stashing and template rendering
- feature flag behaviour

## Synthetic regression packs

Use synthetic scenarios to test:

- duplicate-heavy flows
- waste amendments and cancellations
- low-quality photos and text
- routing anomalies
- admin and staff template rendering

## Shadow mode evaluation

Before turning on user-visible or staff-visible outputs widely:

- run the feature in shadow mode
- store predictions without displaying them
- compare them to human outcomes

## Recommended File and Module Additions

This is a suggested starting layout.

### Application logic

- `perllib/FixMyStreet/AI.pm`
- `perllib/FixMyStreet/AI/Predictions.pm`
- `perllib/FixMyStreet/AI/Duplicates.pm`
- `perllib/FixMyStreet/AI/Quality.pm`
- `perllib/FixMyStreet/AI/Summaries.pm`
- `perllib/FixMyStreet/AI/Routing.pm`
- `perllib/FixMyStreet/AI/FeatureFlags.pm`

### Export and job scripts

- `perllib/FixMyStreet/Script/AI/Export.pm`
- `perllib/FixMyStreet/Script/AI/EnrichReports.pm`
- `perllib/FixMyStreet/Script/AI/ScoreDuplicates.pm`
- `perllib/FixMyStreet/Script/AI/RoutingAudit.pm`
- `perllib/FixMyStreet/Script/AI/GenerateSyntheticData.pm`

### Database layer

- `perllib/FixMyStreet/DB/Result/AiPrediction.pm`
- `perllib/FixMyStreet/DB/Result/AiDuplicateCandidate.pm`
- `perllib/FixMyStreet/DB/Result/AiFeedback.pm`
- `perllib/FixMyStreet/DB/Result/AiExportRun.pm`
- matching resultsets

### Schema and migrations

- SQL migration files in `db/`

### Templates

Add small partials under:

- `templates/web/base/report/`
- `templates/web/base/admin/`
- `templates/web/base/waste/`

Examples:

- `_ai_category_suggestions.html`
- `_ai_duplicate_candidates.html`
- `_ai_quality_warning.html`
- `_ai_summary_panel.html`

### Documentation

- this plan document
- operational runbooks for export and enrichment jobs
- data governance note for AI use

## Recommended First Delivery Slice

If we want a practical first slice with strong value and manageable risk, it should be:

1. AI tables and export framework
2. synthetic data generator for demo and test environments
3. heuristic category suggestion in the report form
4. heuristic duplicate detection in the report form and inspection view
5. cached staff summary prototype for selected reports

That gives:

- visible product value
- limited architectural risk
- clear feedback loops
- no need for high-stakes autonomy

## Final Position

The right way to incorporate AI into FixMyStreet is not to bolt a model call onto controllers. It is to add a disciplined subsystem for:

- controlled exports
- scheduled enrichments
- structured prediction storage
- human-in-the-loop UI surfaces
- feedback capture
- synthetic test and demo data

That approach matches the existing software’s strengths: strong domain models, clear workflows, mature background processing, and configurable cobrand-specific behaviour.
