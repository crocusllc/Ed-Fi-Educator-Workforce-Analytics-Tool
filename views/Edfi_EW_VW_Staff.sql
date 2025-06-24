CREATE VIEW vw_Staff AS
WITH RECURSIVE_SCHOOL_YEARS AS (
    -- Anchor member: Get the starting school year for each teacher assignment
    SELECT
        t.StaffUSI AS TeacherID,
        t.BeginDate AS StartDate,
       CASE
            WHEN t.EndDate IS NULL THEN GETDATE()
            ELSE t.EndDate
        END
        AS EndDate,
        -- Calculate the start year of the school year based on StartDate (August 1st to July 31st)
        CASE
            WHEN MONTH(t.BeginDate) >= 8 THEN YEAR(t.BeginDate)
            ELSE YEAR(t.BeginDate) - 1
        END AS SchoolYearStart,
        -- Calculate the end year of the school year based on EndDate (August 1st to July 31st)
        -->>Added additional logic to ensure that the SchoolYearEnd field is never NULL.  
        -->>When no end date present, use current date
        CASE
            WHEN MONTH(t.EndDate) >= 8 AND t.EndDate is not null THEN YEAR(t.EndDate)
            WHEN MONTH(GETDATE()) >= 8 AND t.EndDate is null THEN YEAR(GETDATE())
            WHEN MONTH(t.EndDate) < 8 AND t.EndDate is not null THEN YEAR(t.EndDate)-1
            WHEN MONTH(GETDATE()) < 8 AND t.EndDate is null THEN YEAR(GETDATE())-1
        END AS SchoolYearEnd
    FROM
        [EdFi_Ods_Populated_Template].[edfi].[StaffEducationOrganizationAssignmentAssociation] t

    UNION ALL

    -- Recursive member: Increment the school year until it exceeds the EndDate
    SELECT
        rsy.TeacherID,
        rsy.StartDate,
        rsy.EndDate,
        rsy.SchoolYearStart + 1, -- Move to the next school year
        rsy.SchoolYearEnd
    FROM
        RECURSIVE_SCHOOL_YEARS rsy
    WHERE
        -- Continue recursion as long as the current school year (plus 1 for the next iteration)
        -- is less than or equal to the calculated end school year for the assignment.
        rsy.SchoolYearStart + 1 <= rsy.SchoolYearEnd
),

VacancyBase AS --Created main Select statement as another With so that it can be queried for Retention logic
(
SELECT
    rsy.TeacherID,
    -- Format the school year as 'YYYY-YYYY+1' based on the August-July definition
    CAST(rsy.SchoolYearStart AS NVARCHAR(4)) + '-' + CAST(rsy.SchoolYearStart + 1 AS NVARCHAR(4)) AS SchoolYear,
    rsy.SchoolYearStart AS SchoolYearStart,--Added SchoolYearStart as it's own field so that it can be used in Retention calculations
    seoaa.[BeginDate],
    seoaa.[EducationOrganizationId],
    seoaa.[EndDate],
    -- Calculate nonRetentionYear based on the June-May definition
    --Added logic to ensure that nonRetentionYear only populated during the year not retained, to support non-retention logic
    CASE
        WHEN seoaa.[EndDate] IS NULL THEN NULL
        WHEN MONTH(seoaa.[EndDate]) >= 6 AND YEAR(seoaa.[EndDate]) = (rsy.SchoolYearStart + 1) THEN YEAR(seoaa.[EndDate])
        WHEN MONTH(seoaa.[EndDate]) < 6 AND YEAR(seoaa.[EndDate]) = (rsy.SchoolYearStart) THEN YEAR(seoaa.[EndDate])
        ELSE NULL
    END AS nonRetentionYear,
    scd.CodeValue AS StaffAssignmentType,
 /*   CASE
        WHEN DAY(seoaa.BeginDate) BETWEEN 1 AND 6 THEN 'Math'
        WHEN DAY(seoaa.BeginDate) BETWEEN 7 AND 13 THEN 'English'
        WHEN DAY(seoaa.BeginDate) BETWEEN 14 AND 22 THEN 'Science'
        WHEN DAY(seoaa.BeginDate) BETWEEN 23 AND 31 THEN 'Social Studies'
        ELSE 'Other'
    END */
    asd.CodeValue AS AssignmentSubjectCategory,
/*    CASE
        WHEN DAY(seoaa.BeginDate) BETWEEN 1 AND 6 THEN 'High'
        WHEN DAY(seoaa.BeginDate) BETWEEN 7 AND 13 THEN 'Middle'
        WHEN DAY(seoaa.BeginDate) BETWEEN 14 AND 22 THEN 'Elementary'
        WHEN DAY(seoaa.BeginDate) BETWEEN 23 AND 31 THEN 'Junior High'
        ELSE 'Other'
    END AS SchoolSegment,*/
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
        WHEN (CONVERT(int,CONVERT(char(8),GETDATE(),112))-CONVERT(char(8),s.BirthDate,112))/10000 >= 56 THEN 1
        ELSE 0
    END AS NearRetirement,
    CASE
        WHEN YEAR(seoaa.BeginDate) = rsy.SchoolYearStart  AND  MONTH(seoaa.BeginDate) >= 6 THEN 1
        WHEN YEAR(seoaa.BeginDate) = rsy.SchoolYearStart+1  AND  MONTH(seoaa.BeginDate) < 6 THEN 1
        ELSE 0
    END AS NewHireSchool,
    CASE --We would need to check previous employment at district.  Using what Mechanism?
        WHEN YEAR(seoaa.BeginDate) = rsy.SchoolYearStart  AND  MONTH(seoaa.BeginDate) >= 6 THEN 1
        WHEN YEAR(seoaa.BeginDate) = rsy.SchoolYearStart+1  AND  MONTH(seoaa.BeginDate) < 6 THEN 1
        ELSE 0
    END AS NewHireDistrict
FROM
    RECURSIVE_SCHOOL_YEARS rsy
-- Join back to the main StaffEducationOrganizationAssignmentAssociation table to get other details
-- Joining on TeacherID (StaffUSI), StartDate (BeginDate), and EndDate ensures we link to the correct assignment record.
INNER JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffEducationOrganizationAssignmentAssociation] AS seoaa
    ON rsy.TeacherID = seoaa.StaffUSI
    AND rsy.StartDate = seoaa.BeginDate
    --Removing join to handle null field end dates, since those don't exist anymore
    --AND (rsy.EndDate = seoaa.EndDate /*OR (rsy.EndDate IS NULL AND seoaa.EndDate IS NULL)*/) -- Handle NULL EndDates in join
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
    (rsy.EndDate IS NULL OR DATEFROMPARTS(rsy.SchoolYearStart, 8, 1) <= rsy.EndDate)
    AND
    (DATEFROMPARTS(rsy.SchoolYearStart + 1, 7, 31) >= rsy.StartDate)
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
            AND SchoolYearStart = vb.SchoolYearStart-1) = vb.District 
            THEN 'RetainedDistrictNotSchool'  
        ELSE 'NoLongerInDistrict'
    END
AS RetentionStatus

FROM VacancyBase AS vb
