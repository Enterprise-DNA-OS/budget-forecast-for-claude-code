-- Budget and Forecast for Claude Code: entities, accounts, versions (actuals, budgets, forecasts,
-- scenarios), monthly lines, the hiring plan, lender covenants, variance commentary, the month-end
-- close, GST and BAS lodgements and distributions. Plain Postgres; runs the same on PGlite.
-- Amounts are stored as positive natural amounts: revenue and costs both positive, balances as balances.
CREATE FUNCTION touch_updated() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN NEW.updated_at=now(); RETURN NEW; END $$;

CREATE TABLE entities (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(trim(name))>0),
 country text NOT NULL CHECK(country IN ('NZ','AU')), currency text NOT NULL CHECK(currency ~ '^[A-Z]{3}$'),
 gst_period text NOT NULL DEFAULT 'monthly' CHECK(gst_period IN ('monthly','two-monthly','quarterly','none')),
 tax_from date NOT NULL DEFAULT date_trunc('month',current_date)::date,
 adaptive_level text UNIQUE, active boolean NOT NULL DEFAULT true, source jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(gst_period<>'two-monthly' OR country='NZ'), CHECK(gst_period<>'quarterly' OR country='AU')
);
CREATE UNIQUE INDEX entities_name ON entities(lower(name));

CREATE TABLE accounts (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), code text NOT NULL CHECK(length(trim(code))>0), name text NOT NULL CHECK(length(trim(name))>0),
 type text NOT NULL CHECK(type IN ('revenue','cogs','expense','other_income','other_expense','asset','liability','equity')),
 tag text, owner text, owner_email text CHECK(owner_email IS NULL OR owner_email ~ '^[^@\s]+@[^@\s]+$'),
 adaptive_code text UNIQUE, active boolean NOT NULL DEFAULT true, source jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(tag IS NULL OR (tag='cash' AND type='asset') OR (tag='debt' AND type='liability') OR (tag IN ('interest','depreciation','tax','wages') AND type IN ('cogs','expense','other_expense')))
);
CREATE UNIQUE INDEX accounts_code ON accounts(lower(code));

CREATE TABLE versions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL CHECK(length(trim(name))>0),
 kind text NOT NULL CHECK(kind IN ('actuals','budget','forecast','scenario')),
 starts_on date CHECK(starts_on IS NULL OR extract(day FROM starts_on)=1), months integer CHECK(months BETWEEN 1 AND 60),
 based_on uuid REFERENCES versions(id), locked boolean NOT NULL DEFAULT false, approved_by text, approved_on date, notes text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((kind='actuals')=(starts_on IS NULL)), CHECK((starts_on IS NULL)=(months IS NULL)),
 CHECK(NOT locked OR (approved_by IS NOT NULL AND approved_on IS NOT NULL)), CHECK(kind<>'actuals' OR NOT locked)
);
CREATE UNIQUE INDEX versions_name ON versions(lower(name));
CREATE UNIQUE INDEX versions_one_actuals ON versions(kind) WHERE kind='actuals';

CREATE TABLE lines (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), version_id uuid NOT NULL REFERENCES versions(id),
 entity_id uuid NOT NULL REFERENCES entities(id), account_id uuid NOT NULL REFERENCES accounts(id),
 period date NOT NULL CHECK(extract(day FROM period)=1), amount numeric NOT NULL, source jsonb NOT NULL DEFAULT '{}',
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(version_id,entity_id,account_id,period)
);
CREATE INDEX lines_entity_period ON lines(entity_id,period);

-- A locked version cannot change, and a plan line must sit inside its version's months.
CREATE FUNCTION guard_line() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v versions; r lines;
BEGIN
 IF TG_OP='DELETE' THEN r:=OLD; ELSE r:=NEW; END IF;
 SELECT * INTO v FROM versions WHERE id=r.version_id;
 IF v.locked THEN RAISE EXCEPTION 'Version "%" is locked (approved by % on %). Copy it to a new version to change it', v.name, v.approved_by, v.approved_on; END IF;
 IF TG_OP='UPDATE' AND OLD.version_id<>NEW.version_id THEN
  IF (SELECT locked FROM versions WHERE id=OLD.version_id) THEN RAISE EXCEPTION 'Cannot move a line out of a locked version'; END IF;
 END IF;
 IF TG_OP<>'DELETE' AND v.kind<>'actuals' AND (r.period<v.starts_on OR r.period>=v.starts_on+v.months*interval '1 month') THEN
  RAISE EXCEPTION 'Month % is outside version "%" (% for % months)', to_char(r.period,'YYYY-MM'), v.name, to_char(v.starts_on,'YYYY-MM'), v.months;
 END IF;
 IF TG_OP='DELETE' THEN RETURN OLD; END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER lines_guard BEFORE INSERT OR UPDATE OR DELETE ON lines FOR EACH ROW EXECUTE FUNCTION guard_line();

