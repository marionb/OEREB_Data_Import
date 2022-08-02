#! /bin/bash
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland

############################################################
# help                                                     #
############################################################
help(){
    echo "Write/Update OEREB V2 data in a DB"
    echo
    echo "Syntax:"
    echo "-------"
    echo "              ./load_fed_data.sh [OPTIONS]"
    echo
    echo "Options:"
    echo "--------"
    echo "-h --help     Print this help"
    echo "-u --update   If this swich is called only data updates are performed"
    echo "-f --file     CSV file containing the themes: id,schema,C/F,Download,THEME ID "
    echo "-e --envDBVar Use environmet variabls for the DB connection"
    echo "              The following variables are set:"
    echo "              ePGHOST, ePGPORT, ePGNAME, ePGUSER, ePGPASSWORD"
    echo
    echo "Connection options:"
    echo "-------------------"
    echo "--PGHOST      database server host (default: localhost)"
    echo "--PGPASSWORD  database password (default: www-data)"
    echo "--PGUSER      database user name (default: www-data)"
    echo "--PGPORT      database server port (default: 25432)"
    echo "--PGDB        database name (deafault: test_DB)"
}

############################################################
# check_DB_connection                                      #
############################################################
check_DB_connection() {
    echo "# check_DB_connection #"
    local error_msg="Can not connect to DB! Check if the DB is available for connection AND if your connections parametres are correct"
    # 1. check if the connection exists and is ready
    if pg_isready -d ${PGName} -h ${PGHOST} -p ${PGPORT} -U ${PGUSER}; then
      # 2. check if the DB is there and returning somthing upon query
      psql "host=${PGHOST} port=${PGPORT} user=${PGUSER} password=${PGPW} dbname=${PGName}" -v "ON_ERROR_STOP=on" -c "SELECT 1;" >/dev/null 2>&1
      local exit_status=$?
      if [ ${exit_status} -ne 0 ]; then
        echo "-------------ERROR---------------------"
        echo ${error_msg}
        echo "---------------------------------------"
        exit 1
      fi
    else
      echo "-------------ERROR---------------------"
      echo ${error_msg}
      echo "---------------------------------------"
      exit 1
    fi
}

############################################################
# update                                                   #
############################################################
update() {
    ${loaddata} \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --CREATE_SCHEMA \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2 \
        --SOURCE $3 \
        --LAWS $4 \
        --ERROR_LOG ${ERROR_LOG_FILE}
}

############################################################
# loaddata                                                 #
############################################################
loaddata() {

    if [[ $# -eq 5 ]]; then
      ${loaddata} \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2 \
        --INPUT_LAYER_ID $5 \
        --SOURCE $3 \
        --LAWS $4 \
        --ERROR_LOG ${ERROR_LOG_FILE}
    elif [[ $# -eq 4 ]]; then
       ${loaddata} \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2 \
        --INPUT_LAYER_ID $4 \
        --SOURCE $3 \
        --ERROR_LOG ${ERROR_LOG_FILE}
    fi
}

############################################################
# Main program                                             #
############################################################
# set -e
set -u
set -o pipefail

ERROR_LOG_FILE="./error_logs.log"
# clean the error log file
rm -f ${ERROR_LOG_FILE}

# set current script path
full_path=$(realpath $0)
dir_path=$(dirname $full_path)

# set path variables with file path
FEDTHEME="${dir_path}/FEDTHEMES.csv"
loaddata="${dir_path}/loaddata.sh"

if ! [ -f "${loaddata}" ];
then
  echo "can not find bash script ${loaddata}"
  exit 1
fi

update=false

# DB connections
PGHOST=localhost
PGPORT=25432
PGName="test_DB"
PGUSER="www-data"
PGPW="www-data"
ENVDB=false

# Parsing command line arguments
PARSED_ARGUMENTS=$(getopt -a -n load_fed_themes -o heuf: --long help,update,file:envDBVar,PGHOST:,PGPORT:,PGDB:,PGUSER:,PGPASSWORD:, -- "$@")
VALID_ARGUMENTS=$?

if [ "${VALID_ARGUMENTS}" != "0" ]; then
    help
    exit 1
fi

# TODO run without eval
eval set -- "${PARSED_ARGUMENTS}"

while :
do
  case "$1" in
    --help | -h)
        help
        exit
        ;;
    --update | -u)
        update=true
        ;;
    --file | -f)
        FEDTHEME="$2"
        shift
        ;;
    --envDBVar | -e)
        ENVDB=true
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
        PGName=$2
        echo "set PGDB to : $2"
        shift
        ;;
    --PGUSER)
        PGUSER=$2
        echo "set PGUSER to : $2"
        shift
        ;;
    --PGPASSWORD)
        PGPW=$2
        shift
        ;;
    --) # end of the argments; break out of the while
        shift; break ;;
    *) # Invalid option
        echo "Error: Invalid option: $1"
        echo "Try ./load_fed_themes.sh -h"
        exit 1
        ;;
  esac
  shift
