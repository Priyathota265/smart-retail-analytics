-- ============================================================
-- FILE: 04_sample_data.sql
-- PROJECT: Smart Retail Analytics Platform
-- DESCRIPTION: Seed data for local development & testing
-- AUTHOR: Priyadarshini Thota
-- ============================================================

USE RetailEdgeDW;
GO

-- ─────────────────────────────────────────
-- DimDate (Jan–Mar 2026)
-- ─────────────────────────────────────────
INSERT INTO dwh.DimDate VALUES (20260101,'2026-01-01',5,'Thursday',1,1,'January',1,2026,0,1,2026,1);
INSERT INTO dwh.DimDate VALUES (20260115,'2026-01-15',5,'Thursday',3,1,'January',1,2026,0,0,2026,1);
INSERT INTO dwh.DimDate VALUES (20260201,'2026-02-01',1,'Sunday',5,2,'February',1,2026,1,0,2026,1);
INSERT INTO dwh.DimDate VALUES (20260215,'2026-02-15',1,'Sunday',7,2,'February',1,2026,1,0,2026,1);
INSERT INTO dwh.DimDate VALUES (20260301,'2026-03-01',1,'Sunday',9,3,'March',1,2026,1,0,2026,1);
INSERT INTO dwh.DimDate VALUES (20260303,'2026-03-03',3,'Tuesday',10,3,'March',1,2026,0,0,2026,1);
GO

-- ─────────────────────────────────────────
-- DimStore
-- ─────────────────────────────────────────
INSERT INTO dwh.DimStore (StoreID,StoreName,Region,State,City,StoreType,OpenDate)
VALUES
('STR001','RetailEdge Houston Downtown','South','TX','Houston','Physical','2019-03-01'),
('STR002','RetailEdge Dallas Flagship','South','TX','Dallas','Physical','2018-06-15'),
('STR003','RetailEdge Online Store','National','N/A','Online','Online','2020-01-01'),
('STR004','RetailEdge Austin Outlet','South','TX','Austin','Outlet','2021-09-10'),
('STR005','RetailEdge New York','Northeast','NY','New York','Physical','2017-11-01');
GO

-- ─────────────────────────────────────────
-- DimProduct
-- ─────────────────────────────────────────
INSERT INTO dwh.DimProduct (ProductID,ProductName,Category,SubCategory,Brand,UnitCost,UnitPrice)
VALUES
('PRD001','UltraSound Speaker Pro','Electronics','Audio','SoundMax',45.00,129.99),
('PRD002','EcoBlend Coffee Maker','Appliances','Kitchen','BrewCo',28.00,79.99),
('PRD003','ActiveFit Running Shoes','Footwear','Athletic','StridePro',32.00,89.99),
('PRD004','SmartHome Hub v3','Electronics','Smart Home','NexaTech',60.00,199.99),
('PRD005','OrganicBliss Skincare Set','Beauty','Skincare','GlowNatural',18.00,54.99),
('PRD006','Premium Yoga Mat','Fitness','Yoga','ZenFlex',12.00,39.99),
('PRD007','4K Action Camera','Electronics','Camera','SnapVision',75.00,249.99),
('PRD008','Stainless Steel Water Bottle','Home','Kitchen',  'HydraMax',8.00,29.99);
GO

-- ─────────────────────────────────────────
-- DimCustomer
-- ─────────────────────────────────────────
INSERT INTO dwh.DimCustomer (CustomerID,FirstName,LastName,Email,Segment,Region,State,City,JoinDate,ChurnRiskScore,ChurnRiskCategory)
VALUES
('CUST001','Emma','Johnson','emma.j@email.com','Premium','South','TX','Houston','2021-05-10',0.1200,'Low'),
('CUST002','Michael','Chen','m.chen@email.com','Regular','South','TX','Dallas','2022-01-20',0.4500,'Medium'),
('CUST003','Aisha','Patel','a.patel@email.com','At-Risk','Northeast','NY','New York','2020-08-15',0.7800,'High'),
('CUST004','Carlos','Rivera','c.rivera@email.com','Premium','South','TX','Austin','2019-11-30',0.0800,'Low'),
('CUST005','Sarah','Williams','s.williams@email.com','Regular','South','TX','Houston','2023-03-05',0.6200,'High'),
('CUST006','James','Kim','j.kim@email.com','Regular','Northeast','NY','New York','2022-07-22',0.3300,'Medium'),
('CUST007','Priya','Sharma','priya.s@email.com','Premium','South','TX','Dallas','2021-02-14',0.0500,'Low'),
('CUST008','David','Brown','d.brown@email.com','At-Risk','South','TX','Houston','2020-06-01',0.8900,'High');
GO

-- ─────────────────────────────────────────
-- FactSales
-- ─────────────────────────────────────────
INSERT INTO dwh.FactSales (OrderID,OrderLineID,DateKey,CustomerKey,ProductKey,StoreKey,Quantity,UnitPrice,Discount,COGS)
VALUES
('ORD-2026-0001',1,20260101,1,1,1,2,129.99,0,90.00),
('ORD-2026-0001',2,20260101,1,5,1,1,54.99,10,18.00),
('ORD-2026-0002',1,20260115,2,2,2,1,79.99,0,28.00),
('ORD-2026-0003',1,20260115,3,4,3,1,199.99,5,60.00),
('ORD-2026-0004',1,20260201,4,7,4,1,249.99,0,75.00),
('ORD-2026-0005',1,20260201,5,3,1,2,89.99,15,64.00),
('ORD-2026-0006',1,20260215,6,6,3,3,39.99,0,36.00),
('ORD-2026-0007',1,20260215,7,1,5,1,129.99,10,45.00),
('ORD-2026-0008',1,20260301,8,8,2,2,29.99,0,16.00),
('ORD-2026-0009',1,20260303,1,4,3,1,199.99,0,60.00),
('ORD-2026-0010',1,20260303,4,2,1,2,79.99,5,56.00);
GO

PRINT 'Seed data inserted successfully.';
GO