CREATE TABLE hires (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id),
 role text NOT NULL CHECK(length(trim(role))>0), person text, department text,
 starts_on date NOT NULL, ends_on date, annual_salary numeric NOT NULL CHECK(annual_salary>0),
 oncost_rate numeric NOT NULL CHECK(oncost_rate>=0 AND oncost_rate<100),
 status text NOT NULL DEFAULT 'planned' CHECK(status IN ('planned','filled','cancelled')),
 reduced_rate_until date, notes text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(ends_on IS NULL OR ends_on>=starts_on)
);

-- Minimum employer retirement contributions by date. Change or add a row with /customise.
CREATE TABLE statutory_rates (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), country text NOT NULL CHECK(country IN ('NZ','AU')), scheme text NOT NULL,
 rate numeric NOT NULL CHECK(rate>=0), from_date date NOT NULL, source text NOT NULL, UNIQUE(country,from_date)
);
INSERT INTO statutory_rates(country,scheme,rate,from_date,source) VALUES
('NZ','KiwiSaver employer minimum',3.5,'2026-04-01','https://www.ird.govt.nz/updates/news-folder/2025/kiwisaver-changes'),
('NZ','KiwiSaver employer minimum',4,'2028-04-01','https://www.ird.govt.nz/updates/news-folder/2025/kiwisaver-changes'),
('AU','Superannuation guarantee',11.5,'2024-07-01','https://www.ato.gov.au/Rates/key-superannuation-rates-and-thresholds/'),
('AU','Superannuation guarantee',12,'2025-07-01','https://www.ato.gov.au/Rates/key-superannuation-rates-and-thresholds/');

CREATE TABLE covenants (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id), lender text NOT NULL,
 metric text NOT NULL CHECK(metric IN ('minimum cash','interest cover','debt to ebitda')),
 test text NOT NULL CHECK(test IN ('>=','<=')), threshold numeric NOT NULL,
 frequency text NOT NULL DEFAULT 'quarterly' CHECK(frequency IN ('monthly','quarterly')),
 active boolean NOT NULL DEFAULT true, evidence text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((metric='debt to ebitda')=(test='<='))
);

CREATE TABLE commentary (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id), account_id uuid NOT NULL REFERENCES accounts(id),
 period date NOT NULL CHECK(extract(day FROM period)=1), note text NOT NULL CHECK(length(trim(note))>0), actor text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE close_tasks (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id),
 period date NOT NULL CHECK(extract(day FROM period)=1), task text NOT NULL CHECK(length(trim(task))>0), owner text,
 due_on date NOT NULL, done_on date, evidence text,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(done_on IS NULL OR evidence IS NOT NULL), UNIQUE(entity_id,period,task)
);

CREATE TABLE lodgements (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id),
 period_end date NOT NULL, lodged_on date NOT NULL, reference text, evidence text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(entity_id,period_end)
);

CREATE TABLE distributions (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), entity_id uuid NOT NULL REFERENCES entities(id),
 amount numeric NOT NULL CHECK(amount>0), status text NOT NULL DEFAULT 'proposed' CHECK(status IN ('proposed','declared','paid','cancelled')),
 declared_on date, pay_on date NOT NULL, solvency_certificate_on date, approved_by text,
 in_forecast boolean NOT NULL DEFAULT false, evidence text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK(status IN ('proposed','cancelled') OR declared_on IS NOT NULL)
);

CREATE TABLE settings (key text PRIMARY KEY, value numeric NOT NULL, note text NOT NULL);
INSERT INTO settings VALUES
('variance_pct',10,'A month-end variance needs a comment when it is at least this percentage of budget'),
('variance_amount',5000,'and at least this amount, in the entity currency'),
('tax_warning_days',14,'Flag a GST return or BAS this many days before it is due');

