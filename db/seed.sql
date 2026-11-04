-- The demo practice's reference projects and facts (invented, see data/sample/).
-- Safe to run again: existing rows are updated, nothing is duplicated.
-- The reference projects are the same rows as data/sample/reference_projects.csv; change both together.

CREATE TABLE IF NOT EXISTS practice_facts (
    name          TEXT PRIMARY KEY,
    value         NUMERIC NOT NULL,
    note          TEXT
);

INSERT INTO reference_projects (id, name, typology, country, year, size_m2, budget_eur_m, highlights) VALUES
('R01','Sample project 01','school','DK',2021,8200,24,'timber structure; DGNB Gold; user involvement with pupils'),
('R02','Sample project 02','library','SE',2019,3100,11,'library and community house; adaptive reuse of a warehouse'),
('R03','Sample project 03','public space','DK',2022,12000,6,'harbour bath and promenade; climate adaptation'),
('R04','Sample project 04','student housing','NO',2020,9500,28,'320 units; modular CLT'),
('R05','Sample project 05','daycare','DK',2023,1400,5,'daycare for 120 children; low-carbon concrete'),
('R06','Sample project 06','cultural building','DE',2018,4600,17,'community centre; competition 1st prize'),
('R07','Sample project 07','social housing','DK',2024,15000,45,'renovation of 1960s estate; residents'' process'),
('R08','Sample project 08','landscape','SE',2017,40000,4,'park and stormwater landscape')
ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, typology = EXCLUDED.typology, country = EXCLUDED.country,
    year = EXCLUDED.year, size_m2 = EXCLUDED.size_m2, budget_eur_m = EXCLUDED.budget_eur_m, highlights = EXCLUDED.highlights;

INSERT INTO practice_facts (name, value, note) VALUES
('annual_turnover_eur',        4200000, 'average of the last 3 years'),
('professional_indemnity_eur', 2500000, 'per claim'),
('staff',                      40,      'average over the last 3 years'),
('lead_experience_years',      15,      'most experienced project lead')
ON CONFLICT (name) DO UPDATE SET value = EXCLUDED.value, note = EXCLUDED.note;
