# HelloID-Conn-Prov-Source-Personio

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.       |
<br />
<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/personio-logo.png">
</p>
<br />

HR System personio.de

## Introduction

This connector retrieves HR data from the Personio API. You need to allow some field the API is allowed to access in Personio

| :information_source: License Information |
|:---------------------------|
| To use the Personio API you now need to have the Professional or Enterprise license. If you don't you have to use a CSV. You can use the "Automation Plus" License to automate the export       |

# Personio API Documentation
[https://developer.personio.de/reference#employees-1](https://developer.personio.de/reference/get_company-employees)

## Getting started
To Start with the sync you need to get your API Credentials from: https://<customer>.personio.de/configuration/api/credentials
Also you need to select the Fields you want to use: https://<customer>.personio.de/configuration/api/access
Required Fields are: First name, Last name, Hire date, Termination date (or some variant), Department, Employee ID

### Configuration Settings
Use the configuration.json in the Source Connector on "Custom connector configuration". You can use the created credentials on the Configuration Tab to set the ClientID and ClienSecret and your Client Domain in Upper Case Letters without dashes.

### Mappings
Use the personMapping_employment.json and contractMapping_employment.json Mappings as example and remove the Fields you didn't select on the Personio Api Access Page

# HelloID Docs
The official HelloID documentation can be found at: https://docs.helloid.com/
