#!/bin/bash

# Archivo de log
log_file="optimize_log_$(date +%Y%m%d_%H%M%S).txt"

# Crear el archivo de log y agregar cabecera
echo "Registro de optimización de tablas - $(date)" | tee -a "$log_file"
echo "-----------------------------------------------" | tee -a "$log_file"

# Solicitar la base de datos de forma interactiva
read -p "Introduce el nombre de la base de datos: " database

# Solicitar el usuario de forma interactiva
read -p "Introduce el usuario de MySQL: " user

# Solicitar la contraseña de forma interactiva y segura
read -s -p "Introduce la contraseña de MySQL para el usuario $user: " password
echo # Agregar una nueva línea después de la entrada de la contraseña

# Definir la ruta de la base de datos en el sistema de archivos
db_path="/var/lib/mysql/$database"

# Verificar si la conexión a MySQL es correcta con los datos proporcionados
echo "Verificando la conexión a MySQL con la información proporcionada..."
mysql -u "$user" -p"$password" -e "USE $database;" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "Error: No se puede conectar a la base de datos con los datos proporcionados o la base de datos no existe." | tee -a "$log_file"
    exit 1
fi
echo "Conexión exitosa. Continuando con la optimización de las tablas..." | tee -a "$log_file"

# Solicitar el listado de tablas a optimizar
read -p "Introduce los nombres de las tablas a optimizar separados por espacio (por ejemplo: tabla1 tabla2 tabla3): " -a tables

# Función para obtener el tamaño de la tabla desde el sistema de archivos en MB
get_table_size_fs_mb() {
    local table=$1
    local size
    size=$(du -sm "$db_path/$table.ibd" 2>/dev/null | cut -f1)
    echo "$size"
}

# Variables para resumen final
total_size_before=0
total_size_after=0

# Comando para optimizar cada tabla y mostrar progreso
for table in "${tables[@]}"
do
    echo "--------------------------------------" | tee -a "$log_file"
    echo "Optimizando tabla: $table ..." | tee -a "$log_file"

    # Obtener el tamaño antes de la optimización (desde el sistema de archivos)
    size_before=$(get_table_size_fs_mb "$table")
    echo "Tamaño antes de optimizar (FS): $size_before MB" | tee -a "$log_file"

    # Sumar el tamaño inicial al total
    total_size_before=$((total_size_before + size_before))

    # Ejecutar la optimización de la tabla
    mysql -u "$user" -p"$password" -e "OPTIMIZE TABLE $database.$table;" | tee -a "$log_file"

    # Obtener el tamaño después de la optimización (desde el sistema de archivos)
    size_after=$(get_table_size_fs_mb "$table")
    echo "Tamaño después de optimizar (FS): $size_after MB" | tee -a "$log_file"

    # Sumar el tamaño final al total
    total_size_after=$((total_size_after + size_after))

    # Calcular el porcentaje de optimización
    if (( size_before > 0 )); then
        optimized_percentage=$(echo "scale=2; (($size_before - $size_after) / $size_before) * 100" | bc)
    else
        optimized_percentage=0
    fi

    echo "Porcentaje de optimización: $optimized_percentage %" | tee -a "$log_file"
    echo "Tabla $table optimizada." | tee -a "$log_file"
done

# Resumen final
echo "--------------------------------------" | tee -a "$log_file"
echo "Resumen final de optimización:" | tee -a "$log_file"
echo "Tamaño total antes de optimizar: $total_size_before MB" | tee -a "$log_file"
echo "Tamaño total después de optimizar: $total_size_after MB" | tee -a "$log_file"
total_optimized_percentage=$(echo "scale=2; (($total_size_before - $total_size_after) / $total_size_before) * 100" | bc)
echo "Porcentaje total de optimización: $total_optimized_percentage %" | tee -a "$log_file"
echo "Optimización de todas las tablas completada." | tee -a "$log_file"
