#!/bin/bash

# What the script does:
#----------------------
#   1. Downloads a federal oereb theme form data.geo.admin.ch
#   2. Creats a new DB schema with the needed structur
#   3. Downloads and adds the laws in to the DB
#   4. Loads the theme data into the DB
#
#   -> Once the data is loaded in to the DB this can be used for pyramid_OEREB
#
# What the script Depends on:
#----------------------------
#   For loading the intelis data and creating the schema ili2pg is used. If it is not available it will be downloaded.
#   The version can be set on running the script
#
# How to run:
#------------
#   $ bash loaddata.sh INPUT_LAYER SCHEMA_NAME [illi2pg_version]
#   i.e:
#   $ bash loaddata.sh ch.bav.kataster-belasteter-standorte-oev_v2_0.oereb contaminated_public_transport_sites
#
#   INPUT_LAYER: one of the available federal themes
#   ili2pg_version: an available version of ili2pg (https://downloads.interlis.ch/ili2pg/)
#
# Note:
#------
#   You will need to adapt the DB connection parameter so it fits your need
#
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland

############################################################
# help                                                     #
############################################################
help()
{
   # Display Help TODO
   echo "Add description of the script functions here."
   echo
   echo "Syntax: scriptTemplate [-g|h|v|V]"
   echo "options:"
   echo "g     Print the GPL license notification."
   echo "h     Print this Help."
   echo "v     Verbose mode."
   echo "V     Print software version and exit."
   echo
}

############################################################
# check_data                                               #
############################################################
check_data() {
    # Check if tranlsation files for Text and Theme exist.
    file_to_check=${1}
    if ( ! wget --spider "${file_to_check}" 2>/dev/null ); then
       echo "The file ${file_to_check} is not available."
       echo "Check if the file name has change"
       exit 1
    fi
    echo "File ${ifile_to_check} is available - continuing"
}

############################################################
# download_targets                                         #
############################################################
download_targets() {
    local target="${1}"
    echo "downloading file ${target}"
    echo "${PWD}"
    wget -N --backups ${target}
}

############################################################
# run_check                                                #
############################################################
run_check() {
    # 1. check imput:
    if [ "${INPUT_LAYER}" = "" ];
    then
        echo "No theme is specified. Please specify a theme"
        exit 1
    fi

    # 2. check if the DB shema is defined:
    if [ "${SCHEMA_NAME}" = "" ];
    then
        echo "No DB schema is specified. Please specify a schema where to write the data"
        exit 1
    fi

    # 2. check if the WGET_SOURCE is available
    check_data ${WGET_SOURCE}

    # 3. check if the LAW_XML_DOWNLOAD (laws) are available --> the name of the file can change
    check_data ${LAW_XML_DOWNLOAD}

    # 4. check if ili2pg is avaiable or downloadable
    if ! [ -f "${ili2pg}" ];
    then
        check_data ${ili2pg_url}
        download_targets ${ili2pg_url}
        unzip -o ${ili2pg_zip} -d ${ili2pg_path}
    fi
}

