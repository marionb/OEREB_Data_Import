# !/bin/bash

# TODO Define DB connection:
PGHOST=localhost
PGPORT=5432
PGDB="test_oereb_import"
PGUSER="postgres"
PGPASSWORD="postgres"

SCHEMA_NAME=${2} # "contaminated_public_transport_sites"

INPUT_LAYER=${1}
WGET_TARGET="${INPUT_LAYER}"
WGET_FILENAME="data.zip"
WGET_SOURCE="https://data.geo.admin.ch/${INPUT_LAYER}/${WGET_FILENAME}"

DATA_XML="data_zip/${INPUT_LAYER}.xtf"

LAW_XML_DOWNLOAD="http://models.geo.admin.ch/V_D/OeREB/OeREBKRM_V2_0_Gesetze_20210414.xml"
LAW_XML="OeREBKRM_V2_0_Gesetze.xml"

ili2pg_version=${3:-"4.6.0"}
ili2pg_path="ili2pg"
ili2pg="${ili2pg_path}/ili2pg-${ili2pg_version}.jar"
ili2pg_zip="ili2pg-${ili2pg_version}.zip"
ili2pg_url="https://downloads.interlis.ch/ili2pg/${ili2pg_zip}"




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

download_targets() {
    local target="${1}"
    echo "downloading file ${target}"
    echo "${PWD}"
    wget -N --backups ${target}
}

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

clean() {
    rm -rf ${INPUT_LAYER}
}

clean
run_check
download # "ch.bav.kataster-belasteter-standorte-oev_v2_0.oereb"
shema_import
import_laws
import_data
clean
