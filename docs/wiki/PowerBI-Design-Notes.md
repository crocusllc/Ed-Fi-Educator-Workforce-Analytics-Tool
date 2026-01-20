
## Calculated Metrics used within PowerBI

### Retained Staff District Percent
```
RetainedStaffDistrictPercent = 
DIVIDE(
    CALCULATE(
        DISTINCTCOUNT(vw_Staff[TeacherID]),
        FILTER(vw_Staff,vw_Staff[RetentionStatus] = "RetainedDistrictAndSchool" || vw_Staff[RetentionStatus] = "RetainedDistrictNotSchool")), 
    CALCULATE(
        DISTINCTCOUNT(vw_Staff[TeacherID]), 
        ALL(vw_Staff[RetentionStatus]))
    )
```

### Retained Staff School Number
```
RetainedStaffSchoolNumber = 
    CALCULATE(
        DISTINCTCOUNT(vw_Staff[TeacherID]),
        FILTER(vw_Staff,vw_Staff[RetentionStatus] = "RetainedDistrictAndSchool"))
```

### Retained Staff School Percentage
```
RetainedStaffSchoolPercent = 
DIVIDE(
    CALCULATE(
        DISTINCTCOUNT(vw_Staff[TeacherID]),
        FILTER(vw_Staff,vw_Staff[RetentionStatus] = "RetainedDistrictAndSchool")), 
    CALCULATE(
        DISTINCTCOUNT(vw_Staff[TeacherID]), 
        ALL(vw_Staff[RetentionStatus]))
    )
```

### Last Refreshed Date
```
Last Refreshed = MAX(vw_VacancyData[LastRefreshed]) 
```