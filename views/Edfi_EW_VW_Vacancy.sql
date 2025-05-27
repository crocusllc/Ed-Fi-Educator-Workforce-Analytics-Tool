-- CTE to prepare the base vacancy data, including calculated SchoolYear,
-- and the initial session name and order based on DatePosted.
WITH VacancyBase AS (
    SELECT
        osp.[EducationOrganizationId]
        ,osp.DatePosted
        ,osp.DatePostingRemoved
        ,osp.RequisitionNumber
        ,CASE WHEN osp.DatePostingRemoved IS NULL THEN 1 ELSE 0 END as isPositionOpen -- Indicates if the position is currently open (1) or closed (0)
        ,'Math/FineArts, etc..TBD' AS AssignmentCategory -- Placeholder for assignment category
        ,'High,Elementary etc' AS Segment -- Placeholder for segment
        ,scd.CodeValue AS AssignmentType -- Staff classification descriptor value
        ,school.[NameOfInstitution] AS Campus -- Name of the institution (Campus)
        ,school.[EducationOrganizationId] AS SchoolId -- Education Organization ID for the school
        -- Handle district-level vacancies by using district name/ID if school is null
        ,CASE WHEN lea.[NameOfInstitution] IS NULL THEN school.[NameOfInstitution] ELSE lea.[NameOfInstitution] END AS District
        ,CASE WHEN lea.[EducationOrganizationId] IS NULL THEN school.[EducationOrganizationId] ELSE lea.[EducationOrganizationId] END AS LEAId
        -- Calculate the SchoolYear based on the DatePosted:
        -- If posted in Aug-Dec, it's the current year to next year (e.g., 2023-2024).
        -- If posted in Jan-Jul, it's the previous year to current year (e.g., 2023-2024 for Jan 2024).
        ,CASE
            WHEN MONTH(osp.DatePosted) >= 8 THEN
                CAST(YEAR(osp.DatePosted) AS VARCHAR(4)) + '-' + CAST(YEAR(osp.DatePosted) + 1 AS VARCHAR(4))
            ELSE
                CAST(YEAR(osp.DatePosted) - 1 AS VARCHAR(4)) + '-' + CAST(YEAR(osp.DatePosted) AS VARCHAR(4))
        END AS SchoolYear
        -- Determine the initial session name based on the DatePosted month ranges
        ,CASE
            WHEN MONTH(osp.DatePosted) BETWEEN 8 AND 10 THEN 'Fall' -- Aug, Sept, Oct
            WHEN MONTH(osp.DatePosted) IN (11, 12, 1) THEN 'Winter' -- Nov, Dec, Jan
            WHEN MONTH(osp.DatePosted) BETWEEN 2 AND 4 THEN 'Spring' -- Feb, March, April
            WHEN MONTH(osp.DatePosted) BETWEEN 5 AND 7 THEN 'Summer' -- May, June, July
            ELSE 'Unknown'
        END AS InitialSessionName
        -- Assign an order to the initial session for comparison
        ,CASE
            WHEN MONTH(osp.DatePosted) BETWEEN 8 AND 10 THEN 1 -- Fall
            WHEN MONTH(osp.DatePosted) IN (11, 12, 1) THEN 2 -- Winter
            WHEN MONTH(osp.DatePosted) BETWEEN 2 AND 4 THEN 3 -- Spring
            WHEN MONTH(osp.DatePosted) BETWEEN 5 AND 7 THEN 4 -- Summer
            ELSE 0 -- Unknown or unhandled case
        END AS InitialSessionOrder
    FROM [EdFi_Ods_Populated_Template].[edfi].[OpenStaffPosition] AS osp
        LEFT JOIN  [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS eo
            ON osp.EducationOrganizationId = eo.EducationOrganizationId
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS school
            ON school.EducationOrganizationId = osp.EducationOrganizationId
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[School] AS SchoolLEA
            ON SchoolLEA.SchoolId = osp.EducationOrganizationId
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS lea
            ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS scd
            ON scd.DescriptorId = osp.StaffClassificationDescriptorId
),
-- CTE to define all academic sessions and their respective orders
AllSessions AS (
    SELECT 'Fall' AS SessionName, 1 AS SessionOrder
    UNION ALL SELECT 'Winter', 2
    UNION ALL SELECT 'Spring', 3
    UNION ALL SELECT 'Summer', 4
)
-- First part of the UNION ALL:
-- Selects open positions and cross-joins them with all sessions
-- that are on or after their initial posting session within the same school year.
SELECT
    vb.[EducationOrganizationId]
    ,vb.DatePosted
    ,vb.DatePostingRemoved
    ,vb.RequisitionNumber
    ,vb.isPositionOpen
    ,vb.AssignmentCategory
    ,vb.Segment
    ,vb.AssignmentType
    ,vb.Campus
    ,vb.SchoolId
    ,vb.District
    ,vb.LEAId
    ,vb.SchoolYear
    ,s.SessionName AS Session -- The session name from the AllSessions CTE
FROM VacancyBase AS vb
INNER JOIN AllSessions AS s
    ON vb.isPositionOpen = 1 AND s.SessionOrder >= vb.InitialSessionOrder

UNION ALL

-- Second part of the UNION ALL:
-- Selects closed positions and only includes the row for their initial posting session.
SELECT
    vb.[EducationOrganizationId]
    ,vb.DatePosted
    ,vb.DatePostingRemoved
    ,vb.RequisitionNumber
    ,vb.isPositionOpen
    ,vb.AssignmentCategory
    ,vb.Segment
    ,vb.AssignmentType
    ,vb.Campus
    ,vb.SchoolId
    ,vb.District
    ,vb.LEAId
    ,vb.SchoolYear
    ,vb.InitialSessionName AS Session -- The initial session name for closed positions
FROM VacancyBase AS vb
WHERE vb.isPositionOpen = 0;