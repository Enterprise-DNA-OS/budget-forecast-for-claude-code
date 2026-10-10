-- Fictional demo: Harbourline Group, an NZ wholesaler with an Australian subsidiary. Dates move with today:
-- the board budget starts six months before this month, actuals run to last month.
-- Deliberately untidy: two big variances nobody has explained, overdue close tasks, a forecast not rolled
-- since the last two closes, cash forecast under the bank's minimum, an overdue GST return, a hire planned
-- below the KiwiSaver minimum, another below the super guarantee, a paid dividend with no solvency
-- certificate, and a proposed dividend the forecast cannot carry.
INSERT INTO entities(id,name,country,currency,gst_period,tax_from,adaptive_level) VALUES
('10000000-0000-4000-8000-000000000001','Harbourline NZ Ltd','NZ','NZD','monthly',(date_trunc('month',current_date)-interval '6 months')::date,'HL-NZ'),
('10000000-0000-4000-8000-000000000002','Harbourline Australia Pty Ltd','AU','AUD','quarterly',(date_trunc('month',current_date)-interval '12 months')::date,'HL-AU')
ON CONFLICT DO NOTHING;

INSERT INTO accounts(id,code,name,type,tag,owner,owner_email,adaptive_code) VALUES
('20000000-0000-4000-8000-000000004000','4000','Sales revenue','revenue',NULL,'Rangi Parata','rangi@harbourline.example','4000'),
('20000000-0000-4000-8000-000000004100','4100','Service revenue','revenue',NULL,'Rangi Parata','rangi@harbourline.example','4100'),
('20000000-0000-4000-8000-000000005000','5000','Cost of sales','cogs',NULL,'Sione Latu','sione@harbourline.example','5000'),
('20000000-0000-4000-8000-000000006000','6000','Wages and salaries','expense','wages','Mia Chen','mia@harbourline.example','6000'),
('20000000-0000-4000-8000-000000006100','6100','Rent','expense',NULL,'Mia Chen','mia@harbourline.example','6100'),
('20000000-0000-4000-8000-000000006200','6200','Marketing','expense',NULL,'Tama Ngata','tama@harbourline.example','6200'),
('20000000-0000-4000-8000-000000006300','6300','Software and subscriptions','expense',NULL,'Mia Chen','mia@harbourline.example','6300'),
('20000000-0000-4000-8000-000000006400','6400','Travel','expense',NULL,'Rangi Parata','rangi@harbourline.example','6400'),
('20000000-0000-4000-8000-000000006500','6500','Depreciation','expense','depreciation',NULL,NULL,'6500'),
('20000000-0000-4000-8000-000000007000','7000','Interest expense','other_expense','interest',NULL,NULL,'7000'),
('20000000-0000-4000-8000-000000007100','7100','Income tax expense','other_expense','tax',NULL,NULL,'7100'),
('20000000-0000-4000-8000-000000001000','1000','Bank','asset','cash',NULL,NULL,'1000'),
('20000000-0000-4000-8000-000000001100','1100','Accounts receivable','asset',NULL,NULL,NULL,'1100'),
('20000000-0000-4000-8000-000000001500','1500','Plant and equipment','asset',NULL,NULL,NULL,'1500'),
('20000000-0000-4000-8000-000000002000','2000','Accounts payable','liability',NULL,NULL,NULL,'2000'),
('20000000-0000-4000-8000-000000002500','2500','Term loan','liability','debt',NULL,NULL,'2500')
ON CONFLICT DO NOTHING;

INSERT INTO versions(id,name,kind,starts_on,months,based_on,locked,approved_by,approved_on,notes,created_at) VALUES
('30000000-0000-4000-8000-000000000000','Actuals','actuals',NULL,NULL,NULL,false,NULL,NULL,'Closed months from the accounting system',now()-interval '400 days'),
('30000000-0000-4000-8000-000000000001','Board budget','budget',(date_trunc('month',current_date)-interval '6 months')::date,12,NULL,false,'Board of directors',(date_trunc('month',current_date)-interval '6 months')::date-10,'Approved at the board meeting before the year started',now()-interval '200 days'),
('30000000-0000-4000-8000-000000000002','Reforecast 1','forecast',(date_trunc('month',current_date)-interval '6 months')::date,12,'30000000-0000-4000-8000-000000000001',false,NULL,NULL,'Rolled after the close three months ago',now()-interval '60 days'),
('30000000-0000-4000-8000-000000000003','Downside','scenario',(date_trunc('month',current_date)-interval '6 months')::date,12,'30000000-0000-4000-8000-000000000002',false,NULL,NULL,'Reforecast 1 with revenue ten percent lower',now()-interval '55 days')
ON CONFLICT DO NOTHING;

