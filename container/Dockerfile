FROM mcr.microsoft.com/mssql/rhel/server:2019-CU6-rhel-8

COPY . /
COPY ./db_backup/*.* /var/opt/mssql/backup/
USER root
RUN chmod +x db-init.sh

RUN yum install -y iputils  

RUN /opt/mssql/bin/mssql-conf set sqlagent.enabled true
RUN /opt/mssql/bin/mssql-conf set hadr.hadrenabled  1
RUN /opt/mssql/bin/mssql-conf set memory.memorylimitmb 2048

CMD /bin/bash ./entrypoint.sh
