# AzureLimitsQuotas

# Prerequisites

# Including required modules
Install Module AZ.ResourceGraph (Powershell 7.2)<br />
1- Access the automation account <br />
2- Go to Shared Resources > Modules<br />
3- Click on "Add Module"<br />
4- Select "Browse from Galery"<br />
5- Click on "Click here to browse from gallery"<br />
6- Search for "Az.ResourceGraph"<br />
7- Click on the module, and click on "Select"<br />
8- Select the runtime Version "7.2"<br />
9- Click on Import<br />

![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/1616ba61-a687-439e-822e-5ed22ed0ce72)

# Creating App Registration
1- From the Azure Portal, access Entra ID<br />
2- Click on App Registrations<br />
3- Click on New registration<br />
4- Add the App Name<br />
5- Click on Register<br />
6- Once the App is created, click on "Certificate & Secrets"<br />
7- Click on "New client secret"<br />
8- Add a name for the secret and click on "Add"<br />
9- Once created, copy the secret value (It will be used for the PWord variable later)<br />

# Creating variables
1- In your Automation Account, click on "Shared Resources" > "Variables"<br />
2- Click on Add variable<br />
3- In the name, add "AppId", in the value include the AppID and change the switch to encrypt the value<br />
4- Repeat the steps for following variables: "CustomerId" (LAW - Agents - Workspace ID), "SharedKey" (LAW - Agents - Primary Key), AppID (App ID for the Custom App created on Entra), "PWord" (,Secret created for the App), "TenantId" (In the top search bar, search for Tenant properties, and copy the Tenant ID)(Encryption optional)<br />

# Setting permission to the System Signed Identity
1- In your automation account, go to "Account Settings" > "Identity"<br />
2- Click on "Azure Role Assignments"<br />
3- Click On "Add Role Assignment"<br />
4- Select the subscription in the scope<br />
5- Select the Reader Role and click "Save"<br />

# Deploying the code

# Create the runbook
1- In your automation account, go to "Process Automation" > "Runbooks"<br />
2- Click on "Create a runbook"<br />
4- Add a name, Select "PowerShell" from "Runbook Type", select "7.2" in the "Runtime version", and click on "Review + Create" > "Create"<br />
5- In the runbook once created, click on "Edit" > "Edit in Portal"<br />
6- Paste the code in the edit panel<br />
7- Save the code<br />
8- Go to Test Pane, and start a test<br />
9- If the code returns "200" in the output, click on "Publish" to publish the code<br />

# Creating schedule for the code
1- In your automation account, click on "Shared Resources" > "Schedules"<br />
2- Click on "Add a Schedule"<br />
3- Add a Name, select the start date and time and change the recurency to "Recurring"<br />
4- Change the recurrency to "1 Day" and set expiration to "Never"<br />
5- Click on "Create"<br />
6- Go to your Runbook: In your automation account, go to "Process Automation" > "Runbooks" > Click on your runbook<br />
7- Click on "Resources" > "Schedule"<br />
8- Click on "Add Schedule"<br />
9- Click on "Schedule"<br />
10- Select the previously created schedule and save<br />

![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/6e01f347-3ca8-48d7-b0d1-5b6b7fd64ed8)

# Expected Results
![image](https://github.com/gplima89/AzureLimitsQuotas/assets/108761690/020e562d-3cf3-4b3a-bf33-6673340d2ad2)

# Next Steps
Setup Alerts based on a sheduled query in the Log Analytics Workspace Custom Table that was created, and searching for "PercentageUsed" over 80%<br />
Create action groups accorting to your need
