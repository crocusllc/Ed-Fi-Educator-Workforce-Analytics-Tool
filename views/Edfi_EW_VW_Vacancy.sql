SELECT
	osp.[EducationOrganizationId]
	--,osp.PositionTitle --We can't really use this in the dashbaords. Include?
	--,osp.CreateDate --Do we care about this?  I think not
	,osp.DatePosted
	,osp.DatePostingRemoved
	,CASE WHEN osp.DatePostingRemoved IS NULL THEN 1 ELSE 0 END as isPositionOpen --keeping calculations on DB side by adding counter here
	,'Math/FineArts, etc..TBD' AS AssignmentCategory-- Mapping and inclusion in Dashboard TBD
	,'High,Elementary etc' AS Segment -- will be mapped to [edfi].[EducationOrganizationCategory] once populated
	,scd.CodeValue AS AssignmentType
	,school.[NameOfInstitution] AS Campus --Name used in the Dashboard
	,school.[EducationOrganizationId] AS SchoolId
	/*NOTE:  Handling for Vacancies at the District level by placing district name/ID in place of school.
	This substitution will allow them to appear in the Vacancies by Campus chart. Need to validate behavior*/
	,CASE WHEN lea.[NameOfInstitution] IS NULL THEN school.[NameOfInstitution] ELSE lea.[NameOfInstitution] END AS District --Name used in the Dashboard
	,CASE WHEN lea.[EducationOrganizationId] IS NULL THEN school.[EducationOrganizationId] ELSE lea.[EducationOrganizationId] END AS LEAId
	,CASE
		WHEN MONTH(osp.DatePosted) >= 8 THEN
			CAST(YEAR(osp.DatePosted) AS VARCHAR(4)) + '-' + CAST(YEAR(osp.DatePosted) + 1 AS VARCHAR(4))
		ELSE
			CAST(YEAR(osp.DatePosted) - 1 AS VARCHAR(4)) + '-' + CAST(YEAR(osp.DatePosted) AS VARCHAR(4))
	END AS SchoolYear
	,CASE -- To be changed when Session table is updated
		WHEN MONTH(osp.DatePosted) BETWEEN 8 AND 10 THEN 'Fall' -- Aug, Sept, Oct
		WHEN MONTH(osp.DatePosted) IN (11, 12, 1) THEN 'Winter' -- Nov, Dec, Jan
		WHEN MONTH(osp.DatePosted) BETWEEN 2 AND 4 THEN 'Spring' -- Feb, March, April
		WHEN MONTH(osp.DatePosted) BETWEEN 5 AND 7 THEN 'Summer' -- May, June, July
		ELSE 'Unknown' -- Fallback for any unexpected month values
	END AS Session
FROM [EdFi_Ods_Populated_Template].[edfi].[OpenStaffPosition] AS osp
	LEFT JOIN  [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS eo --Organization associated to the vacancy
		ON osp.EducationOrganizationId = eo.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS school --then seoa joined to school to get School Name
		ON school.EducationOrganizationId = osp.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[School] AS SchoolLEA --now join school to get associated LEA
		ON SchoolLEA.SchoolId = osp.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS lea --finally join seoa again to get LEA Name
		ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS scd --add staff classification
		ON scd.DescriptorId = osp.StaffClassificationDescriptorId
