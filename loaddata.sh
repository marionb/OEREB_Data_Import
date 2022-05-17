#!/bin/bash

# What the script does:
#----------------------
#   1. Downloads a federal oereb theme form data.geo.admin.ch
#   2. Creats a new DB schema with the needed structur
#   3. Downloads and adds the laws in to the DB
#   4. Loads the theme data into the DB
#   5. Create the missung tables datenintegration and verfuegbarkeit in the schema. 
#      They empty and are not filled
#
#   If the data already exists in the DB use the -c switch to just run an update of the data
#
#   -> Once the data is loaded in to the DB this can be used for pyramid_OEREB
#
# What the script Depends on:
#----------------------------
#   - For loading the intelis data and creating the schema ili2pg is used. 
#     If it is not available it will be downloaded.
#     The version can be set on running the script.
#
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland

############################################################
# help                                                     #
############################################################
help()
{
   echo "Write/Update OEREB V2 data in a DB"
   echo
   echo "Syntax:"
   echo "-------"
   echo "                ./loaddata.sh [OPTIONS] --SCHEMA_NAME <DBSchema> --INPUT_LAYER <OEREB_V2_LAYER>"
   # exampe: $ ./loaddata.sh --PGHOST localhost --PGPASSWORD www-data --PGUSER www-data --PGPORT 25432 --SCHEMA_NAME contaminated_public_transport_sites --INPUT_LAYER ch.bav.kataster-belasteter-standorte-oev_v2_0.oereb
   echo
   echo "Required options:"
   echo "-----------------"
   echo "--INPUT_LAYER        the oereb V2 layer to load. A list of availabe layers can be found under: http://models.geo.admin.ch/V_D/OeREB -> OeREBKRM_V2_0_Themen_xxx.xml"
   echo "                     this script can only load data that is available on  https://data.geo.admin.ch/"
   echo "--SCHEMA_NAME        the name of the DB schema to write the data in. If the oprion CREATE_SCHEMA is not set to false the schema will be created"
   echo
   echo "General options:"
   echo "----------------"
   echo "--help -h            print this help"
   echo "--ILI2PGVERSION      ili2pg version to be used (default: 4.6.0)" #TODO test with newer version
   echo "--CREATE_SCHEMA -c   switch to drop (if it exists) and creat the schema (default: on/true)"
   echo
   echo "Connection options:"
   echo "-------------------"
   echo "--PGHOST         database server host (default: localhost)"
   echo "--PGPASSWORD     database password (default: www-data)"
   echo "--PGUSER         database user name (default: www-data)"
   echo "--PGPORT         database server port (default: 25432)"
   echo "--PGDB           database name (deafault: test_DB)"
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
    echo "File ${file_to_check} is available - continuing"
}

############################################################
# download_targets                                         #
############################################################
download_targets() {
    local target="${1}"
    echo "# download_targets #"
    echo "downloading file ${target}"
    echo "${PWD}"
    wget -N ${target}
}

############################################################
# run_check                                                #
############################################################
run_check() {
    echo "# run_checks #"
    # 1. check imput:
    if [ "${INPUT_LAYER}" = "unset" ];
    then
        echo "No theme is specified. Please specify a theme"
        exit 1
    fi

    # 2. check if the DB shema is defined:
    if [ "${SCHEMA_NAME}" = "unset" ];
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
        rm -rf ${ili2pg_path}
        unzip -o ${ili2pg_zip} -d ${ili2pg_path}
    fi
}

