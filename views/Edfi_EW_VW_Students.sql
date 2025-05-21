SELECT 
	stud.[StudentUSI]
	,stud.[FirstName]
	,stud.[LastSurname]
	,ssa.[EntryDate]
	,'' AS SchoolYear
	,ssa.[ExitWithdrawDate]
	,school.[NameOfInstitution] AS SchoolName
	,school.[EducationOrganizationId] AS SchoolId
	,lea.[NameOfInstitution] AS LEAName
	,lea.[EducationOrganizationId] AS LEAId
	,r.[ShortDescription] AS RaceEthnic

FROM [EdFi_Ods_Populated_Template].[edfi].[StudentSchoolAssociation] as ssa -- starting with studentSchool because it contains entry/exit dates to enable historical view
	LEFT JOIN   [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Student] AS stud --then adding student details for enrollment
		ON ssa.StudentUSI = stud.StudentUSI
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[EducationOrganization] AS school --then seoa joined to school to get School Name
		on school.EducationOrganizationId = ssa.SchoolId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[School] AS SchoolLEA --now join school to get associated LEA
		ON SchoolLEA.SchoolId = ssa.SchoolId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[EducationOrganization] AS lea --finally join seoa again to get LEA Name
		ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
	LEFT JOIN  [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[StudentEducationOrganizationAssociationRace] AS studRace --get race association
		ON StudRace.EducationOrganizationId = lea.EducationOrganizationId AND StudRace.StudentUSI = ssa.StudentUSI -- race per student per school
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Descriptor] as r
		ON r.DescriptorId = studRace.RaceDescriptorId
