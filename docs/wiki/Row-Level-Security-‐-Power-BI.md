_**Integrating PowerBI dashboards with a specific security framework is implementation specific.  Details and implementation steps will depend largely on requirements of the identity provider being used.  The approaches below provide a generic guide on how security needs can be handled.**_
# Static Filter Approach
This approach relies on out of the box configuration of the Dashboards using the Manage Roles feature.  It is easy to set up, but not scalable for large numbers of users.  

### In PowerBI Desktop
1. Modeling tab => Manage Roles.
2. Add one role for County and one role for each district represented in the data set
3. The County role will have no filters applied as county users have access to all data.
4. For each District Role, add a filter that sets the field LEAId equal to the ID for that district.  For example, the role name given to a District called Elk Grove Unified, would be "ElkGrove".  For that role, add a filter, where the value for Column is LEAId, condition is "Equals" and the in the Value field, enter the actual ID for Elk Grove Unified.  Add this filter for all three views:  vw_Staff, vw_Student, vw_VacancyData.  Repeat the process for all districts covered in the data set.
5. Test the Roles by using Modelling Tab =>View As. Select the role you with to test and verify that only data for that district displays in the dashboard.
6. Publish the file to the PowerBI desired workspace.

### In PowerBI online.  
1. Login to your PowerBI instance
2. Go to Workspaces=>Your Workspace
3. For the Semantic Model associated with your dashboard, open Security settings and manually add users to desired groups.  Those users will now have access only to assigned data.


# Dynamic filter Approach
This section outlines the standard procedure for implementing dynamic Row Level Security (RLS) in Power BI. This architecture leverages Microsoft Authentication (Entra ID/Azure AD) to filter data dynamically based on the authenticated user's identity.  Setup is more involved, but the burden of managing access for large numbers of users within PowerBI is alleviated.

Instead of creating static roles for every data segment, use a single dynamic role. This role utilizes the `USERPRINCIPALNAME()` DAX function to filter a security bridge table, which then propagates filters to the views through an intermediary district table.

## Data Model Overview

To support dynamic filtering, incorporate a dedicated **Security Bridge Table** into the semantic model.

### The Security Table (`UserDistrictMapping`)
This table links an authenticated user's email address to the specific data attributes (Districts) they are permitted to view.

**Required Schema:**

| UserEmail | DistrictID |
| :--- | :--- |
| user.one@org.com | D-101 |
| user.two@org.com | D-102 |
| user.three@org.com | D-101 |
| user.three@org.com | D-102 |

> **Note:** Establish a Many-to-Many relationship between users and districts (one user may manage multiple districts) by allowing multiple rows per `UserEmail`.

Because data supporting the dashboards is brought into PowerBI using three flattened views, each with District data, an additional DistrictDimension table has to be used to pass through the dynamic filter.

This table is created using the following code:
```
DistrictDimension = DISTINCT(
    UNION(
        VALUES('vw_Staff'[LEAId]),
        VALUES('vw_Student'[LEAId]),
        VALUES('vw_VacancyData'[LEAId])
    )
)
```

## Implementation Steps

### Step 1: Configure Relationships
Proper relationship configuration ensures the security filter propagates correctly from the bridge table to the district data.  Table relationships can be managed from Model View => Manage Relationships

1.  Create a relationship between `UserDistrictMapping` (Security Table) and `DistrictDimension` (Dimension Table) on the `DistrictID` column.  The relationship should be **many-to-one** (Many users to one district).
2.  Set the **Cross-filter direction** to **Both**.
3.  Check the option **Apply security filter in both directions**.
4. Create relationships between the `DistrictDimension` table and each of the three views.  The relationship should be  **one-to-many** (One district to many facts about that district).
5. Set the  **Cross-Filter direction** to **Single**.


### Step 2: Define the Security Role
Define the RLS role within Power BI Desktop using DAX.

1.  Navigate to the **Modeling** ribbon and select **Manage Roles**.
2.  Create a new role named `DynamicSecurity`.
3.  Select the **UserDistrictMapping** table.
4.  Input the following DAX expression:

```dax
[UserEmail] = USERPRINCIPALNAME()
```

> **Note:** Use `USERPRINCIPALNAME()` to return the UPN (User Principal Name) in the `email@domain.com` format. Avoid `USERNAME()`, as it may return `DOMAIN\User`, causing mismatches with the Power BI Service.

### Step 3: Administrative Override Pattern (Optional)
To grant specific administrators full visibility without explicit entries in the mapping table, use the following logic:

```dax
[UserEmail] = USERPRINCIPALNAME() || 
USERPRINCIPALNAME() = "admin@org.com"
```

### Step 4. Service Deployment and Configuration

After configuring the RLS logic within the `.pbix` file, enforce the logic in the Power BI Service after publishing.

1.  Publish the report to the designated Workspace.
2.  Navigate to the **Dataset** (Semantic Model) security settings.
3.  Locate the `DynamicSecurity` role.
4.  Assign broad **Security Groups** (e.g., "All Staff" or "District Managers") rather than individual emails.
5.  Validate the logic using the "Test as role" feature in the Service.

**Logic:** Assigning a broad group ensures all users pass through the RLS logic. Users present in the Security Group but missing from the `UserDistrictMapping` table will view blank visuals, preserving data security.

## Official References

For further reading and validation of these patterns, refer to the following Microsoft documentation.

* **[Row-level security (RLS) with Power BI](https://learn.microsoft.com/en-us/power-bi/enterprise/service-admin-rls)**
    * The core documentation covering the end-to-end process: defining roles in Desktop, validating them, and managing membership in the Power BI Service.

* **[Row-level security (RLS) guidance in Power BI Desktop](https://learn.microsoft.com/en-us/power-bi/guidance/rls-guidance)**
    * Best practices for data modeling with RLS. This article specifically details the "Security Bridge Table" pattern used in this guide to handle Many-to-Many user mappings efficiently.

* **[USERPRINCIPALNAME function (DAX)](https://learn.microsoft.com/en-us/dax/userprincipalname-function-dax)**
    * Technical syntax reference for the DAX function used to retrieve the authenticated user's credentials.

* **[Dynamic Row Level Security with Power BI (Video)](https://learn.microsoft.com/en-us/shows/power-bi-security/dynamic-row-level-security-with-power-bi)**
    * A video walkthrough from the Microsoft Power BI team demonstrating the implementation of dynamic RLS patterns.