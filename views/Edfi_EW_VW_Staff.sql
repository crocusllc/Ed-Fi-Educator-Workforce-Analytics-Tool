SELECT 
	seoaa.[BeginDate]
	,seoaa.[EducationOrganizationId]
	,seoaa.[StaffUSI]
	,seoaa.[EndDate]
	, CASE
		WHEN [EndDate] is null THEN null
		WHEN month([EndDate]) >= 6 then year([EndDate])
		ELSE year([EndDate])-1
		END
		AS nonRetentionYear
	,scd.CodeValue AS StaffAssignmentType
	,'Math/FineArts, etc..TBD' AS AssignmentSubjectCategory --depending on decision.
	,'High,Elementary etc' AS SchoolSegment -- will be mapped to [edfi].[EducationOrganizationCategory] once populated
	,cred.ShortDescription AS CredentialType
	,school.[NameOfInstitution] AS Campus -- Name used in the Dashboard
	,school.[EducationOrganizationId] AS SchoolId
	,lea.[NameOfInstitution] AS District --Name used in the Dashboard
	,lea.[EducationOrganizationId] AS LEAId
	,r.[CodeValue] AS RaceEthnic
	,s.[FirstName]
	,s.[LastSurname]
	,s.[YearsOfPriorTeachingExperience]


FROM [EdFi_Ods_Populated_Template].[edfi].[StaffEducationOrganizationAssignmentAssociation] as seoaa -- starting with Staff EdOrg because it contains historical
	Left Join [EdFi_Ods_Populated_Template].[edfi].[Staff] AS s -- Add staff table for demographics
		ON s.StaffUSI = seoaa.StaffUSI
	left Join [EdFi_Ods_Populated_Template].[edfi].[StaffRace] AS sr -- Add Staff Race
		ON sr.StaffUSI = seoaa.StaffUSI
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS school --then seoa joined to school to get School Name
		ON school.EducationOrganizationId = seoaa.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[School] AS SchoolLEA --now join school to get associated LEA
		ON SchoolLEA.SchoolId = seoaa.EducationOrganizationId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[EducationOrganization] AS lea --finally join seoa again to get LEA Name
		ON lea.EducationOrganizationId = SchoolLEA.LocalEducationAgencyId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS r --Add race descriptor
		ON r.DescriptorId = sr.RaceDescriptorId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS scd --add staff classification
		ON scd.DescriptorId = seoaa.StaffClassificationDescriptorId
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[StaffCredential] AS sc
		ON sc.StaffUSI = s.StaffUSI
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Credential] AS c -- Add in staff credential and descriptor
		ON c.CredentialIdentifier = sc.CredentialIdentifier
	LEFT JOIN [EdFi_Ods_Populated_Template].[edfi].[Descriptor] AS cred
		ON cred.DescriptorId = c.CredentialFieldDescriptorId