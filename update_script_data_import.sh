# !/bin/bash
SCRIPTFOLDER=${1:-"OEREB_Data_Import"}
rm -rf {${SCRIPTFOLDER},main.zip}
wget https://github.com/marionb/OEREB_Data_Import/archive/refs/heads/main.zip
unzip main.zip
mv OEREB_Data_Import-main ${SCRIPTFOLDER}
rm {${SCRIPTFOLDER}/docker-compose.yaml,main.zip}
