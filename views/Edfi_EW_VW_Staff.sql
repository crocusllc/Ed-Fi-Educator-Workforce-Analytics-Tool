CREATE VIEW vw_Staff AS
WITH SCHOOL_YEAR_NUMBERS AS (
    SELECT 0 AS YearOffset
    /*Staff Begin dates go back up to 40 years*/
    UNION ALL SELECT 1 
    UNION ALL SELECT 2  
    UNION ALL SELECT 3 
    UNION ALL SELECT 4 
    UNION ALL SELECT 5
    UNION ALL SELECT 6  
    UNION ALL SELECT 7 
    UNION ALL SELECT 8 
    UNION ALL SELECT 9
    UNION ALL SELECT 10
    UNION ALL SELECT 11 
    UNION ALL SELECT 12
    UNION ALL SELECT 13
    UNION ALL SELECT 14
    UNION ALL SELECT 15
    UNION ALL SELECT 16
    UNION ALL SELECT 17 
    UNION ALL SELECT 18
    UNION ALL SELECT 19
    UNION ALL SELECT 20
    UNION ALL SELECT 21
    UNION ALL SELECT 22
    UNION ALL SELECT 23
    UNION ALL SELECT 24
    UNION ALL SELECT 25
    UNION ALL SELECT 26
    UNION ALL SELECT 27
    UNION ALL SELECT 28
    UNION ALL SELECT 29
    UNION ALL SELECT 30
    UNION ALL SELECT 31
    UNION ALL SELECT 32
    UNION ALL SELECT 33
    UNION ALL SELECT 34
    UNION ALL SELECT 35
    UNION ALL SELECT 36
    UNION ALL SELECT 37
    UNION ALL SELECT 38
    UNION ALL SELECT 39
    UNION ALL SELECT 40
),

STAFF_ASSIGNMENT_BASE AS (
    -- Calculate the base assignment data with school year ranges
    SELECT
        t.StaffUSI AS TeacherID,
        t.BeginDate AS StartDate,
        CASE
            WHEN t.EndDate IS NULL THEN GETDATE()
            ELSE t.EndDate
        END AS EndDate,
        -- Calculate the start year of the school year based on StartDate (August 1st to July 31st)
        CASE
            WHEN MONTH(t.BeginDate) >= 6 THEN YEAR(t.BeginDate) --changing this to 6 from 8: hired in summer for comming school year.
            WHEN MONTH(t.BeginDate) <  6 THEN YEAR(t.BeginDate) - 1
            ELSE NULL
        END AS SchoolYearStart,
        -- Calculate the end year of the school year based on EndDate (August 1st to July 31st)
        --Ensure that the SchoolYearEnd field is never NULL by filling current Year.  
        CASE
            WHEN MONTH(t.EndDate) >= 8 AND t.EndDate is not null THEN YEAR(t.EndDate)
            WHEN MONTH(GETDATE()) >= 8 AND t.EndDate is null THEN YEAR(GETDATE())
            WHEN MONTH(t.EndDate) < 8 AND t.EndDate is not null THEN YEAR(t.EndDate)-1
            WHEN MONTH(GETDATE()) < 8 AND t.EndDate is null THEN YEAR(GETDATE())-1
        END AS SchoolYearEnd
    FROM
        [edfi].[StaffEducationOrganizationAssignmentAssociation] t


),

SCHOOL_YEARS_EXPANDED AS (
    -- Cross join with the numbers to create all school years for each assignment
    SELECT
        sab.TeacherID,
        sab.StartDate,
        sab.EndDate,
        sab.SchoolYearStart + syn.YearOffset as SchoolYearStart,
        sab.SchoolYearEnd
    FROM
        STAFF_ASSIGNMENT_BASE sab
        CROSS JOIN SCHOOL_YEAR_NUMBERS syn
    WHERE
        -- Only include years that fall within the assignment period
        sab.SchoolYearStart + syn.YearOffset <= sab.SchoolYearEnd
),

