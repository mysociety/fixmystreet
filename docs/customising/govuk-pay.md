---
layout: page
title: GOV.UK Pay integration
---

# GOV.UK Pay integration

GOV.UK Pay can be used as a payment gateway for WasteWorks services such as
garden waste subscriptions and bulky collections. It follows the same
architecture as the existing SCP (Capita) and Adelante integrations.

## Files

There are two key files:

- **`perllib/Integrations/GOVUKPay.pm`** — A standalone HTTP client for the GOV.UK Pay REST API. This is purely responsible for talking to GOV.UK Pay: creating payments, fetching payment details, checking status, and searching. It handles authentication with your API key, JSON serialization, error handling, and retry logic. You'd use this directly if you need to do anything custom with GOV.UK Pay outside the normal payment flow (e.g., refunds, searching past payments).

- **`perllib/FixMyStreet/Roles/Cobrand/GOVUKPay.pm`** — A Moo::Role that wires GOVUKPay.pm into FixMyStreet's payment system. It implements the standard payment gateway interface (`waste_cc_has_redirect`, `waste_cc_get_redirect_url`, `waste_cc_check_payment_status`, etc.) so that cobrands can swap payment providers without changing their code. If you're implementing GOV.UK Pay for a new council, you compose this role into your cobrand. If you're debugging payment issues, most of the logic lives here.

## Cobrand setup

To use GOV.UK Pay in a cobrand, add the role and implement the required
`waste_cc_payment_reference` method:

```perl
package FixMyStreet::Cobrand::YourCouncil;
use parent 'FixMyStreet::Cobrand::UKCouncils';
use Moo;

with 'FixMyStreet::Roles::Cobrand::GOVUKPay';
with 'FixMyStreet::Roles::Cobrand::Waste';

sub waste_cc_payment_reference {
    my ($self, $p) = @_;
    return 'FMS-' . $p->id;
}

1;
```

## Configuration

Add the following to `conf/general.yml`:

```yaml
COBRAND_FEATURES:
  waste:
    yourcouncil: 1
  payment_gateway:
    yourcouncil:
      govukpay_api_key: 'your-live-or-test-api-key'
      govukpay_api_url: 'https://publicapi.payments.service.gov.uk'
      govukpay_description_prefix: 'Your Council'
      log_ident: 'yourcouncil_govukpay'
```

**What each setting does:**

- **`govukpay_api_key`** — Your authentication token for GOV.UK Pay. 

- **`govukpay_api_url`** — The base URL for the GOV.UK Pay REST API. 

- **`govukpay_description_prefix`** — Prefix used when constructing the GOV.UK Pay payment description (for example, Your Council: Garden Subscription - New).

- **`log_ident`** — Used in logs to distinguish GOV.UK Pay activity from other payment providers (SCP, Adelante, etc.).

**For testing:**

Use a **sandbox API key** from your GOV.UK Pay admin console. It starts with `api_test_` and won't charge real card numbers. Test payment details (card number `4111111111111111`, any future date, any CVC) are documented at <https://docs.payments.service.gov.uk/>.

## Payment flow

Here's what happens when a user subscribes to garden waste or requests a bulky collection:

**User initiates payment:**
1. User fills in the waste form and submits (e.g., garden subscription with payment option)
2. Waste controller checks that payment is required via `waste_cc_has_redirect()`
3. If yes, controller calls `waste_cc_get_redirect_url()` to start the payment

**GOV.UK Pay creates the payment:**
4. This method calls `Integrations::GOVUKPay->create_payment()` with a unique reference (usually from `waste_cc_payment_reference`), amount, and description
5. GOV.UK Pay API returns a payment object with a `next_url` (their hosted payment page)
6. We store the payment ID in report metadata under the `scpReference` key (shared key used by multiple payment providers)
7. User is redirected to the GOV.UK Pay payment page

**User completes payment:**
8. User enters their card details on GOV.UK Pay's secure form
9. After payment (success or failure), user is redirected to `/waste/pay_complete/{report_id}/{token}`
10. Token is used to look up which report this is for (as a security check)

**We verify payment succeeded:**
11. Waste controller calls `waste_cc_check_payment_status()` to confirm the payment really went through via `Integrations::GOVUKPay->get_payment_details()` (GET `/v1/payments/{id}`)
12. If status is `success`, we call `waste_confirm_payment()` to mark the report as paid
13. If status is `failed` or `cancelled`, user sees an error and can try again

**Background reconciliation:**
- `perllib/FixMyStreet/Script/Waste/CheckPayments.pm` runs periodically (via cron) to catch any reports that started payment but never completed the callback (network timeout, browser crash, etc.). It checks GOV.UK Pay for any payments that succeeded after the fact and confirms those reports.


## GOV.UK Pay API reference

| Endpoint | Method | Consistency |
|---|---|---|
| `/v1/payments` | POST | Strongly consistent |
| `/v1/payments/{id}` | GET | Strongly consistent |
| `/v1/payments` | GET (search) | Eventually consistent |

**Strongly consistent** means the response always reflects the very latest
state of the payment — if a user just completed payment, the API will
immediately return the updated status. This is what we use on the
`pay_complete` callback to verify the result.

**Eventually consistent** means the response may be briefly out of date.
The search endpoint can take a short time to reflect recent changes, so it is
best for reporting or ad-hoc bulk lookups where a small delay is acceptable.
The current waste payment callback and reconciliation flows do not use this
endpoint; they use GET `/v1/payments/{id}` for per-payment status checks.

Full docs: <https://docs.payments.service.gov.uk/>
