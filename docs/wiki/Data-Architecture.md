Dashboards developed for the Workforce Analytics Tool are supported by several views built on top of an Ed-Fi data store.
* [Edfi_EW_VW_Vacancy.sql](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/blob/main/views/Edfi_EW_VW_Vacancy.sql)
* [Edfi_EW_VW_Staff.sql](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/blob/main/views/Edfi_EW_VW_Staff.sql)
* [Edfi_EW_VW_Students.sql](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/blob/main/views/Edfi_EW_VW_Student.sql)


Each view is designed to provide the necessary data to the dashboard with minimal additional transformations in Power BI. Because dashboards rely on time-series data to display trends over time, individual vacancy and staff records—containing begin and end dates—are transformed into annual datasets using cross joins. The diagram below shows where data is transformed prior to being visualized in the dashboards.


![Data Architecture](https://drive.google.com/uc?export=view&id=1kJtxAZHbjyW36smU3tN1ad6nSwJ7sfzi)


