# AzureLimitsQuotas

# Prerequisites

# Including required modules
Install Module AZ.ResourceGraph (Powershell 7.2)
1- Access the automation account
2- Go to Shared Resources > Modules
3- Click on "Add Module"
4- Select "Browse from Galery"
5- Click on "Click here to browse from gallery"
6- Search for "Az.ResourceGraph"
7- Click on the module, and click on "Select"
8- Select the runtime Version "7.2"
9- Click on Import

![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/1616ba61-a687-439e-822e-5ed22ed0ce72)

# Creating variables
1- In your Automation Account, click on "Shared Resources" > "Variables"
2- Click on Add variable
3- In the name, add "AppId", in the value include the AppID and change the switch to encrypt the value
4- Repeat the steps for following variables: "CustomerId", "PWord", "SharedKey", "TenantId" (Encryption optional)

# Setting permission to the System Signed Identity
1- In your automation account, go to "Account Settings" > "Identity"
2- Click on "Azure Role Assignments"
3- Click On "Add Role Assignment"
4- Select the subscription in the scope
5- Select the Reader Role and click "Save"

# Deploying the code

# Create the runbook
1- In your automation account, go to "Process Automation" > "Runbooks"
2- Click on "Create a runbook"
4- Add a name, Select "PowerShell" from "Runbook Type", select "7.2" in the "Runtime version", and click on "Review + Create" > "Create"
5- In the runbook once created, click on "Edit" > "Edit in Portal"
6- Paste the code in the edit panel
7- Save the code
8- Go to Test Pane, and start a test
9- If the code returns "200" in the output, click on "Publish" to publish the code

# Creating schedule for the code
1- In your automation account, click on "Shared Resources" > "Schedules"
2- Click on "Add a Schedule"
3- Add a Name, select the start date and time and change the recurency to "Recurring"
4- Change the recurrency to "1 Day" and set expiration to "Never"
5- Click on "Create"
6- Go to your Runbook: In your automation account, go to "Process Automation" > "Runbooks" > Click on your runbook
7- Click on "Resources" > "Schedule"
8- Click on "Add Schedule"
9- Click on "Schedule"
10- Select the previously created schedule and save

![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/6e01f347-3ca8-48d7-b0d1-5b6b7fd64ed8)

# Expected Results
![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/020e562d-3cf3-4b3a-bf33-6673340d2ad2)

# Next Steps
Setup Alerts based on a sheduled query in the Log Analytics Workspace Custom Table that was created, and searching for "PercentageUsed" over 80%
Create action groups accorting to your need
