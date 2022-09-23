#!/bin/sh

# from https://docs.docker.com/storage/volumes/
#-----------Backup------------------------------------
# docker run -v /dbdata --name dbstore ubuntu /bin/bash
# docker run --rm --volumes-from dbstore -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /dbdata
#-----------Restore -----------------------------------------
#docker run -v /dbdata --name dbstore2 ubuntu /bin/bash
#un-tar the backup file in the new container’s data volume:
#docker run --rm --volumes-from dbstore2 -v $(pwd):/backup ubuntu bash -c "cd /dbdata && tar xvf /backup/backup.tar --strip 1"
# Needs sub-folders:
# /dbdata
# /backup


#docker run -v /dbdata --name db_data ubuntu /bin/bash
# follow by
# docker run --rm --volumes-from db_data -v $(pwd):/backup ubuntu tar cvf /backup/backup.tar /dbdata
docker volume create --driver local \
    --opt type=none \
    --opt device=/dbdata \
    --opt o=bind db_data