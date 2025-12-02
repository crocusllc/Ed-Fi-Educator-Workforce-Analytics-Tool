CREATE VIEW vw_Staff AS
WITH 
-- Tally Table
YearOffsets (YearOffset) AS (
    SELECT v.YearOffset 
    FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),
                 (10),(11),(12),(13),(14),(15),(16),(17),(18),(19),
                 (20),(21),(22),(23),(24),(25),(26),(27),(28),(29),
                 (30),(31),(32),(33),(34),(35),(36),(37),(38),(39),(40)
         ) AS v(YearOffset)
),

-- Race Handling 
StaffRaceAssoc AS (
    SELECT 
        [StaffUSI],
        CASE 
            WHEN COUNT(RaceDescriptorId) > 1 THEN 9999 
            ELSE MIN(RaceDescriptorId) 
        END AS RaceDescriptorId
    FROM [edfi].[StaffRace]
    GROUP BY StaffUSI
),

-- Base Assignment Calculation
AssignmentBase AS (
    SELECT 
        t.StaffUSI,
        t.BeginDate,
        t.EndDate, -- Original EndDate needed for nonRetentionYear logic
        -- Effective End Date for the Join Logic
        CASE 
            WHEN t.EndDate IS NULL OR t.EndDate > GETDATE() THEN CAST(GETDATE() AS DATE)
            ELSE t.EndDate 
        END AS EffectiveEndDate,
        t.EducationOrganizationId,
        t.StaffClassificationDescriptorId
    FROM [edfi].[StaffEducationOrganizationAssignmentAssociation] t
),

--Calculate School Year Ranges (Optimized)
AssignmentRanges AS (
    SELECT 
        ab.*,
        -- Start Year Logic
        CASE 
            WHEN MONTH(ab.BeginDate) >= 6 THEN YEAR(ab.BeginDate)
            ELSE YEAR(ab.BeginDate) - 1
        END AS StartSY,
        -- End Year Logic
        CASE 
            WHEN MONTH(ab.EffectiveEndDate) >= 7 THEN YEAR(ab.EffectiveEndDate)
            ELSE YEAR(ab.EffectiveEndDate) - 1
        END AS EndSY
    FROM AssignmentBase ab
),

-- Cross Join with Tally Table
ExplodedAssignments AS (
    SELECT 
        ar.StaffUSI AS TeacherID, 
        ar.BeginDate,
        ar.EndDate,
        ar.EducationOrganizationId,
        ar.StaffClassificationDescriptorId,
        (ar.StartSY + yo.YearOffset) AS SchoolYearStart,
        (ar.StartSY + yo.YearOffset + 1) AS SchoolYearEnd
    FROM AssignmentRanges ar
    CROSS JOIN YearOffsets yo
    WHERE (ar.StartSY + yo.YearOffset) <= ar.EndSY 
      AND (ar.StartSY + yo.YearOffset) <= CASE WHEN MONTH(GETDATE()) >= 7 THEN YEAR(GETDATE()) ELSE YEAR(GETDATE())-1 END
      AND (ar.EndDate IS NULL OR DATEFROMPARTS((ar.StartSY + yo.YearOffset), 7, 1) <= ar.EndDate)
      AND (DATEFROMPARTS((ar.StartSY + yo.YearOffset) + 1, 6, 30 ) >= ar.BeginDate)
),

