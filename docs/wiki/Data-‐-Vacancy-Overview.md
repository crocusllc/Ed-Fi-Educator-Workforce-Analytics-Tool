## Vacancy View

The Vacancy view feeds the Essential Question 1 (EQ 1\) use case providing insights into all open positions for a district and county.  Essential Question 1 states:  *How do educator vacancies vary across our district/county?*

### **Prerequisites for Ed-Fi Data Standard** 

The core data needed to answer this question comes from a list of vacancies loaded into the edfi.OpenStaffPosition table.  The view requires that an open staff position contains both a date posted and a date posting removed field.  The position closing date is essential for providing a comprehensive depiction of historical vacancy data.

Supplemental data, allowing for additional insights through on-dashboard filtering, includes the academic subject associated with each vacancy \- found in edfi.OpenStaffPositionAcademicSubject \- and the category of the school posting the vacancy, found in  edfi.SchoolCategory.

Additionally, you must ensure that all descriptor values used by your district are loaded into the platform.

### **Source Tables**

| Table | Purpose |
| :---- | :---- |
| \[edfi\].\[OpenStaffPosition\] | Base table for all vacancies. |
| \[edfi\].\[EducationOrganization\] | Provides name and characteristics of school and district. |
| \[edfi\].\[School\] | Provides lookup for school-district association. |
| \[edfi\].\[SchoolCategory\] | Provides school category (e.g. High School) |
| \[edfi\].\[OpenStaffPositionAcademicSubject\] | Provides academic subject of the associated open position. |
| \[edfi\].\[Descriptor\] | Used to get values for various descriptor codes. |

### 

### **Vacancy View Data Dictionary**

| Data Element | Definition | Ed-Fi Mapping | Logic/Notes |
| :---- | :---- | :---- | :---- |
| EducationOrganizationId | EdOrd posting the vacancy, from the OpenStaffPositions table. | \[edfi\].\[OpenStaffPosition\] | None |
| DatePosted | Date posted, from OpenStaffPositions table. | \[edfi\].\[OpenStaffPosition\] | None |
| DatePostingRemoved | Date on which listing was removed from OpenStaffPositions table. | \[edfi\].\[OpenStaffPosition\] | None |
| RequisitionNumber | Unique listing identifier, from OpenStaffPositions table. | \[edfi\].\[OpenStaffPosition\] | None |
| isPositionOpen | Flag for when a vacancy is currently open. | \[edfi\].\[OpenStaffPosition\].RequisitionNumber | Shows requisition number when posting removed is not null.  This allows for distinct counts when aggregating vacancies. |
| AssignmentCategory | Category of vacancy assignment. | \[edfi\].\[OpenStaffPositionAcademicSubject\] | None |
| AssignmentType | Type of assignment from OpenStaffPosition table. | \[edfi\].\[OpenStaffPosition\] | Using StaffClassificationDescriptorId. |
| Campus | Name of School. | \[edfi\].\[EducationOrganization\] | Field \= \[NameOfInstitution\] |
| Segment | Classification of school from SchoolCategory table. | \[edfi\].\[SchoolCategory\] | None |
| SchoolId | EdOrgId for the School. | \[edfi\].\[EducationOrganization\] | None |
| District | Name of the District. | \[edfi\].\[EducationOrganization\] | If vacancy listing is at the district level, then district name is the district name.  If the vacancy is school level, then use the school name. |
| LEAId | EdOrdId of the district. | \[edfi\].\[EducationOrganization\] | If vacancy listing is at the district level, then district Id.  If the vacancy is school level, then use school id. |
| SchoolYear | School year of vacancy. | \[edfi\].\[OpenStaffPosition\] | Format 'YYYY-YYYY' calculated based on DatePosted, with July as cutoff month (cut off month is set based on demo data; adjust for local context). |
| InitialSessionName | Name of the session of DatePosted. | \[edfi\].\[OpenStaffPosition\] | Assigns vacancy to a month of the year |
| InitialSessionOrder | Order of the session of DatePosted. | \[edfi\].\[OpenStaffPosition\] | Same as above, but used to define order of months. |
| LastRefreshed | Most Recent Update date. | \[edfi\].\[OpenStaffPosition\] | Uses Last Modified field. |


