CREATE OR ALTER VIEW vw_Student AS
WITH 
-- 1. Tally Table (Cleaner VALUES Syntax)
YearOffsets (YearOffset) AS (
    SELECT v.YearOffset 
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),
                 (7),(8),(9),(10),(11),(12)
         ) AS v(YearOffset)
),

-- 2. Race Handling
StudentRace AS (
    SELECT 
        [EducationOrganizationId],
        [StudentUSI],
        CASE 
            WHEN COUNT(RaceDescriptorId) > 1 THEN 9999 -- Multiracial
            ELSE MIN(RaceDescriptorId) 
        END AS RaceDescriptorId 
    FROM [edfi].[StudentEducationOrganizationAssociationRace]
    GROUP BY StudentUSI, EducationOrganizationId
), 

-- 3. Base Association Logic
STUDENT_ASSOCIATION_BASE AS (
    SELECT 
        t.StudentUSI AS StudentID,
        t.EntryDate AS StartDate,
        CASE 
            WHEN t.ExitWithdrawDate IS NULL THEN GETDATE()
            ELSE t.ExitWithdrawDate
        END AS EndDate,
        -- Start Year Calculation
        CASE 
            WHEN MONTH(t.EntryDate) >= 7 THEN YEAR(t.EntryDate)
            ELSE YEAR(t.EntryDate) - 1
        END AS SchoolYearStart,
        -- End Year Calculation
        CASE 
            WHEN MONTH(t.ExitWithdrawDate) >= 7 AND t.ExitWithdrawDate IS NOT NULL THEN YEAR(t.ExitWithdrawDate)
            WHEN MONTH(GETDATE()) >= 7 AND t.ExitWithdrawDate IS NULL THEN YEAR(GETDATE())
            WHEN MONTH(t.ExitWithdrawDate) < 7 AND t.ExitWithdrawDate IS NOT NULL THEN YEAR(t.ExitWithdrawDate)-1
            WHEN MONTH(GETDATE()) < 7 AND t.ExitWithdrawDate IS NULL THEN YEAR(GETDATE())-1
        END AS SchoolYearEnd,
        t.SchoolId
    FROM [edfi].[StudentSchoolAssociation] AS t
),

-- 4. The Explosion (Cross Join)
SCHOOL_YEARS_EXPANDED AS (
    SELECT 
        sab.StudentID,
        sab.StartDate,
        sab.EndDate,
        sab.SchoolYearStart + syn.YearOffset AS SchoolYearStart,
        sab.SchoolYearEnd
    FROM STUDENT_ASSOCIATION_BASE sab
    CROSS JOIN YearOffsets syn
    WHERE 
        (sab.SchoolYearStart + syn.YearOffset) <= sab.SchoolYearEnd
)

-- 5. Final Join & Select
SELECT 
    sye.StudentID,
    -- Format: YYYY-YYYY+1
    CAST(sye.SchoolYearStart AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearStart+1 AS NVARCHAR(4)) AS SchoolYear,
    sye.SchoolYearStart,
    sye.SchoolYearStart+1 AS SchoolYearEnd,
    stud.[StudentUSI],
    stud.[FirstName],
    stud.[LastSurname],
    ssa.[EntryDate],
    ssa.[ExitWithdrawDate],
    school.[NameOfInstitution] AS Campus,
    school.[EducationOrganizationId] AS SchoolId,
    lea.[NameOfInstitution] AS District,
    lea.[EducationOrganizationId] AS LEAId,
    CASE 
        WHEN StudRace.[RaceDescriptorId] = 9999 THEN 'Multiple'
        WHEN r.[ShortDescription] IS NULL THEN 'None'
        ELSE r.[ShortDescription] 
    END AS RaceEthnic

FROM SCHOOL_YEARS_EXPANDED sye
-- Join back to original table to replicate original row count behavior
INNER JOIN [edfi].[StudentSchoolAssociation] AS ssa
    ON sye.StudentID = ssa.StudentUSI
    AND sye.StartDate = ssa.EntryDate

INNER JOIN [edfi].[Student] AS stud 
    ON ssa.StudentUSI = stud.StudentUSI
INNER JOIN [edfi].[EducationOrganization] AS school 
    ON school.EducationOrganizationId = ssa.SchoolId
LEFT JOIN [edfi].[School] AS SchoolLEA 
    ON SchoolLEA.SchoolId = ssa.SchoolId
LEFT JOIN [edfi].[EducationOrganization] AS lea 
    ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
LEFT JOIN StudentRace AS StudRace
    ON StudRace.EducationOrganizationId = lea.EducationOrganizationId 
    AND StudRace.StudentUSI = ssa.StudentUSI
LEFT JOIN [edfi].[Descriptor] AS r
    ON r.DescriptorId = StudRace.RaceDescriptorId

WHERE 
    (sye.EndDate IS NULL OR DATEFROMPARTS(sye.SchoolYearStart, 7, 1) <= sye.EndDate)
    AND (DATEFROMPARTS(sye.SchoolYearStart + 1, 6, 30) >= sye.StartDate)
    AND sye.SchoolYearStart > YEAR(GETDATE())-10;
