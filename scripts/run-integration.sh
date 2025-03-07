#!/bin/bash

trap cleanup INT

STATUS=2
function cleanup {
  echo "Stopping services"
	pgrep "hackillinois" | xargs kill
	rm -rf log/
	exit $STATUS
}

REPO_ROOT="$(git rev-parse --show-toplevel)"

export HI_CONFIG=file://$REPO_ROOT/config/test_config.json
export BASE_PACKAGE=github.com/HackIllinois/api

if [  -z "$1" ]
then
	API_FILE_OUTPUT=/dev/null
else
	API_FILE_OUTPUT=$1
fi

if [  -z "$2" ]
then
	TEST_DIR=$BASE_PACKAGE/tests/e2e/...
else
	TEST_DIR=$BASE_PACKAGE/$2
fi
echo "API output will be redirected to $API_FILE_OUTPUT"
echo "Will be running tests in $TEST_DIR"
echo > $API_FILE_OUTPUT # better than rm just in case you want to nuke your system :)

mkdir log/
touch log/access.log

echo "Checking if another API is running on port 8000 ...";
curl --silent --output /dev/null localhost:8000
if [ $? -eq 0 ]
then
	echo "Another API is running on port 8000. Please make sure to stop the process in order to run integration tests."
	exit $STATUS
fi

$REPO_ROOT/bin/hackillinois-api --service auth >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service user >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service registration >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service decision >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service rsvp >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service checkin >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service upload >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service mail >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service event >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service stat >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service notifications >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service project >> $API_FILE_OUTPUT 2>&1 &
$REPO_ROOT/bin/hackillinois-api --service profile >> $API_FILE_OUTPUT 2>&1 &

$REPO_ROOT/bin/hackillinois-api --service gateway >> $API_FILE_OUTPUT 2>&1 &

sleep 2

echo "Beginning integration tests";
echo "Checking if the API is running...";
curl --silent --output /dev/null localhost:8000 || (echo "Failed to connect to the API. Is it running? If it's not, start it with 'make run-test'"; exit 1;)
echo "Running end-to-end tests";
HI_CONFIG=file://$REPO_ROOT/config/test_config.json go test $TEST_DIR -v -count 1 -p 1;
STATUS=$?

cleanup

