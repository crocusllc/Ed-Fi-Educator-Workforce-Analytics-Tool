CREATE VIEW vw_StudentStaff_demographics AS
 With students as ( 
 SELECT distinct
      [StudentUSI] as ID
      ,Campus
      ,District
      ,SchoolYear
      ,RaceEthnic
      ,'Student' as TypeOf
  from [EdFi_Ods_Populated_Template].[dbo].[vw_Student]
  WHERE ExitWithdrawDate is null), 

staff as (
    SELECT  distinct
      [TeacherID] AS Id
      ,Campus as SchoolName
      ,District as LEAName
      ,SchoolYear
      ,RaceEthnic
      ,'Staff' as TypeOf
      from vw_Staff
      )

Select * from students

union all

Select * from staff