STAFF_BASE  AS --Main select statement to be queried for Retention logic
(
SELECT
    sye.TeacherID,
    -- Format the school year as 'YYYY-YYYY+1' based on the August-July definition
    CAST(sye.SchoolYearStart AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearStart+1  AS NVARCHAR(4)) AS SchoolYear,
    sye.SchoolYearStart,--Added SchoolYearStart as it's own field so that it can be used in Retention calculations
   sye.SchoolYearStart + 1 as SchoolYearEnd,
   CAST(sye.SchoolYearStart+1  AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearStart + 2 AS NVARCHAR(4)) AS RetainedSchoolYear,
    sye.SchoolYearStart + 1 AS RetainedSchoolYearStart,    
    seoaa.[BeginDate],
    seoaa.[EducationOrganizationId],
    seoaa.[EndDate],
    -- Calculate nonRetentionYear based on the June-May definition
    --Added logic to ensure that nonRetentionYear only populated during the year not retained, to support non-retention logic
    CASE
        WHEN seoaa.[EndDate] IS NULL THEN NULL
        WHEN MONTH(seoaa.[EndDate]) >= 7 AND YEAR(seoaa.[EndDate]) = (sye.SchoolYearStart) THEN YEAR(seoaa.[EndDate])
        WHEN MONTH(seoaa.[EndDate]) < 7 AND YEAR(seoaa.[EndDate]) = (sye.SchoolYearStart + 1) THEN YEAR(seoaa.[EndDate])-1
        ELSE NULL
    END AS nonRetentionYear,
    scd.CodeValue AS StaffAssignmentType,
    asd.CodeValue AS AssignmentSubjectCategory,
    cred.ShortDescription AS CredentialType,
    edorg.[NameOfInstitution] AS Campus, -- Name used in the Dashboard
    edorg.[EducationOrganizationId] AS SchoolId,
    eoa.Latitude AS SchoolLat,
    eoa.Longitude AS SchoolLong,
    scdesc.CodeValue AS SchoolSegment,
    /*Handle LEA details for staff that are not associated with schools, but using edorg level LEA info*/
    CASE WHEN lea.[NameOfInstitution] IS NOT NULL THEN lea.[NameOfInstitution] ELSE edorg.[NameOfInstitution] END AS District, -- Name used in the Dashboard
    CASE WHEN lea.[EducationOrganizationId] IS NOT NULL THEN lea.[EducationOrganizationId] ELSE edorg.[EducationOrganizationId] END AS LEAId,
    CASE WHEN eoaLEA.Latitude IS NOT NULL THEN eoaLEA.Latitude ELSE eoaLEA2.Latitude END AS LeaLat,
    CASE WHEN eoaLEA.Longitude IS NOT NULL THEN eoaLEA.Longitude ELSE eoaLEA2.Longitude END AS LeaLong,
    r.[CodeValue] AS RaceEthnic,
    s.[FirstName],
    s.[LastSurname],
    s.[YearsOfPriorTeachingExperience],
    s.BirthDate,
    CASE
          WHEN YEAR(seoaa.BeginDate) = sye.SchoolYearStart  AND  MONTH(seoaa.BeginDate) >= 6 THEN 1
        WHEN YEAR(seoaa.BeginDate) = sye.SchoolYearStart + 1 AND  MONTH(seoaa.BeginDate) < 6 THEN 1
        ELSE 0
    END AS NewHire,
    CASE
        WHEN (CONVERT(int,CONVERT(char(8),DATEFROMPARTS(sye.SchoolYearStart+1,6,15),112))-CONVERT(char(8),s.BirthDate,112))/10000 >= 56 THEN 1
        ELSE 0
    END AS NearRetirement
FROM
    SCHOOL_YEARS_EXPANDED sye
-- Join back to the main StaffEducationOrganizationAssignmentAssociation table to get other details
-- Joining on TeacherID (StaffUSI), StartDate (BeginDate), and EndDate ensures we link to the correct assignment record.
INNER JOIN [edfi].[StaffEducationOrganizationAssignmentAssociation] AS seoaa
    ON sye.TeacherID = seoaa.StaffUSI
    AND sye.StartDate = seoaa.BeginDate
-- Add staff table for demographics
LEFT JOIN [edfi].[Staff] AS s
    ON s.StaffUSI = seoaa.StaffUSI
-- Add Staff Race
LEFT JOIN [edfi].[StaffRace] AS sr
    ON sr.StaffUSI = seoaa.StaffUSI
-- Join to school to get School Name
LEFT JOIN [edfi].[EducationOrganization] AS edorg
    ON edorg.EducationOrganizationId = seoaa.EducationOrganizationId
-- Join school to get associated LEA
LEFT JOIN [edfi].[School] AS SchoolLEA
    ON SchoolLEA.SchoolId = seoaa.EducationOrganizationId
-- Join again to get LEA Name
LEFT JOIN [edfi].[EducationOrganization] AS lea
    ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
--Add School Category Descriptor
LEFT JOIN [edfi].[SchoolCategory] AS schoolCat
    ON schoolCat.SchoolId = seoaa.EducationOrganizationId
LEFT JOIN [edfi].[Descriptor] AS scdesc
    ON scdesc.DescriptorId = schoolCat.SchoolCategoryDescriptorId
-- Add race descriptor
LEFT JOIN [edfi].[Descriptor] AS r
    ON r.DescriptorId = sr.RaceDescriptorId
-- Add staff classification descriptor
LEFT JOIN [edfi].[Descriptor] AS scd
    ON scd.DescriptorId = seoaa.StaffClassificationDescriptorId
-- Add Academic Subject
LEFT JOIN [edfi].[StaffSchoolAssociationAcademicSubject] AS ssaas
    ON ssaas.SchoolId = seoaa.EducationOrganizationId AND ssaas.StaffUSI = seoaa.StaffUSI
LEFT JOIN [edfi].[Descriptor] AS asd
    ON asd.DescriptorId = ssaas.AcademicSubjectDescriptorId

-- Join StaffCredential and Credential tables
LEFT JOIN [edfi].[StaffCredential] AS sc
    ON sc.StaffUSI = s.StaffUSI
LEFT JOIN [edfi].[Credential] AS c
    ON c.CredentialIdentifier = sc.CredentialIdentifier
-- Add credential descriptor
LEFT JOIN [edfi].[Descriptor] AS cred
    ON cred.DescriptorId = c.TeachingCredentialDescriptorId
--School Location
LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoa
    ON eoa.EducationOrganizationId = seoaa.EducationOrganizationId 
--School's LEA Location
LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoaLEA
    ON eoaLEA.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
--LEA's Location
LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoaLEA2
    ON eoaLEA2.EducationOrganizationId = edorg.EducationOrganizationId

WHERE
    -- Ensure that the generated school year actually overlaps with the teacher's assignment period.
    -- This filters out school years that might be generated by the recursion but don't
    -- truly fall within the teacher's active assignment dates.
    (sye.EndDate IS NULL OR DATEFROMPARTS(sye.SchoolYearStart, 8, 1) <= sye.EndDate)
    AND
    (DATEFROMPARTS(sye.SchoolYearStart + 1, 7, 31) >= sye.StartDate)
) 

