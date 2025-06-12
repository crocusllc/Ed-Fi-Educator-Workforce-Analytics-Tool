CREATE VIEW vw_VacancyData AS
WITH 
/* Possible solution for adding in session dates at the district level
1. Create subquery that contains all School sessions and union with district IDs, taking most common start and end dates
2. Join Subquery instead of Session to the base view
SchoolSessions as (
Select * from Session
Union ALL
--select all districts from edorg and add in common session begin and end dates
),
*/
VacancyBase AS (
    SELECT
        osp.[EducationOrganizationId]
        ,osp.DatePosted
        ,osp.DatePostingRemoved
        ,osp.RequisitionNumber
        ,CASE -- Indicates if the position is currently open (RequisitionNumber) or closed (Null)
              --to allow for distict counts of vacancies when agregating by Year
            WHEN osp.DatePostingRemoved IS NULL THEN RequisitionNumber 
            ELSE NULL 
        END as isPositionOpen 
        ,CASE
            WHEN DAY(DatePosted) between 1 and 6 THEN 'Math'
            WHEN DAY(DatePosted) between 7 and 13 THEN 'English'
            WHEN DAY(DatePosted) between 14 and 22 THEN 'Science'
            WHEN DAY(DatePosted) between 23 and 31 THEN 'Social Studies'
            else 'Other'
        END
            AS AssignmentCategory -- Placeholder for assignment category based on day of month
        ,CASE
            WHEN DAY(DatePosted) between 1 and 6 THEN 'High'
            WHEN DAY(DatePosted) between 7 and 13 THEN 'Middle'
            WHEN DAY(DatePosted) between 14 and 22 THEN 'Elementary'
            WHEN DAY(DatePosted) between 23 and 31 THEN 'Junior High'
            else 'Other'
        END AS Segment -- Placeholder for segment based on day of month
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
        /*
        -- Determine the initial session name based on the DatePosted month ranges
        --Currently commented out because we are using sessions
        --However, hardcoding months may be a better indicator of when positions are opened
        ,CASE
            WHEN MONTH(osp.DatePosted) BETWEEN 8 AND 10 THEN 'Fall' -- Aug, Sept, Oct
            WHEN MONTH(osp.DatePosted) IN (11, 12, 1) THEN 'Winter' -- Nov, Dec, Jan
            WHEN MONTH(osp.DatePosted) BETWEEN 2 AND 4 THEN 'Spring' -- Feb, March, April
            WHEN MONTH(osp.DatePosted) BETWEEN 5 AND 7 THEN 'Summer' -- May, June, July
            ELSE 'Unknown'
        END AS InitialSessionName
         */
        -- Assign an order to the initial session for comparison
        ,ss.SessionName AS InitialSessionName
        ,CASE
            WHEN ss.SessionName = 'Fall'  THEN 1 -- Fall
            WHEN ss.SessionName = 'Winter' THEN 2 -- Winter
            WHEN ss.SessionName = 'Spring'  THEN 3 -- Spring
            WHEN ss.SessionName = 'Summer' THEN 4 -- Summer
            ELSE 0 -- Unknown or unhandled case
        END AS InitialSessionOrder
       

        ,osp.LastModifiedDate AS LastRefreshed
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
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Session] AS ss --Use school session based on vacancy date posted
            ON ss.SchoolId = osp.EducationOrganizationId 
                AND osp.DatePosted between ss.BeginDate and ss.EndDate
),
-- CTE to define all academic sessions and their respective orders
--commenting out Winter and Spring since not present in the Session data
AllSessions AS (
    SELECT 'Fall' AS SessionName, 1 AS SessionOrder
  -- UNION ALL SELECT 'Winter', 2
    UNION ALL SELECT 'Spring', 3
  -- UNION ALL SELECT 'Summer', 4
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
    ,vb.LastRefreshed -- Included LastRefreshed in the final select
FROM VacancyBase AS vb
INNER JOIN AllSessions AS s
        --Join session on SessionName as well
    ON vb.isPositionOpen IS NOT NULL  AND s.SessionOrder >= vb.InitialSessionOrder AND s.SessionName = vb.InitialSessionName

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
    ,vb.LastRefreshed -- Included LastRefreshed in the final select
FROM VacancyBase AS vb
WHERE vb.isPositionOpen IS NULL
