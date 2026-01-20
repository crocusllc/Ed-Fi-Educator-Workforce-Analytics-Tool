BEGIN transaction;

declare @AddressTypeDescriptor int;
declare @StateDescriptor int;

SELECT  @AddressTypeDescriptor = descriptorId 
FROM edfi.Descriptor
where namespace = 'uri://ed-fi.org/AddressTypeDescriptor'
and CodeValue = 'Physical';

SELECT @StateDescriptor = DescriptorId
FROM edfi.descriptor
where namespace like '%StateAbb%'
and CODEVALUE like 'CA';

INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (34673143,@AddressTypeDescriptor,'Sacramento','95827',@StateDescriptor,'9594 Kiefer Blvd',38.5436223576072,-121.341273139255);
INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (346731434,@AddressTypeDescriptor,'Sacramento','95823',@StateDescriptor,'6300 Ehrhardt Ave',38.4539617180862,-121.429319548908);
INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (346731435,@AddressTypeDescriptor,'Sacramento','95829',@StateDescriptor,'8333 Kingsbridge Dr',38.4559488009049,-121.346660675896);
INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (346743901,@AddressTypeDescriptor,'Sacramento','95831',@StateDescriptor,'7345 Gloria Dr',38.4943722117678,-121.536253875893);
INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (346743960,@AddressTypeDescriptor,'Sacramento','95822',@StateDescriptor,'7525 Candlewood Way',38.4848377632891,-121.499993671164);
INSERT INTO [edfi].[EducationOrganizationAddress] (EducationOrganizationId  ,AddressTypeDescriptorId,City,PostalCode,StateAbbreviationDescriptorId ,StreetNumberName  ,Latitude ,Longitude)  VALUES (346743961,@AddressTypeDescriptor,'Sacramento','95817',@StateDescriptor,'3525 Martin Luther King Jr Blvd',38.5427833280194,-121.464315369316);

commit;