-- Enrich Data 
EnrichedStaff AS (
    SELECT
        ea.TeacherID,
        CAST(ea.SchoolYearStart AS NVARCHAR(4)) + '-' + CAST(ea.SchoolYearStart+1 AS NVARCHAR(4)) AS SchoolYear,
        ea.SchoolYearStart,
        ea.SchoolYearEnd,
        CAST(ea.SchoolYearStart+1 AS NVARCHAR(4)) + '-' + CAST(ea.SchoolYearStart + 2 AS NVARCHAR(4)) AS RetainedSchoolYear,
        ea.SchoolYearStart + 1 AS RetainedSchoolYearStart,
        
        ea.BeginDate,
        ea.EducationOrganizationId,
        ea.EndDate,

        -- nonRetentionYear Logic
        CASE
            WHEN ea.EndDate IS NULL THEN NULL
            WHEN MONTH(ea.EndDate) >= 7 AND YEAR(ea.EndDate) = (ea.SchoolYearStart) THEN YEAR(ea.EndDate)
            WHEN MONTH(ea.EndDate) < 7 AND YEAR(ea.EndDate) = (ea.SchoolYearStart + 1) THEN YEAR(ea.EndDate)-1
            ELSE NULL
        END AS nonRetentionYear,

        scd.CodeValue AS StaffAssignmentType,
        ISNULL(asd.CodeValue, 'None') AS AssignmentSubjectCategory,
        ISNULL(cred.ShortDescription, 'None') AS CredentialType,
        
        edorg.[NameOfInstitution] AS Campus,
        edorg.[EducationOrganizationId] AS SchoolId,
        eoa.Latitude AS SchoolLat,
        eoa.Longitude AS SchoolLong,
        
        ISNULL(scdesc.CodeValue, 'District') AS SchoolSegment,
        
        -- LEA Logic
        ISNULL(lea.[NameOfInstitution], edorg.[NameOfInstitution]) AS District,
        ISNULL(lea.[EducationOrganizationId], edorg.[EducationOrganizationId]) AS LEAId,
        
        -- LEA Lat/Long Logic
        COALESCE(eoaLEA.Latitude, eoaLEA2.Latitude) AS LeaLat,
        COALESCE(eoaLEA.Longitude, eoaLEA2.Longitude) AS LeaLong,

        -- Race Logic
        CASE 
            WHEN sr.RaceDescriptorId = 9999 THEN 'Multiple'
            WHEN r.CodeValue IS NULL THEN 'None'
            ELSE r.CodeValue
        END AS RaceEthnic,

        s.FirstName,
        s.LastSurname,
        s.YearsOfPriorTeachingExperience,
        s.BirthDate, -- Restored
        'Countywide' AS County,

        -- New Hire Logic
        CASE
            WHEN YEAR(ea.BeginDate) = ea.SchoolYearStart AND MONTH(ea.BeginDate) >= 7 THEN 'New Hire'
            WHEN YEAR(ea.BeginDate) = ea.SchoolYearStart + 1 AND MONTH(ea.BeginDate) < 7 THEN 'New Hire'
            ELSE NULL
        END AS NewHire,

        -- Near Retirement Logic
        CASE
            WHEN (CONVERT(int,CONVERT(char(8),DATEFROMPARTS(ea.SchoolYearStart+1,7,1),112))-CONVERT(char(8),s.BirthDate,112))/10000 >= 56 THEN 'Near Retirement'
            ELSE NULL
        END AS NearRetirement,

        -- WINDOW FUNCTIONS for Retention (Performance Fix)
        -- Calculate the Next Year's School and District here to avoid subqueries later
        LEAD(edorg.EducationOrganizationId) OVER (PARTITION BY ea.TeacherID ORDER BY ea.SchoolYearStart) AS NextYearSchoolId,
        LEAD(ISNULL(lea.EducationOrganizationId, edorg.EducationOrganizationId)) OVER (PARTITION BY ea.TeacherID ORDER BY ea.SchoolYearStart) AS NextYearLEAId,
        LEAD(ea.SchoolYearStart) OVER (PARTITION BY ea.TeacherID ORDER BY ea.SchoolYearStart) AS NextYearValue

    FROM ExplodedAssignments ea
        INNER JOIN [edfi].[StaffEducationOrganizationAssignmentAssociation] AS seoaa 
            ON ea.TeacherID = seoaa.StaffUSI 
            AND ea.BeginDate = seoaa.BeginDate
            -- Note: We join on PK/Dates to map back to original row if needed, 
            -- though ExplodedAssignments already contains the core data.
        
        LEFT JOIN [edfi].[Staff] AS s ON s.StaffUSI = ea.TeacherID
        LEFT JOIN StaffRaceAssoc AS sr ON sr.StaffUSI = ea.TeacherID
        LEFT JOIN [edfi].[EducationOrganization] AS edorg ON edorg.EducationOrganizationId = ea.EducationOrganizationId
        LEFT JOIN [edfi].[School] AS SchoolLEA ON SchoolLEA.SchoolId = ea.EducationOrganizationId
        LEFT JOIN [edfi].[EducationOrganization] AS lea ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
        LEFT JOIN [edfi].[SchoolCategory] AS schoolCat ON schoolCat.SchoolId = ea.EducationOrganizationId
        LEFT JOIN [edfi].[Descriptor] AS scdesc ON scdesc.DescriptorId = schoolCat.SchoolCategoryDescriptorId
        LEFT JOIN [edfi].[Descriptor] AS r ON r.DescriptorId = sr.RaceDescriptorId
        LEFT JOIN [edfi].[Descriptor] AS scd ON scd.DescriptorId = ea.StaffClassificationDescriptorId
        LEFT JOIN [edfi].[StaffSchoolAssociationAcademicSubject] AS ssaas 
            ON ssaas.SchoolId = ea.EducationOrganizationId AND ssaas.StaffUSI = ea.TeacherID
        LEFT JOIN [edfi].[Descriptor] AS asd ON asd.DescriptorId = ssaas.AcademicSubjectDescriptorId
        
        LEFT JOIN [edfi].[StaffCredential] AS sc ON sc.StaffUSI = s.StaffUSI
        LEFT JOIN [edfi].[Credential] AS c ON c.CredentialIdentifier = sc.CredentialIdentifier
        LEFT JOIN [edfi].[Descriptor] AS cred ON cred.DescriptorId = c.TeachingCredentialDescriptorId
        
        -- Address Joins
        LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoa ON eoa.EducationOrganizationId = ea.EducationOrganizationId 
        LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoaLEA ON eoaLEA.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
        LEFT JOIN [edfi].[EducationOrganizationAddress] AS eoaLEA2 ON eoaLEA2.EducationOrganizationId = edorg.EducationOrganizationId
)

