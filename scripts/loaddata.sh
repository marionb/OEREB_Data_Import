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
   echo "--INPUT_LAYER        the oereb V2 layer to load. A list of availabe layers can be found under: http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Themen.xml"
   echo "                     this script can only load data that is available on  https://data.geo.admin.ch/"
   echo "--INPUT_LAYER_ID     the oereb V2 layer id. This is the ID as it is configured in pyramid_oereb. i.e ch.BaulinienNationalstrassen, ch.BaulinienEisenbahnanlagen, ..."
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
   echo "                     http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze.xml"
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
    # 1.1. check imput:
    if [ "${INPUT_LAYER}" = "unset" ]; then
        ERROR_MSG="No theme/input_layer is specified. Please specify a theme"
        ERR_LINE=${LINENO}
        exit 1
    fi

    # 1.2. check imput:
    if [ "${INPUT_LAYER_ID}" = "unset" ]; then
        ERROR_MSG="No theme id/input_layer_id is specified. Please specify a theme id"
        ERR_LINE=${LINENO}
        exit 1
    fi

    # 2. check if the DB shema is defined:
    if [ "${SCHEMA_NAME}" = "" ];
    then
        echo "No DB schema is specified. Please specify a schema where to write the data"
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
# schema_import                                             #
############################################################
schema_import(){
    echo "# schema_import #"
    # remove the temporary import schema it exists - it should not but this is to be shure:
    psql "${DB_CONNECTION}" -v "ON_ERROR_STOP=on" -c "DROP SCHEMA IF EXISTS ${TEMP_IMPORT_SCHEMA_NAME} CASCADE;"
    # create new shema
    java -jar ${ili2pg} \
        --schemaimport \
        --dbhost ${PGHOST} \
        --dbport ${PGPORT}  \
        --dbdatabase ${PGDB} \
        --dbusr ${PGUSER} \
        --dbpwd ${PGPASSWORD} \
        --dbschema ${TEMP_IMPORT_SCHEMA_NAME} \
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
        --models OeREBKRMtrsfr_V2_0 >/dev/null 2>&1 #Remove '> /dev/null 2>&1' to debug
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
          --dbschema ${TEMP_IMPORT_SCHEMA_NAME} \
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
        --dbschema ${TEMP_IMPORT_SCHEMA_NAME} \
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
# rename_schema                                            #
############################################################
rename_schema() {
  # Remove the old schema and rename the new one. Do nothing if the new one does not exist.
  # In this case the old data will still be used.
  echo "# rename_schema #"

  schema_exists=$(psql -qt "${DB_CONNECTION}"  -c "SELECT exists(SELECT schema_name FROM information_schema.schemata WHERE schema_name = '${TEMP_IMPORT_SCHEMA_NAME}');")
  if [ ${schema_exists} == t ]; then # the new schema exists
      # drop the old shema
      # rename the new shema to the name of the old
      psql -qt "${DB_CONNECTION}"  \
        -c "DROP SCHEMA IF EXISTS ${SCHEMA_NAME} CASCADE; ALTER SCHEMA ${TEMP_IMPORT_SCHEMA_NAME} RENAME TO ${SCHEMA_NAME};"

  else # the new schema does not exist: do nothing
      echo "schema does not exist"
  fi
}

############################################################
# update_di_table                                          #
############################################################
update_di_table() {
  # set current script path
  echo "# update_di_table #"
  local full_path=$(realpath $0)
  local dir_path=$(dirname $full_path)
  # set path variables with file path
  local sql_script="${dir_path}/update_DI_table.sql"
  local office__ID
  psql "${DB_CONNECTION}" \
    -v "ON_ERROR_STOP=on" -v "INPUT_LAYER_ID='${INPUT_LAYER_ID}'" -v "OFFICE_ID='ch.admin.bk'"\
    -f ${sql_script}
}

############################################################
# clean                                                    #
############################################################
clean() {
    exit_status=$?
    if [ ${exit_status} -ne 0 ]; then
      error_time=`date +"%Y-%m-%d %T"`
      echo "# clean after error #"
      # remove TEMP_IMPORT_SCHEMA_NAME in DB to clean up
      psql -qt "${DB_CONNECTION}"  \
        -c "DROP SCHEMA IF EXISTS ${TEMP_IMPORT_SCHEMA_NAME} CASCADE;"
      # -------- error time, layer_id, schema, line number, bash_command, error msg -------- #
      echo "${error_time}, ${INPUT_LAYER}, ${SCHEMA_NAME}, ${ERR_LINE}, ${BASH_COMMAND}, ${ERROR_MSG}" >> ${ERROR_LOG_FILE}
    fi
    echo "# general clean up: remove ${INPUT_LAYER}"
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
# Schema name of the temporary import shema.
# If all goes well with the import then the schema is renamerd to SCHEMA_NAME.
# This is to be able to rollbalck if somthing goes wrong
TEMP_IMPORT_SCHEMA_NAME=unset

CREATE_SCHEMA=true

INPUT_LAYER=unset
WGET_SOURCE=unset
WGET_FILENAME="data.zip"
ZIP_DEST="data_zip"
LAWS=unset

LAW_XML_DOWNLOAD="http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze.xml"

ili2pg_version="4.7.0"
ili2pg_path="ili2pg"

declare -a LAW_ARRAY=()

#--------------------------#
# Get options & set options

OPTION_AMOUNT=$(( $#/2 ))

if [ ${OPTION_AMOUNT} -le 4 ]; then
    help
    exit 1
fi

while [ ${OPTION_AMOUNT} -gt 0 ]; do
  OPTION_AMOUNT=$(( ${OPTION_AMOUNT}-1 ))
  case "$1" in
    --help | -h)
      help
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
      TEMP_IMPORT_SCHEMA_NAME="temp_import_$2"
      echo "set SCHEMA_NAME to : $2"
      echo "set TEMP_IMPORT_SCHEMA_NAME to ${TEMP_IMPORT_SCHEMA_NAME}"
      shift
      ;;
    --CREATE_SCHEMA | -c)
      CREATE_SCHEMA=false
      echo "set CREATE_SCHEMA to false"
      ;;
    --INPUT_LAYER)
      INPUT_LAYER=$2
      echo "set INPUT_LAYER to : $2"
      shift
      ;;
    --INPUT_LAYER_ID)
      INPUT_LAYER_ID=$2
      echo "set INPUT_LAYER_ID to : $2"
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
    -?*) # Inalid option - ignore
      printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
      ;;
    *) # Default case: No more options, so break out of the loop.
      break
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

DB_CONNECTION="host=${PGHOST} port=${PGPORT} user=${PGUSER} password=${PGPASSWORD} dbname=${PGDB}"
#----------------------------------#
# Run the functions
loaddata_main() {
  clean
  run_check
  download
  if [ ${CREATE_SCHEMA} == "true" ]; then
    # Clear old data and run an import of the data
    # - Create the schema (if it exists drop it before)
    # - Import the data and the laws
    # - Update the DI table in pyramid_oereb_main
    schema_import
    import_laws
    import_data
    rename_schema
    update_di_table
  else
    # Run an update of the data:
    #    Updated data in the DB according to the transfed file.
    #    - new objects are added
    #    - current objects are updated
    #    - no loger available objects are removed
    #    Update the DI table in pyramid_oereb_main
    update_data
    update_di_table
  fi
}

loaddata_main
