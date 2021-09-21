ARANGOIMPORT="${ARANGOIMPORT:-build/bin/arangoimport}"
ARANGOSH="${ARANGOSH:-build/bin/arangosh}"
ARANGO_ENDPOINT="${ARANGO_ENDPOINT:-tcp://127.0.0.1:8529}"
ARANGO_USERNAME="${ARANGO_USERNAME:-root}"
ARANGO_PASSWORD="${ARANGO_PASSWORD:-}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-1}"
NUMBER_OF_SHARDS="${NUMBER_OF_SHARDS:-3}"
DATADIR="${DATADIR:-.}"
JAVASCRIPT_DIRECTORY="${JAVASCRIPT_DIRECTORY:-js}";

run_import () {
  local collection="$1"
  local file="$2"
  local type="$3"
  shift 3
  $ARANGOIMPORT --type csv --collection "$collection" --separator "|" --create-collection true --create-collection-type "$type" --file "$file" --server.endpoint "$ARANGO_ENDPOINT" --server.username "$ARANGO_USERNAME" --server.password "$ARANGO_PASSWORD" "$@"
  import_result=$?
}

process_directory () {
  local collection="$1"
  local type="$2"
  shift 2
  
  # clean up collection beforehand
  echo "db._drop('$collection');" | $ARANGOSH --server.endpoint "$ARANGO_ENDPOINT" --server.username "$ARANGO_USERNAME" --server.password "$ARANGO_PASSWORD" --javascript.startup-directory "$JAVASCRIPT_DIRECTORY"
  import_result="$?"
  if [[ "x$import_result" != "x0" ]]; then
    exit "$import_result"
  fi

  echo "db._create('$collection', {numberOfShards: $NUMBER_OF_SHARDS, replicationFactor: $REPLICATION_FACTOR});" | $ARANGOSH --server.endpoint "$ARANGO_ENDPOINT" --server.username "$ARANGO_USERNAME" --server.password "$ARANGO_PASSWORD" --javascript.startup-directory "$JAVASCRIPT_DIRECTORY"
  import_result="$?"
  if [[ "x$import_result" != "x0" ]]; then
    exit "$import_result"
  fi
  
  # import all csv files for collection
  for file in `find "$DATADIR/$collection" -type f -name "*.csv"`; do
    run_import "$collection" "$file" "$type" $@
    if [[ "x$import_result" != "x0" ]]; then
      exit "$import_result"
    fi
  done
}

process_directory "Person" "document" "--datatype LocationCityId=string" "--translate id=_key"
process_directory "Tag" "document" "--datatype=TagShit=string" "--translate=id=_key"
process_directory "Comment" "document" "--datatype=CommentShit=string" "--translate=id=_key"
process_directory "Edgy" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Comment" "--translate=Person=_from" "--translate=Comment=_to" "--translate=id=_key"