############################################################
# download                                                 #
############################################################
download() {
    set +e
    mkdir -p "${WGET_TARGET}"
    cd "${WGET_TARGET}"
    download_targets "${WGET_SOURCE}"

    echo "Unzip files"
    unzip -o "${WGET_FILENAME}" -d "data_zip"

    # rename data file to something stable
    cp data_zip/*_20*.xtf "data_zip/${INPUT_LAYER}.xtf"

    download_targets "${LAW_XML_DOWNLOAD}"
    cp $(basename "${LAW_XML_DOWNLOAD}") ${LAW_XML}
    chmod g+r data_zip/*
    cd $OLDPWD
    set -e
}

############################################################
# shema_import                                             #
############################################################
shema_import(){
    java -jar ${ili2pg} \
        --schemaimport \
        --dbhost ${PGHOST} \
        --dbport ${PGPORT}  \
        --dbdatabase ${PGDB} \
        --dbusr ${PGUSER} \
        --dbpwd ${PGPASSWORD} \
        --dbschema ${SCHEMA_NAME} \
        --defaultSrsAuth "EPSG" \
        --defaultSrsCode "2056" \
        --createFk \
        --createFkIdx \
        --createGeomIdx \
        --createTidCol \
        --createBasketCol \
        --createDatasetCol \
        --createTypeDiscriminator \
        --createMetaInfo \
        --createNumChecks \
        --createUnique \
        --expandMultilingual \
        --expandLocalised \
        --setupPgExt \
        --strokeArcs \
        --models OeREBKRMtrsfr_V2_0
}

############################################################
# import_laws                                              #
############################################################
import_laws() {
    var_dataset="OeREBKRM_V2_0"
    java -jar ${ili2pg} \
        --import \
        --dbhost ${PGHOST} \
        --dbport ${PGPORT}  \
        --dbdatabase ${PGDB} \
        --dbusr ${PGUSER} \
        --dbpwd ${PGPASSWORD} \
        --dbschema ${SCHEMA_NAME} \
        --dataset ${var_dataset} \
        "${INPUT_LAYER}/${LAW_XML}"
}

############################################################
# import_data                                              #
############################################################
import_data() {
    var_dataset="OeREBKRMtrsfr_V2_0.Transferstruktur"
    java -jar ${ili2pg} \
        --import \
        --dbhost ${PGHOST} \
        --dbport ${PGPORT}  \
        --dbdatabase ${PGDB} \
        --dbusr ${PGUSER} \
        --dbpwd ${PGPASSWORD} \
        --dbschema ${SCHEMA_NAME} \
        --defaultSrsAuth EPSG \
        --defaultSrsCode 2056 \
        --strokeArcs \
        --dataset ${var_dataset} \
        "${INPUT_LAYER}/${DATA_XML}"
}

############################################################
# create_missing_tables                                    #
############################################################
create_missing_tables() {
    sql_to_load="tables_for_trsf_struct.sql"
    if ! [ -f ${sql_to_load} ]; then
      psql -d ${PGDB} -U ${PGUSER} -v "user=${PGUSER}" -v "schema=${SCHEMA_NAME}" -f ${sql_to_load}
    else
      echo "The file ${sql_to_load} does not exist!"
      echo "Can not load the tables of the transfere structure."
      exit 1
    fi
}

############################################################
# clean                                                    #
############################################################
clean() {
    rm -rf ${INPUT_LAYER}
}

# clean up upon error
trap clean ERR EXIT


############################################################
# Main program                                             #
############################################################

#--------------------------------#
# TODO set the primary variables

PGHOST=localhost
PGPORT=25432
PGDB="test_DB"
PGUSER="www-data"
PGPASSWORD="www-data"

SCHEMA_NAME=unset # "contaminated_public_transport_sites"

CREATE_SCHEMA=true

INPUT_LAYER=unset
WGET_TARGET="${INPUT_LAYER}"
WGET_FILENAME="data.zip"


LAW_XML_DOWNLOAD="http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml"
LAW_XML="OeREBKRM_V2_0_Gesetze.xml"

ili2pg_version="4.6.0"
ili2pg_path="ili2pg"


#--------------------------#
# Get options & set options
PARSED_ARGUMENTS=$(getopt -a -n loaddata -o hc --long help,PGHOST:,PGPORT:,PGDB:,PGUSER:,PGPASSWORD:,SCHEMA_NAME:,CREATE_SCHEMA,INPUT_LAYER:,ILI2PGVERSION: -- "$@")
VLID_ARGUMENTS=$?
if [ "${VALID_ARGUMENTS}" != "0" ]; then
    help
fi

echo "PARSED_ARGUMENTS is ${PARSED_ARGUMENTS}"
eval set -- "${PARSED_ARGUMENTS}"


while :
do
  case "$1" in
    --help | -h)
      help
      shift
      ;;
    --PGHOST)
      PGHOST=$2
      echo "set PGHOST to : $2"
      shift
      ;;
    --PGPORT)
      PGPORT=$2
      echo "set PGPORT to : $2"
      shift
      ;;
    --PGDB)
      PGDB=$2
      echo "set PGDB to : $2"
      shift
      ;;
    --PGUSER)
      PGUSER=$2
      echo "set PGUSER to : $2"
      shift
      ;;
    --PGPASSWORD)
      PGPASSWORD=$2
      echo "set PGPASSWORD to : $2"
      shift
      ;;
    --SCHEMA_NAME)
      SCHEMA_NAME=$2
      echo "set SCHEMA_NAME to : $2"
      shift
      ;;
    --CREATE_SCHEMA | -c)
      CREATE_SCHEMA=true
      echo "CREATE_SCHEMA set to true"
      shift
      ;;
    --INPUT_LAYER)
      INPUT_LAYER=$2
      echo "set INPUT_LAYER to : $2"
      shift
      ;;
    --ILI2PGVERSION)
      ILI2PGVERSION=$2
      echo "set ILI2PGVERSION to : $2"
      ;;
    --) # end of the argments; break out of the while
      shift; break ;;
    *) # Inalid option
      echo "Error: Invalid option"
      help
      ;;
  esac
  shift
done

#----------------------------------#
# Set the seccondary variables
WGET_SOURCE="https://data.geo.admin.ch/${INPUT_LAYER}/${WGET_FILENAME}"

DATA_XML="data_zip/${INPUT_LAYER}.xtf"

ili2pg="${ili2pg_path}/ili2pg-${ili2pg_version}.jar"
ili2pg_zip="ili2pg-${ili2pg_version}.zip"
ili2pg_url="https://downloads.interlis.ch/ili2pg/${ili2pg_zip}"

#-------------------#
# Run the functions
clean
run_check
download

# only import the shema if wanted - it is done per default!
if [ ${CREATE_SCHEMA} == "true" ]; then
  shema_import
fi

import_laws
import_data

# if the schema is not created neither create the extra tables
if [ ${CREATE_SCHEMA} == "true" ]; then
  create_missing_tables
fi

clean
