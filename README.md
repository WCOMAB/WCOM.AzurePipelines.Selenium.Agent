# Azure DevOps Pipelines Selenium Agent docker image

[![Build Status](https://dev.azure.com/wcom/General/_apis/build/status%2FWCOM.AzurePipelines.Selenium.Agent?branchName=main)](https://dev.azure.com/wcom/General/_build/latest?definitionId=107&branchName=main)

Docker image which can be used to build Azure Pipelines Selenium tests running on i.e. in a AKS cluster.

## Installed SDKs

* Selenium Chromium web driver
* .NET 6
* .NET 7
* .NET 8
* Node LTS
* Python 3

## Environment variables

* `AZP_TOKEN` - Azure DevOps PAT used to register agent
* `AZP_URL` - Azure DevOps org base url
* `AZP_POOL` - Azure Pipelines Agent pool to register with.
* `AZP_ARGS`- Optional variable for arguments to the build agent i.e. `--once`.
