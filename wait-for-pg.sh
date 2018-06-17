#!/bin/bash
# wait-for-postgres.sh

until $1; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"
exec $2
