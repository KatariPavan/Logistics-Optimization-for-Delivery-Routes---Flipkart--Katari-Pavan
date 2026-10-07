-- Creating Tables--

Create table order_table(
Order_ID varchar(25),
Warehouse_ID varchar(25),
Route_ID varchar(25),
Agent_ID varchar(25),
Order_date date,
Expected_delivery_date date,
Actual_delivery_date date,
status varchar(25),
order_value decimal (12,2)
);

Create table route_table(
Route_ID varchar(25),
start_location varchar(25),
end_location varchar(25),
distance_km int,
Avg_travel_time_min int,
traffic_delay_min int
);


create table deliveryAgents_table(
Agent_ID varchar(25),
Agent_name varchar(25),
Route_ID varchar(25),
Avg_speed_kmph decimal (12,2),
on_time_delivery_percentage decimal(12,2),
experience_years decimal(12,2)
);

create table shipmenttracking(
tracking_id varchar(25),
Order_ID varchar(25),
checkpoint varchar(25),
checkpoint_time TIMESTAMP,
delay_reason varchar(25),
delay_minutes int
);

create table warehouse(
warehouse_id varchar(25),
warehouse_name varchar(50),
city varchar(25),
processing_capacity int,
avg_processing_time_min int
);

select * from warehouse;
select * from shipmenttracking;
select * from deliveryAgents_table;
select * from route_table;
select * from order_table;

--Task 1: Data Cleaning & Preparation
--Identify and delete duplicate Order_ID records.
begin;
SELECT 
    Order_ID,
    COUNT(*) AS duplicate_count
FROM order_table
GROUP BY Order_ID
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

DELETE FROM order_table
WHERE Order_ID NOT IN (
    SELECT MIN(Order_ID)
    FROM order_table
    GROUP BY Order_ID
);

commit;

--Replace null Traffic_Delay_Min with the average delay for that route.
UPDATE route_table rt
SET Traffic_Delay_Min = (
    SELECT AVG(t2.Traffic_Delay_Min)
    FROM route_table t2
    WHERE t2.Route_ID = rt.Route_ID
      AND t2.Traffic_Delay_Min IS NOT NULL
)
WHERE Traffic_Delay_Min IS NULL;
--Verfying the output
SELECT Route_ID, Traffic_Delay_Min
FROM route_table
WHERE Traffic_Delay_Min IS NULL;

--Convert all date columns into YYYY-MM-DD format using SQL functions.
UPDATE order_table
SET 
    Order_date = CAST(Order_date AS DATE),
    Expected_delivery_date = CAST(Expected_delivery_date AS DATE),
    Actual_delivery_date = CAST(Actual_delivery_date AS DATE);

--Ensure that no Actual_Delivery_Date is before Order_Date (flag such records).
SELECT 
    Order_ID,
    Order_Date,
    Actual_Delivery_Date,
    CASE
        WHEN Actual_Delivery_Date < Order_Date THEN 'Invalid'
        ELSE 'Valid'
    END AS Delivery_Date_Flag
FROM order_table;

--Task 2: Delivery Delay Analysis
--Calculate delivery delay (in days) for each order
SELECT 
    Order_ID,
    Order_Date,
    Expected_Delivery_Date,
    Actual_Delivery_Date,
	Actual_Delivery_Date - Expected_Delivery_Date AS Delivery_Delay_Days
FROM order_table;

--Find Top 10 delayed routes based on average delay days.
SELECT ot.Route_ID, rt.start_location,rt.end_location,
		Round(AVG(ot.Actual_Delivery_Date - ot.Expected_Delivery_Date),2) as Avg_delay_days
FROM Order_table ot JOIN
	route_table rt ON ot.Route_ID = rt.Route_ID
WHERE ot.Actual_Delivery_Date IS NOT NULL	
GROUP BY ot.Route_ID,
		rt.start_location,
  	    rt.end_location
ORDER BY ot.Route_ID DESC
LIMIT 10;

