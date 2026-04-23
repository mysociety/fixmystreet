---
layout: page
title: AI Architecture Flowchart
---

# AI Architecture Flowchart

This flowchart shows the current FixMyStreet fork as a bounded system and the proposed AI and automation components extending from the relevant parts of that system.

The dashed boundary denotes everything that is part of the existing fork. The AI components sit outside that boundary and connect at the points where they would actually integrate:

- data export from the database and operational services
- cached predictions and enrichments flowing back into controllers and templates
- staff and public UI surfaces consuming AI suggestions
- synthetic data and evaluation tooling supporting tests, staging, and rollout safety

<img src="/assets/img/ai-architecture-flowchart.svg" alt="Flowchart of the FixMyStreet fork architecture with AI extensions connected to the relevant components">

