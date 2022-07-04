# Data Loading for OEREB

The goal of these scripts is to facilitate the data loading of OEREB data into the DB used by [pyramid_oereb](https://github.com/openoereb/pyramid_oereb)
It is mainly used for loading data of federal themes. However if the structure is correct it can also be used for other themes.

The data is loaded using ili2pg and it is loaded into a postgres DB with postgis.

## How to Install and Run the Project

The project consists of two bash scripts and a csv file containing the configurations for each theme to be loaded.

To load a bunch of themes configured in `FEDTHEMES.csv` use the command

```
$ ./load_fed_themes.sh --PGHOST dbhost --PGPASSWORD dbpass --PGUSER dbuser --PGPORT dbport --PGDB d_name
```
to get detailed information on how to run use:
```
$ ./load_fed_themes.sh -h
```

To load only a single Theme you can either configure the `FEDTHEMES.csv` or use directly the script `loaddata.sh`

With `docker-compose.yaml` an empty example DB is provided that can be used to test writing data using the scripts.

## Update the script in a local project

To include the scripts within a project you can use `update_script_data_import.sh` to get updates.

**Note:** this is not very well tested so be carful!!!

# How to read the error_logs.log

This log file contains the log information for every theme that ran into an error when it ran through `loaddata.sh`
The following table is the result when running the scripts with the example configuration from `FEDTHEMES.csv`.

|error time|layer_id|schema|line number|bash_command|error msg|
|---|---|---|---|---|---|
|2022-07-04 20:47:18|ch.astra.baulinien-nationalstrassen_v2_0.oereb|motorways_building_lines|195|exit 1|No valide law file to import!|
|2022-07-04 20:48:16|ch.bav.kataster-belasteter-standorte-oev_v2_0.oereb|contaminated_public_transport_sites|77|exit 1|The file http://bad_download_url is not available.|
2022-07-04 20:48:33|ch.BelasteteStandorte|contaminated_sites||`java -jar ${ili2pg} --import --dbhost ${PGHOST} --dbport ${P}...`||

# TODO

- test the update function
- improve input reading
- add config for a docker container in which the scripts can be run