--Use window functions to rank all orders by delay within each warehouse.
SELECT
    Order_ID,
    Warehouse_ID,
    Order_Date,
    Expected_Delivery_Date,
    Actual_Delivery_Date,
    Actual_Delivery_Date - Expected_Delivery_Date AS Delay_Days,
    RANK() OVER (
        PARTITION BY Warehouse_ID
        ORDER BY Actual_Delivery_Date - Expected_Delivery_Date DESC
    ) AS Delay_Rank_R,
	ROW_NUMBER() OVER (
    PARTITION BY Warehouse_ID
    ORDER BY Actual_Delivery_Date - Expected_Delivery_Date DESC
) AS Delay_Rank_Rn,
DENSE_RANK() OVER (
    PARTITION BY Warehouse_ID
    ORDER BY Actual_Delivery_Date - Expected_Delivery_Date DESC
) AS Delay_Rank_Dn
FROM Order_table
WHERE Actual_Delivery_Date IS NOT NULL;


--Task 3: Route Optimization Insights
--For each route, calculate:
select * from route_table;
--Average delivery time (in days)
select *, ROUND((Avg_travel_time_min/60)) as Avg_Delivery_Time_Days 
from route_table;

--Average traffic delay.
select Route_ID, Round(Avg(traffic_delay_min),2) as Avg_Traffic_Delay_min
from route_table
group by Route_ID;

--Distance-to-time efficiency ratio: Distance_KM / Average_Travel_Time_Min.
SELECT
    Route_ID,
    distance_km,
    Avg_travel_time_min,
    ROUND(
        Distance_KM / NULLIF(Avg_travel_time_min, 0),
        2
    ) AS Distance_Time_Efficiency_Ratio
FROM route_table;

--Identify 3 routes with the worst efficiency ratio.
SELECT
    Route_ID,
    distance_km,
    Avg_travel_time_min,
    ROUND(
        Distance_KM / NULLIF(Avg_travel_time_min, 0),
        2
    ) AS Distance_Time_Efficiency_Ratio,
	ROW_NUMBER() OVER(
	ORDER BY ROUND(
        Distance_KM / NULLIF(Avg_travel_time_min, 0),
        2 
    )ASC) as Worst_Efficiency_rank 
FROM route_table
limit 3 ;

--Find routes with >20% delayed shipments

SELECT
    Route_ID,
    COUNT(*) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE Actual_Delivery_Date::date > Expected_Delivery_Date::date
    ) AS Delayed_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE Actual_Delivery_Date::date > Expected_Delivery_Date::date
        ) * 100.0 / COUNT(*),
        2
    ) AS Delayed_Shipment_Percentage
FROM Order_table
WHERE Actual_Delivery_Date IS NOT NULL
GROUP BY Route_ID
HAVING
    COUNT(*) FILTER (
        WHERE Actual_Delivery_Date::date > Expected_Delivery_Date::date
    ) * 100.0 / COUNT(*) > 20
ORDER BY Delayed_Shipment_Percentage DESC;

--Recommend potential routes for optimization.
SELECT
    rt.Route_ID,
    rt.start_location,
    rt.end_location,
    ROUND(
        AVG(ot.Actual_Delivery_Date::date - ot.Order_Date::date),
        2
    ) AS Avg_Delivery_Time_Days,
    ROUND(
        AVG(rt.Traffic_Delay_Min),
        2
    ) AS Avg_Traffic_Delay_Min,
    ROUND(
        rt.Distance_KM / NULLIF(rt.Avg_Travel_Time_Min, 0),
        2
    ) AS Distance_Time_Efficiency,
    COUNT(*) AS Total_Shipments,
    COUNT(*) FILTER (
        WHERE ot.Actual_Delivery_Date::date >
              ot.Expected_Delivery_Date::date
    ) AS Delayed_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE ot.Actual_Delivery_Date::date >
                  ot.Expected_Delivery_Date::date
        ) * 100.0 / COUNT(*),
        2
    ) AS Delayed_Shipment_Percentage