-- Monthly P&L: base amount, a 1% a month trend from the budget's first month, a factor for actuals,
-- a factor for last month's actuals, and a factor for the forecast's open months.
CREATE TEMP TABLE seed_pl(entity_id uuid, account_id uuid, amt numeric, af numeric, last_af numeric, ff numeric) ON COMMIT DROP;
INSERT INTO seed_pl VALUES
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000004000',430000,0.98,0.86,0.97),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000004100',90000,1.03,1.03,1.02),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000005000',215000,0.97,0.97,0.98),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006000',168000,1.02,1.02,1.03),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006100',24000,1,1,1),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006200',22000,1.04,2,1.05),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006300',9000,1.05,1.05,1.05),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006400',6500,0.95,0.95,1),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000006500',8000,1,1,1),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000007000',7500,1,1,1),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000007100',12000,1,1,1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000004000',260000,0.99,0.99,0.98),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000004100',40000,1.02,1.02,1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000005000',128000,0.98,0.98,0.98),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006000',98000,1.01,1.01,1.02),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006100',18000,1,1,1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006200',12000,1.03,1.6,1.1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006300',6000,1.02,1.02,1.02),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006400',4000,0.97,0.97,1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000006500',3000,1,1,1),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000007100',8000,1,1,1);

-- Balances: amount = a + b * (months from this month), the same in actuals and forecast.
CREATE TEMP TABLE seed_bs(entity_id uuid, account_id uuid, a numeric, b numeric) ON COMMIT DROP;
INSERT INTO seed_bs VALUES
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000001000',420000,-35000),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000001100',610000,2000),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000001500',900000,-8000),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000002000',240000,0),
('10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000002500',1020000,-10000),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000001000',380000,-2000),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000001100',260000,0),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000001500',120000,-3000),
('10000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000002000',140000,0);

CREATE TEMP TABLE seed_m ON COMMIT DROP AS
 SELECT c, (date_trunc('month',current_date)+c*interval '1 month')::date AS period FROM generate_series(-18,5) c;

-- Actuals: eighteen closed months.
INSERT INTO lines(version_id,entity_id,account_id,period,amount)
 SELECT '30000000-0000-4000-8000-000000000000'::uuid,p.entity_id,p.account_id,m.period,round(p.amt*(1+0.01*(m.c+6))*CASE WHEN m.c=-1 THEN p.last_af ELSE p.af END)
 FROM seed_pl p CROSS JOIN seed_m m WHERE m.c<=-1
 UNION ALL SELECT '30000000-0000-4000-8000-000000000000'::uuid,b.entity_id,b.account_id,m.period,b.a+b.b*m.c FROM seed_bs b CROSS JOIN seed_m m WHERE m.c<=-1
ON CONFLICT DO NOTHING;
-- Board budget: twelve months of P&L, then approved and locked.
INSERT INTO lines(version_id,entity_id,account_id,period,amount)
 SELECT '30000000-0000-4000-8000-000000000001'::uuid,p.entity_id,p.account_id,m.period,round(p.amt*(1+0.01*(m.c+6))) FROM seed_pl p CROSS JOIN seed_m m
 WHERE m.c BETWEEN -6 AND 5 AND NOT (SELECT locked FROM versions WHERE id='30000000-0000-4000-8000-000000000001')
ON CONFLICT DO NOTHING;
UPDATE versions SET locked=true WHERE id='30000000-0000-4000-8000-000000000001' AND NOT locked;
-- Reforecast 1: rolled three closes ago, so actuals to three months back and forecast after that.
INSERT INTO lines(version_id,entity_id,account_id,period,amount)
 SELECT '30000000-0000-4000-8000-000000000002'::uuid,p.entity_id,p.account_id,m.period,round(p.amt*(1+0.01*(m.c+6))*CASE WHEN m.c<=-3 THEN p.af ELSE p.ff END)
 FROM seed_pl p CROSS JOIN seed_m m WHERE m.c BETWEEN -6 AND 5
 UNION ALL SELECT '30000000-0000-4000-8000-000000000002'::uuid,b.entity_id,b.account_id,m.period,b.a+b.b*m.c FROM seed_bs b CROSS JOIN seed_m m WHERE m.c BETWEEN -6 AND 5
ON CONFLICT DO NOTHING;
-- Downside: Reforecast 1 with revenue ten percent lower.
INSERT INTO lines(version_id,entity_id,account_id,period,amount)
 SELECT '30000000-0000-4000-8000-000000000003'::uuid,l.entity_id,l.account_id,l.period,CASE WHEN a.type='revenue' THEN round(l.amount*0.9) ELSE l.amount END
 FROM lines l JOIN accounts a ON a.id=l.account_id WHERE l.version_id='30000000-0000-4000-8000-000000000002'
