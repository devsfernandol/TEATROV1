# Lo carga (source) el entrypoint de la imagen oficial de MySQL una sola vez, al
# crear el volumen de datos, después de 01-teatro.sql. No debe ser ejecutable:
# así puede usar la función docker_process_sql del entrypoint.
#
# Crea el usuario de la aplicación con los permisos mínimos sobre TEATRO.

docker_process_sql <<SQL
CREATE USER IF NOT EXISTS 'teatro_app'@'%' IDENTIFIED BY '${TEATRO_DB_PASSWORD}';
GRANT SELECT, INSERT, UPDATE, DELETE ON \`TEATRO\`.* TO 'teatro_app'@'%';
SQL
