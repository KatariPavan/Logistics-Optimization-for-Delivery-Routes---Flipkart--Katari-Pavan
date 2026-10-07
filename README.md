Logistics & Delivery Analytics | PostgreSQL

- Cleaned and validated logistics data by identifying duplicate Order IDs, handling route-level missing traffic-delay values,
  standardizing date formats, and flagging invalid delivery dates.
- Analyzed delivery performance by calculating order-level delay days, identifying the "Top 10 delayed routes", and
  ranking orders by delivery delay within warehouses using SQL window functions.
- Evaluated route efficiency using "average delivery time, traffic delay, and Distance-to-Time Efficiency Ratio",
  identifying inefficient routes and routes with **>20% delayed shipments** for optimization.
- Assessed warehouse performance by comparing processing times against the global average, analyzing total vs. delayed shipments,
  and ranking warehouses based on on-time delivery performance using CTEs and window functions.
- Evaluated delivery-agent performance by ranking agents per route based on on-time delivery %, identifying agents
  below the 80% on-time threshold, and comparing average speeds of top- and bottom-performing agents.
- Analyzed shipment tracking data to identify last checkpoints, common delay reasons, and
  orders with "more than two delayed checkpoints".
- Developed SQL-based operational KPIs including "Average Delivery Delay by Region, On-Time Delivery %, and
  Average Traffic Delay by Route" to support data-driven logistics and workload optimization.