FROM Order_table ot
JOIN route_table rt
    ON ot.Route_ID = rt.Route_ID

WHERE ot.Actual_Delivery_Date IS NOT NULL
GROUP BY
    rt.Route_ID,
    rt.start_location,
    rt.end_location,
    rt.Distance_KM,
    rt.Avg_Travel_Time_Min
HAVING
    COUNT(*) FILTER (
        WHERE ot.Actual_Delivery_Date::date >
              ot.Expected_Delivery_Date::date
    ) * 100.0 / COUNT(*) > 20
ORDER BY
    Delayed_Shipment_Percentage DESC,
    Avg_Traffic_Delay_Min DESC;

--Task 4: Warehouse Performance
--Find the top 3 warehouses with the highest average processing time.

SELECT Warehouse_ID, Warehouse_name,
avg_processing_time_min
FROM warehouse
ORDER BY avg_processing_time_min DESC
LIMIT 3;

SELECT * FROM warehouse
--Calculate total vs. delayed shipments for each warehouse.

SELECT W.Warehouse_ID,COUNT(OT.ORDER_ID) AS Total_orders,
COUNT(OT.*) FILTER (
        WHERE OT.Actual_Delivery_Date::date >
              OT.Expected_Delivery_Date::date
    ) AS Delayed_Shipments,
    ROUND(
        COUNT(*) FILTER (
            WHERE OT.Actual_Delivery_Date::date >
                  OT.Expected_Delivery_Date::date
        ) * 100.0 / COUNT(*),
        2
    ) AS Delayed_Shipment_Percentage
FROM ORDER_TABLE OT JOIN Warehouse W
ON W.Warehouse_ID = OT.Warehouse_ID
GROUP BY W.Warehouse_ID
Order by Delayed_Shipment_Percentage DESC;

--Use CTEs to find bottleneck warehouses where processing time > global average.

WITH warehouse_processing AS (
    SELECT
        Warehouse_ID,
        AVG(
            Expected_Delivery_Date::date - Order_Date::date
        ) AS Avg_Processing_Days
    FROM Order_table
    WHERE Expected_Delivery_Date IS NOT NULL
      AND Order_Date IS NOT NULL
    GROUP BY Warehouse_ID
),

global_average AS (
    SELECT
        AVG(Avg_Processing_Days) AS Global_Avg_Processing_Days
    FROM warehouse_processing
)

SELECT
    wp.Warehouse_ID,
    ROUND(wp.Avg_Processing_Days, 2) AS Avg_Processing_Days,
    ROUND(ga.Global_Avg_Processing_Days, 2) AS Global_Avg_Processing_Days,
    ROUND(
        wp.Avg_Processing_Days - ga.Global_Avg_Processing_Days,
        2
    ) AS Excess_Processing_Days
FROM warehouse_processing wp
CROSS JOIN global_average ga
WHERE wp.Avg_Processing_Days > ga.Global_Avg_Processing_Days
ORDER BY Excess_Processing_Days DESC;

--Rank warehouses based on on-time delivery percentage.
SELECT
    w.Warehouse_ID,
    w.warehouse_name,
    COUNT(ot.Order_ID) AS Total_orders,
    dat.on_time_delivery_percentage,
    DENSE_RANK() OVER (
        ORDER BY dat.on_time_delivery_percentage DESC
    ) AS Warehouse_Rank
FROM deliveryAgents_table dat
JOIN order_table ot
    ON dat.Route_ID = ot.Route_ID
JOIN warehouse w
    ON ot.Warehouse_ID = w.Warehouse_ID
GROUP BY
    w.Warehouse_ID,
    w.warehouse_name,
    dat.on_time_delivery_percentage
ORDER BY Warehouse_Rank;

