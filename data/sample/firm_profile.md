# Firm profile (invented for this demo)

**Practice:** "Sample Practice", a fictional 40-person architecture and landscape practice based in Denmark, bidding in Denmark, Sweden, Norway and Germany. Not a real firm.

This file describes the practice in words. The code does not read it; where a rule is checked by code, the place to change it is named (see also *Handover* in the README).

## Checked by code
- **Countries:** Denmark, Sweden, Norway, Germany. *`COUNTRIES` in the fetch step of `n8n/fetch-ted-notices.json`.*
- **Services:** architectural services and urban planning/landscape (CPV 712 and 714 as the main code), so pure engineering or site supervision drops out. *`CPV` and `MAIN_CPV_PREFIXES` in the same step.*
- **Typologies pursued:** schools, daycare, libraries and cultural buildings, housing (social and student), public space and landscape. *`GROUP` in the fit check of `n8n/assess-tenders.json`.*
- **Not pursued:** healthcare and infrastructure (no references). *`NOT_PURSUED` in the same step.*

## For the person deciding (not checked by code)
- Construction budgets roughly EUR 2-60 million; competitions of any size if the typology fits.
- Open competitions, restricted procedures, framework agreements for design services.
- At most 3 bids in parallel.
- Bids in Danish, Swedish, Norwegian, German or English.

## Facts the fit check compares against
Stored in the `practice_facts` table (loaded from [db/seed.sql](../../db/seed.sql)). Invented, like the rest of this practice.
- Average annual turnover, last 3 years: EUR 4.2 million.
- Professional indemnity insurance: EUR 2.5 million per claim.
- Staff: 40 on average over the last 3 years.
- Most experienced project lead: 15 years.
