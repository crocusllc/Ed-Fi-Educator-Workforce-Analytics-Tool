CREATE VIEW vw_Student AS

WITH SCHOOL_YEAR_NUMBERS AS (
    SELECT 0 AS YearOffset
    UNION ALL SELECT 1 UNION ALL SELECT 2  UNION ALL SELECT 3 UNION ALL SELECT 4 
),

/*SCHOOL_SESSIONS AS (
    SELECT csy.SchoolYearDescription, sesh.*
    FROM EdFi.SchoolYearType CSY 
    JOIN (SELECT SchoolYear,
		         SchoolId EducationOrganizationId,
			     Min(BeginDate) FirstBeginDate,
			     Max(EndDate) LastEndDate
	    FROM Edfi.[Session]
	    GROUP BY SchoolYear,
		         SchoolId
	    UNION
	    SELECT SchoolYear,
		         LocalEducationAgencyId EducationOrganizationId,
			     Min(BeginDate) FirstBeginDate,
			     Max(EndDate) LastEndDate
	    FROM Edfi.[Session]
	    JOIN Edfi.School	
		    ON school.schoolId = Session.SchoolId
	    GROUP BY SchoolYear,
		         LocalEducationAgencyId
	    ) Sesh
	    ON CSY.SchoolYear = Sesh.SchoolYear
),
*/
STUDENT_ASSOCIATION_BASE AS (
    -- Calculate the base association data with school year ranges
    SELECT
        t.StudentUSI AS StudentID,
        t.EntryDate AS StartDate,
       CASE
            WHEN t.ExitWithdrawDate IS NULL THEN GETDATE()
            ELSE t.ExitWithdrawDate
        END AS EndDate,
        -- Calculate the start year of the school year based on StartDate (August 1st to July 31st)
      CASE
            WHEN MONTH(t.EntryDate) >= 8 THEN YEAR(t.EntryDate)
            ELSE YEAR(t.EntryDate) - 1
        END AS SchoolYearStart,
       /*  (SELECT SchoolYear FROM SCHOOL_SESSIONS AS ss
            WHERE 
            ss.EducationOrganizationId = t.SchoolId and 
             t.EntryDate >=   ss.FirstBeginDate
            AND (t.EntryDate <= ss.LastEndDate)
          )
            AS SchoolYearStart,*/
        --ss.SchoolYear - 1 AS SchoolYearStart,
        --ss.SchoolYear AS SchoolYearEnd,
        -- Calculate the end year of the school year based on EndDate (August 1st to July 31st)
        -->>Added additional logic to ensure that the SchoolYearEnd field is never NULL.  
        -->>When no end date present, use current date
      /*  CASE
            WHEN t.ExitWithdrawDate is not null THEN
                (SELECT SchoolYear FROM SCHOOL_SESSIONS AS ss
                    WHERE 
                    ss.EducationOrganizationId = t.SchoolId and 
                     t.ExitWithdrawDate >=   ss.FirstBeginDate
                    AND (t.ExitWithdrawDate <= ss.LastEndDate)
                  )
            ELSE
                   (SELECT max(SchoolYear) FROM SCHOOL_SESSIONS AS ss
                        WHERE 
                        ss.EducationOrganizationId = t.SchoolId  
                      )  
          END            
                      AS SchoolYearEnd,*/
        CASE
            WHEN MONTH(t.ExitWithdrawDate) >= 8 AND t.ExitWithdrawDate is not null THEN YEAR(t.ExitWithdrawDate)
            WHEN MONTH(GETDATE()) >= 8 AND t.ExitWithdrawDate is null THEN YEAR(GETDATE())
            WHEN MONTH(t.ExitWithdrawDate) < 8 AND t.ExitWithdrawDate is not null THEN YEAR(t.ExitWithdrawDate)-1
            WHEN MONTH(GETDATE()) < 8 AND t.ExitWithdrawDate is null THEN YEAR(GETDATE())-1
        END AS SchoolYearEnd,
        SchoolId
    FROM
        [edfi].[StudentSchoolAssociation] AS t
      /*  JOIN SCHOOL_SESSIONS as ss
        ON ss.EducationOrganizationId = t.SchoolId
        where  t.EntryDate <=   ss.LastEndDate
       AND (t.ExitWithdrawDate >= ss.FirstBeginDate OR t.ExitWithdrawDate IS NULL)*/
),

SCHOOL_YEARS_EXPANDED AS (
    -- Cross join with the numbers to create all school years for each student association
    SELECT
        sab.StudentID,
        sab.StartDate,
        sab.EndDate,
        sab.SchoolYearStart,
        sab.SchoolYearEnd - syn.YearOffset AS SchoolYearEnd
    FROM
        STUDENT_ASSOCIATION_BASE sab
        CROSS JOIN SCHOOL_YEAR_NUMBERS syn
   WHERE
        -- Only include years that fall within the association period
       sab.SchoolYearEnd -  syn.YearOffset >= sab.SchoolYearStart
)


SELECT 
    sye.StudentID,
    -- Format the school year as 'YYYY-YYYY+1' based on the August-July definition
    CAST(sye.SchoolYearEnd -1  AS NVARCHAR(4)) + '-' + CAST(sye.SchoolYearEnd AS NVARCHAR(4)) AS SchoolYear,
    sye.SchoolYearEnd-1 AS SchoolYearStart,--Added SchoolYearStart as it's own field so that it can be used in Retention calculations
    sye.SchoolYearEnd,
	stud.[StudentUSI]
	,stud.[FirstName]
	,stud.[LastSurname]
	,ssa.[EntryDate]
	,ssa.[ExitWithdrawDate]
	,school.[NameOfInstitution] AS Campus
	,school.[EducationOrganizationId] AS SchoolId
	,lea.[NameOfInstitution] AS District
	,lea.[EducationOrganizationId] AS LEAId
	,r.[ShortDescription] AS RaceEthnic

FROM
    SCHOOL_YEARS_EXPANDED sye
INNER JOIN [edfi].[StudentSchoolAssociation] as ssa
    ON sye.StudentID = ssa.StudentUSI
    AND sye.StartDate = ssa.EntryDate
	LEFT JOIN   [edfi].[Student] AS stud --then adding student details for enrollment
		ON ssa.StudentUSI = stud.StudentUSI
	LEFT JOIN [edfi].[EducationOrganization] AS school --then seoa joined to school to get School Name
		on school.EducationOrganizationId = ssa.SchoolId
	LEFT JOIN [edfi].[School] AS SchoolLEA --now join school to get associated LEA
		ON SchoolLEA.SchoolId = ssa.SchoolId
	LEFT JOIN [edfi].[EducationOrganization] AS lea --finally join seoa again to get LEA Name
		ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
	LEFT JOIN  [edfi].[StudentEducationOrganizationAssociationRace] AS studRace --get race association
		ON StudRace.EducationOrganizationId = lea.EducationOrganizationId AND StudRace.StudentUSI = ssa.StudentUSI -- race per student per school
	LEFT JOIN [edfi].[Descriptor] as r
		ON r.DescriptorId = studRace.RaceDescriptorId
WHERE
    -- Ensure that the generated school year actually overlaps with the student's association period.
    -- This filters out school years that might be generated by the recursion but don't
    -- truly fall within the student's active association dates.
    (sye.EndDate IS NULL OR DATEFROMPARTS(sye.SchoolYearStart, 8, 1) <= sye.EndDate)
    AND
    (DATEFROMPARTS(sye.SchoolYearStart + 1, 7, 31) >= sye.StartDate)