ON CONFLICT DO NOTHING;

INSERT INTO commentary(id,entity_id,account_id,period,note,actor) VALUES
('40000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000004000',(date_trunc('month',current_date)-interval '1 month')::date,'Two wholesale orders for Kaiwaka Foods slipped into this month; both are invoiced','Rangi Parata')
ON CONFLICT DO NOTHING;

INSERT INTO close_tasks(id,entity_id,period,task,owner,due_on,done_on,evidence) VALUES
('50000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',(date_trunc('month',current_date)-interval '1 month')::date,'Bank reconciliation','Mia Chen',current_date-6,current_date-7,'All accounts reconciled to statements'),
('50000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001',(date_trunc('month',current_date)-interval '1 month')::date,'Accruals and prepayments','Mia Chen',current_date-3,NULL,NULL),
('50000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001',(date_trunc('month',current_date)-interval '1 month')::date,'Payroll reconciliation','Mia Chen',current_date-4,current_date-4,'Payroll report agrees to wages'),
('50000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001',(date_trunc('month',current_date)-interval '1 month')::date,'Variance commentary','Rangi Parata',current_date+2,NULL,NULL),
('50000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000002',(date_trunc('month',current_date)-interval '1 month')::date,'Bank reconciliation','Hannah Brooks',current_date-6,current_date-6,'Reconciled'),
('50000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000002',(date_trunc('month',current_date)-interval '1 month')::date,'Intercompany reconciliation','Hannah Brooks',current_date-1,NULL,NULL)
ON CONFLICT DO NOTHING;

INSERT INTO hires(id,entity_id,role,person,department,starts_on,ends_on,annual_salary,oncost_rate,status) VALUES
('60000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Financial controller','Mia Chen','Finance',(date_trunc('month',current_date)-interval '30 months')::date,NULL,135000,3.5,'filled'),
('60000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Sales manager',NULL,'Sales',(date_trunc('month',current_date)+interval '1 month')::date,NULL,120000,3,'planned'),
('60000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','Warehouse lead',NULL,'Operations',(date_trunc('month',current_date)+interval '3 months')::date,NULL,72000,3.5,'planned'),
('60000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000002','Account manager',NULL,'Sales',(date_trunc('month',current_date)+interval '2 months')::date,NULL,95000,11.5,'planned'),
('60000000-0000-4000-8000-000000000005','10000000-0000-4000-8000-000000000002','Operations coordinator','Hannah Brooks','Operations',(date_trunc('month',current_date)-interval '14 months')::date,NULL,82000,12,'filled')
ON CONFLICT DO NOTHING;

INSERT INTO covenants(id,entity_id,lender,metric,test,threshold,frequency,evidence) VALUES
('70000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Kauri Bank','minimum cash','>=',250000,'monthly','Facility agreement clause 18.1'),
('70000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Kauri Bank','interest cover','>=',3,'quarterly','Facility agreement clause 18.2'),
('70000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','Kauri Bank','debt to ebitda','<=',2.5,'quarterly','Facility agreement clause 18.3')
ON CONFLICT DO NOTHING;

INSERT INTO distributions(id,entity_id,amount,status,declared_on,pay_on,solvency_certificate_on,approved_by,in_forecast,evidence) VALUES
('80000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001',150000,'paid',current_date-20,current_date-10,NULL,'Board of directors',true,'Board minutes'),
('80000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002',400000,'proposed',NULL,current_date+30,NULL,NULL,false,'Paper for the next board meeting')
ON CONFLICT DO NOTHING;

-- GST: NZ lodged every month except three months ago (overdue) and last month (not due yet).
INSERT INTO lodgements(entity_id,period_end,lodged_on,reference,evidence)
 SELECT entity_id,period_end,least(due_on-3,current_date),'GST-'||to_char(period_end,'YYYYMM'),'Filed in myIR' FROM v_tax_calendar
 WHERE country='NZ' AND period_end NOT IN ((date_trunc('month',current_date)-interval '2 months'-interval '1 day')::date,(date_trunc('month',current_date)-interval '1 day')::date)
ON CONFLICT DO NOTHING;
-- BAS: every quarter already due is lodged.
INSERT INTO lodgements(entity_id,period_end,lodged_on,reference,evidence)
 SELECT entity_id,period_end,least(due_on-5,current_date),'BAS-'||to_char(period_end,'YYYYMM'),'Lodged through the tax agent' FROM v_tax_calendar
 WHERE country='AU' AND due_on<current_date
ON CONFLICT DO NOTHING;