done

# Use env. variables for DB connections
if [ ${ENVDB} == "true" ]; then
    set +u
    if [[ -n "${ePGPASSWORD}" ]] && \
        [[ -n "${ePGHOST}" ]] && \
        [[ -n "${ePGPORT}" ]] && \
        [[ -n "${ePGNAME}" ]] && \
        [[ -n "${ePGUSER}" ]]; then
      PGHOST=${ePGHOST}
      PGPORT=${ePGPORT}
      PGName=${ePGNAME}
      PGUSER=${ePGUSER}
      PGPW=${ePGPASSWORD}
    else
      echo "-------------ERROR---------------------"
      echo "You are trying to use the DB connection params from env. variablse but one is not available."
      echo "Make sure that the following variable are avaliable as env. vaiables!"
      echo "PGHOST=${ePGHOST}"
      echo "PGPORT=${ePGPORT}"
      echo "PGName=${ePGNAME}"
      echo "PGUSER=${ePGUSER}"
      echo "PGPW=${ePGPASSWORD}"
      echo "----------------------------------------"
      exit 1
    fi
    set -u
fi

check_DB_connection

arr_record1=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f1) )
arr_record2=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f2) )
arr_record3=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f3) )
arr_record4=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f4) )
arr_record5=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f5) )
arr_record6=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f6) )

# uncomment to debug
# echo "source : ${arr_record4[@]}"

length=${#arr_record4[@]}
for (( j=0; j<length; j++ ));
do
    load_theme=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record3[$j]}"`

    if [[ ${load_theme} = 'Y' ]]; then
      echo "${arr_record1[$j]} is a federal theme - treating"
      input_layer_id=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record1[$j]}"`
      schema_name=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record2[$j]}"`
      input_layer=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record5[$j]}"`
      theme_url=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record4[$j]}"`

      # for more simplicity - handle theme_url here
      if [[ -z ${theme_url} ]] || [[ "${theme_url}" = "unset" ]]; then
        WGET_SOURCE="https://data.geo.admin.ch/${input_layer}/data.zip"
        theme_url=${WGET_SOURCE}
          echo "-------------NOTICE---------------------"
          echo "no download source given! Using the standart source:"
          echo "${WGET_SOURCE}"
          echo "----------------------------------------"
      fi

      laws=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record6[$j]}"`

      [[ ${update} == "true" ]] && \
        update ${schema_name} ${input_layer} ${theme_url} ${laws} ${input_layer_id} || \
        loaddata ${schema_name} ${input_layer} ${theme_url} ${laws} ${input_layer_id}
    else
      echo "${arr_record1[$j]} is not a federal theme - passing"
    fi
done

if [[ -f ${ERROR_LOG_FILE} ]] && [[ `wc -l < ${ERROR_LOG_FILE}` -ge 0 ]]; then
    echo "---------------NOTICE------------------------"
    echo "Not all layers could be loaded!"
    echo "Check in ${ERROR_LOG_FILE} for more details!"
    echo
    echo "Error logs:"
    cat ${ERROR_LOG_FILE}
    echo "--------------------------------------------"
    exit 1
else
    echo "--- Finished loading all layers from ${FEDTHEME} successfully ---"
fi