-- Final Projection & Retention Calculation
SELECT 
    es.TeacherID,
    es.SchoolYear,
    es.SchoolYearStart,
    es.SchoolYearEnd,
    es.RetainedSchoolYear,
    es.RetainedSchoolYearStart,
    es.BeginDate,
    es.EducationOrganizationId,
    es.EndDate,
    es.nonRetentionYear,
    es.StaffAssignmentType,
    es.AssignmentSubjectCategory,
    es.CredentialType,
    es.Campus,
    es.SchoolId,
    es.SchoolLat,
    es.SchoolLong,
    es.SchoolSegment,
    es.District,
    es.LEAId,
    es.LeaLat,
    es.LeaLong,
    es.RaceEthnic,
    es.FirstName,
    es.LastSurname,
    es.YearsOfPriorTeachingExperience,
    es.BirthDate,
    es.County,
    es.NewHire,
    es.NearRetirement,
    
    -- Retention Logic (Optimized using LEAD results)
    CASE 
        -- If they didn't leave, or they left and came back to the SAME school next year:
        WHEN es.nonRetentionYear IS NULL OR (es.NextYearSchoolId = es.SchoolId) 
             THEN 'RetainedDistrictAndSchool'
        
        -- If they left, but are found in the SAME district next year (different school):
        WHEN es.nonRetentionYear IS NOT NULL AND (es.NextYearLEAId = es.LEAId)
             THEN 'RetainedDistrictNotSchool'
             
        -- If they left, and are found in a DIFFERENT district next year:
        WHEN es.nonRetentionYear IS NOT NULL AND (es.NextYearLEAId != es.LEAId)
             THEN 'NoLongerInDistrict'
             
        -- If they left, and there is NO record for next year (or a gap in years):
        WHEN es.nonRetentionYear IS NOT NULL AND (es.NextYearValue IS NULL OR es.NextYearValue != es.SchoolYearStart + 1)
             THEN 'NoLongerInCounty'
             
        ELSE 'UNKNOWN'
    END AS RetentionStatus

FROM EnrichedStaff es
WHERE es.SchoolYearStart > YEAR(GETDATE()) - 10


