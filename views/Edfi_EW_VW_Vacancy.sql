WITH VacancyRaw AS (
    -- Gather the raw data and handle basic ISNULL logic. 
    SELECT 
        osp.[EducationOrganizationId]
        ,osp.DatePosted
        ,osp.DatePostingRemoved
        ,osp.RequisitionNumber
        ,CASE 
            WHEN osp.DatePostingRemoved IS NULL THEN osp.RequisitionNumber 
            ELSE NULL 
         END as isPositionOpen 
        ,ISNULL(ospasd.CodeValue, 'None') AS AssignmentCategory
        ,scd.CodeValue AS AssignmentType 
        ,school.[NameOfInstitution] AS Campus
        ,ISNULL(scdesc.CodeValue, 'District') AS Segment
        ,school.[EducationOrganizationId] AS SchoolId
        ,ISNULL(lea.[NameOfInstitution], school.[NameOfInstitution]) AS District
        ,ISNULL(lea.[EducationOrganizationId], school.[EducationOrganizationId]) AS LEAId
        ,osp.LastModifiedDate AS LastRefreshed
        
        -- Normalize dates to the 1st of the month to make joining easier
        ,CAST(DATEFROMPARTS(YEAR(osp.DatePosted), MONTH(osp.DatePosted), 1) AS DATE) AS StartMonth
        ,CASE 
            WHEN osp.DatePostingRemoved IS NOT NULL THEN 
                 CAST(DATEFROMPARTS(YEAR(osp.DatePostingRemoved), MONTH(osp.DatePostingRemoved), 1) AS DATE)
            ELSE 
                 -- If currently open, project up to the current month
                 CAST(DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) AS DATE)
         END AS EndMonth
    FROM [edfi].[OpenStaffPosition] AS osp
        LEFT JOIN [edfi].[EducationOrganization] AS eo 
            ON osp.EducationOrganizationId = eo.EducationOrganizationId
        LEFT JOIN [edfi].[EducationOrganization] AS school 
            ON school.EducationOrganizationId = osp.EducationOrganizationId
        LEFT JOIN [edfi].[School] AS SchoolLEA 
            ON SchoolLEA.SchoolId = osp.EducationOrganizationId
        LEFT JOIN [edfi].[EducationOrganization] AS lea 
            ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
        LEFT JOIN [edfi].[Descriptor] AS scd 
            ON scd.DescriptorId = osp.StaffClassificationDescriptorId
        LEFT JOIN [edfi].[SchoolCategory] AS schoolCat 
            ON schoolCat.SchoolId = osp.EducationOrganizationId
        LEFT JOIN [edfi].[Descriptor] AS scdesc 
            ON scdesc.DescriptorId = schoolCat.SchoolCategoryDescriptorId
        LEFT JOIN [edfi].[OpenStaffPositionAcademicSubject] AS ospas 
            ON ospas.EducationOrganizationId = osp.EducationOrganizationId AND ospas.RequisitionNumber = osp.RequisitionNumber
        LEFT JOIN [edfi].[Descriptor] AS ospasd 
            ON ospasd.DescriptorId = ospas.AcademicSubjectDescriptorId
),
-- Determine the global range of dates needed to build our calendar
DateRange AS (
    SELECT MIN(StartMonth) as MinDate, MAX(EndMonth) as MaxDate
    FROM VacancyRaw
),
-- Recursive CTE to generate a row for every month from the very first posting until today
MonthlyCalendar AS (
    SELECT MinDate as CalendarDate
    FROM DateRange
    UNION ALL
    SELECT DATEADD(MONTH, 1, CalendarDate)
    FROM MonthlyCalendar
    WHERE CalendarDate < (SELECT MaxDate FROM DateRange)
)
-- Join Raw Data to the Calendar
SELECT 
    vr.EducationOrganizationId
    ,vr.DatePosted
    ,vr.DatePostingRemoved
    ,vr.RequisitionNumber
    ,vr.isPositionOpen
    ,vr.AssignmentCategory
    ,vr.Segment
    ,vr.AssignmentType
    ,vr.Campus
    ,vr.SchoolId
    ,vr.District
    ,vr.LEAId
    
    -- DYNAMIC CALCULATION: Based on the generated Calendar Date
    ,CASE 
        WHEN MONTH(mc.CalendarDate) >= 7 THEN 
            CAST(YEAR(mc.CalendarDate) AS VARCHAR(4)) + '-' + CAST(YEAR(mc.CalendarDate) + 1 AS VARCHAR(4))
        ELSE 
            CAST(YEAR(mc.CalendarDate) - 1 AS VARCHAR(4)) + '-' + CAST(YEAR(mc.CalendarDate) AS VARCHAR(4))
    END AS SchoolYear
    
    ,DATENAME(MONTH, mc.CalendarDate) AS Session
    ,vr.LastRefreshed
    
    -- Handle sorting logic (July=1, June=12)
    ,CASE 
        WHEN MONTH(mc.CalendarDate) >= 7 THEN MONTH(mc.CalendarDate) - 6
        ELSE MONTH(mc.CalendarDate) + 6
    END AS SessionOrder
    
FROM VacancyRaw vr
INNER JOIN MonthlyCalendar mc
    ON mc.CalendarDate BETWEEN vr.StartMonth AND vr.EndMonth