SELECT sb.*,
--Adding this field to support Retention Charts
   CASE
        WHEN sb.nonRetentionYear IS NULL 
            OR (
            SELECT Campus 
            FROM STAFF_BASE 
            WHERE TeacherID = sb.TeacherID 
            AND SchoolYearStart = sb.SchoolYearStart+1) = sb.Campus  -- if the teacher leaves but comes back to the same school next year        
        THEN 'RetainedDistrictAndSchool' 
        WHEN sb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM STAFF_BASE 
            WHERE TeacherID = sb.TeacherID 
            AND SchoolYearStart = sb.SchoolYearStart+1) = sb.District  -- if the district is the same in the next school year
            THEN 'RetainedDistrictNotSchool'  
       WHEN sb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM STAFF_BASE 
            WHERE TeacherID = sb.TeacherID 
            AND SchoolYearStart = sb.SchoolYearStart+1) != sb.District  -- if the district is not the same in the next school year
            THEN 'NoLongerInDistrict'  
        WHEN sb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM STAFF_BASE 
            WHERE TeacherID = sb.TeacherID 
            AND SchoolYearStart = sb.SchoolYearStart+1 ) IS NULL --if the educator is no longer present in the data set in the next school year
            THEN 'NoLongerInCounty'        

        ELSE 'ERROR'
    END
AS RetentionStatus
FROM STAFF_BASE AS sb
--Limit dataset to Start Years needed for dashboards. Using past 10 Years.
WHERE SchoolYearStart>YEAR(GETDATE())-10
