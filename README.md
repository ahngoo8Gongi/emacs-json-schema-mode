# GNU emacs schema validation for JSON and YAML
Provides GNU emacs modes for JSON and YAML that allow to validate data
against JSON schemata.

*NOTICE*: This software is shared for research and collabration purposes.
Please consider the warranty disclaimer:

THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

## License
1. This package is distributed under terms of the 
   GNU General Public License Version 3.0 or later
1. The file schema.json has originally been licensed under terms
   of the licenses displayed in LICENSE.schema.json

## Prerequisites
1. Requires "kwalify" as schema validator on your $PATH

## Usage
Files of which the file name ends with .json or .yaml are automatically opened
in json-mode or yaml-mode with automatic validation after save enabled 
by default.

In these modes, there is an additional menu "Schema validation" from which
schema validation can be manually triggered.

Alsonteractive command schema-validate-buffer is available to trigger manual
schema validation.

Validation results are printed to buffer \*SCHEMA\*.

### Configuration
Association between schemata and file is established based on file names.
These relationships are established via configuration files in directories
named '.emacs.d'. On validation request, the directory holding the file
to validate and all paretn directories are searched for configuration files.

File names of the configuration files for the validating modes end with 
'schema.config'.  Each of them contains a LISP list of that the CAR is 
'schema-patterns' followed by a list of lists that hold the associations.
The CAR of these lists is a regular expression to match the file names.
The CDR is a fully qualified path of a schema to validate file against.

Multiple matches, also from different configuration files, lead to multiple
validations.

#### Example file schema.config
    ("schema-patterns" (
        (".*\.schema.json$" "/usr/share/schema.json") 
	("^data.json$" "/home/user/data.schema.json")
    ))

According to this configration any file of which the name ends with 
'schema.json' will be validated against the JSON schema in 
'/usr/share/schema.json' (typically the JSON schema describing JSON 
schema) and any file named 'data.json' will be validated against the
JSON schema '/home/user/data.schema.json'.
