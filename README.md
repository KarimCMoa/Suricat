# Suricat
Suricat is a tool that allows you to detect and send alerts about various things on your computer (Windows) via messages on the Telegram tool.

Yes I know, for the moment it's a powershell file, I'll change that in the future but right now I'm very lazy (I'm going to be very lazy so don't expect too much maintenance)

## Features
- Telegram integration for effective notifications
- Notifications are currently not sent instantly, I need to fix this
- System for excluding folders from detection (e.g. temp folder)
- System for directly hardcoding the list of disks to be monitored
- Automatic detection of all disks will come in time if I'm not too lazy.

## Start & Stop
- When a computer turns on
- When a computer is put to sleep
- When a computer shuts down

## Files
- When a file has been created
- When a file has been modified
- When a file has been replaced
- When a file has been deleted

## Informations
For each message sent, the following information will be present:
- Local IP address
- Public IP address
- Computer name
- User account
- Date
- Time of day

## To make it work:
### Step 1
Open the task scheduler
Click on “Action”, then on “Create a task”.
Give the task a name
Check “Run even if user is not logged in” and “Do not save password. The task only accesses local resources”.
Check “Run with maximum permissions”.
Select “Windows 10” in “Configure for”.
### Step 2
Go to “Triggers” then click on “New”.
Select “On startup”.

### Step 3
Go to “Actions” then click on “New”.
Select “Start a program
In Program/script, select “powershell” and in “Add arguments”, give the path to the ps1 file (example: -File “C:\ProgramData\Detector.ps1”)

### Step 4
Go to “Conditions” and check that everything is unchecked

### Step 5
Check everything except “Stop the task if it runs more than” and “If no new execution is scheduled, delete the task”.
Select the drop-down menu and click on “Do not start a new instance”.

### Step 6
All set for the task scheduler part, go to the powershell file and put in the Telegram token and chatId