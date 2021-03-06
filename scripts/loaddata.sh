#!/bin/bash

# What the script does:
#----------------------
#   1. Downloads a federal oereb theme form data.geo.admin.ch
#   2. Creats a new DB schema with the needed structur
#   3. Downloads and adds the laws in to the DB
#   4. Loads the theme data into the DB
#
#   If the data already exists in the DB you can use the -c switch to just run an update of the data it is how ever not very well tested!
#
#   -> Once the data is loaded in to the DB this can be used for pyramid_OEREB
#
# What the script Depends on:
#----------------------------
#   - For loading the interlis data and creating the schema ili2pg is used for this java is needes.
#     If it is not available it will be downloaded.
#     The version can be set on running the script.
#   - There script uses a bunch of bash commandas such as:
#     - unzip, wget, ... TODO complete the list
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
   echo "--SOURCE -s          data source to fetch the data from. The federal themes can be found under:"
   echo "                         https://data.geo.admin.ch/<INPUT_LAYER>/data.zip"
   echo "General options:"
   echo "----------------"
   echo "--help -h            print this help"
   echo "--ILI2PGVERSION      ili2pg version to be used (default: 4.6.0)" #TODO test with newer version
   echo "--CREATE_SCHEMA -c   switch to drop (if it exists) and creat the schema (default: on/true)"
   echo "--LAWS               pass the files from which the laws are imported. Default used is given with the variable LAW_XML_DOWNLOAD and is currently set to:"
   echo "                     http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml"
   echo "                     The given file name can be:"
   echo "                     a) a valide URL download path"
   echo "                     b) a valide file path on the system"
   echo "                     c) the bare name of a file (the file will be searched within the downloaded given SOURCE)"
   echo "--ERROR_LOG          file in which the details about the failure of the theme is loged if there is an error"
   echo "                     Default is ./error_logs.log"
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
    if ( ! ${WGET_COMMAND} --spider "${file_to_check}" 2>/dev/null ); then
       ERROR_MSG="The file ${file_to_check} is not available."
       ERR_LINE=${LINENO}
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
    ${WGET_COMMAND} -N ${target}
}

