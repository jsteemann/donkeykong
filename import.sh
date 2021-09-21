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
  
  # clean up collection and recreate it
  echo "db._drop('$collection'); db._create('$collection', {numberOfShards: $NUMBER_OF_SHARDS, replicationFactor: $REPLICATION_FACTOR});" | $ARANGOSH --server.endpoint "$ARANGO_ENDPOINT" --server.username "$ARANGO_USERNAME" --server.password "$ARANGO_PASSWORD" --javascript.startup-directory "$JAVASCRIPT_DIRECTORY" --quiet true
  import_result="$?"
  if [[ "x$import_result" != "x0" ]]; then
    exit "$import_result"
  fi
  
  # import all csv files for collection
  for file in `find "$DATADIR"/*/"$collection" -type f -name "*.csv"`; do
    run_import "$collection" "$file" "$type" $@
    if [[ "x$import_result" != "x0" ]]; then
      exit "$import_result"
    fi
  done
}

# sanity checks
if [[ ! -f "$ARANGOSH" ]]; then
  echo "unable to find arangosh in $ARANGOSH"
  exit 1
fi
if [[ ! -f "$ARANGOIMPORT" ]]; then
  echo "unable to find arangoimport in $ARANGOIMPORT"
  exit 1
fi

if [[ ! -d "$DATADIR" ]]; then
  echo "unable to find data directory $DATADIR"
  exit 1
fi
for sub in static dynamic; do
  if [[ ! -d "$DATADIR/$sub" ]]; then
    echo "unable to find '$sub' subdirectory in data directory $DATADIR"
    exit 1
  fi
done

process_directory "Person" "document" "--datatype LocationCityId=string" "--translate id=_key"
process_directory "Comment" "document" "--datatype CreatorPersonId=string" "--datatype LocationCountryId=string" "--datatype ParentPostId=string" "--datatype ParentCommmentId=string" "--translate id=_key"
process_directory "Forum" "document" "--datatype ModeratorPersonId=string" "--translate id=_key"
process_directory "Post" "document" "--datatype CreatorPersonId=string" "--datatype ContainerForumId=string" "--dataType LocationForumId=string" "--translate id=_key"
process_directory "Comment_hasTag_Tag" "edge" "--from-collection-prefix=Comment" "--to-collection-prefix=Tag" "--translate CommentId=_from" "--translate TagId=_to" 
process_directory "Forum_hasMember_Person" "edge" "--from-collection-prefix=Forum" "--to-collection-prefix=Person" "--translate ForumId=_from" "--translate PersonId=_to" 
process_directory "Forum_hasTag_Tag" "edge" "--from-collection-prefix=Forum" "--to-collection-prefix=Tag" "--translate ForumId=_from" "--translate TagId=_to" 
process_directory "Person_hasInterest_Tag" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Tag" "--translate PersonId=_from" "--translate TagId=_to" 
process_directory "Person_knows_Person" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Person" "--translate Person1Id=_from" "--translate Person2Id=_to" 
process_directory "Person_likes_Comment" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Comment" "--translate PersonId=_from" "--translate CommentId=_to" 
process_directory "Person_likes_Post" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Post" "--translate PersonId=_from" "--translate PostId=_to" 
process_directory "Person_studyAt_University" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=University" "--translate PersonId=_from" "--translate UniversityId=_to" 
process_directory "Person_workAt_Company" "edge" "--from-collection-prefix=Person" "--to-collection-prefix=Company" "--translate PersonId=_from" "--translate CompanyId=_to" 
process_directory "Post_hasTag_Tag" "edge" "--from-collection-prefix=Post" "--to-collection-prefix=Tag" "--translate PostId=_from" "--translate TagId=_to" 

