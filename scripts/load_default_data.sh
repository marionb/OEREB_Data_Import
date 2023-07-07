#! /bin/bash
# Author:
#--------
#   Marion Baumgartner, Camptocamp SA, Switzerland
#
# What this script does:
# This script gets the default data such as glosary data form the dev environment
# and writes it in to the DB

############################################################
# help                                                     #
############################################################
help(){
    echo "TODO ..."
}


# DB connections
PGHOST=localhost
PGPORT=25432
PGName="test_DB"
PGUSER="www-data"
PGPW="www-data"
SCHEMA_NAME=pyramid_oereb_main
TABLE_NAME=glossary

# Get the URL file from the dev environmet because a json is easier to handle than a xml
#DATA_FILE_URL="https://raw.githubusercontent.com/openoereb/pyramid_oereb/master/dev/sample_data/ch.glossary.json"
#Use a fix commit so if the master changes it should still exist -> if the file is update this needs to be adapted!!!
DATA_FILE_URL="https://raw.githubusercontent.com/openoereb/pyramid_oereb/5dffd08600338cbf8628371877f9d29fc4503891/dev/sample_data/ch.glossary.json"
FILE_DIR="./default_data_dir"
DATA_FILE_NAME="${FILE_DIR}/data_file.json"
SQL_SCRIPT="${FILE_DIR}/data_file.sql"


clean_up() {
    rm -rf ${FILE_DIR}
}

clean_up

mkdir ${FILE_DIR}

wget -O "${DATA_FILE_NAME}" ${DATA_FILE_URL}

# convert the json data into a sql insert statement:
# 1. clean the table and reset the ID sequence
echo "TRUNCATE :schema.:table RESTART IDENTITY;" > ${SQL_SCRIPT}
# 2. header for the insert statement
echo "INSERT INTO :schema.:table (title, content) VALUES" >> ${SQL_SCRIPT}
# 3. prepare and format the insert data
cat ${DATA_FILE_NAME} | sed "s/'/''/g" | jq -r '.[] | "('\''\(.title)'\'', '\''\(.content)'\''),"'>> ${SQL_SCRIPT}
# 4. replace the last comma with a semicolon
sed -i -z 's/\(.*\),/\1;/' ${SQL_SCRIPT}

# 5. use psql to execute the sql script
# psql postgres://user:password@ip_add_or_domain:port/db_name ...
psql postgres://${PGUSER}:${PGPW}@${PGHOST}:${PGPORT}/${PGName} -v "schema=${SCHEMA_NAME}" -v "table=${TABLE_NAME}" -f ${SQL_SCRIPT}

# 6. clean up
clean_up