--Task 5: Delivery Agent Performance
--Rank agents (per route) by on-time delivery percentage
SELECT agent_id, route_id,
DENSE_RANK() OVER(PARTITION BY (route_id) ORDER BY on_time_delivery_percentage) DESC
FROM deliveryAgents_table

--Find agents with on-time% < 80%
SELECT agent_id,agent_name,on_time_delivery_percentage
FROM deliveryAgents_table
WHERE on_time_delivery_percentage < 80.00
ORDER BY on_time_delivery_percentage DESC;

--Compare average speed of top 5 vs bottom 5 agents using subqueries.
SELECT
    top_avg_speed,
    bottom_avg_speed,
    ROUND(top_avg_speed - bottom_avg_speed, 2) AS Speed_Difference
FROM(   SELECT ROUND(AVG(Avg_speed_kmph), 2) AS top_avg_speed
    	FROM (SELECT Avg_speed_kmph
       		  FROM deliveryAgents_table
        	  ORDER BY Avg_speed_kmph DESC
           	  LIMIT 5
    ) top_agents) t
CROSS JOIN(
    SELECT ROUND(AVG(Avg_speed_kmph), 2) AS bottom_avg_speed
    FROM (
        SELECT Avg_speed_kmph
        FROM deliveryAgents_table
        ORDER BY Avg_speed_kmph ASC
        LIMIT 5
    ) bottom_agents) b;

--Suggest training or workload balancing strategies for low performers

--Task 6: Shipment Tracking Analytics
--For each order, list the last checkpoint and time.
SELECT * FROM
(SELECT Order_id, checkpoint as last_checkpoint, checkpoint_time,
DENSE_RANK() OVER(PARTITION BY (order_id) ORDER BY checkpoint_time DESC) AS rnk
FROM shipmenttracking) t
WHERE rnk = 1;

--Find the most common delay reasons (excluding None).
SELECT delay_reason, Count(delay_reason) AS common_delay_reasons FROM shipmenttracking
WHERE delay_reason <> 'None'
GROUP BY delay_reason
ORDER BY common_delay_reasons DESC
LIMIT 1;

--Identify orders with >2 delayed checkpoints
SELECT * FROM shipmenttracking

SELECT order_id, COUNT(checkpoint) AS delayed_checkpoints
FROM shipmenttracking
GROUP BY order_id
HAVING COUNT(checkpoint) >2;

--Task 7: Advanced KPI Reporting
--Calculate KPIs using SQL queries:
/* 
Average Delivery Delay per Region (Start_Location).
On-Time Delivery % = (Total On-Time Deliveries / Total Deliveries) * 100.
Average Traffic Delay per Route.
*/

SELECT
    rt.start_location AS Region,
    ROUND(AVG(
            ot.Actual_Delivery_Date::date
            - ot.Expected_Delivery_Date::date
        ),2) AS Avg_Delivery_Delay_Days,
	COUNT(ot.*) AS Total_Deliveries,
    COUNT(ot.*) FILTER (
        WHERE ot.Actual_Delivery_Date::date
              <= ot.Expected_Delivery_Date::date
    ) AS On_Time_Deliveries,
    ROUND(
        COUNT(ot.*) FILTER (
            WHERE ot.Actual_Delivery_Date::date
                  <= ot.Expected_Delivery_Date::date
        ) * 100.0 / COUNT(*),2) AS On_Time_Delivery_Percentage,
    rt.Route_ID,
    ROUND(AVG(rt.Traffic_Delay_Min),2) AS Avg_Traffic_Delay_Min

FROM order_table ot

JOIN route_table rt
    ON ot.Route_ID = rt.Route_ID

WHERE ot.Actual_Delivery_Date IS NOT NULL
  AND ot.Expected_Delivery_Date IS NOT NULL
  AND rt.Traffic_Delay_Min IS NOT NULL

GROUP BY
    rt.start_location,
    rt.Route_ID

ORDER BY
    Avg_Delivery_Delay_Days DESC,
    Avg_Traffic_Delay_Min DESC;