CREATE TABLE activity (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, record text NOT NULL, record_id text, action text NOT NULL, actor text NOT NULL,
 before_data jsonb, after_data jsonb, evidence text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE imports (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY, filename text NOT NULL, sha256 text NOT NULL, kind text NOT NULL,
 row_count integer NOT NULL, actor text NOT NULL, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TRIGGER entities_touch BEFORE UPDATE ON entities FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER accounts_touch BEFORE UPDATE ON accounts FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER versions_touch BEFORE UPDATE ON versions FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER lines_touch BEFORE UPDATE ON lines FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER hires_touch BEFORE UPDATE ON hires FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER covenants_touch BEFORE UPDATE ON covenants FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER commentary_touch BEFORE UPDATE ON commentary FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER close_tasks_touch BEFORE UPDATE ON close_tasks FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER lodgements_touch BEFORE UPDATE ON lodgements FOR EACH ROW EXECUTE FUNCTION touch_updated();
CREATE TRIGGER distributions_touch BEFORE UPDATE ON distributions FOR EACH ROW EXECUTE FUNCTION touch_updated();

-- ---------------------------------------------------------------- helpers
CREATE FUNCTION setting(k text) RETURNS numeric LANGUAGE sql STABLE AS $$ SELECT value FROM settings WHERE key=k $$;
CREATE FUNCTION fmt(n numeric) RETURNS text LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN n IS NULL THEN 'no value' WHEN abs(n)>=1000 THEN to_char(round(n),'FM999,999,999,990') ELSE n::text END $$;
CREATE FUNCTION profit_sign(t text) RETURNS integer LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE WHEN t IN ('revenue','other_income') THEN 1 WHEN t IN ('cogs','expense','other_expense') THEN -1 ELSE 0 END $$;
CREATE FUNCTION actuals_id() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT id FROM versions WHERE kind='actuals' $$;
-- The budget the month-end is judged against: the newest approved budget covering the last closed month.
CREATE FUNCTION current_budget() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT id FROM versions WHERE kind='budget'
 ORDER BY (locked AND coalesce((SELECT max(period) FROM lines WHERE version_id=actuals_id()) BETWEEN starts_on AND (starts_on+(months-1)*interval '1 month')::date,false)) DESC,
  locked DESC, starts_on DESC, created_at DESC LIMIT 1 $$;
-- The forecast everything forward-looking reads: the newest forecast.
CREATE FUNCTION current_forecast() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT id FROM versions WHERE kind='forecast' ORDER BY starts_on DESC, created_at DESC LIMIT 1 $$;
-- GST (IRD) and BAS (ATO) due dates for a period ending on period_end. Weekends and holidays not shifted.
CREATE FUNCTION gst_due(country text, gst_period text, period_end date) RETURNS date LANGUAGE sql IMMUTABLE AS $$
 SELECT CASE
  WHEN country='NZ' AND extract(month FROM period_end)=3 THEN make_date(extract(year FROM period_end)::int,5,7)
  WHEN country='NZ' AND extract(month FROM period_end)=11 THEN make_date(extract(year FROM period_end)::int+1,1,15)
  WHEN country='NZ' THEN (date_trunc('month',period_end)+interval '1 month')::date+27
  WHEN gst_period='monthly' THEN (date_trunc('month',period_end)+interval '1 month')::date+20
  WHEN extract(month FROM period_end)=12 THEN make_date(extract(year FROM period_end)::int+1,2,28)
  ELSE (date_trunc('month',period_end)+interval '1 month')::date+27 END $$;

-- ---------------------------------------------------------------- views
CREATE VIEW v_versions AS
 SELECT v.*, (v.starts_on+(v.months-1)*interval '1 month')::date AS ends_on,
  (SELECT count(*) FROM lines l WHERE l.version_id=v.id) AS line_count FROM versions v;

CREATE VIEW v_latest AS
 SELECT e.id AS entity_id, e.name AS entity, max(l.period) AS last_actual
 FROM entities e LEFT JOIN lines l ON l.entity_id=e.id AND l.version_id=actuals_id() GROUP BY e.id,e.name;

-- Actuals up to each entity's last closed month, the current forecast after it.
CREATE VIEW v_series AS
 SELECT l.entity_id,l.account_id,l.period,l.amount,'actual'::text AS basis FROM lines l WHERE l.version_id=actuals_id()
 UNION ALL
 SELECT l.entity_id,l.account_id,l.period,l.amount,'forecast' FROM lines l JOIN v_latest m ON m.entity_id=l.entity_id
 WHERE l.version_id=current_forecast() AND (m.last_actual IS NULL OR l.period>m.last_actual);

CREATE VIEW v_monthly AS
 SELECT s.entity_id, s.period, min(s.basis) AS basis,
  coalesce(sum(profit_sign(a.type)*s.amount) FILTER (WHERE profit_sign(a.type)<>0 AND coalesce(a.tag,'') NOT IN ('interest','depreciation','tax')),0) AS ebitda,
  coalesce(sum(s.amount) FILTER (WHERE a.tag='interest'),0) AS interest,
  sum(s.amount) FILTER (WHERE a.tag='cash') AS cash,
  coalesce(sum(s.amount) FILTER (WHERE a.tag='debt'),0) AS debt,
  sum(s.amount) FILTER (WHERE a.type='asset') AS assets,
  coalesce(sum(s.amount) FILTER (WHERE a.type='liability'),0) AS liabilities,
  coalesce(sum(profit_sign(a.type)*s.amount),0) AS net_profit
 FROM v_series s JOIN accounts a ON a.id=s.account_id GROUP BY s.entity_id,s.period;

-- Trailing twelve months. Assumes no missing months in the series.
CREATE VIEW v_ttm AS
 SELECT m.*, sum(m.ebitda) OVER w AS ttm_ebitda, sum(m.interest) OVER w AS ttm_interest, count(*) OVER w AS months_in
 FROM v_monthly m WINDOW w AS (PARTITION BY m.entity_id ORDER BY m.period ROWS BETWEEN 11 PRECEDING AND CURRENT ROW);

CREATE VIEW v_cash AS
 SELECT e.id AS entity_id, e.name AS entity, e.currency, m.period, to_char(m.period,'YYYY-MM') AS month, m.basis, m.cash AS closing_cash, m.net_profit
 FROM v_monthly m JOIN entities e ON e.id=m.entity_id WHERE m.cash IS NOT NULL;

CREATE VIEW v_covenant_tests AS
 SELECT t.*, CASE WHEN t.value IS NULL THEN false WHEN t.test='>=' THEN t.value>=t.threshold ELSE t.value<=t.threshold END AS passes
 FROM (SELECT c.id AS covenant_id, c.entity_id, e.name AS entity, e.currency, c.lender, c.metric, c.test, c.threshold, c.frequency,
   m.period, to_char(m.period,'YYYY-MM') AS month, m.basis,
   CASE c.metric WHEN 'minimum cash' THEN m.cash
    WHEN 'interest cover' THEN CASE WHEN m.ttm_ebitda<=0 THEN NULL WHEN m.ttm_interest=0 THEN 999 ELSE round(m.ttm_ebitda/m.ttm_interest,2) END
    ELSE CASE WHEN m.ttm_ebitda<=0 THEN NULL ELSE round(m.debt/m.ttm_ebitda,2) END END AS value
  FROM covenants c JOIN entities e ON e.id=c.entity_id JOIN v_ttm m ON m.entity_id=c.entity_id
  WHERE c.active AND (c.frequency='monthly' OR extract(month FROM m.period) IN (3,6,9,12)) AND (c.metric='minimum cash' OR m.months_in=12)) t;

CREATE VIEW v_covenants AS
 SELECT c.id, c.entity_id, e.name AS entity, e.currency, c.lender, c.metric, c.test, c.threshold, c.frequency,
  a.month AS last_tested, a.value AS last_value, a.passes AS last_passed,
  f.month AS first_forecast_breach, f.value AS breach_value
 FROM covenants c JOIN entities e ON e.id=c.entity_id
 LEFT JOIN LATERAL (SELECT * FROM v_covenant_tests t WHERE t.covenant_id=c.id AND t.basis='actual' ORDER BY t.period DESC LIMIT 1) a ON true
 LEFT JOIN LATERAL (SELECT * FROM v_covenant_tests t WHERE t.covenant_id=c.id AND t.basis='forecast' AND NOT t.passes ORDER BY t.period LIMIT 1) f ON true
 WHERE c.active;

CREATE VIEW v_variance AS
 WITH b AS (SELECT current_budget() AS id),
 k AS (SELECT l.entity_id,l.account_id FROM lines l JOIN v_latest m ON m.entity_id=l.entity_id AND l.period=m.last_actual
  WHERE l.version_id=actuals_id() OR l.version_id=(SELECT id FROM b) GROUP BY l.entity_id,l.account_id)
 SELECT e.id AS entity_id, a.id AS account_id, e.name AS entity, e.currency, to_char(m.last_actual,'YYYY-MM') AS month, m.last_actual AS period,
  a.code, a.name AS account, a.type, a.owner,
  coalesce(act.amount,0) AS actual, coalesce(bud.amount,0) AS budget,
  profit_sign(a.type)*(coalesce(act.amount,0)-coalesce(bud.amount,0)) AS variance,
  round(100*profit_sign(a.type)*(coalesce(act.amount,0)-coalesce(bud.amount,0))/nullif(abs(bud.amount),0),1) AS pct,
  EXISTS(SELECT 1 FROM commentary c WHERE c.entity_id=e.id AND c.account_id=a.id AND c.period=m.last_actual) AS explained
 FROM k JOIN entities e ON e.id=k.entity_id JOIN accounts a ON a.id=k.account_id JOIN v_latest m ON m.entity_id=e.id
 LEFT JOIN lines act ON act.version_id=actuals_id() AND act.entity_id=e.id AND act.account_id=a.id AND act.period=m.last_actual
 LEFT JOIN lines bud ON bud.version_id=(SELECT id FROM b) AND bud.entity_id=e.id AND bud.account_id=a.id AND bud.period=m.last_actual
 WHERE profit_sign(a.type)<>0;

CREATE VIEW v_commentary_due AS
 SELECT * FROM v_variance WHERE NOT explained AND abs(variance)>=setting('variance_amount') AND (pct IS NULL OR abs(pct)>=setting('variance_pct'));

-- Where the year lands: actuals to date plus the current forecast for the rest of the budget's months.
CREATE VIEW v_outlook AS
 SELECT x.*, profit_sign(x.type)*(x.outlook-x.budget) AS gap FROM (
  SELECT e.id AS entity_id, e.name AS entity, e.currency, a.code, a.name AS account, a.type,
   coalesce(sum(s.amount) FILTER (WHERE s.basis='actual'),0) AS actual_to_date,
   coalesce(sum(s.amount) FILTER (WHERE s.basis='forecast'),0) AS forecast_rest,
   coalesce(sum(s.amount),0) AS outlook,
   coalesce((SELECT sum(b.amount) FROM lines b WHERE b.version_id=r.id AND b.entity_id=e.id AND b.account_id=a.id),0) AS budget
  FROM v_versions r CROSS JOIN entities e CROSS JOIN accounts a
  LEFT JOIN v_series s ON s.entity_id=e.id AND s.account_id=a.id AND s.period BETWEEN r.starts_on AND r.ends_on
  WHERE r.id=current_budget() AND e.active AND profit_sign(a.type)<>0
  GROUP BY e.id,e.name,e.currency,a.id,a.code,a.name,a.type,r.id) x
 WHERE x.outlook<>0 OR x.budget<>0;

CREATE VIEW v_hire_months AS
 SELECT h.id AS hire_id, h.entity_id, m::date AS period, round(h.annual_salary/12*(1+h.oncost_rate/100),2) AS cost
 FROM hires h CROSS JOIN LATERAL generate_series(date_trunc('month',h.starts_on),date_trunc('month',coalesce(h.ends_on,h.starts_on+interval '10 years')),interval '1 month') m
 WHERE h.status<>'cancelled';

CREATE VIEW v_headcount AS
 SELECT h.id, h.entity_id, e.name AS entity, e.currency, h.role, h.person, h.department, h.status, h.starts_on, h.ends_on, h.annual_salary, h.oncost_rate,
  round(h.annual_salary/12*(1+h.oncost_rate/100),2) AS monthly_cost,
  coalesce((SELECT sum(hm.cost) FROM v_hire_months hm JOIN v_versions f ON f.id=current_forecast() WHERE hm.hire_id=h.id AND hm.period BETWEEN f.starts_on AND f.ends_on),0) AS cost_in_forecast
 FROM hires h JOIN entities e ON e.id=h.entity_id;

CREATE VIEW v_tax_calendar AS
 SELECT x.*, CASE WHEN x.lodged_on IS NOT NULL THEN 'lodged' WHEN x.due_on<current_date THEN 'overdue'
   WHEN x.due_on<=current_date+setting('tax_warning_days')::int THEN 'due soon' ELSE 'upcoming' END AS state
 FROM (SELECT e.id AS entity_id, e.name AS entity, e.country, CASE e.country WHEN 'NZ' THEN 'GST return' ELSE 'BAS' END AS return_type,
   p.period_end, gst_due(e.country,e.gst_period,p.period_end) AS due_on, l.lodged_on, l.reference
  FROM entities e
  CROSS JOIN LATERAL (SELECT (m+interval '1 month'-interval '1 day')::date AS period_end
   FROM generate_series(date_trunc('month',e.tax_from),date_trunc('month',current_date)-interval '1 month',interval '1 month') m) p
  LEFT JOIN lodgements l ON l.entity_id=e.id AND l.period_end=p.period_end
  WHERE e.active AND e.gst_period<>'none' AND (e.gst_period='monthly'
   OR (e.gst_period='two-monthly' AND extract(month FROM p.period_end)::int%2=0)
   OR (e.gst_period='quarterly' AND extract(month FROM p.period_end) IN (3,6,9,12)))) x;

CREATE VIEW v_distributions AS
 SELECT d.id, d.entity_id, e.name AS entity, e.country, e.currency, d.amount, d.status, d.declared_on, d.pay_on, d.solvency_certificate_on, d.approved_by, d.in_forecast,
  (SELECT m.assets-m.liabilities FROM v_monthly m WHERE m.entity_id=d.entity_id AND m.basis='actual' AND m.assets IS NOT NULL AND m.period<=coalesce(d.declared_on,current_date) ORDER BY m.period DESC LIMIT 1) AS net_assets_before,
  CASE WHEN d.status IN ('proposed','declared') THEN
   (SELECT min(m.cash) FROM v_monthly m WHERE m.entity_id=d.entity_id AND m.period>=date_trunc('month',d.pay_on) AND m.period<date_trunc('month',d.pay_on)+interval '12 months')
   - CASE WHEN d.in_forecast THEN 0 ELSE d.amount END END AS lowest_cash_after
 FROM distributions d JOIN entities e ON e.id=d.entity_id;

CREATE VIEW v_close AS
 SELECT t.id, e.name AS entity, to_char(t.period,'YYYY-MM') AS month, t.task, t.owner, t.due_on, t.done_on,
  CASE WHEN t.done_on IS NOT NULL THEN 'done' WHEN t.due_on<current_date THEN 'overdue' ELSE 'open' END AS state, t.period, t.entity_id
 FROM close_tasks t JOIN entities e ON e.id=t.entity_id;

-- Forecast months that have since closed but still hold forecast figures.
CREATE VIEW v_unrolled AS
 SELECT f.entity_id, e.name AS entity, string_agg(DISTINCT to_char(f.period,'YYYY-MM'),', ') AS months
 FROM lines f JOIN entities e ON e.id=f.entity_id JOIN v_latest m ON m.entity_id=f.entity_id
 LEFT JOIN lines a ON a.version_id=actuals_id() AND a.entity_id=f.entity_id AND a.account_id=f.account_id AND a.period=f.period
 WHERE f.version_id=current_forecast() AND f.period<=m.last_actual AND a.amount IS DISTINCT FROM f.amount
 GROUP BY f.entity_id,e.name;

CREATE VIEW v_attention AS
 SELECT entity||' / '||code||' '||account AS item, 'variance not explained' AS issue,
  month||': '||fmt(variance)||' '||currency||' ('||coalesce(pct::text,'no budget')||'%) against budget'||coalesce(', budget holder '||owner,'') AS detail FROM v_commentary_due
 UNION ALL SELECT entity||' / '||task, 'close task overdue', month||' close, due '||due_on||coalesce(', '||owner,'') FROM v_close WHERE state='overdue'
 UNION ALL SELECT entity||' / '||lender||' '||metric, 'covenant breach forecast', first_forecast_breach||': '||fmt(breach_value)||' against '||test||' '||fmt(threshold) FROM v_covenants WHERE first_forecast_breach IS NOT NULL
 UNION ALL SELECT entity, 'cash below zero forecast', min(month)||': '||fmt(min(closing_cash))||' '||currency FROM v_cash WHERE basis='forecast' AND closing_cash<0 GROUP BY entity,currency
 UNION ALL SELECT entity||' / '||return_type||' '||period_end, CASE state WHEN 'overdue' THEN 'tax return overdue' ELSE 'tax return due soon' END, 'due '||due_on FROM v_tax_calendar WHERE state IN ('overdue','due soon')
 UNION ALL SELECT entity, 'forecast not rolled', 'The current forecast still holds forecast figures for closed months '||months FROM v_unrolled
 UNION ALL SELECT name, 'budget not approved', 'Started '||starts_on||'; nothing is judged against an unapproved budget' FROM versions WHERE kind='budget' AND NOT locked AND starts_on<=current_date;

-- Record checks. Sources and limits: docs/compliance.md.
CREATE VIEW v_compliance AS
 SELECT CASE e.country WHEN 'NZ' THEN 'NZ-KIWISAVER' ELSE 'AU-SUPER-GUARANTEE' END AS rule,
  h.role||coalesce(' ('||h.person||')','')||' / '||e.name AS item,
  'Planned at '||h.oncost_rate||'% employer contribution; the minimum is '||r.rate||'% from '||r.from_date AS finding
 FROM hires h JOIN entities e ON e.id=h.entity_id
 JOIN LATERAL (SELECT * FROM statutory_rates r WHERE r.country=e.country AND h.oncost_rate<r.rate
   AND r.from_date<=coalesce(h.ends_on,'infinity'::date)
   AND r.from_date<=coalesce((SELECT max(ends_on) FROM v_versions WHERE kind IN ('budget','forecast')),current_date)
   ORDER BY r.rate DESC LIMIT 1) r ON true
 WHERE h.status<>'cancelled' AND NOT (e.country='NZ' AND coalesce(h.reduced_rate_until,'-infinity'::date)>=current_date AND h.oncost_rate>=3)
 UNION ALL SELECT CASE country WHEN 'NZ' THEN 'NZ-GST-DUE' ELSE 'AU-BAS-DUE' END, entity||' / period ending '||period_end,
  return_type||' was due '||due_on||' and is not recorded as lodged' FROM v_tax_calendar WHERE state='overdue'
 UNION ALL SELECT 'NZ-S52-CERTIFICATE', entity||' / '||fmt(amount)||' '||currency||' distribution',
  'Declared '||declared_on||' with no directors'' solvency certificate on file' FROM v_distributions WHERE country='NZ' AND status IN ('declared','paid') AND solvency_certificate_on IS NULL
 UNION ALL SELECT 'AU-S254T-NET-ASSETS', entity||' / '||fmt(amount)||' '||currency||' dividend',
  CASE WHEN net_assets_before IS NULL THEN 'No actual balance sheet on file to show assets exceed liabilities'
   ELSE 'Net assets of '||fmt(net_assets_before)||' at the last closed month do not cover it' END
  FROM v_distributions WHERE country='AU' AND status IN ('proposed','declared') AND (net_assets_before IS NULL OR net_assets_before<amount)
 UNION ALL SELECT 'SOLVENCY-CASH', entity||' / '||fmt(amount)||' '||currency||' distribution',
  'Forecast cash falls to '||fmt(lowest_cash_after)||' in the 12 months after paying it' FROM v_distributions WHERE lowest_cash_after<0
 UNION ALL SELECT 'BUDGET-APPROVAL', name, 'Started '||starts_on||' and has not been approved and locked' FROM versions WHERE kind='budget' AND NOT locked AND starts_on<=current_date
 UNION ALL SELECT 'COVENANT-BREACH', entity||' / '||lender||' '||metric, 'Tested '||last_tested||' on actuals at '||fmt(last_value)||' against '||test||' '||fmt(threshold)
  FROM v_covenants WHERE last_tested IS NOT NULL AND NOT last_passed;

ALTER TABLE entities ENABLE ROW LEVEL SECURITY; ALTER TABLE accounts ENABLE ROW LEVEL SECURITY; ALTER TABLE versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE lines ENABLE ROW LEVEL SECURITY; ALTER TABLE hires ENABLE ROW LEVEL SECURITY; ALTER TABLE statutory_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE covenants ENABLE ROW LEVEL SECURITY; ALTER TABLE commentary ENABLE ROW LEVEL SECURITY; ALTER TABLE close_tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE lodgements ENABLE ROW LEVEL SECURITY; ALTER TABLE distributions ENABLE ROW LEVEL SECURITY; ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity ENABLE ROW LEVEL SECURITY; ALTER TABLE imports ENABLE ROW LEVEL SECURITY;
