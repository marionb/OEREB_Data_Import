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

### Using Docker:

The `docker-compose.yaml` contains an empty example DB is provided as well as a container which launches the script. To run:

1. Create a `.env` (an example is given in `sample.env`). Specify another DB connection if needed
2. Run:
    ```
    $ docker compose up --build
    ```
3. The container logs show if a theme could not be imported.

## Update the script in a local project

To include the scripts within a project you can use `update_script_data_import.sh` to get updates.

**Note:** this is not very well tested so be carful!!!$

## The `FEDTHEMES.csv`

This file contains the configuration of the individual themes. It is a comma separated csv file and contains the following information:

|ID|DB SCHEMA|Load THEME Y/N|DOWNLOAD|INPUT_LAYER|LAWS|
|---|---|---|---|---|---|
|The theme ID. This is given for fed. themes|the name of the DB schema into which the data will be loaded|Determines if the theme is treated by the script od not|The download path if data for the data. If not given the default is `https://data.geo.admin.ch/<INPUT_LAYER>/data.zip`|The ID of the theme. Mainly used to create the default download URL|An option to customize the URL/file path where the laws can be found. This is a list separated by `;` Defaults to `http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml`|

This is with exception to the DB connection all the information needed to run the script `loaddata.sh`. It is passed to the script `load_fed_themed.sh` which iterates through all the entries in the file and executes `loaddata.sh` with them.

Another file name or path can be passed with `--file | -f`.

## How to read the error_logs.log

This log file contains the log information for every theme that ran into an error when it ran through `loaddata.sh`
The following table is the result when running the scripts with the example configuration from `FEDTHEMES.csv`.

|error time|layer_id|schema|line number|bash_command|error msg|
|---|---|---|---|---|---|
|2022-07-04 20:47:18|ch.astra.baulinien-nationalstrassen_v2_0.oereb|motorways_building_lines|195|exit 1|No valide law file to import!|
|2022-07-04 20:48:16|ch.bav.kataster-belasteter-standorte-oev_v2_0.oereb|contaminated_public_transport_sites|77|exit 1|The file http://bad_download_url is not available.|
2022-07-04 20:48:33|ch.BelasteteStandorte|contaminated_sites||`java -jar ${ili2pg} --import --dbhost ${PGHOST} --dbport ${P}...`||

**NOTE** currently they are not persists running the script within the docker container. The content is how ever output at the end if a theme did not load properly

# TODO

- test the update function
- improve input reading
- add config for a docker container in which the scripts can be run
- complete dependency list
- spellcheck!
- add option to read from pyramid_oereb config ---> ???
