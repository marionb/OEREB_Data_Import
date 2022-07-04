#! /bin/bash
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland

############################################################
# help                   # TODO update help                #
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
    # echo "-e --envDBVar Use environmet variabls for the DB connection"
    echo "              The following variables are set:"
    echo "              DBHOST, DBPORT, DBNAME, DBUSER, DBPASSWORD"
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

    if [[ $# -eq 4 ]]; then
      ${loaddata} \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2 \
        --SOURCE $3 \
        --LAWS $4 \
        --ERROR_LOG ${ERROR_LOG_FILE}
    elif [[ $# -eq 3 ]]; then
       ${loaddata} \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2 \
        --SOURCE $3 \
        --ERROR_LOG ${ERROR_LOG_FILE}
    fi
}

############################################################
# Main program                                             #
############################################################
ERROR_LOG_FILE="./error_logs.log"
# clean the error log file
rm ${ERROR_LOG_FILE}

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
PARSED_ARGUMENTS=$(getopt -a -n load_fed_themes -o huf: --long help,update,file:envDBVar,PGHOST:,PGPORT:,PGDB:,PGUSER:,PGPASSWORD:, -- "$@")
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
    #--envDBVar | -e) # TODO read the DB connection params from evironment variables
    #    ENVDB=true
    #    ;;
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

# # Use env. variables for DB connections -- TODO if needed--:
# if [ ${ENVDB} == "true" ]; then
#     PGHOST=${DBHOST}
#     PGPORT=${DBPORT}
#     PGName=${DBNAME}
#     PGUSER=${DBUSER}
#     PGPW=${DBPASSWORD}
# fi

arr_record1=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f1) )
arr_record2=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f2) )
arr_record3=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f3) )
arr_record4=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f4) )
arr_record5=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f5) )
arr_record6=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f6) )

# uncomment to debug
# echo "source : ${arr_record4[@]}"

length=${#arr_record1[@]}
for (( j=0; j<length; j++ ));
do
    schema_name=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record2[$j]}"`
    input_layer=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record5[$j]}"`
    federal_theme=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record3[$j]}"`
    theme_url=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record4[$j]}"`

    # for more simplicity - handle empty theme_url here
    if [ -z ${theme_url} ]; then
      theme_url="unset"
    fi

    laws=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record6[$j]}"`

    case ${federal_theme} in
        "F")
            [[ ${update} == "true" ]] && \
                update ${schema_name} ${input_layer} ${theme_url} ${laws}|| \
                loaddata ${schema_name} ${input_layer} ${theme_url} ${laws}
            ;;
        "C") 
            echo "${arr_record1[$j]} is not a federal theme - passing"
            ;;
    esac
done


if [ `wc -l < error_logs.log` -ge 0 ]; then
    echo "---------------NOTICE------------------------"
    echo "Not all layers could be loaded!"
    echo "Check in ${ERROR_LOG_FILE} for more details!"
    echo "--------------------------------------------"
else
    echo "--- Finished loading all layers from ${FEDTHEME} successfully ---"
fi
