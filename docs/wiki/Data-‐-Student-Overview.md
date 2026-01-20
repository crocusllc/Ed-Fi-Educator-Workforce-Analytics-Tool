## Student View

The Student view is used to support the Essential Question 3 (EQ 3\) Dashboard.  Essential Question 3 states:  *How do educators (including newly hired) counts and characteristics vary across districts/campuses?*.  In EQ 3, student data is used in just a single chart to compare student race/ethnicity breakdown to staff breakdown.

### **Prerequisites for Ed-Fi Data Standard** 

The primary data required to support the insights provided in the dashboard are students, student race, and student enrollment. Student data can be found in the edfi.Student table. Race information can be found in the edfi.StudentEducationOrganizationAssociationRace table. Note: Students can have more than one race (signified by more than one row per student in the edfi.StudentEducationOrganizationAssociationRace table), these students will be categorized as multiracial by the view. Student enrollment determines the geographic breakdown and can be found in the edfi.StudentSchoolAssociation table

Additionally, you must ensure that all descriptor values used by your district are loaded into the platform.

## Source Tables

| Table | Purpose |
| :---- | :---- |
| \[edfi\].\[StudentSchoolAssociation\] | Base table for all student associations. |
| \[edfi\].\[Student\] | Base table for student details. |
| \[edfi\].\[School\] | Used to associate schools to districts. |
| \[edfi\].\[EducationOrganization\] | Used for education organization details. |
| \[edfi\].\[StudentEducationOrganizationAssociationRace\] | Used to get student race.  A student race association should be loaded into this table for each race with which they are associated. |
| \[edfi\].\[Descriptor\] | Used to get values for various descriptor codes. |

## 

## Data Elements

| Data Element | Definition | Ed-Fi Mapping | Logic/Notes |
| :---- | :---- | :---- | :---- |
| StudentID | Student unique identifier | \[edfi\].\[Student\] | None |
| SchoolYear | School year during which student was associated with a school | \[edfi\].\[StudentSchoolAssociation\] derived \[EntryDate\] and \[ExitWithdrawDate\] | Calculated value that populates a row for each year between entry and exit dates. If entry date month is on or after July, then associate with a new school year (School year set based on demo data; adjust for local context). |
| FirstName | Student first name | \[edfi\].\[Student\] | none |
| LastName | Student last name | \[edfi\].\[Student\] | none |
| EntryDate | Date on which student was first associated with a school | \[edfi\].\[StudentSchoolAssociation\] | none |
| ExitWithdrawDate | Date on which student was last associated with a school | \[edfi\].\[StudentSchoolAssociation\] | none |
| Campus | Name of assigned school | \[edfi\].\[EducationOrganization\] | none |
| SchoolId | ID of assigned school | \[edfi\].\[EducationOrganization\] | none |
| District | Name of assigned district | \[edfi\].\[EducationOrganization\] | none |
| LEAId | Id of assigned district | \[edfi\].\[EducationOrganization\] | none |
| RaceEthnic | Race of assigned student | \[edfi\].\[StudentEducationOrganizationAssociationRace\] | Students with more than one race will be categorized as multiracial. |


