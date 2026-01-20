## Accessing PowerBI Files

1. Ensure that your github account has been given access to the appropriate Crocus Repository
2. Log Into Github
3. Go to the following page: [.pbix Files](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/tree/main/pbix/MasterFiles)
4. Download the most current file to your desktop
## Opening PowerBI Files 
1. Download PowerBI desktop from the  [Official Windows Site](https://www.microsoft.com/en-us/download/details.aspx?id=58494)
2. Install the program on your local machine.
3. Use it to open the previously downloaded .pbix file.


## Setting Up Database
1. Create and provision your Microsoft SQL Database, ensuring that security is set up in alignment with your districts policies.
2. Load data into Ed-Fi Tables using the [Staff Overview](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/wiki/Data-%E2%80%90-Staff-Overview), [Vacancy Overview](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/wiki/Data-%E2%80%90-Vacancy-Overview) and [Student Overview](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/wiki/Data-%E2%80%90-Student-Overview) from this wiki as a guide.
3. Download [View Files](https://github.com/crocusllc/Ed-Fi-Educator-Workforce-Analytics-Tool/tree/main/views)
3. Upload and run scripts to create views to your database.

## Connecting to Data
1. When you first open the workbook, charts will not render because you are not connected to the data source.  You should be automatically prompted to enter the data credentials.  (If not, click "Refresh Data")
2. Select Database in the left tab, then enter the username and password provisioned for your Database.
![Get Data](https://drive.google.com/uc?export=view&id=1VKWVsePCixsCDZFW6AvOKnbT4sV47xA1)
3. If you are prompted to allow unencrypted data connection, do so by clicking "OK".
![Get Data](https://drive.google.com/uc?export=view&id=1yCot19cEo71V1NnyebWudi3IlLuy_JyG)

Once connected, all charts will automatically render.


## Troubleshooting
1. If setup does not work, reach out to your Ed-Fi contact for support.
