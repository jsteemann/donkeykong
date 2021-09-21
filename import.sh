ARANGOIMPORT="${ARANGOIMPORT:-build/bin/arangoimport}"
ARANGOSH="${ARANGOSH:-build/bin/arangosh}"
ENDPOINT="${ENDPOINT:-tcp://127.0.0.1:8529}"
USERNAME="${USERNAME:-root}"
PASSWORD="${PASSWORD:-}"

run_import () {
  local collection="$1"
  local file="$2"
  local type="$3"
  shift 3
  echo $ARANGOIMPORT -type csv --collection "$collection" --separator "|" --create-collection true --create-collection-type "$type" --file "$file" --server.endpoint "$endpoint" --server.username "$username" --server.password "$password" "$@"
  $ARANGOIMPORT --type csv --collection "$collection" --separator "|" --create-collection true --create-collection-type "$type" --file "$file" --server.endpoint "$ENDPOINT" --server.username "$USERNAME" --server.password "$PASSWORD" "$@"
  import_result=$?
}

process_directory () {
  local collection="$1"
  local type="$2"
  shift 2
  
  # clean up collection beforehand
  echo "db._drop('$collection');" | $ARANGOSH $AUTH
  
  # import all csv files for collection
  for file in `find "$collection" -type f -name "*.csv"`; do
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