############################################################
# run_check                                                #
############################################################
run_check() {
    echo "# run_checks #"
    # 1. check imput:
    if [ "${INPUT_LAYER}" = "unset" ]; then
        ERROR_MSG="No theme is specified. Please specify a theme"
        ERR_LINE=${LINENO}
        exit 1
    fi

    # 2. check if the DB shema is defined:
    if [ "${SCHEMA_NAME}" = "unset" ]; then
      ERROR_MSG="No DB schema is specified. Please specify a schema where to write the data"
      ERR_LINE=${LINENO}
      exit 1
    fi

    # 3. check if the WGET_SOURCE is available
    if [ "${WGET_SOURCE}" = "unset" ]; then
      ERROR_MSG="No data source provided! please provide a data."
      ERR_LINE=${LINENO}
      exit 1
    fi
    check_data ${WGET_SOURCE}

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
    cp ${ZIP_DEST}/*_20*.xtf ${ZIP_DEST}/${INPUT_LAYER}.xtf
    chmod g+r ${ZIP_DEST}/*
    cd $OLDPWD

    # prepar the laws list and download them if needed
    prepare_laws ${LAWS}

    set -e
}

prepare_laws(){
  echo "# preparing laws for import #"
  if [ -n "${LAWS}" ]; then

    GIVEN_LAW_ARRAY=($(echo $LAWS | tr ";" "\n"))

    length=${#GIVEN_LAW_ARRAY[@]}
    for (( j=0; j<length; j++ )); do
      law=${GIVEN_LAW_ARRAY[$j]}

      if ( ${WGET_COMMAND} --spider "${law}" 2>/dev/null ); then # 1 check if it is a URL that can be dwonloades
        echo "${law} is a URL download it:"
        cd "${WGET_TARGET}"
        download_targets ${law}
        law_file=${WGET_TARGET}/$(basename "${law}")
        LAW_ARRAY+=("${law_file}")
        cd $OLDPWD
      elif [ -f "${law}" ]; then # 2 check if it is a full file path
        # just add the law to the array
        # echo "${law} exists already using it!"
        LAW_ARRAY+="${law}"
      elif [ -f "${INPUT_LAYER}/${ZIP_DEST}/${law}" ]; then #3 check if it is a file within the data_zip
        # echo "${law} exists already using it as ${INPUT_LAYER}/${ZIP_DEST}/${law}!"
        LAW_ARRAY+="${INPUT_LAYER}/${ZIP_DEST}/${law}"
      else
        echo "---------------NOTICE----------------------"
        echo "The law ${law} can neither be found as file nor as url."
        echo "It will be ignored!"
        echo "-------------------------------------------"
      fi
    done
  else
    # Now law to import!
    ERROR_MSG="All laws are missing!"
    ERR_LINE=${LINENO}
    exit 1
  fi

  if [ ${#LAW_ARRAY[@]} -eq 0 ]; then
    ERROR_MSG="No valide law file to import!"
    ERR_LINE=${LINENO}
    exit 1
  fi
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
        --models OeREBKRMtrsfr_V2_0  # >/dev/null 2>&1 #Remove '> /dev/null 2>&1' to debug
}

############################################################
# import_laws                                              #
############################################################
import_laws() {
    echo "# import_laws #"

    length=${#LAW_ARRAY[@]}
    for (( j=0; j<${length}; j++ )); do
      var_dataset="OeREBKRM_V2_0_${j}"
      law=${LAW_ARRAY[$j]}
      java -jar ${ili2pg} \
          --import \
          --dbhost ${PGHOST} \
          --dbport ${PGPORT}  \
          --dbdatabase ${PGDB} \
          --dbusr ${PGUSER} \
          --dbpwd ${PGPASSWORD} \
          --dbschema ${SCHEMA_NAME} \
          --dataset ${var_dataset} \
          "${law}"  > /dev/null  2>&1 #Remove '> /dev/null 2>&1' to debug
    done
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
        "${INPUT_LAYER}/${DATA_XML}" > /dev/null 2>&1 #Remove '> /dev/null 2>&1' to debug
}

############################################################
# update_data                                              #
############################################################
update_data() {
    echo "# update_laws #"

    length=${#LAW_ARRAY[@]}
    for (( j=0; j<${length}; j++ )); do
      var_dataset="OeREBKRM_V2_0_${j}"
      law=${LAW_ARRAY[$j]}
      java -jar ${ili2pg} \
          --update \
          --dbhost ${PGHOST} \
          --dbport ${PGPORT}  \
          --dbdatabase ${PGDB} \
          --dbusr ${PGUSER} \
          --dbpwd ${PGPASSWORD} \
          --dbschema ${SCHEMA_NAME} \
          --dataset ${var_dataset} \
          "${law}" > /dev/null  2>&1 #Remove '> /dev/null 2>&1' to debug
    done

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
        "${INPUT_LAYER}/${DATA_XML}" > /dev/null 2>&1 #Remove '> /dev/null 2>&1' to debug
}

############################################################
# clean                                                    #
############################################################
clean() {
    exit_status=$?
    if [ ${exit_status} -ne 0 ]; then
      error_time=`date +"%Y-%m-%d %T"`
      echo "# clean after error #"
      # -------- error time, layer_id, schema, line number, bash_command, error msg -------- #
      echo "${error_time}, ${INPUT_LAYER}, ${SCHEMA_NAME}, ${ERR_LINE}, ${BASH_COMMAND}, ${ERROR_MSG}" >> ${ERROR_LOG_FILE}
    fi
    echo "remove ${INPUT_LAYER}"
    rm -rf ${INPUT_LAYER}
}


# clean up upon error
trap clean INT TERM ERR EXIT


############################################################
# Main program                                             #
############################################################
WGET_COMMAND="wget --no-check-certificate"
# WGET_COMMAND="wget"

set -e
set -u
set -o pipefail
# set -x # uncomment to Debug

ERROR_LOG_FILE="./error_logs.log"
ERROR_MSG=""
ERR_LINE=""

PGHOST=localhost
PGPORT=25432
PGDB="test_DB"
PGUSER="www-data"
PGPASSWORD="www-data"

SCHEMA_NAME=unset

CREATE_SCHEMA=true

INPUT_LAYER=unset
WGET_SOURCE=unset
WGET_FILENAME="data.zip"
ZIP_DEST="data_zip"

LAW_XML_DOWNLOAD="http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml"

ili2pg_version="4.7.0"
ili2pg_path="ili2pg"

declare -a LAW_ARRAY=()

#--------------------------#
# Get options & set options
PARSED_ARGUMENTS=$(getopt -a -n loaddata -o hcl --long help,PGHOST:,PGPORT:,PGDB:,PGUSER:,PGPASSWORD:,SCHEMA_NAME:,CREATE_SCHEMA,LAWS:,INPUT_LAYER:,ILI2PGVERSION:,SOURCE:,ERROR_LOG:, -- "$@")
VALID_ARGUMENTS=$#

# echo "PARSED_ARGUMENTS is ${PARSED_ARGUMENTS}"

# if [ "${VALID_ARGUMENTS}" -eq 0 ] || [ "${VALID_ARGUMENTS}" != "0" ]; then
if [ "${VALID_ARGUMENTS}" -eq "0" ]; then
    help
    # break
    exit 0
fi

# TODO run without eval
eval set -- "${PARSED_ARGUMENTS}"

while :
do
  case "$1" in
    --help | -h)
      help
      # break
      exit 0
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
    --SOURCE | -s)
      WGET_SOURCE=$2
      echo "set data source to: $2"
      shift
      ;;
    --LAWS)
      LAWS=$2
      echo "set law sources: $2"
      shift
      ;;
    --ERROR_LOG)
      ERROR_LOG_FILE=$2
      echo "set error logs to: $2"
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

if [[ -z ${LAWS} ]] || [[ ${LAWS} = "unset" ]]; then
    LAWS="${LAW_XML_DOWNLOAD}"
    echo "----------------------------------"
    echo "no laws prowided! Using the standart law file:"
    echo "${LAWS}"
    echo "----------------------------------"
fi

DATA_XML="${ZIP_DEST}/${INPUT_LAYER}.xtf"

ili2pg="${ili2pg_path}/ili2pg-${ili2pg_version}.jar"
ili2pg_zip="ili2pg-${ili2pg_version}.zip"
ili2pg_url="https://downloads.interlis.ch/ili2pg/${ili2pg_zip}"

#----------------------------------#
# Run the functions
loaddata_main() {
  clean
  run_check
  download
  if [ ${CREATE_SCHEMA} == "true" ]; then
    # create the schema, import the data and the laws
    shema_import
    import_laws
    import_data
  else
    # Run an update of the data:
    #    Updated data in the DB according to the transfed file.
    #    - new objects are added
    #    - current objects are updated
    #    - no loger available objects are removed
    update_data
  fi
}

loaddata_main
