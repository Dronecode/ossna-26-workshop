SCRIPT=$(realpath "$0")
SCRIPTPATH=$(dirname "$SCRIPT")

docker build -t dronecode/ossna-26-workshop -f ${SCRIPTPATH}/Dockerfile  ${SCRIPTPATH}/..