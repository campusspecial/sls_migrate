Springloops Migration
===========

# Description
This is an issue migration tool intended for transferring tasks from the Springloops issue tracker to GitHub. Although this is primarily intended for importing to GitHub, feel free to integrate other issue trackers toward which to export.

The GitHub issues export tool will be formatted for use with [Huboard](https://huboard.com) issue dashboard (it's [open source](https://github.com/rauhryan/huboard)!), but suggestions for improvement are welcome. Please open an issue accordingly.

# Instructions
1. Export all issues from Springloops into a CSV
2. Create database.yml from database.example.yml and enter 
3. Create springloops.yml from springloops.example.yml and enter your account information for Springloops
4. Create github.yml from github.example.yml and enter your account information for GitHub
5. Import tasks from Springloops with `$ ruby bin/sls_import`
6. Create a repository on Github for each project in Springloops
7. Export tasks to GitHub with `$ ruby bin/github_export`
