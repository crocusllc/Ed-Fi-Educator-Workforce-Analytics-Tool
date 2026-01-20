_**Integrating Apache Superset dashboards with a specific security framework is implementation specific.  Details and implementation steps will depend largely on requirements of the identity provider being used.  The approaches below provide a generic guide on how security needs can be handled.**_

# Implementing Row Level Security using SuperSet
SuperSet supports Row Level Security out of the box by leveraging [Jinja Templating](https://superset.apache.org/docs/configuration/sql-templating), the same plugin framework that enables dynamic dashboard dataset manipulation.  The following instructions show how to set up row level security based on assigned user role and email address of the user. 

There are two basic approaches:  Static Filtering and Dynamic Filtering, both of which rely on the user's email address.  More advanced SSO integration that leverage attributes, such as Department or District maintained by the Identity provider, is briefly outlined as an alternative approach, as it is much more complex and requires some custom development.

## Static Filter Approach
### Step 1:  Set Up Jinja Config Files in Superset
Before implementing any RLS, you must enable Jinja templating in your `superset_config.py`. It is not enabled by default for security reasons.

~~~
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "ROW_LEVEL_SECURITY": True
}
~~~
### Step 2:  Create New Roles as required for Dashboards
For the EW Dashboards, there are two basic roles envisioned.  County - can see all data, and District - can only see data for their district.  Row level security will only apply to the District role.  
Instructions:
1. Go to Settings -> List Roles, add a new role called District.
2. Go to Settings -> List Users, ensure that all district level users are added to only this role. 
3. Add those users to the standard Gamma group as well.  For overview of out-of-the-box roles, see bottom of this tutorial. 


### Step 3:  Add new Row Level Security Role
1. Go to Settings -> Row Level Security.
2. Click + Add Rule.  Add a rule name. e.g. "Sacramento Unified Users"
3. Tables: Select the datasets you want to secure.  For this implementation, select the three basic views  - vw_student, vw_staff, vw_VacancyData - as well as the dynamic data sets - RetentionOverTimeByDimension, RetentionOverTimeByDimension-District, RetentionSummaryByDimension, RetentionSummaryByDimension-District.
4. Roles: Select the District role previously added.
5. Group Key:  This can be optionally used to aggregate several rules for an additional grouping layer.  It can be left blank for this implementation. 
6. Clause:  Add the SQL expression that will be added into the WHERE clause for specified data sets.  Dashboard will be limited to rows for which this clause returns TRUE.  Use the current_user_email() MACRO gets the active user's email address to drive data access. It is important that this statement matches the District name that is stored in the data set.  In the example below, the SQL statement checks the domain of the user email and returns the appropriate district name.
SQL
~~~
CASE 
  WHEN SUBSTRING('{{ current_user_email() }}', CHARINDEX('@', '{{ current_user_email() }}') + 1, LEN('{{ current_user_email() }}')) = crocusllc.com THEN 'Sacramento City Unified School District'
  WHEN  SUBSTRING('{{ current_user_email() }}', CHARINDEX('@', '{{ current_user_email() }}') + 1, LEN('{{ current_user_email() }}')) = edfi.org THEN 'Elk Grove Unified'
END = District
~~~
Note: Single quotes are crucial around the Jinja tag.  Be sure to replace sample domains with the actual domains used by each district.

## Dynamic Filter Approach
This is the more common approach when dealing with a significant number of dashboard users.  It handles row-level data access dynamically through a mapping table.

### Step 1: Create the Mapping Table
It is recommended that this table live in the same database that hosts view data.
```
CREATE TABLE user_district_mapping (
    user_email VARCHAR(255),
    district_id VARCHAR(50),
    -- Critical for performance:
    INDEX idx_user_email (user_email)
);

-- Example Data
INSERT INTO user_district_mapping (user_email, district_id)
VALUES 
('john.doe@company.com', 'District_A'),
('john.doe@company.com', 'District_B'), -- User can have multiple rows
('jane.smith@company.com', 'District_A');
```
### Step 2: Define the RLS Rule in Superset
1. Navigate to Settings -> Row Level Security.
2. Click + Add Rule.
3. Tables: Select your main dataset (e.g., sales_data).
4. Clause: Enter the following SQL/Jinja snippet.