############################################################
# download                                                 #
############################################################
download() {
    echo "# download #"
    set +e
    mkdir -p "${WGET_TARGET}"
    cd "${WGET_TARGET}"
    download_targets "${WGET_SOURCE}"

    echo "Unzip files"
    unzip -o "${WGET_FILENAME}" -d "${ZIP_DEST}"

    # rename data file to something stable
    cp "${ZIP_DEST}/*_20*.xtf" "${ZIP_DEST}/${INPUT_LAYER}.xtf"

    download_targets "${LAW_XML_DOWNLOAD}"
    cp $(basename "${LAW_XML_DOWNLOAD}") ${LAW_XML}
    chmod g+r ${ZIP_DEST}/*
    cd $OLDPWD
    set -e
}

############################################################
# shema_import                                             #
############################################################
shema_import(){
    echo "# shema_import #"
    # remove old schema if it exists:
    psql "host=${PGHOST} port=${PGPORT} user=${PGUSER} password=${PGPASSWORD} dbname=${PGDB}" -c "DROP SCHEMA IF EXISTS ${SCHEMA_NAME} CASCADE;"
    # create new shema
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
    echo "# import_laws #"
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
    echo "# import_data #"
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
# update_data                                              #
############################################################
update_data() {
    echo "# update_laws #"
    var_dataset="OeREBKRM_V2_0"
    java -jar ${ili2pg} \
        --update \
        --dbhost ${PGHOST} \
        --dbport ${PGPORT}  \
        --dbdatabase ${PGDB} \
        --dbusr ${PGUSER} \
        --dbpwd ${PGPASSWORD} \
        --dbschema ${SCHEMA_NAME} \
        --dataset ${var_dataset} \
        "${INPUT_LAYER}/${LAW_XML}"

    echo "# update_data #"
    var_dataset="OeREBKRMtrsfr_V2_0.Transferstruktur"
    java -jar ${ili2pg} \
        --update \
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

PGHOST=localhost
PGPORT=25432
PGDB="test_DB"
PGUSER="www-data"
PGPASSWORD="www-data"

SCHEMA_NAME=unset # "contaminated_public_transport_sites"

CREATE_SCHEMA=true

INPUT_LAYER=unset
WGET_FILENAME="data.zip"
ZIP_DEST="data_zip"


LAW_XML_DOWNLOAD="http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml"
LAW_XML="OeREBKRM_V2_0_Gesetze.xml"

ili2pg_version="4.7.0"
ili2pg_path="ili2pg"

#--------------------------#
# Get options & set options
PARSED_ARGUMENTS=$(getopt -a -n loaddata -o hc --long help,PGHOST:,PGPORT:,PGDB:,PGUSER:,PGPASSWORD:,SCHEMA_NAME:,CREATE_SCHEMA,INPUT_LAYER:,ILI2PGVERSION: -- "$@")
VALID_ARGUMENTS=$?

echo "PARSED_ARGUMENTS is ${PARSED_ARGUMENTS}"

# if [ "${VALID_ARGUMENTS}" -eq 0 ] || [ "${VALID_ARGUMENTS}" != "0" ]; then
if [ "${VALID_ARGUMENTS}" != "0" ]; then
    help
    exit 1
fi

eval set -- "${PARSED_ARGUMENTS}"

while :
do
  case "$1" in
    --help | -h)
      help
      break
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
      shift
      ;;
    --SCHEMA_NAME)
      SCHEMA_NAME=$2
      echo "set SCHEMA_NAME to : $2"
      shift
      ;;
    --CREATE_SCHEMA | -c)
      CREATE_SCHEMA=false
      echo "CREATE_SCHEMA set to false"
      ;;
    --INPUT_LAYER)
      INPUT_LAYER=$2
      echo "set INPUT_LAYER to : $2"
      shift
      ;;
    --ILI2PGVERSION)
      ILI2PGVERSION=$2
      echo "set ILI2PGVERSION to : $2"
      shift
      ;;
    --) # end of the argments; break out of the while
      shift; break ;;
    *) # Inalid option
      echo "Error: Invalid option: $1"
      echo "Try ./loaddata.sh -h"
      exit 1
      ;;
  esac
  shift
done

#----------------------------------#
# Set the seccondary variables
WGET_TARGET="${INPUT_LAYER}"
WGET_SOURCE="https://data.geo.admin.ch/${INPUT_LAYER}/${WGET_FILENAME}"

DATA_XML="data_zip/${INPUT_LAYER}.xtf"

ili2pg="${ili2pg_path}/ili2pg-${ili2pg_version}.jar"
ili2pg_zip="ili2pg-${ili2pg_version}.zip"
ili2pg_url="https://downloads.interlis.ch/ili2pg/${ili2pg_zip}"

#-------------------#
# Run the functions
loaddata_main() {
  clean
  run_check
  download

  if [ ${CREATE_SCHEMA} == "true" ]; then
    # creat the schema import the data and the laws and creat missing tables
    shema_import
    import_laws
    import_data
  else
    # only run an update of the data
    echo update_data
  fi

  clean
}

loaddata_main
