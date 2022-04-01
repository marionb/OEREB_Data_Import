#! /bin/bash
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland
# TODO:
#------
#   Set the DB parameters

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
    echo "              DBHOST, DBPORT, DBNAME, DBUSER, DBPASSWORD"
    echo
    echo "Connection options:"
    echo "-------------------"
    echo "--PGHOST      database server host (default: localhost)"
    echo "--PGPW        database password (default: www-data)"
    echo "--PGUSER      database user name (default: www-data)"
    echo "--PGPORT      database server port (default: 25432)"
}

############################################################
# update                                                   #
############################################################
update() {
    ./loaddata.sh \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --CREATE_SCHEMA \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2
}

############################################################
# loaddata                                                 #
############################################################
loaddata() {
    ./loaddata.sh \
        --PGHOST ${PGHOST} \
        --PGPASSWORD ${PGPW} \
        --PGUSER ${PGUSER} \
        --PGDB ${PGName} \
        --PGPORT ${PGPORT} \
        --SCHEMA_NAME $1 \
        --INPUT_LAYER $2        
}

############################################################
# Main program                                             #
############################################################
FEDTHEME="FEDTHEMES.csv"
update=false

# DB connections
PGHOST=localhost
PGPORT=25432
PGName="test_DB"
PGUSER="www-data"
PGPW="www-data"
ENVDB=false

PARSED_ARGUMENTS=$(getopt -a -n load_fed_themes -o huf: --long help,update,file: -- "$@")
VALID_ARGUMENTS=$?

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
        exit
        ;;
    --update | -u)
        update=true
        shift
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
    --) # end of the argments; break out of the while
        shift; break ;;
    *) # Inalid option
        echo "Error: Invalid option: $1"
        echo "Try ./load_fed_themes.sh -h"
        exit 1
        ;;
  esac
done

# Use env. variables for DB connections:
if [ ${ENVDB} == "true" ]; then
    PGHOST=${DBHOST}
    PGPORT=${DBPORT}
    PGName=${DBNAME}
    PGUSER=${DBUSER}
    PGPW=${DBPASSWORD}
fi

arr_record1=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f1) )
arr_record2=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f2) )
arr_record3=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f3) )
arr_record5=( $(tail -n +2 ${FEDTHEME} | cut -d ',' -f5) )

# echo "schema_name : ${arr_record2[@]}"

length=${#arr_record1[@]}
for (( j=0; j<length; j++ ));
do
    schema_name=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record2[$j]}"`
    input_layer=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record5[$j]}"`
    federal_theme=`sed -e 's/^"//' -e 's/"$//' <<<"${arr_record3[$j]}"`

    case ${federal_theme} in
        "F")
            [[ ${update} == "true" ]] && \
                update ${schema_name} ${input_layer} || \
                loaddata ${schema_name} ${input_layer}
            ;;
        "C") 
            echo "${arr_record1[$j]} is not a federal theme - passing"
            ;;
    esac
done
