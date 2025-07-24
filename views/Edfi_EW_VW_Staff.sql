CREATE VIEW vw_Staff AS
WITH SCHOOL_YEAR_NUMBERS AS (
    SELECT 0 AS YearOffset
    UNION ALL SELECT 1 
    UNION ALL SELECT 2  
    UNION ALL SELECT 3 
    UNION ALL SELECT 4 
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
            ELSE YEAR(t.BeginDate) - 1
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
        sab.SchoolYearStart,
        sab.SchoolYearEnd - syn.YearOffset AS SchoolYearEnd
    FROM
        STAFF_ASSIGNMENT_BASE sab
        CROSS JOIN SCHOOL_YEAR_NUMBERS syn
    WHERE
        -- Only include years that fall within the assignment period
        sab.SchoolYearEnd - syn.YearOffset >= sab.SchoolYearStart
),

VacancyBase AS --Main select statement to be queried for Retention logic
(
SELECT
    sye.TeacherID,
    -- Format the school year as 'YYYY-YYYY+1' based on the August-July definition
    CAST(sye.SchoolYearEnd-1 AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearEnd  AS NVARCHAR(4)) AS SchoolYear,
    sye.SchoolYearEnd-1 AS SchoolYearStart,--Added SchoolYearStart as it's own field so that it can be used in Retention calculations
    CAST(sye.SchoolYearEnd  AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearEnd+1 AS NVARCHAR(4)) AS RetainedSchoolYear,
    sye.SchoolYearEnd + 1 AS RetainedSchoolYearStart,    
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
    school.[NameOfInstitution] AS Campus, -- Name used in the Dashboard
    school.[EducationOrganizationId] AS SchoolId,
    eoa.Latitude AS SchoolLat,
    eoa.Longitude AS SchoolLong,
    scdesc.CodeValue AS SchoolSegment,
    lea.[NameOfInstitution] AS District, -- Name used in the Dashboard
    lea.[EducationOrganizationId] AS LEAId,
    eoaLEA.Latitude AS LeaLat,
    eoaLEA.Longitude AS LeaLong,
    r.[CodeValue] AS RaceEthnic,
    s.[FirstName],
    s.[LastSurname],
    s.[YearsOfPriorTeachingExperience],
    s.BirthDate,
    CASE
        WHEN (CONVERT(int,CONVERT(char(8),GETDATE(),112))-CONVERT(char(8),s.BirthDate,112))/10000 >= 56 THEN 'Near Retirement'
        WHEN YEAR(seoaa.BeginDate) = sye.SchoolYearStart  AND  MONTH(seoaa.BeginDate) >= 6 THEN 'New Hire'
        WHEN YEAR(seoaa.BeginDate) = sye.SchoolYearStart+1  AND  MONTH(seoaa.BeginDate) < 6 THEN 'New Hire'
        ELSE NULL
    END AS TenureStatus
FROM
    SCHOOL_YEARS_EXPANDED sye
-- Join back to the main StaffEducationOrganizationAssignmentAssociation table to get other details
-- Joining on TeacherID (StaffUSI), StartDate (BeginDate), and EndDate ensures we link to the correct assignment record.
INNER JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffEducationOrganizationAssignmentAssociation] AS seoaa
    ON sye.TeacherID = seoaa.StaffUSI
    AND sye.StartDate = seoaa.BeginDate
-- Add staff table for demographics
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Staff] AS s
    ON s.StaffUSI = seoaa.StaffUSI
-- Add Staff Race
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffRace] AS sr
    ON sr.StaffUSI = seoaa.StaffUSI
-- Join to school to get School Name
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS school
    ON school.EducationOrganizationId = seoaa.EducationOrganizationId
-- Join school to get associated LEA
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[School] AS SchoolLEA
    ON SchoolLEA.SchoolId = seoaa.EducationOrganizationId
-- Join again to get LEA Name
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS lea
    ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
--Add School Category Descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[SchoolCategory] AS schoolCat
    ON schoolCat.SchoolId = seoaa.EducationOrganizationId
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] as scdesc
    ON scdesc.DescriptorId = schoolCat.SchoolCategoryDescriptorId
-- Add race descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS r
    ON r.DescriptorId = sr.RaceDescriptorId
-- Add staff classification descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS scd
    ON scd.DescriptorId = seoaa.StaffClassificationDescriptorId
-- Add Academic Subject
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffSchoolAssociationAcademicSubject] AS ssaas
    ON ssaas.SchoolId = seoaa.EducationOrganizationId AND ssaas.StaffUSI = seoaa.StaffUSI
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS asd
    ON asd.DescriptorId = ssaas.AcademicSubjectDescriptorId

-- Join StaffCredential and Credential tables
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffCredential] AS sc
    ON sc.StaffUSI = s.StaffUSI
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Credential] AS c
    ON c.CredentialIdentifier = sc.CredentialIdentifier
-- Add credential descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS cred
    ON cred.DescriptorId = c.CredentialFieldDescriptorId
--Add Tenure Track Flag
LEFT JOIN [EdFi_Ods_Populated_Template].[tpdm].[StaffEducationOrganizationEmploymentAssociationExtension] as seoeae
    on seoeae.StaffUSI = seoaa.StaffUSI 
--School Location
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganizationAddress] AS eoa
    ON eoa.EducationOrganizationId = seoaa.EducationOrganizationId 
--LEA Location
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganizationAddress] AS eoaLEA
    ON eoaLEA.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
WHERE
    -- Ensure that the generated school year actually overlaps with the teacher's assignment period.
    -- This filters out school years that might be generated by the recursion but don't
    -- truly fall within the teacher's active assignment dates.
    (sye.EndDate IS NULL OR DATEFROMPARTS(sye.SchoolYearStart, 8, 1) <= sye.EndDate)
    AND
    (DATEFROMPARTS(sye.SchoolYearStart + 1, 7, 31) >= sye.StartDate)
) 

SELECT vb.*,
--Adding this field to support Retention Charts
--Need to do some more testing on this.  I think comparisons need to be tweaked
   CASE
        WHEN vb.nonRetentionYear IS NULL THEN 'RetainedDistrictAndSchool' 
        WHEN vb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM VacancyBase 
            WHERE TeacherID = vb.TeacherID 
            AND SchoolYearStart = vb.SchoolYearStart+1) = vb.District  -- if the district is the same in the next school year
            THEN 'RetainedDistrictNotSchool'  
       WHEN vb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM VacancyBase 
            WHERE TeacherID = vb.TeacherID 
            AND SchoolYearStart = vb.SchoolYearStart+1) != vb.District  -- if the district is not the same in the next school year
            THEN 'NoLongerInDistrict'  
        WHEN vb.nonRetentionYear IS NOT NULL 
            AND (
            SELECT District 
            FROM VacancyBase 
            WHERE TeacherID = vb.TeacherID 
            AND SchoolYearStart = vb.SchoolYearStart+1 ) IS NULL --if the educator is no longer present in the data set in the next school year
            THEN 'NoLongerInCounty'        

        ELSE 'ERROR'
    END
AS RetentionStatus
FROM VacancyBase AS vb
