/* 1) OUTLET */
CREATE TABLE OUTLET (
  Outlet_ID          INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Outlet_Name        VARCHAR(100) NOT NULL,
  Suburb             VARCHAR(80)  NOT NULL,
  State              VARCHAR(30)  NOT NULL,
  Postcode           CHAR(4)      NOT NULL,
  Store_Phone_Num    VARCHAR(20)  NULL,
  UNIQUE KEY uq_outlet_name (Outlet_Name)
);

 /* 2) STAFF */
CREATE TABLE STAFF (
  Staff_ID           INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Outlet_ID          INT UNSIGNED NOT NULL,
  Staff_First_Name   VARCHAR(60)  NOT NULL,
  Staff_Last_Name    VARCHAR(60)  NOT NULL,
  Job_Role           VARCHAR(20)  NOT NULL,
  Staff_Phone_Num    VARCHAR(20)  NULL,
  Hire_Date          DATE         NOT NULL,
  CONSTRAINT ck_staff_role CHECK (Job_Role IN ('Manager','Chef','Server','Barista')),
  CONSTRAINT fk_staff_outlet
    FOREIGN KEY (Outlet_ID) REFERENCES OUTLET(Outlet_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  -- helps ROSTER outlet-matching rule
  UNIQUE KEY uq_staff_outlet_staff (Outlet_ID, Staff_ID),
  KEY ix_staff_outlet (Outlet_ID),
  KEY ix_staff_name (Staff_Last_Name, Staff_First_Name)
);

 /* 3) SHIFT */
CREATE TABLE SHIFT (
  Shift_ID           INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Outlet_ID          INT UNSIGNED NOT NULL,
  Shift_Date         DATE NOT NULL,
  Start_Time         TIME NOT NULL,
  End_Time           TIME NOT NULL,
  CONSTRAINT ck_shift_time CHECK (Start_Time < End_Time),
  CONSTRAINT fk_shift_outlet
    FOREIGN KEY (Outlet_ID) REFERENCES OUTLET(Outlet_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  -- allow composite FK from ROSTER to assert same-outlet pairing
  UNIQUE KEY uq_shift_outlet_shift (Outlet_ID, Shift_ID),
  -- prevent accidental duplicate shift windows at an outlet
  UNIQUE KEY uq_shift_window (Outlet_ID, Shift_Date, Start_Time, End_Time),
  KEY ix_shift_date (Shift_Date)
);

 /* 4) CUSTOMER */
CREATE TABLE CUSTOMER (
  Customer_ID            INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Customer_First_Name    VARCHAR(60) NOT NULL,
  Customer_Last_Name     VARCHAR(60) NOT NULL,
  Email                  VARCHAR(120) NULL,
  Customer_Phone_Number  VARCHAR(20)  NULL,
  Member_Since           DATE         NOT NULL,
  UNIQUE KEY uq_customer_email (Email),
  KEY ix_customer_name (Customer_Last_Name, Customer_First_Name)
);

 /* 5) RESERVATION */
CREATE TABLE RESERVATION (
  Reservation_ID       INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Customer_ID          INT UNSIGNED NOT NULL,
  Outlet_ID            INT UNSIGNED NOT NULL,
  Reservation_Datetime DATETIME     NOT NULL,
  Number_Of_Guests     INT UNSIGNED NOT NULL,
  Reservation_Status   VARCHAR(12)  NOT NULL,
  CONSTRAINT ck_res_status CHECK (Reservation_Status IN ('requested','confirmed','cancelled','no_show')),
  CONSTRAINT fk_res_customer
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_res_outlet
    FOREIGN KEY (Outlet_ID) REFERENCES OUTLET(Outlet_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  KEY ix_res_outlet_dt (Outlet_ID, Reservation_Datetime),
  KEY ix_res_customer_dt (Customer_ID, Reservation_Datetime)
);

 /* 6) PRODUCT_CATEGORY */
CREATE TABLE PRODUCT_CATEGORY (
  Category_ID        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Category_Name      VARCHAR(40)  NOT NULL,
  Category_Description VARCHAR(200) NULL,
  UNIQUE KEY uq_category_name (Category_Name)
);

 /* 7) PRODUCT */
CREATE TABLE PRODUCT (
  Product_ID         INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Category_ID        INT UNSIGNED NOT NULL,
  Product_Name       VARCHAR(120) NOT NULL,
  Unit_Price         DECIMAL(10,2) NOT NULL,
  Product_Description VARCHAR(300) NULL,
  CONSTRAINT fk_product_category
    FOREIGN KEY (Category_ID) REFERENCES PRODUCT_CATEGORY(Category_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  UNIQUE KEY uq_product_name (Product_Name),
  KEY ix_product_category (Category_ID)
);

 /* 8) CUSTOMER_ORDER */
CREATE TABLE CUSTOMER_ORDER (
  Order_ID           INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Customer_ID        INT UNSIGNED NOT NULL,
  Outlet_ID          INT UNSIGNED NOT NULL,
  Order_Datetime     DATETIME     NOT NULL,
  Order_Type         VARCHAR(10)  NOT NULL,     -- dine in / takeaway / delivery
  Order_Status       VARCHAR(10)  NOT NULL,     -- open / paid / void / refunded
  Subtotal           DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  Tax                DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  Discount_Total     DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  Grand_Total        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  Delivery_Address   VARCHAR(200)  NULL,
  CONSTRAINT ck_order_type CHECK (Order_Type IN ('dine in','takeaway','delivery')),
  CONSTRAINT ck_order_status CHECK (Order_Status IN ('open','paid','void','refunded')),
  CONSTRAINT ck_delivery_address CHECK (
     Order_Type <> 'delivery' OR Delivery_Address IS NOT NULL
  ),
  CONSTRAINT fk_order_customer
    FOREIGN KEY (Customer_ID) REFERENCES CUSTOMER(Customer_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  CONSTRAINT fk_order_outlet
    FOREIGN KEY (Outlet_ID) REFERENCES OUTLET(Outlet_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  KEY ix_order_outlet_dt (Outlet_ID, Order_Datetime),
  KEY ix_order_customer_dt (Customer_ID, Order_Datetime),
  KEY ix_order_status (Order_Status)
);

 /* 9) ORDER_DETAIL  (PK uses (Order_ID, Line_No)) */
CREATE TABLE ORDER_DETAIL (
  Order_ID             INT UNSIGNED NOT NULL,
  Line_No              INT UNSIGNED NOT NULL,
  Product_ID           INT UNSIGNED NOT NULL,
  Unit_Price_At_Order  DECIMAL(10,2) NOT NULL,
  Quantity             INT UNSIGNED NOT NULL,
  Line_Discount        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  Tax_Rate_At_Order    DECIMAL(5,2)  NOT NULL,  -- e.g., 10.00 for 10%
  Line_Total           DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (Order_ID, Line_No),
  CONSTRAINT fk_od_order
    FOREIGN KEY (Order_ID) REFERENCES CUSTOMER_ORDER(Order_ID)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_od_product
    FOREIGN KEY (Product_ID) REFERENCES PRODUCT(Product_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  -- enable "one product per order" rule if you want Cape-Codd-style uniqueness:
  -- UNIQUE KEY uq_od_order_product (Order_ID, Product_ID),
  KEY ix_od_product (Product_ID)
);

 /* 10) PAYMENT */
CREATE TABLE PAYMENT (
  Payment_ID        INT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
  Order_ID          INT UNSIGNED NOT NULL,
  Payment_Datetime  DATETIME     NOT NULL,
  Amount            DECIMAL(10,2) NOT NULL,
  Payment_Method    VARCHAR(10)  NOT NULL,     -- cash/card/online/giftcard
  Payment_Status    VARCHAR(10)  NOT NULL,     -- approved/failed/refunded
  CONSTRAINT ck_payment_method CHECK (Payment_Method IN ('cash','card','online','giftcard')),
  CONSTRAINT ck_payment_status CHECK (Payment_Status IN ('approved','failed','refunded')),
  CONSTRAINT ck_payment_amount CHECK (Amount > 0),
  CONSTRAINT fk_payment_order
    FOREIGN KEY (Order_ID) REFERENCES CUSTOMER_ORDER(Order_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  KEY ix_payment_order (Order_ID),
  KEY ix_payment_dt (Payment_Datetime)
);

 /* 11) ROSTER  (junction for Staff–Shift with outlet integrity) */
CREATE TABLE ROSTER (
  Shift_ID             INT UNSIGNED NOT NULL,
  Staff_ID             INT UNSIGNED NOT NULL,
  Outlet_ID            INT UNSIGNED NOT NULL,   -- enforces same-outlet pairing
  Scheduled_Start_Time DATETIME     NOT NULL,
  Scheduled_End_Time   DATETIME     NOT NULL,
  Actual_Start_Time    DATETIME     NULL,
  Actual_End_Time      DATETIME     NULL,
  Role_On_Shift        VARCHAR(20)  NOT NULL,
  Hours_Worked         DECIMAL(6,2) AS (
    CASE
      WHEN Actual_Start_Time IS NULL OR Actual_End_Time IS NULL
        THEN NULL
      ELSE ROUND(TIMESTAMPDIFF(MINUTE, Actual_Start_Time, Actual_End_Time)/60, 2)
    END
  ) STORED,
  CONSTRAINT ck_roster_sched CHECK (Scheduled_Start_Time < Scheduled_End_Time),
  CONSTRAINT ck_roster_actual CHECK (
    Actual_Start_Time IS NULL OR Actual_End_Time IS NULL OR Actual_Start_Time < Actual_End_Time
  ),
  CONSTRAINT ck_roster_role CHECK (Role_On_Shift IN ('Manager','Chef','Server','Barista')),
  PRIMARY KEY (Shift_ID, Staff_ID),
  CONSTRAINT fk_roster_shift
    FOREIGN KEY (Outlet_ID, Shift_ID) REFERENCES SHIFT(Outlet_ID, Shift_ID)
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT fk_roster_staff
    FOREIGN KEY (Outlet_ID, Staff_ID) REFERENCES STAFF(Outlet_ID, Staff_ID)
      ON UPDATE CASCADE ON DELETE RESTRICT,
  KEY ix_roster_staff (Staff_ID),
  KEY ix_roster_shift (Shift_ID)
);






-- =========================
-- OUTLET (exactly 3)
-- =========================
INSERT INTO OUTLET (Outlet_ID, Outlet_Name, Suburb, State, Postcode, Store_Phone_Num) VALUES
  (1, 'Urban Eats CBD',        'Sydney CBD', 'NSW', '2000', '0291000001'),
  (2, 'Urban Eats Newtown',    'Newtown',    'NSW', '2042', '0291000002'),
  (3, 'Urban Eats Parramatta', 'Parramatta', 'NSW', '2150', '0291000003');

-- =========================
-- STAFF (4 core roles per outlet; no cross-outlet staff)
-- =========================
INSERT INTO STAFF (Staff_ID, Outlet_ID, Staff_First_Name, Staff_Last_Name, Job_Role, Staff_Phone_Num, Hire_Date) VALUES
  -- Outlet 1
  (1, 1, 'Ava',   'Nguyen',  'Manager', '0400000001', '2023-01-10'),
  (2, 1, 'Liam',  'Patel',   'Chef',    '0400000002', '2023-03-04'),
  (3, 1, 'Mia',   'Zhou',    'Server',  '0400000003', '2024-02-12'),
  (4, 1, 'Noah',  'Price',   'Barista', '0400000004', '2024-06-01'),
  -- Outlet 2
  (5, 2, 'Isla',  'Brown',   'Manager', '0400000005', '2022-11-20'),
  (6, 2, 'Ethan', 'Taylor',  'Chef',    '0400000006', '2023-08-09'),
  (7, 2, 'Grace', 'Wilson',  'Server',  '0400000007', '2024-06-22'),
  (8, 2, 'Jack',  'Martin',  'Barista', '0400000008', '2025-01-05'),
  -- Outlet 3
  (9,  3, 'Emily','Clark',   'Manager', '0400000009', '2022-07-15'),
  (10, 3, 'Leo',  'Harris',  'Chef',    '0400000010', '2023-10-31'),
  (11, 3, 'Sophie','Cooper', 'Server',  '0400000011', '2025-02-12'),
  (12, 3, 'Lucas','King',    'Barista', '0400000012', '2024-09-30');

-- =========================
-- SHIFT (2 shifts/day/outlet across 3 days = 18 shifts)
-- =========================
INSERT INTO SHIFT (Shift_ID, Outlet_ID, Shift_Date, Start_Time, End_Time) VALUES
  -- 2025-09-15
  (1, 1, '2025-09-15', '08:00:00', '14:00:00'),
  (2, 1, '2025-09-15', '14:00:00', '22:00:00'),
  (3, 2, '2025-09-15', '08:00:00', '14:00:00'),
  (4, 2, '2025-09-15', '14:00:00', '22:00:00'),
  (5, 3, '2025-09-15', '08:00:00', '14:00:00'),
  (6, 3, '2025-09-15', '14:00:00', '22:00:00'),
  -- 2025-09-16
  (7, 1, '2025-09-16', '08:00:00', '14:00:00'),
  (8, 1, '2025-09-16', '14:00:00', '22:00:00'),
  (9, 2, '2025-09-16', '08:00:00', '14:00:00'),
  (10,2, '2025-09-16', '14:00:00', '22:00:00'),
  (11,3, '2025-09-16', '08:00:00', '14:00:00'),
  (12,3, '2025-09-16', '14:00:00', '22:00:00'),
  -- 2025-09-17
  (13,1, '2025-09-17', '08:00:00', '14:00:00'),
  (14,1, '2025-09-17', '14:00:00', '22:00:00'),
  (15,2, '2025-09-17', '08:00:00', '14:00:00'),
  (16,2, '2025-09-17', '14:00:00', '22:00:00'),
  (17,3, '2025-09-17', '08:00:00', '14:00:00'),
  (18,3, '2025-09-17', '14:00:00', '22:00:00');

-- =========================
-- PRODUCT_CATEGORY (only three)
-- =========================
INSERT INTO PRODUCT_CATEGORY (Category_ID, Category_Name, Category_Description) VALUES
  (1, 'Beverages', 'Hot and cold drinks'),
  (2, 'Meals',     'Breakfast and mains'),
  (3, 'Desserts',  'Sweets and cakes');

-- =========================
-- PRODUCT (15 items across the three categories)
-- =========================
INSERT INTO PRODUCT (Product_ID, Category_ID, Product_Name, Unit_Price, Product_Description) VALUES
  -- Beverages
  (1, 1, 'Flat White',     4.50, 'Espresso with microfoam'),
  (2, 1, 'Cappuccino',     4.50, 'Espresso with milk foam'),
  (3, 1, 'Iced Latte',     5.50, 'Cold milk over espresso'),
  (4, 1, 'Matcha Latte',   5.00, 'Green tea latte'),
  (5, 1, 'Long Black',     3.80, 'Americano style'),
  -- Meals
  (6, 2, 'Smashed Avo Toast',   14.00, 'Avocado, feta, sourdough'),
  (7, 2, 'Big Breakfast',       19.00, 'Eggs, bacon, sausage, toast'),
  (8, 2, 'Beef Burger',         18.00, 'Beef patty, cheese, fries'),
  (9, 2, 'Grilled Chicken Salad',16.50, 'Chicken, greens, dressing'),
  (10,2, 'Veggie Wrap',         12.50, 'Roasted veggies, hummus'),
  -- Desserts
  (11,3, 'Chocolate Brownie',   6.50, 'Rich chocolate brownie'),
  (12,3, 'Cheesecake Slice',    7.00, 'Classic NY cheesecake'),
  (13,3, 'Lemon Tart',          6.00, 'Tangy lemon tart'),
  (14,3, 'Ice Cream Sundae',    5.50, 'Vanilla sundae'),
  (15,3, 'Almond Croissant',    5.50, 'Buttery almond pastry');

-- =========================
-- Customer 
-- =========================
INSERT INTO CUSTOMER (Customer_ID, Customer_First_Name, Customer_Last_Name, Email, Customer_Phone_Number, Member_Since) VALUES
  (1, 'Olivia', 'Green', 'olivia.green@example.com', '0411000001', '2023-06-01'),
  (2, 'William', 'Lee', 'william.lee@example.com', '0411000002', '2023-08-15'),
  (3, 'Amelia', 'Davis', 'amelia.davis@example.com', '0411000003', '2024-01-20'),
  (4, 'James', 'Moore', 'james.moore@example.com', '0411000004', '2024-03-05'),
  (5, 'Charlotte', 'Young', 'charlotte.young@example.com', '0411000005', '2022-12-11'),
  (6, 'Benjamin', 'Scott', 'benjamin.scott@example.com', '0411000006', '2025-02-02'),
  (7, 'Harper', 'Adams', 'harper.adams@example.com', '0411000007', '2024-09-09'),
  (8, 'Elijah', 'Nelson', 'elijah.nelson@example.com', '0411000008', '2023-10-25'),
  (9, 'Ava', 'Carter', 'ava.carter@example.com', '0411000009', '2023-05-14'),
  (10, 'Lucas', 'Mitchell', 'lucas.mitchell@example.com', '0411000010', '2025-05-01'),
  (11, 'Sofia', 'Perez', 'sofia.perez@example.com', '0411000011', '2024-12-30'),
  (12, 'Mason', 'Roberts', 'mason.roberts@example.com', '0411000012', '2024-04-17'),
  (13, 'Ella', 'Turner', 'ella.turner@example.com', '0411000013', '2025-06-23'),
  (14, 'Henry', 'Phillips', 'henry.phillips@example.com', '0411000014', '2024-07-07'),
  (15, 'Lily', 'Campbell', 'lily.campbell@example.com', '0411000015', '2022-09-01');
-- =========================
-- RESERVATIONS 
-- =========================
INSERT INTO RESERVATION (Reservation_ID, Customer_ID, Outlet_ID, Reservation_Datetime, Number_Of_Guests, Reservation_Status) VALUES
  (1, 1, 1, '2025-09-18 12:30:00', 2, 'requested'),
  (2, 2, 1, '2025-09-18 19:00:00', 4, 'confirmed'),
  (3, 3, 2, '2025-09-19 08:30:00', 1, 'confirmed'),
  (4, 4, 2, '2025-09-19 13:00:00', 3, 'cancelled'),
  (5, 5, 3, '2025-09-20 18:30:00', 5, 'confirmed'),
  (6, 6, 3, '2025-09-20 20:00:00', 2, 'requested'),
  (7, 7, 1, '2025-09-21 10:00:00', 2, 'confirmed'),
  (8, 8, 1, '2025-09-21 11:30:00', 6, 'requested'),
  (9, 9, 2, '2025-09-22 09:00:00', 1, 'no_show'),
  (10,10,3, '2025-09-22 12:30:00', 2, 'confirmed'),
  (11,11,2, '2025-09-23 18:00:00', 4, 'cancelled'),
  (12,12,3, '2025-09-24 07:30:00', 2, 'confirmed');

-- =========================
-- CUSTOMER_ORDERS (dine in / takeaway / delivery; statuses per business)
-- =========================
INSERT INTO CUSTOMER_ORDER
 (Order_ID, Customer_ID, Outlet_ID, Order_Datetime, Order_Type, Order_Status,
  Subtotal, Tax, Discount_Total, Grand_Total, Delivery_Address)
VALUES
 -- Fri (breakfast/lunch/dinner)
 (16,  1, 1,'2025-09-19 08:20:00','dine in','paid',      14.50, 1.45, 0.00, 15.95, NULL),
 (17,  2, 1,'2025-09-19 12:15:00','takeaway','paid',     22.50, 2.25, 0.00, 24.75, NULL),
 (18,  3, 2,'2025-09-19 19:10:00','delivery','paid',     48.00, 4.80, 0.00, 52.80, '12 King St, Newtown NSW'),

 -- Sat (morning/lunch/dinner)
 (19,  4, 3,'2025-09-20 09:05:00','dine in','paid',      23.30, 2.33, 0.00, 25.63, NULL),
 (20,  5, 3,'2025-09-20 12:45:00','takeaway','paid',     28.00, 2.80, 0.00, 30.80, NULL),
 (21,  6, 2,'2025-09-20 19:40:00','delivery','paid',     47.00, 4.70, 1.00, 51.70, '25 Enmore Rd, Newtown NSW'),

 -- Sun (morning/lunch/afternoon/dinner)
 (22,  7, 1,'2025-09-21 08:15:00','dine in','paid',      15.00, 1.50, 0.00, 16.50, NULL),
 (23,  8, 1,'2025-09-21 13:10:00','dine in','paid',      29.80, 2.98, 0.00, 32.78, NULL),
 (24,  9, 2,'2025-09-21 15:30:00','takeaway','paid',     17.00, 1.70, 0.00, 18.70, NULL),
 (25, 10, 3,'2025-09-21 18:50:00','delivery','paid',     45.00, 4.50, 0.00, 49.50, '90 Church St, Parramatta NSW'),

 -- Mon (breakfast/lunch/dinner)
 (26, 11, 1,'2025-09-22 09:10:00','takeaway','paid',     17.80, 1.78, 0.00, 19.58, NULL),
 (27, 12, 2,'2025-09-22 12:05:00','dine in','paid',      27.50, 2.75, 0.00, 30.25, NULL),
 (28, 13, 3,'2025-09-22 19:20:00','delivery','paid',     41.50, 4.15, 0.00, 45.65, '55 George St, Parramatta NSW'),

 -- Tue (breakfast/evening)
 (29, 14, 1,'2025-09-23 08:30:00','dine in','paid',      14.80, 1.48, 0.00, 16.28, NULL),
 (30, 15, 2,'2025-09-23 20:10:00','takeaway','paid',     30.00, 3.00, 0.00, 33.00, NULL);

-- =========================
-- ORDER DETAIL (10% tax lines; line totals are tax-inclusive)
-- =========================
INSERT INTO ORDER_DETAIL
 (Order_ID, Line_No, Product_ID, Unit_Price_At_Order, Quantity, Line_Discount, Tax_Rate_At_Order, Line_Total) VALUES
 -- 16: 2x Cappuccino + Almond Croissant
 (16,1, 2,4.50,2,0.00,10.00,  9.90),
 (16,2,15,5.50,1,0.00,10.00,  6.05),

 -- 17: Beef Burger + Flat White
 (17,1, 8,18.00,1,0.00,10.00,19.80),
 (17,2, 1, 4.50,1,0.00,10.00, 4.95),

 -- 18: 2x Beef Burger + Iced Latte + Brownie
 (18,1, 8,18.00,2,0.00,10.00,39.60),
 (18,2, 3, 5.50,1,0.00,10.00, 6.05),
 (18,3,11, 6.50,1,0.00,10.00, 7.15),

 -- 19: Long Black + Almond Croissant + Avo Toast
 (19,1, 5, 3.80,1,0.00,10.00, 4.18),
 (19,2,15, 5.50,1,0.00,10.00, 6.05),
 (19,3, 6,14.00,1,0.00,10.00,15.40),

 -- 20: Chicken Salad + Flat White + Cheesecake
 (20,1,10,16.50,1,0.00,10.00,18.15),
 (20,2, 1, 4.50,1,0.00,10.00, 4.95),
 (20,3,12, 7.00,1,0.00,10.00, 7.70),

 -- 21: 2x Beef Burger + 2x Lemon Tart with $1 discount
 (21,1, 8,18.00,2,0.00,10.00,39.60),
 (21,2,13, 6.00,2,1.00,10.00,12.10),

 -- 22: Cappuccino + Matcha + Almond Croissant
 (22,1, 2,4.50,1,0.00,10.00,4.95),
 (22,2, 4,5.00,1,0.00,10.00,5.50),
 (22,3,15,5.50,1,0.00,10.00,6.05),

 -- 23: Big Breakfast + Long Black + Cheesecake
 (23,1, 7,19.00,1,0.00,10.00,20.90),
 (23,2, 5, 3.80,1,0.00,10.00, 4.18),
 (23,3,12, 7.00,1,0.00,10.00, 7.70),

 -- 24: Veggie Wrap + Flat White
 (24,1,10,12.50,1,0.00,10.00,13.75),
 (24,2, 1, 4.50,1,0.00,10.00, 4.95),

 -- 25: 2x Chicken Salad + Brownie + Iced Latte
 (25,1,10,16.50,2,0.00,10.00,36.30),
 (25,2,11, 6.50,1,0.00,10.00, 7.15),
 (25,3, 3, 5.50,1,0.00,10.00, 6.05),

 -- 26: Avo Toast + Long Black
 (26,1, 6,14.00,1,0.00,10.00,15.40),
 (26,2, 5, 3.80,1,0.00,10.00, 4.18),

 -- 27: Chicken Salad + Cappuccino + Brownie
 (27,1,10,16.50,1,0.00,10.00,18.15),
 (27,2, 2, 4.50,1,0.00,10.00, 4.95),
 (27,3,11, 6.50,1,0.00,10.00, 7.15),

 -- 28: Beef Burger + Veggie Wrap + Lemon Tart + Matcha
 (28,1, 8,18.00,1,0.00,10.00,19.80),
 (28,2,10,12.50,1,0.00,10.00,13.75),
 (28,3,13, 6.00,1,0.00,10.00, 6.60),
 (28,4, 4, 5.00,1,0.00,10.00, 5.50),

 -- 29: Flat White + Chai Latte + Almond Croissant
 (29,1, 1, 4.50,1,0.00,10.00, 4.95),
 (29,2, 6, 4.80,1,0.00,10.00, 5.28),       
 (29,3,15, 5.50,1,0.00,10.00, 6.05),

 -- 30: Beef Burger + Iced Latte + Brownie
 (30,1, 8,18.00,1,0.00,10.00,19.80),
 (30,2, 3, 5.50,1,0.00,10.00, 6.05),
 (30,3,11, 6.50,1,0.00,10.00, 7.15);

-- =========================
-- PAYMENTS 
-- =========================
INSERT INTO PAYMENT (Order_ID, Payment_Datetime, Amount, Payment_Method, Payment_Status) VALUES
 (16,'2025-09-19 08:20:00',15.95,'card','approved'),
 (17,'2025-09-19 12:15:00',24.75,'card','approved'),
 (18,'2025-09-19 19:10:00',52.80,'online','approved'),
 (19,'2025-09-20 09:05:00',25.63,'card','approved'),
 (20,'2025-09-20 12:45:00',30.80,'card','approved'),
 (21,'2025-09-20 19:40:00',51.70,'online','approved'),
 (22,'2025-09-21 08:15:00',16.50,'card','approved'),
 (23,'2025-09-21 13:10:00',32.78,'card','approved'),
 (24,'2025-09-21 15:30:00',18.70,'card','approved'),
 (25,'2025-09-21 18:50:00',49.50,'online','approved'),
 (26,'2025-09-22 09:10:00',19.58,'card','approved'),
 (27,'2025-09-22 12:05:00',30.25,'card','approved'),
 (28,'2025-09-22 19:20:00',45.65,'online','approved'),
 (29,'2025-09-23 08:30:00',16.28,'card','approved'),
 (30,'2025-09-23 20:10:00',33.00,'card','approved');


-- =========================
-- ROSTER (same outlet rule; some staff do 2 shifts/day)
-- =========================
INSERT INTO ROSTER
  (Shift_ID, Staff_ID, Outlet_ID,
   Scheduled_Start_Time, Scheduled_End_Time,
   Actual_Start_Time,   Actual_End_Time,
   Role_On_Shift)
VALUES
  -- 2025-09-15 • OUTLET 1 • morning (Shift 1)
  (1, 1, 1, '2025-09-15 08:00:00','2025-09-15 14:00:00','2025-09-15 08:05:00','2025-09-15 13:50:00','Manager'),
  (1, 2, 1, '2025-09-15 08:00:00','2025-09-15 14:00:00','2025-09-15 08:03:00','2025-09-15 13:45:00','Chef'),
  (1, 3, 1, '2025-09-15 08:00:00','2025-09-15 14:00:00','2025-09-15 08:00:00','2025-09-15 13:40:00','Server'),
  (1, 4, 1, '2025-09-15 08:00:00','2025-09-15 14:00:00','2025-09-15 08:10:00','2025-09-15 13:55:00','Barista'),

  -- 2025-09-15 • OUTLET 1 • evening (Shift 2)
  (2, 1, 1, '2025-09-15 14:00:00','2025-09-15 22:00:00','2025-09-15 14:05:00','2025-09-15 21:50:00','Manager'),
  (2, 2, 1, '2025-09-15 14:00:00','2025-09-15 22:00:00','2025-09-15 14:10:00','2025-09-15 21:45:00','Chef'),
  (2, 3, 1, '2025-09-15 14:00:00','2025-09-15 22:00:00','2025-09-15 14:00:00','2025-09-15 21:35:00','Server'),
  (2, 4, 1, '2025-09-15 14:00:00','2025-09-15 22:00:00','2025-09-15 14:00:00','2025-09-15 21:40:00','Barista'),

  -- 2025-09-16 • OUTLET 2 • morning (Shift 9)
  (9,  5, 2, '2025-09-16 08:00:00','2025-09-16 14:00:00','2025-09-16 08:00:00','2025-09-16 14:00:00','Manager'),
  (9,  6, 2, '2025-09-16 08:00:00','2025-09-16 14:00:00','2025-09-16 08:02:00','2025-09-16 13:50:00','Chef'),
  (9,  7, 2, '2025-09-16 08:00:00','2025-09-16 14:00:00','2025-09-16 08:05:00','2025-09-16 13:45:00','Server'),
  (9,  8, 2, '2025-09-16 08:00:00','2025-09-16 14:00:00','2025-09-16 08:00:00','2025-09-16 13:42:00','Barista'),

  -- 2025-09-16 • OUTLET 2 • evening (Shift 10)
  (10, 5, 2, '2025-09-16 14:00:00','2025-09-16 22:00:00','2025-09-16 14:00:00','2025-09-16 22:00:00','Manager'),
  (10, 6, 2, '2025-09-16 14:00:00','2025-09-16 22:00:00','2025-09-16 14:07:00','2025-09-16 21:43:00','Chef'),
  (10, 7, 2, '2025-09-16 14:00:00','2025-09-16 22:00:00','2025-09-16 14:10:00','2025-09-16 21:45:00','Server'),
  (10, 8, 2, '2025-09-16 14:00:00','2025-09-16 22:00:00','2025-09-16 14:00:00','2025-09-16 21:50:00','Barista'),

  -- 2025-09-17 • OUTLET 3 • morning (Shift 17)
  (17, 9,  3, '2025-09-17 08:00:00','2025-09-17 14:00:00','2025-09-17 08:00:00','2025-09-17 13:40:00','Manager'),
  (17, 10, 3, '2025-09-17 08:00:00','2025-09-17 14:00:00','2025-09-17 08:09:00','2025-09-17 13:50:00','Chef'),
  (17, 11, 3, '2025-09-17 08:00:00','2025-09-17 14:00:00','2025-09-17 08:05:00','2025-09-17 13:35:00','Server'),
  (17, 12, 3, '2025-09-17 08:00:00','2025-09-17 14:00:00','2025-09-17 08:00:00','2025-09-17 13:54:00','Barista'),

  -- 2025-09-17 • OUTLET 3 • evening (Shift 18)
  (18, 9,  3, '2025-09-17 14:00:00','2025-09-17 22:00:00','2025-09-17 14:05:00','2025-09-17 21:45:00','Manager'),
  (18, 10, 3, '2025-09-17 14:00:00','2025-09-17 22:00:00','2025-09-17 14:00:00','2025-09-17 21:42:00','Chef'),
  (18, 11, 3, '2025-09-17 14:00:00','2025-09-17 22:00:00','2025-09-17 14:00:00','2025-09-17 21:35:00','Server'),
  (18, 12, 3, '2025-09-17 14:00:00','2025-09-17 22:00:00','2025-09-17 14:10:00','2025-09-17 21:58:00','Barista');



