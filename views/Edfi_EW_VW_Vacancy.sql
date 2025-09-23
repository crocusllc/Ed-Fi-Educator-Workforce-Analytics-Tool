CREATE VIEW vw_VacancyData AS
WITH VacancyBase AS (
    SELECT
        osp.[EducationOrganizationId]
        ,osp.DatePosted
        ,osp.DatePostingRemoved
        ,osp.RequisitionNumber
        ,CASE -- Indicates if the position is currently open (RequisitionNumber) or closed (Null)
              --to allow for distict counts of vacancies when agregating by Year
            WHEN osp.DatePostingRemoved IS NULL THEN osp.RequisitionNumber 
            ELSE NULL END as isPositionOpen 

        ,CASE WHEN ospasd.CodeValue IS NULL THEN 'None' ELSE ospasd.CodeValue  END AS AssignmentCategory --Academic Subject of open Position
        ,scd.CodeValue AS AssignmentType -- Staff classification descriptor value
        ,school.[NameOfInstitution] AS Campus -- Name of the institution (Campus)
        ,CASE WHEN scdesc.CodeValue  IS NULL THEN 'District' ELSE scdesc.CodeValue END AS Segment
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
        -- Determine the initial session name based on the DatePosted month 
        , DATENAME(month,osp.DatePosted) AS InitialSessionName
        -- Assign an order to the initial session for comparison
        ,
        CASE-- School Year Hiring Starts in August
            WHEN MONTH(osp.DatePosted) = 8  THEN 1 
            WHEN MONTH(osp.DatePosted) = 9 THEN 2
            WHEN MONTH(osp.DatePosted) = 10 THEN 3 
            WHEN MONTH(osp.DatePosted) = 11 THEN 4
            WHEN MONTH(osp.DatePosted) =12  THEN 5 
            WHEN MONTH(osp.DatePosted) = 1 THEN 6
            WHEN MONTH(osp.DatePosted) = 2 THEN 7 
            WHEN MONTH(osp.DatePosted) = 3 THEN 8
            WHEN MONTH(osp.DatePosted) = 4  THEN 9 
            WHEN MONTH(osp.DatePosted) = 5 THEN 10
            WHEN MONTH(osp.DatePosted) = 6 THEN 11 
            WHEN MONTH(osp.DatePosted) = 7 THEN 12
            ELSE 0 -- Unknown or unhandled case
        END  AS InitialSessionOrder
        ,MONTH(osp.DatePosted) AS MonthOrder
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
        --Add School Category Descriptor
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[SchoolCategory] AS schoolCat
            ON schoolCat.SchoolId = osp.EducationOrganizationId
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS  scdesc
            ON scdesc.DescriptorId = schoolCat.SchoolCategoryDescriptorId
        --Add Academic Subject Category "Assignment Category"
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[OpenStaffPositionAcademicSubject] AS ospas
            ON ospas.EducationOrganizationId = osp.EducationOrganizationId AND ospas.RequisitionNumber = osp.RequisitionNumber
        LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS  ospasd
            ON ospasd.DescriptorId = ospas.AcademicSubjectDescriptorId

),
-- CTE to define all academic sessions and their respective orders
AllSessions AS (
     SELECT 'August' AS SessionName, 1 AS SessionOrder, 8 AS MonthOrder
    UNION ALL SELECT 'September', 2,9
    UNION ALL SELECT 'October', 3,10
    UNION ALL SELECT 'November', 4,11
    UNION ALL SELECT 'December', 5,12
    UNION ALL SELECT 'January' , 6,1
    UNION ALL SELECT 'February', 7,2
    UNION ALL SELECT 'March', 8,3
    UNION ALL SELECT 'April', 9,4
    UNION ALL SELECT 'May', 10,5
    UNION ALL SELECT 'June', 11,6
    UNION ALL SELECT 'July', 12,7

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
   ON vb.isPositionOpen IS NOT NULL  AND s.SessionOrder >= vb.InitialSessionOrder

UNION ALL

-- Second part of the UNION ALL:
-- Selects closed positions and  includes for each month the vacancy was open.
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
    ,s.SessionName AS Session -- The initial session name for closed positions
    ,vb.LastRefreshed -- Included LastRefreshed in the final select
FROM VacancyBase AS vb
INNER JOIN AllSessions AS s
   ON vb.isPositionOpen IS  NULL  
   AND s.SessionOrder >= vb.InitialSessionOrder 
   AND (
       SELECT SessionOrder 
       FROM AllSessions 
       WHERE MonthOrder = MONTH(vb.DatePostingRemoved))>=s.SessionOrder

