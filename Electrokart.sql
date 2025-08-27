select * from electrokart;
--Customer Retention Rate – Find the % of customers who have made repeat purchases.
select 
    round(
        count(distinct case when order_count > 1 then customer_id end) * 100.0 /
        count(distinct customer_id),
    2
    ) as retention_rate from (select customer_id, count(order_id) as order_count
    from electrokart
    group by customer_id
);

--Region vs Churn – Check if churn is higher in certain Regions.
select 
    region, round(sum(churn_flag) * 100.0 / count(distinct customer_id), 2) as churn_rate_percentage
from (
    select region, customer_id, max(customer_churn) as churn_flag
    from electrokart
    group by region, customer_id
) group by region;

--Category-Wise Profit – Total profit by Product_Category.
select round(sum((unit_price*units_sold)*(1-discount_percent/100)-(cost_price*units_sold)),2)
as category_revenue, product_category from electrokart group by product_category ;

--High-Value Lost Customers – List churned customers who spent more than ₹50,000 in total.
select customer_id, total_spend from( 
select customer_id, max(customer_churn) as churn_flag, round(sum((unit_price*units_sold)*(1-(discount_percent/100))),2) as total_spend
from electrokart group by customer_id) 
where churn_flag=1 and total_spend>50000

--First-Time Buyer Conversion – How many New customers became Returning in the dataset?
select count(customer_id) as repeating_customers from 
(select count(order_id) as cnt, customer_id, min(customer_churn) as churned from electrokart group by customer_id)
where cnt>1 and churned=0;

--Top 5 Products by Revenue – Based on (Unit_Price * Units_Sold) - (Discount_Percent%)
select round(sum((unit_price*units_sold)*(1-(discount_percent/100)))
over (partition by product_category),2) as category_sales, product_id, product_category
from electrokart order by category_sales desc limit 5;

--Monthly Sales Trend – Total sales per month in 2024.
select extract (year from order_date) as order_year, to_char (order_date, 'Month') as month,
round(sum((unit_price*units_sold)*(1-(discount_percent/100))),2) as revenue from electrokart group by 
to_char (order_date, 'Month'), extract (year from order_date), extract (month from order_date) order by extract (month from order_date) ;

--Churn Prediction Signals 
with high_returns as (select customer_id, 'high_return' as reason from electrokart 
group by customer_id having count (case when returned = 'Yes' then 1 end)::FLOAT / count(*) > 0.3),
inactive as (select customer_id, 'inactive' as reason from electrokart group by customer_id 
having max(order_date) < (select max(order_date) from electrokart) - interval '90 days')
select customer_id, string_agg(reason, ' + ') as risk_factors  
from (select * from high_returns union select * from inactive) group by customer_id;

--Seasonality Analysis – Which months see the highest revenue for each category?
with monthly_total as (select round(sum((unit_price * units_sold) * (1 - discount_percent/100)), 2) as revenue_total, product_category,
to_char(order_date, 'month') as month from electrokart 
group by product_category, to_char(order_date, 'month')), 
monthly_category as (select dense_rank() over (partition by product_category order by revenue_total desc) as drnk, * from monthly_total)
select product_category, month as "mostly sold in the month of" from monthly_category where drnk=1 
    
--Cross Sell Opportunity (which products are usually bought together by customers)
with customer_category as (
    select distinct customer_id, product_category
    from electrokart
),
ranked_categories as (select cc.product_category AS base_category, cp.product_category as other_category,
count(distinct cc.customer_id) as customer_count, row_number() over (partition by cc.product_category
order by  count (distinct cc.customer_id) desc
) as rn from customer_category cc join customer_category cp on cc.customer_id = cp.customer_id and cc.product_category <> cp.product_category
group by cc.product_category, cp.product_category)
select base_category, other_category from ranked_categories where rn = 1 order by base_category;


