set sql_mode=only_full_group_by;
SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
select * from members;
select * from menu;
select * from sales;

----------------------------------------------------------- Case Study Questions ---------------------------------------------------------------------------
-- 1. What is the total amount each customer spent at the restaurant?

select s.customer_id as "Customer ID", sum(m.price) as "Amount Spent" from sales s join menu m on s.product_id = m.product_id group by s.customer_id;

-- 2. How many days has each customer visited the restaurant?
select customer_id as "Customer ID", count(distinct order_date) from sales group by customer_id;

-- 3. What was the first item from the menu purchased by each customer?
select s.customer_id as "Customer ID",
	   min(s.order_date) as "Order Date",
       s.product_id as "Product ID",
       m.product_name as "Product Name"
from sales s join menu m on s.product_id = m.product_id group by s.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?

select s.product_id as Product_ID, m.product_name as Product_Name, count(s.product_id) as Item_Purchased_Count from sales s join menu m
on s.product_id = m.product_id group by s.product_id
order by count(s.product_id) desc limit 1;

-- 5. Which item was the most popular for each customer?
with CTE as (
	select
    m.Product_name as Product_Name,
    s.Customer_id as Customer_ID,
    count(s.order_date) as Orders,
    rank() over (partition by s.customer_id order by count(s.order_date) desc) as "rnk",
    row_number() over (partition by s.customer_id order by count(s.order_date) desc) as "rn"
    from sales s join menu m on s.product_id = m.product_id
    group by m.product_name, s.customer_id
)
select Product_Name, Customer_ID, Orders from CTE
where rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?
with cte as (
	select
    s.product_id as Product_ID,
    s.customer_id as Customer_ID,
    m.product_name as Product_Name,
    s.order_date as Order_Date,
    row_number() over (partition by s.customer_id order by s.order_date) as "rn"
    from sales s join members mm on s.customer_id = mm.customer_id
    join menu m on s.product_id = m.product_id
    where s.order_date >= mm.join_date
)
select Product_ID, Customer_ID, Product_Name, Order_Date from cte where rn = 1;

-- 7. Which item was purchased just before the customer became a member?

with cte as (
	select
    s.product_id as Product_ID,
    s.customer_id as Customer_ID,
    m.product_name as Product_Name,
    s.order_date as Order_Date,
    row_number() over (partition by s.customer_id order by s.order_date desc) as "rn",
    rank() over (partition by s.customer_id order by s.order_date desc) as "rnk"
    from sales s join members mm on s.customer_id = mm.customer_id
    join menu m on s.product_id = m.product_id
    where s.order_date < mm.join_date
)
select Customer_ID, Product_ID, Product_Name, Order_Date from cte
where rnk = 1;

-- 8. What is the total items and amount spent for each member before they became a member?

select 
s.Customer_id as Customer_ID,
count(s.product_id) as No_of_Items_Ordered,
sum(m.price)
from sales s join members mm on s.customer_id = mm.customer_id
join menu m on s.product_id = m.product_id
where s.order_date < mm.join_date
group by s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select s.Customer_id, sum(case when s.product_id = 1 then m.price * 20 else m.price * 10 end) as Points from sales s join menu m on s.product_id = m.product_id
where s.product_id = 1
group by s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - 
-- how many points do customer A and B have at the end of January?

select 
	s.customer_id,
	sum(case when order_date between mem.join_date and date_add(mem.join_date, interval 6 DAY) then m.price * 20
		when s.product_id = 1 then m.price * 20
		else m.price * 10 end) as Points
	from sales s join members mem on s.customer_id = mem.customer_id
    join menu m on s.product_id = m.product_id
    where month(s.order_date) = 1
    group by s.customer_id;
    
    
----------------------------------------------------------- Bonus Questions ---------------------------------------------------------------------------

-- Join All The Things

-- The following questions are related creating basic data tables that Danny and his team can use to quickly derive insights without needing to join the underlying tables using SQL.
-- Recreate the following table output using the available data:
--  customer_id	order_date	product_name	price	member
--  A	2021-01-01	curry	15	N
--  A	2021-01-01	sushi	10	N
--  A	2021-01-07	curry	15	Y
--  A	2021-01-10	ramen	12	Y
--  A	2021-01-11	ramen	12	Y
--  A	2021-01-11	ramen	12	Y
--  B	2021-01-01	curry	15	N
--  B	2021-01-02	curry	15	N
--  B	2021-01-04	sushi	10	N
--  B	2021-01-11	sushi	10	Y
--  B	2021-01-16	ramen	12	Y
--  B	2021-02-01	ramen	12	Y
--  C	2021-01-01	ramen	12	N
--  C	2021-01-01	ramen	12	N
--  C	2021-01-07	ramen	12	N

select 
s.Customer_id as Customer_ID,
s.Order_date as Order_date,
m.product_name as Product_Name,
m.price as Price,
(case when mem.join_date is null then "N"
when order_date < mem.join_date then "N"
else "Y" end) as Member
from sales s join menu m on s.product_id = m.product_id
left join members mem on s.customer_id = mem.customer_id
order by s.customer_id, s.order_date;

-- Rank All The Things
-- Danny also requires further information about the ranking of customer products, but he purposely does not need the ranking for non-member purchases
--  so he expects null ranking values for the records when customers are not yet part of the loyalty program.
-- customer_id	order_date	product_name	price	member	ranking
	-- A		2021-01-01	curry			15		N		null
	-- A		2021-01-01	sushi			10		N		null
	-- A		2021-01-07	curry			15		Y		1
	-- A		2021-01-10	ramen			12		Y		2
	-- A		2021-01-11	ramen			12		Y		3
	-- A		2021-01-11	ramen			12		Y		3
	-- B		2021-01-01	curry			15		N		null
	-- B		2021-01-02	curry			15		N		null
	-- B		2021-01-04	sushi			10		N		null
	-- B		2021-01-11	sushi			10		Y		1
	-- B		2021-01-16	ramen			12		Y		2
	-- B		2021-02-01	ramen			12		Y		3
	-- C		2021-01-01	ramen			12		N		null
	-- C		2021-01-01	ramen			12		N		null
	-- C		2021-01-07	ramen			12		N		null

select
s.Customer_id as Customer_ID,
s.Order_date as Order_date,
m.product_name as Product_Name,
m.price as Price,
(case when mem.join_date is null then "N"
when order_date < mem.join_date then "N"
else "Y" end) as Member,
(case when mem.join_date is null then "NULL"
when order_date < mem.join_date then "NULL"
else rank() over(partition by s.customer_id, (case when mem.join_date is null then "NULL"
when order_date < mem.join_date then "NULL"
else "Y" end) order by s.order_date) end) as Member
from sales s join menu m on s.product_id = m.product_id
left join members mem on s.customer_id = mem.customer_id
order by s.customer_id, s.order_date;