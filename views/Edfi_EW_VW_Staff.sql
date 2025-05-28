CREATE VIEW vw_Staff AS
WITH RECURSIVE_SCHOOL_YEARS AS (
    -- Anchor member: Get the starting school year for each teacher assignment
    SELECT
        t.StaffUSI AS TeacherID,
        t.BeginDate AS StartDate,
        t.EndDate,
        -- Calculate the start year of the school year based on StartDate (August 1st to July 31st)
        CASE
            WHEN MONTH(t.BeginDate) >= 8 THEN YEAR(t.BeginDate)
            ELSE YEAR(t.BeginDate) - 1
        END AS SchoolYearStart,
        -- Calculate the end year of the school year based on EndDate (August 1st to July 31st)
        CASE
            WHEN MONTH(t.EndDate) >= 8 THEN YEAR(t.EndDate)
            ELSE YEAR(t.EndDate) - 1
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
)
SELECT
    rsy.TeacherID,
    -- Format the school year as 'YYYY-YYYY+1' based on the August-July definition
    CAST(rsy.SchoolYearStart AS NVARCHAR(4)) + '-' + CAST(rsy.SchoolYearStart + 1 AS NVARCHAR(4)) AS SchoolYear,
    seoaa.[BeginDate],
    seoaa.[EducationOrganizationId],
    seoaa.[EndDate],
    -- Calculate nonRetentionYear based on the June-May definition
    CASE
        WHEN seoaa.[EndDate] IS NULL THEN NULL
        WHEN MONTH(seoaa.[EndDate]) >= 6 THEN YEAR(seoaa.[EndDate])
        ELSE YEAR(seoaa.[EndDate]) - 1
    END AS nonRetentionYear,
    scd.CodeValue AS StaffAssignmentType,
    CASE
        WHEN DAY(seoaa.BeginDate) BETWEEN 1 AND 6 THEN 'Math'
        WHEN DAY(seoaa.BeginDate) BETWEEN 7 AND 13 THEN 'English'
        WHEN DAY(seoaa.BeginDate) BETWEEN 14 AND 22 THEN 'Science'
        WHEN DAY(seoaa.BeginDate) BETWEEN 23 AND 31 THEN 'Social Studies'
        ELSE 'Other'
    END AS AssignmentSubjectCategory,
    CASE
        WHEN DAY(seoaa.BeginDate) BETWEEN 1 AND 6 THEN 'High'
        WHEN DAY(seoaa.BeginDate) BETWEEN 7 AND 13 THEN 'Middle'
        WHEN DAY(seoaa.BeginDate) BETWEEN 14 AND 22 THEN 'Elementary'
        WHEN DAY(seoaa.BeginDate) BETWEEN 23 AND 31 THEN 'Junior High'
        ELSE 'Other'
    END AS SchoolSegment,
    cred.ShortDescription AS CredentialType,
    school.[NameOfInstitution] AS Campus, -- Name used in the Dashboard
    school.[EducationOrganizationId] AS SchoolId,
    lea.[NameOfInstitution] AS District, -- Name used in the Dashboard
    lea.[EducationOrganizationId] AS LEAId,
    r.[CodeValue] AS RaceEthnic,
    s.[FirstName],
    s.[LastSurname],
    s.[YearsOfPriorTeachingExperience]
FROM
    RECURSIVE_SCHOOL_YEARS rsy
-- Join back to the main StaffEducationOrganizationAssignmentAssociation table to get other details
-- Joining on TeacherID (StaffUSI), StartDate (BeginDate), and EndDate ensures we link to the correct assignment record.
INNER JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffEducationOrganizationAssignmentAssociation] AS seoaa
    ON rsy.TeacherID = seoaa.StaffUSI
    AND rsy.StartDate = seoaa.BeginDate
    AND (rsy.EndDate = seoaa.EndDate OR (rsy.EndDate IS NULL AND seoaa.EndDate IS NULL)) -- Handle NULL EndDates in join
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
-- Add race descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS r
    ON r.DescriptorId = sr.RaceDescriptorId
-- Add staff classification descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS scd
    ON scd.DescriptorId = seoaa.StaffClassificationDescriptorId
-- Join StaffCredential and Credential tables
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffCredential] AS sc
    ON sc.StaffUSI = s.StaffUSI
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Credential] AS c
    ON c.CredentialIdentifier = sc.CredentialIdentifier
-- Add credential descriptor
LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS cred
    ON cred.DescriptorId = c.CredentialFieldDescriptorId
WHERE
    -- Ensure that the generated school year actually overlaps with the teacher's assignment period.
    -- This filters out school years that might be generated by the recursion but don't
    -- truly fall within the teacher's active assignment dates.
    (rsy.EndDate IS NULL OR DATEFROMPARTS(rsy.SchoolYearStart, 8, 1) <= rsy.EndDate)
    AND
    (DATEFROMPARTS(rsy.SchoolYearStart + 1, 7, 31) >= rsy.StartDate)
