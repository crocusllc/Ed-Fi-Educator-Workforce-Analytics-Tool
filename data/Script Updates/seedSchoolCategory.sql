begin transaction;

insert into edfi.SchoolCategory (schoolId, SchoolCategoryDescriptorId)
select educationOrganizationId, DescriptorId 
from edfi.descriptor
CROSS JOIN edfi.EducationOrganization
where codevalue like 'High School'
and namespace like '%schoolCat%'
and nameofinstitution in (	'Valley High',
							'Sheldon High School',
							'Rosemont High',
							'School of Engineering & Sciences');

insert into edfi.SchoolCategory (schoolId, SchoolCategoryDescriptorId)
select educationOrganizationId, DescriptorId 
from edfi.descriptor
CROSS JOIN edfi.EducationOrganization
where codevalue like 'Elementary School'
and namespace like '%schoolCat%'
and nameofinstitution in (	'John D. Sloat Elementary','Father Keith B. Kenny');

commit;

