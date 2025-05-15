SELECT 
	seoaa.[BeginDate]
	,seoaa.[EducationOrganizationId]
	,scd.ShortDescription AS AssignmentType
	,seoaa.[StaffUSI]
	,cred.ShortDescription AS CredentialType
	,'' AS Segment --EducationOrganizationCategory goes here.
	,school.[NameOfInstitution] AS SchoolName
	,school.[EducationOrganizationId] AS SchoolId
	,lea.[NameOfInstitution] AS LEAName
	,lea.[EducationOrganizationId] AS LEAId
	,r.[ShortDescription] AS RaceEthnic
	,s.[FirstName]
	,s.[LastSurname]
	,s.[YearsOfPriorTeachingExperience]
	,seoaa.[EndDate]
	,seoaa.[PositionTitle]

FROM [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[StaffEducationOrganizationAssignmentAssociation] as seoaa -- starting with Staff EdOrg because it contains historical
	Left Join [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Staff] AS s
		ON s.StaffUSI = seoaa.StaffUSI
	left Join [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[StaffRace] AS sr
		ON sr.StaffUSI = seoaa.StaffUSI
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[EducationOrganization] AS school --then seoa joined to school to get School Name
		ON school.EducationOrganizationId = seoaa.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[School] AS SchoolLEA --now join school to get associated LEA
		ON SchoolLEA.SchoolId = seoaa.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[EducationOrganization] AS lea --finally join seoa again to get LEA Name
		ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Descriptor] AS r
		ON r.DescriptorId = sr.RaceDescriptorId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Descriptor] AS scd
		ON scd.DescriptorId = seoaa.StaffClassificationDescriptorId
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[StaffCredential] AS sc
		ON sc.StaffUSI = s.StaffUSI
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Credential] AS c
		ON c.CredentialIdentifier = sc.CredentialIdentifier
	LEFT JOIN [EdFi_Ods_Sandbox_oKFXKjFNu2jK].[edfi].[Descriptor] AS cred
		ON cred.DescriptorId = c.CredentialFieldDescriptorId