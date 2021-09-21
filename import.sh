ARANGOIMPORT="${ARANGOIMPORT:-build/bin/arangoimport}"
ARANGOSH="${ARANGOSH:-build/bin/arangosh}"
ENDPOINT="${ENDPOINT:-tcp://127.0.0.1:8529}"
USERNAME="${USERNAME:-root}"
PASSWORD="${PASSWORD:-}"
REPLICATION_FACTOR="${REPLICATION_FACTOR:-1}"
NUMBER_OF_SHARDS="${NUMBER_OF_SHARDS:-3}"

run_import () {
  local collection="$1"
  local file="$2"
  local type="$3"
  shift 3
  echo $ARANGOIMPORT -type csv --collection "$collection" --separator "|" --create-collection true --create-collection-type "$type" --file "$file" --server.endpoint "$endpoint" --server.username "$username" --server.password "$password" --replication-factor "$REPLICATION_FACTOR" --number-of-shards "$NUMBER_OF_SHARDS" "$@"
  $ARANGOIMPORT --type csv --collection "$collection" --separator "|" --create-collection true --create-collection-type "$type" --file "$file" --server.endpoint "$ENDPOINT" --server.username "$USERNAME" --server.password "$PASSWORD" --replication-factor "$REPLICATION_FACTOR" --number-of-shards "$NUMBER_OF_SHARDS" "$@"
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
process_directory "Comment" "document" "--datatype CreatorPersonId=string" "--datatype LocationCountryId=string" 
"--datatype ParentPostId=string" "--datatype ParentCommmentId=string" "--translate id=_key"
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
process_directory "Post_hastTag_Tag" "edge" "--from-collection-prefix=Post" "--to-collection-prefix=Tag" "--translate PostId=_from" "--translate TagId=_to" 

