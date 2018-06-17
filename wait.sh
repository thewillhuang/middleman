#!/bin/bash
# wait-for-postgres.sh

until $1; do
  >&2 echo "command unavailable - sleeping"
  sleep 1
done

>&2 echo "command ready - executing command"
exec $2
