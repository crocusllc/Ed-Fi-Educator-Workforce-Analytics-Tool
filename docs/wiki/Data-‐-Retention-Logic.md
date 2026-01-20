## **Retention Scenarios**

The retention scenarios are driven by teachers in the sample data set with more than one assignment.  Additional sample data or actual staff assignment data will allow for a more comprehensive test of retention logic.

| Scenario | TeacherID | Conditions | Non Retention Year | Category | Rationale |
| :---- | :---- | :---- | :---- | :---- | :---- |
| 1 | 1151 | Left School A, District A June 11, 2021 Started School A District A June 11, 2021 | 2020-2021 | RetainedDistrictAndSchool | Teacher has two records showing that they left and returned on the same day. Hence, they are considered retained. |
| 2 | 1151 | Left School A District A 8/14/2024  No subsequent enrollment | 2023-2024 | NoLongerInCounty | Any staff exit with no subsequent enrollment will show as NoLongerIn County and  no longer  in the district (for LEA version). |
| 3 | 1236 | Left School A, District A June 11, 2021 Started School B, District B August 3, 2022 | 2020-2021 | NoLongerInCounty | This staff returned, but not the following year.  Hence considered non-returning in the year they left. |
| 4 | 1956 | Left School A: June 15, 2019  Started School B in the same district: July 1, 2020 | 2018-2019 | RetainedDistrictNotSchool | Teacher switched schools within the district.  |
| 5 | 2035 | Left School A District A June 11, 2019  Started School B District A July 1 2019 | 2018-2019 | RetainedDistrictNotSchool | Teacher switched schools within the county and stayed within the same district. |
| 6 | 2125 | Left School A District A June 12, 2020  Started School B District A July 1 2021 | 2019-2020 | RetainedDistrictNotSchool | Teacher switched schools within the county and stayed in the same district. |