```
district_id IN (
    SELECT district_id 
    FROM user_district_mapping 
    WHERE LOWER(user_email) = LOWER('{{ current_user_email() }}')
)
```
**NOTE:**  Use of the LOWER function handles inconsistent capitalization from identity providers like Microsoft.

### Step 3: Optionally define Superuser access
If you have an Admin who needs to see all districts, the standard rule above will block them unless you add rows for them for every single district. Add a logic branch in your SQL. Create a role in Superset called Super_Viewer and assign it to admins. Then update the RLS clause:

```
(
    -- If the user is a super admin, allow 1=1 (True)
    'Super_Viewer' IN ( '{{ current_user_roles() | join("', '") }}' )
    OR
    --Otherwise, check the mapping table
    district_id IN (
        SELECT district_id 
        FROM user_district_mapping 
        WHERE LOWER(user_email) = LOWER('{{ current_user_email() }}')
    )
)
```

## If Role information is Maintained by Identity Provider - such as Microsoft SSO
In the case where role information such as district membership or specific role must be stored by the identity provider, RLS implementation becomes more complex, because Superset's default SSO behavior only syncs basic info (User, Email).  To get custom claims (like department or groups) from the Microsoft token into your RLS, you must "intercept" the login process using a Custom Security Manager.

At a high level, these are the steps that will need to be taken:
1. Create a Custom Security Manager Create a file named custom_sso_security_manager.py in your PYTHONPATH (same folder as superset_config.py).
2. Register the Jinja Context Processor Now, you need to tell Superset how to read that session variable inside an SQL query. Edit your superset_config.py
3. Implement the Advanced RLS Rule Now you can use your custom macro in the RLS UI.

### Reference for Advanced SSO integration
* [https://github.com/apache/superset/discussions/34542](https://github.com/apache/superset/discussions/34542)
  * Discussion with examples of how to do the implementation
* [https://superset.apache.org/docs/configuration/sql-templating/#adding-your-own-jinja-context)](https://superset.apache.org/docs/configuration/sql-templating/#adding-your-own-jinja-context)
  * Documentation on how to set up Jinja templating
* [https://superset.apache.org/docs/configuration/configuring-superset/#custom-security-manager](https://superset.apache.org/docs/configuration/configuring-superset/#custom-security-manager)
  * How to configure the custom security manager
* [https://flask.palletsprojects.com/en/stable/quickstart/#sessions](https://flask.palletsprojects.com/en/stable/quickstart/#sessions)
  * This documentation is useful for understanding the session object limits and behavior in flask, needed to manage sessions.

## Overview of Superset Out-of-The Box roles

* **Admin**
    * **Description:** The "superuser" of the platform. Admins have unrestricted access to all features, data sources, and settings. They are the only users who can manage user accounts, assign roles, and alter permissions.
    * **Audience:** System administrators, DevOps engineers, or the Head of Data Governance responsible for maintaining the Superset instance.

* **Alpha**
    * **Description:** The "creator" role. Alpha users have access to all data sources and can create, modify, and delete their own charts and dashboards. However, they cannot manage other users or grant access permissions.
    * **Audience:** Power users, data analysts, and workspace leads who build and publish content for the rest of the organization.

* **Gamma**
    * **Description:** The "consumer" role. Gamma users have limited, read-only access. They can only view dashboards and charts backed by data sources they have been explicitly granted access to. They generally cannot browse the full catalog of data.
    * **Audience:** Business executives, external clients, and general stakeholders who strictly need to view reports without editing them.

* **sql_lab**
    * **Description:** An additive role that grants access to the SQL Lab IDE. This allows a user to run raw SQL queries directly against the database. It is often assigned *in addition* to the Alpha or Gamma roles.
    * **Audience:** Data scientists, engineers, and technical analysts who need to validate data or perform complex ad-hoc analysis using raw SQL.


