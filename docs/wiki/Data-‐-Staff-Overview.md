## Staff View

The Staff view feeds the Essential Question 2 (EQ 2\) and Essential Question 3 (EQ 3\) use cases. Essential Question 2 asks:  *Are there assignments of educators that are connected to higher retention?*  Essential Question 3 asks:  *How do educator (including newly hired) counts and characteristics vary across campuses/districts?*

### **Prerequisites for Ed-Fi Data Standard** 

Both of these essential questions leverage  staff and staff-school association data.  The edfi.Staff table serves as the base table for staff, with supporting staff characteristics, such as *Name, Date of Birt*h, and *Years of Experience*.  While *Date of Birth* may be considered sensitive identifying information, it is necessary for these dashboards, as it is used to calculate the "Near Retirement" flag.   

Additionally, you must ensure that all descriptor values used by your district are loaded into the platform.

**Special Considerations**

* Both StaffUniqueId and StaffUSI are present in Ed-Fi tables.  StaffUSI should be used for the unique staff identifier across tables.  
* The “Near Retirement" flag is not taken directly from loaded data but is calculated based on staff age in a given academic year using the edfi.Staff.DateofBirth field. It is thrown when staff is at or above age 56\. This age has been set based on demo data; this should be adjusted to meet local context.  
* The “New Hire” flag is thrown in the academic year for which a staff is first assigned to an educational organization.  
* Regardless of the amount of historical staff data that is loaded, views will limit data displayed to 10 years.  
* Since historical school year session data may not always be available in district datasets, school years are assumed to begin in August for the purpose of the demo version.

The tables below provide details about what data needs to be loaded into the Ed-Fi ODS.

## Source Tables

| Table | Purpose |
| :---- | :---- |
| \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\] | Base table for All staff EdOrg Associations. |
| \[edfi\].\[Staff\] | Base table for staff details. |
| \[edfi\].\[School\] | Used to associate schools to districts. |
| \[edfi\].\[StaffRace\] | Used to get Staff Race.  Staff with more than one race should be loaded into this table for each associated race and will be displayed as Multiracial in the dashboards. |
| \[edfi\].\[EducationOrganization\] | Used for EdOrg Details. |
| \[edfi\].\[SchoolCategory\] | Use to get school category info. |
| \[edfi\].\[StaffSchoolAssociationAcademicSubject\] | Used to get academic subject of staff assignment. |
| \[edfi\].\[StaffCredential\] | Used to get association between staff and credential. |
| \[edfi\].\[Credential\] | Base Credentials table. |
| \[edfi\].\[EducationOrganizationAddress\] | Used to get Lat/Log for Education Organizations (Schools and District locations) |
| \[edfi\].\[Descriptor\] | Used to get values for various descriptor codes. |

## Data Elements

| Data Element | Definition | Ed-Fi Mapping | Logic/Notes |
| :---- | :---- | :---- | :---- |
| TeacherID | Staff ID | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\] | None |
| SchoolYear | School Year during which Staff was associated with and EdOrg | Derived from \[edfi\].\[BeginDate\] and \[edfi\].\[EndDate\] | Calculated value that populates a row for each year between begin data and end date. If BeginDate Month is on or after July, then associate with a new school year (set based on demo data; adjust for local context) |
| BeginDate | Date on which staff was assigned to EdOrg | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\] | None |
| EducationOrganizationId | Identifier of associated EdOrg | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\] | None |
| EndDate | Date on which staff assignment to EdOrg ended | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\] | none |
| StaffAssignmentType | Staff Assignment classification: e.g. Teacher, Superintendent | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\].\[StaffClassificationDescriptorId\] | None |
| AssignmentSubjectCategory | Subject that staff is assigned to:  e.g. Math, English | \[edfi\].\[StaffSchoolAssociationAcademicSubject\] | None |
| CredentialType | Staff Credential Type:  e.g. Regular/Standard, Emergency | \[edfi\].\[Credential\]=\>\[StaffCredential\] | None |
| Campus | Name of assigned School | \[edfi\].\[EducationOrganization\] | For District level staff, gets name directly from EdOrg otherwise through School. |
| SchoolId | ID of assigned School | \[edfi\].\[EducationOrganization\] | None |
| SchoolLat | School latitude | \[edfi\].\[EducationOrganizationAddress\] | None |
| SchoolLong | School longitude | \[edfi\].\[EducationOrganizationAddress\] | None |
| SchoolSegment | School Segment: e.g. High School | \[edfi\].\[SchoolCategory\] | None |
| District | Name of assigned district | \[edfi\].\[EducationOrganization\] | For District level staff, gets name directly from EdOrg otherwise through School. |
| LEAId | Id of assigned district | \[edfi\].\[EducationOrganization\] | For District level staff, gets id directly from EdOrg otherwise through School. |
| LeaLat | District latitude | \[edfi\].\[EducationOrganizationAddress\] | For District level staff, gets address directly through EdOrg otherwise through School. |
| LeaLong | District longitude | \[edfi\].\[EducationOrganizationAddress\] | For District level staff, gets address directly through EdOrg otherwise through School. |
| RaceEthnic | Staff Race/Ethnicity | \[edfi\].\[StaffRace\] | \*Logic needs to be adjusted to handle multiple race assignments based on local need. |
| FirstName | First name of staff | \[edfi\].\[Staff\] | Included for testing, but consider removing. |
| LastSurname | Last name of staff | \[edfi\].\[Staff\] | Included for testing, but consider removing. |
| YearsOfPriorTeachingExperience | Number of Years teaching experience | \[edfi\].\[Staff\] | None |
| BirthDate | Staff Birthdate | \[edfi\].\[Staff\] | Used to validate NearRetirement calculation.  |
| NewHire | Flag that indicates whether given SchoolYear was first year of staff assignment at an EdOrg | \[edfi\].\[StaffEducationOrganizationAssignmentAssociation\].\[BeginDate\] | Returns "New Hire" when the BeginDate Year corresponds to the School year. |
| TenureStatus | Flag that indicates whether staff was "Near Retirement" for given SchoolYear | \[edfi\].\[Staff\].\[BirthDate\] | If staff was 57 or older at the start of a given school year, then return "Near Retirement" (set based on demo data; adjust for local context). |


