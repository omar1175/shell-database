#!/bin/bash
# table_module.sh - Enhanced with comprehensive validation

# Source colors
source ./config/text.sh 2>/dev/null

# --- RESERVED KEYWORDS ---
declare -a RESERVED_WORDS=(
    "select" "from" "where" "insert" "update" "delete" "drop" "create"
    "table" "database" "index" "view" "trigger" "procedure" "function"
    "alter" "add" "column" "constraint" "primary" "foreign" "key"
    "null" "not" "unique" "default" "check" "references" "cascade"
    "int" "integer" "varchar" "char" "text" "date" "time" "timestamp"
    "boolean" "bool" "float" "double" "decimal" "numeric"
)

# --- VALIDATION FUNCTIONS ---

# Validate identifier
validate_identifier() {
    local name="$1"
    local type="$2"
    
    [[ -z "$name" ]] && echo -e "${RED}✗ ${type^} name cannot be empty${CLEAR}" && return 1
    [[ ${#name} -lt 1 || ${#name} -gt 64 ]] && echo -e "${RED}✗ ${type^} name must be 1-64 characters${CLEAR}" && return 1
    [[ ! "$name" =~ ^[a-zA-Z] ]] && echo -e "${RED}✗ ${type^} name must start with a letter${CLEAR}" && return 1
    [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]] && echo -e "${RED}✗ Invalid characters in ${type} name${CLEAR}" && return 1
    
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    for keyword in "${RESERVED_WORDS[@]}"; do
        [[ "$name_lower" == "$keyword" ]] && echo -e "${RED}✗ '$name' is a reserved keyword${CLEAR}" && return 1
    done
    
    return 0
}

# Validate no path traversal
validate_safe_name() {
    local name="$1"
    [[ "$name" =~ \.\. ]] || [[ "$name" =~ / ]] || [[ "$name" =~ \\ ]] && \
        echo -e "${RED}✗ Invalid name: security violation${CLEAR}" && return 1
    return 0
}

# Validate table exists
validate_table_exists() {
    local table="$1"
    [[ ! -f "$current_db_path/$table" ]] && echo -e "${RED}✗ Table '$table' does not exist${CLEAR}" && return 1
    return 0
}

# Validate table unique
validate_table_unique() {
    local table="$1"
    [[ -f "$current_db_path/$table" ]] && echo -e "${RED}✗ Table '$table' already exists${CLEAR}" && return 1
    return 0
}

# Validate data type
validate_data_type() {
    local type="$1"
    case "$type" in
        int|string|boolean|bool|varchar|float|date) return 0 ;;
        *) echo -e "${RED}✗ Invalid data type: '$type'${CLEAR}" && return 1 ;;
    esac
}

# Validate column uniqueness in table
validate_column_unique() {
    local col_name="$1"
    local table="$2"
    
    if [[ -f "$current_db_path/.$table" ]]; then
        # Check if column already exists
        existing=$(grep -i "^${col_name}|" "$current_db_path/.$table" 2>/dev/null)
        [[ -n "$existing" ]] && echo -e "${RED}✗ Column '$col_name' already exists${CLEAR}" && return 1
    fi
    
    return 0
}

# Validate integer value
validate_int() {
    local value="$1"
    [[ "$value" == "null" ]] && return 0
    [[ ! "$value" =~ ^-?[0-9]+$ ]] && echo -e "${RED}✗ Must be an integer${CLEAR}" && return 1
    return 0
}

# Validate boolean value
validate_bool() {
    local value="$1"
    [[ "$value" == "null" ]] && return 0
    [[ ! "$value" =~ ^(true|false|0|1)$ ]] && echo -e "${RED}✗ Must be true/false/0/1${CLEAR}" && return 1
    return 0
}

# Validate NOT NULL constraint
validate_not_null() {
    local value="$1"
    local col_name="$2"
    [[ -z "$value" || "$value" == "null" ]] && echo -e "${RED}✗ '$col_name' cannot be NULL${CLEAR}" && return 1
    return 0
}

# Validate PRIMARY KEY uniqueness
validate_pk_unique() {
    local value="$1"
    local col_idx="$2"
    local table="$3"
    local skip_line="${4:-0}"
    
    local exists=$(awk -F'|' -v col=$((col_idx+1)) -v val="$value" -v skip="$skip_line" \
        'NR>1 && NR!=skip && $col == val {print "found"}' "$current_db_path/$table")
    
    [[ "$exists" == "found" ]] && echo -e "${RED}✗ PRIMARY KEY '$value' already exists${CLEAR}" && return 1
    return 0
}

# --- TABLE OPERATIONS ---

case $current_table_state in

    "SHOW_TABLES")
        clear
        echo -e "${CYAN_BOLD}========================================${CLEAR}"
        echo -e "${CYAN_BOLD}        EXISTING TABLES                 ${CLEAR}"
        echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
        
        tables=($(ls "$current_db_path" 2>/dev/null | grep -v "^\."))
        
        if [[ ${#tables[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No tables found${CLEAR}"
        else
            printf "${BOLD}%-5s %-30s %-10s${CLEAR}\n" "No." "Table Name" "Rows"
            echo "----------------------------------------"
            
            counter=1
            for table in "${tables[@]}"; do
                row_count=$(tail -n +2 "$current_db_path/$table" 2>/dev/null | wc -l)
                printf "%-5s ${CYAN}%-30s${CLEAR} %-10s\n" "$counter" "$table" "$row_count"
                ((counter++))
            done
        fi
        
        echo -e "\n${CYAN_BOLD}========================================${CLEAR}"
        echo -e "\nPress any key to go back..."
        read -rsn1
        ;;

    "CREATE_TABLE")
    tput cnorm
    clear
    echo -e "${CYAN_BOLD}========================================${CLEAR}"
    echo -e "${CYAN_BOLD}           CREATE TABLE                 ${CLEAR}"
    echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
    
    echo -e "${BOLD}Table Name: ${CLEAR}\c"
    read -r tableName
    
    # Validate table name
    if ! validate_identifier "$tableName" "table" || \
       ! validate_safe_name "$tableName" || \
       ! validate_table_unique "$tableName"; then
        echo -e "\nPress any key to continue..."
        read -rsn1
        tput civis
    else
        echo -e "\n${BOLD}Number of Columns: ${CLEAR}\c"
        read -r numCols
        
        if ! [[ "$numCols" =~ ^[0-9]+$ ]] || [[ $numCols -lt 1 ]]; then
            echo -e "\n${RED}✗ Invalid number of columns${CLEAR}"
            echo -e "\nPress any key to continue..."
            read -rsn1
            tput civis
        else
            # Create temporary metadata file
            temp_meta="$current_db_path/.temp_meta_${tableName}_$$"
            echo "Column_Name|Column_Type|Primary_Key|Not_Null|Unique" > "$temp_meta"
            
            pkCount=0
            validTable=true
            declare -a colNames
            
            for ((i=0; i<numCols; i++)); do
                echo -e "\n${CYAN}--- Column $((i+1)) of $numCols ---${CLEAR}"
                
                # Column name
                echo -e "${BOLD}Column Name: ${CLEAR}\c"
                read -r colName
                
                if ! validate_identifier "$colName" "column" || \
                   ! validate_column_unique "$colName" "$tableName"; then
                    validTable=false
                    break
                fi
                
                colNames[$i]="$colName"
                
                # Data type
                echo -e "\n${BOLD}Data Type:${CLEAR}"
                echo "  1) int"
                echo "  2) string"
                echo "  3) boolean"
                echo -e "${BOLD}Choice: ${CLEAR}\c"
                read -r typeChoice
                
                case $typeChoice in
                    1) colType="int" ;;
                    2) colType="string" ;;
                    3) colType="boolean" ;;
                    *) colType="string" ;;
                esac
                
                # --- START OF UPDATED YES/NO VALIDATION LOGIC ---
                
                # Primary Key validation
                isPK="no"
                if [[ $pkCount -eq 0 && "$colType" != "boolean" ]]; then
                    while true; do
                        echo -e "\n${BOLD}Primary Key? (y/n): ${CLEAR}\c"
                        read -r pkAnswer
                        case $pkAnswer in
                            [Yy]) isPK="yes"; pkCount=1; break ;;
                            [Nn]) isPK="no"; break ;;
                            *) echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${CLEAR}" ;;
                        esac
                    done
                fi
                
                # NOT NULL validation
                isNotNull="no"
                if [[ "$isPK" != "yes" ]]; then
                    while true; do
                        echo -e "${BOLD}NOT NULL constraint? (y/n): ${CLEAR}\c"
                        read -r nnAnswer
                        case $nnAnswer in
                            [Yy]) isNotNull="yes"; break ;;
                            [Nn]) isNotNull="no"; break ;;
                            *) echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${CLEAR}" ;;
                        esac
                    done
                else
                    isNotNull="yes"  # PK is always NOT NULL
                fi
                
                # UNIQUE validation
                isUnique="no"
                if [[ "$isPK" != "yes" ]]; then
                    while true; do
                        echo -e "${BOLD}UNIQUE constraint? (y/n): ${CLEAR}\c"
                        read -r uqAnswer
                        case $uqAnswer in
                            [Yy]) isUnique="yes"; break ;;
                            [Nn]) isUnique="no"; break ;;
                            *) echo -e "${RED}Invalid input. Please enter 'y' or 'n'.${CLEAR}" ;;
                        esac
                    done
                else
                    isUnique="yes"  # PK is always UNIQUE
                fi
                
                # --- END OF UPDATED YES/NO VALIDATION LOGIC ---

                # Write metadata
                echo "$colName|$colType|$isPK|$isNotNull|$isUnique" >> "$temp_meta"
            done
            
            if [[ "$validTable" == true ]]; then
                # Create header
                headerLine=""
                for ((i=0; i<numCols; i++)); do
                    [[ $i -lt $((numCols - 1)) ]] && headerLine+="${colNames[$i]}|" || headerLine+="${colNames[$i]}"
                done
                
                # Atomic write
                temp_table="$current_db_path/.temp_${tableName}_$$"
                echo "$headerLine" > "$temp_table"
                
                # Atomic rename
                mv "$temp_meta" "$current_db_path/.$tableName" 2>>./logs/.error.log
                mv "$temp_table" "$current_db_path/$tableName" 2>>./logs/.error.log
                
                if [[ $? -eq 0 ]]; then
                    chmod 644 "$current_db_path/$tableName" "$current_db_path/.$tableName" 2>>./logs/.error.log
                    echo -e "\n${GREEN}✓ Table '$tableName' created successfully${CLEAR}"
                else
                    echo -e "\n${RED}✗ Error creating table${CLEAR}"
                fi
            else
                rm -f "$temp_meta" 2>>./logs/.error.log
                echo -e "\n${RED}✗ Table creation cancelled${CLEAR}"
            fi
            
            echo -e "\nPress any key to continue..."
            read -rsn1
        fi
        tput civis
    fi
    ;;
    "INSERT_TABLE")
        tput cnorm
        clear
        echo -e "${CYAN_BOLD}========================================${CLEAR}"
        echo -e "${CYAN_BOLD}         INSERT INTO TABLE              ${CLEAR}"
        echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
        
        echo -e "${BOLD}Table Name: ${CLEAR}\c"
        read -r tableName
        
        if ! validate_table_exists "$tableName"; then
            echo -e "\nPress any key to continue..."
            read -rsn1
            tput civis
        else
            # Load metadata
            unset colNames colTypes colPKs colNotNull colUnique
            declare -a colNames colTypes colPKs colNotNull colUnique
            
            IFS='|' read -r -a headerArr <<< "$(head -n 1 "$current_db_path/$tableName")"
            numCols=${#headerArr[@]}
            
            for ((j=0; j<numCols; j++)); do
                metaLine=$(sed -n "$((j + 2))p" "$current_db_path/.$tableName" 2>/dev/null)
                colNames[$j]=$(echo "$metaLine" | cut -d '|' -f 1 | tr -d '\r\n ')
                colTypes[$j]=$(echo "$metaLine" | cut -d '|' -f 2 | tr -d '\r\n ')
                colPKs[$j]=$(echo "$metaLine" | cut -d '|' -f 3 | tr -d '\r\n ')
                colNotNull[$j]=$(echo "$metaLine" | cut -d '|' -f 4 | tr -d '\r\n ')
                colUnique[$j]=$(echo "$metaLine" | cut -d '|' -f 5 | tr -d '\r\n ')
            done
            
            echo -e "\n${BOLD}Number of Rows to Insert: ${CLEAR}\c"
            read -r numRows
            
            if ! [[ "$numRows" =~ ^[0-9]+$ ]] || [[ $numRows -lt 1 ]]; then
                echo -e "\n${RED}✗ Invalid number of rows${CLEAR}"
                echo -e "\nPress any key to continue..."
                read -rsn1
                tput civis
            else
                for ((rowNum=1; rowNum<=numRows; rowNum++)); do
                    echo -e "\n${YELLOW}========= Row $rowNum of $numRows =========${CLEAR}\n"
                    
                    newRow=""
                    rowValid=true
                    
                    for ((colIdx=0; colIdx<numCols; colIdx++)); do
                        echo -e "${BOLD}${colNames[$colIdx]}${CLEAR}"
                        echo -e "  Type: ${CYAN}${colTypes[$colIdx]}${CLEAR}"
                        echo -e "  PK: ${CYAN}${colPKs[$colIdx]:-no}${CLEAR} | NOT NULL: ${CYAN}${colNotNull[$colIdx]:-no}${CLEAR} | UNIQUE: ${CYAN}${colUnique[$colIdx]:-no}${CLEAR}"
                        echo -e "  Value: \c"
                        read -r cellValue
                        
                        # Validate NOT NULL
                        if [[ "${colNotNull[$colIdx]}" == "yes" ]]; then
                            if ! validate_not_null "$cellValue" "${colNames[$colIdx]}"; then
                                rowValid=false
                                break
                            fi
                        fi
                        
                        # Allow null for non-required fields
                        [[ -z "$cellValue" && "${colNotNull[$colIdx]}" != "yes" ]] && cellValue="null"
                        
                        # Validate data type
                        if [[ "$cellValue" != "null" ]]; then
                            case "${colTypes[$colIdx]}" in
                                int)
                                    if ! validate_int "$cellValue"; then
                                        rowValid=false
                                        break
                                    fi
                                    ;;
                                boolean|bool)
                                    if ! validate_bool "$cellValue"; then
                                        rowValid=false
                                        break
                                    fi
                                    ;;
                            esac
                        fi
                        
                        # Validate PRIMARY KEY uniqueness
                        if [[ "${colPKs[$colIdx]}" == "yes" ]]; then
                            if ! validate_pk_unique "$cellValue" "$colIdx" "$tableName"; then
                                rowValid=false
                                break
                            fi
                        fi
                        
                        # Validate UNIQUE constraint
                        if [[ "${colUnique[$colIdx]}" == "yes" && "$cellValue" != "null" ]]; then
                            if ! validate_pk_unique "$cellValue" "$colIdx" "$tableName"; then
                                echo -e "${RED}✗ UNIQUE constraint violated${CLEAR}"
                                rowValid=false
                                break
                            fi
                        fi
                        
                        [[ $colIdx -lt $((numCols - 1)) ]] && newRow+="$cellValue|" || newRow+="$cellValue"
                        echo ""
                    done
                    
                    if [[ "$rowValid" == true ]]; then
                        echo "$newRow" >> "$current_db_path/$tableName"
                        echo -e "${GREEN}✓ Row $rowNum inserted${CLEAR}\n"
                    else
                        echo -e "${YELLOW}⚠ Row $rowNum rejected. Retrying...${CLEAR}\n"
                        sleep 1
                        ((rowNum--))
                    fi
                done
                
                echo -e "${GREEN}✓✓✓ All rows inserted successfully! ✓✓✓${CLEAR}"
                echo -e "\nPress any key to continue..."
                read -rsn1
            fi
            tput civis
        fi
        ;;

    "SELECT_TABLE")
        tput cnorm
        clear
        echo -e "${CYAN_BOLD}========================================${CLEAR}"
        echo -e "${CYAN_BOLD}          SELECT FROM TABLE             ${CLEAR}"
        echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
        
        echo -e "${BOLD}Table Name: ${CLEAR}\c"
        read -r tableName
        
        if ! validate_table_exists "$tableName"; then
            echo -e "\nPress any key to continue..."
            read -rsn1
            tput civis
        else
            echo -e "\n${BOLD}Select Option:${CLEAR}"
            echo "  1) Select All"
            echo "  2) Select Specific Column"
            echo "  3) Select with WHERE (basic)"
            echo -e "${BOLD}Choice: ${CLEAR}\c"
            read -r selectChoice
            
            case $selectChoice in
                1)
                    echo -e "\n${BLUE_BOLD}========= Table: $tableName =========${CLEAR}"
                    cat "$current_db_path/$tableName"
                    echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                    ;;
                2)
                    IFS='|' read -r -a headerArr <<< "$(head -n 1 "$current_db_path/$tableName")"
                    numCols=${#headerArr[@]}
                    
                    echo -e "\n${BOLD}Columns:${CLEAR}"
                    for ((i=0; i<numCols; i++)); do
                        echo "  $((i+1))) ${headerArr[$i]}"
                    done
                    
                    echo -e "\n${BOLD}Column Number: ${CLEAR}\c"
                    read -r colNum
                    
                    if [[ $colNum -ge 1 && $colNum -le $numCols ]]; then
                        echo -e "\n${BLUE_BOLD}========= Column: ${headerArr[$((colNum-1))]} =========${CLEAR}"
                        cut -d'|' -f"$colNum" "$current_db_path/$tableName"
                        echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                    else
                        echo -e "\n${RED}✗ Invalid column${CLEAR}"
                    fi
                    ;;
                3)
                    echo -e "\n${YELLOW}(Basic WHERE implementation)${CLEAR}"
                    echo -e "${BOLD}Column name: ${CLEAR}\c"
                    read -r whereCol
                    echo -e "${BOLD}Value: ${CLEAR}\c"
                    read -r whereVal
                    
                    echo -e "\n${BLUE_BOLD}========= Results =========${CLEAR}"
                    head -n1 "$current_db_path/$tableName"
                    grep "|$whereVal|" "$current_db_path/$tableName" 2>/dev/null
                    echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                    ;;
            esac
            
            echo -e "\nPress any key to continue..."
            read -rsn1
        fi
        tput civis
        ;;

    "DELETE_ROW")
        tput cnorm
        echo -e "Table Name: \c"
        read -r tableName
        if [[ -f "$current_db_path/$tableName" ]]; then
            lineCount=$(wc -l < "$current_db_path/$tableName")
            if [[ $lineCount -le 1 ]]; then
                echo -e "${RED}Table is empty (only header exists).${CLEAR}"
            else
                echo -e "\n${BOLD}Current Table Data:${CLEAR}"
                echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                cat "$current_db_path/$tableName"
                echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                
                # Show rows starting from line 2 (skipping header)
                echo -e "\n${BOLD}Available Rows:${CLEAR}"
                sed -n '2,$p' "$current_db_path/$tableName" | nl -w2 -s') '
                echo -e "\nEnter the row number to delete: \c"
                read -r rowIdx
                
                if [[ $rowIdx =~ ^[0-9]+$ ]] && [[ $rowIdx -ge 1 ]] && [[ $rowIdx -lt $lineCount ]]; then
                    # Adjust for header (row 1), so target is rowIdx + 1
                    sed -i "$((rowIdx + 1))d" "$current_db_path/$tableName"
                    echo -e "${GREEN}✓ Row deleted successfully.${CLEAR}"
                else
                    echo -e "${RED}Invalid row number.${CLEAR}"
                fi
            fi
        else
            echo -e "${RED}Error: Table not found.${CLEAR}"
        fi
        sleep 1
        tput civis
        ;;


   "UPDATE_CELL")
        tput cnorm
        clear
        echo -e "${CYAN_BOLD}========================================${CLEAR}"
        echo -e "${CYAN_BOLD}           UPDATE TABLE DATA            ${CLEAR}"
        echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
        
        echo -e "${BOLD}Table Name: ${CLEAR}\c"
        read -r tableName
        
        if [[ ! -f "$current_db_path/$tableName" ]]; then
            echo -e "\n${RED}✗ Error: Table '$tableName' not found.${CLEAR}"
            echo -e "\nPress any key to return to menu..."
            read -rsn1
            tput civis
        else
            # Check if table has data
            lineCount=$(wc -l < "$current_db_path/$tableName")
            
            if [[ $lineCount -le 1 ]]; then
                echo -e "\n${RED}✗ Table is empty (only header exists).${CLEAR}"
                echo -e "\nPress any key to return to menu..."
                read -rsn1
                tput civis
            else
                # Load table metadata
                unset colNames colTypes colPKs
                declare -a colNames
                declare -a colTypes
                declare -a colPKs
                
                # Read header
                IFS='|' read -r -a colNames <<< "$(head -n 1 "$current_db_path/$tableName")"
                numCols=${#colNames[@]}
                
                # Load metadata if exists
                if [[ -f "$current_db_path/.$tableName" ]]; then
                    for ((j=0; j<numCols; j++)); do
                        metaLine=$(sed -n "$((j + 2))p" "$current_db_path/.$tableName" 2>/dev/null)
                        colTypes[$j]=$(echo "$metaLine" | cut -d '|' -f 2 | tr -d '\r\n ')
                        colPKs[$j]=$(echo "$metaLine" | cut -d '|' -f 3 | tr -d '\r\n ')
                    done
                else
                    # No metadata, set defaults
                    for ((j=0; j<numCols; j++)); do
                        colTypes[$j]="string"
                        colPKs[$j]="no"
                    done
                fi
                
                # Display current table data
                echo -e "\n${BOLD}Current Table Data:${CLEAR}"
                echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                cat "$current_db_path/$tableName"
                echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                
                # Show numbered rows (excluding header)
                echo -e "\n${BOLD}Available Rows:${CLEAR}"
                sed -n '2,$p' "$current_db_path/$tableName" | nl -w2 -s') '
                
                # Get row number to update
                echo -e "\n${BOLD}Enter the row number to update: ${CLEAR}\c"
                read -r rowNum
                
                # Validate row number
                if ! [[ $rowNum =~ ^[0-9]+$ ]] || [[ $rowNum -lt 1 ]] || [[ $rowNum -ge $lineCount ]]; then
                    echo -e "\n${RED}✗ Invalid row number.${CLEAR}"
                    echo -e "\nPress any key to return to menu..."
                    read -rsn1
                    tput civis
                else
                    # Get the actual row data (rowNum + 1 to account for header)
                    actualLineNum=$((rowNum + 1))
                    currentRowData=$(sed -n "${actualLineNum}p" "$current_db_path/$tableName")
                    
                    # Split current row data
                    IFS='|' read -r -a currentValues <<< "$currentRowData"
                    
                    # Display current row values
                    echo -e "\n${CYAN_BOLD}========= Current Values for Row $rowNum =========${CLEAR}\n"
                    for ((i=0; i<numCols; i++)); do
                        echo -e "${BOLD}$((i+1))) ${colNames[$i]}${CLEAR}"
                        echo -e "   Current Value: ${YELLOW}${currentValues[$i]}${CLEAR}"
                        echo -e "   Type: ${CYAN}${colTypes[$i]:-string}${CLEAR}"
                        echo -e "   Primary Key: ${CYAN}${colPKs[$i]:-no}${CLEAR}"
                        echo ""
                    done
                    
                    # Ask which column to update
                    echo -e "${BOLD}Enter the column number to update (or 0 to cancel): ${CLEAR}\c"
                    read -r colNum
                    
                    # Validate column number
                    if [[ $colNum -eq 0 ]]; then
                        echo -e "\n${CYAN}ℹ Operation cancelled.${CLEAR}"
                        echo -e "\nPress any key to return to menu..."
                        read -rsn1
                        tput civis
                    elif ! [[ $colNum =~ ^[0-9]+$ ]] || [[ $colNum -lt 1 ]] || [[ $colNum -gt $numCols ]]; then
                        echo -e "\n${RED}✗ Invalid column number.${CLEAR}"
                        echo -e "\nPress any key to return to menu..."
                        read -rsn1
                        tput civis
                    else
                        # Adjust to 0-based index
                        colIdx=$((colNum - 1))
                        
                        # Show current value and get new value
                        echo -e "\n${CYAN_BOLD}========= Update Cell =========${CLEAR}"
                        echo -e "${BOLD}Column: ${colNames[$colIdx]}${CLEAR}"
                        echo -e "Current Value: ${YELLOW}${currentValues[$colIdx]}${CLEAR}"
                        echo -e "Type: ${CYAN}${colTypes[$colIdx]:-string}${CLEAR}"
                        echo -e "Primary Key: ${CYAN}${colPKs[$colIdx]:-no}${CLEAR}\n"
                        
                        echo -e "${BOLD}Enter new value: ${CLEAR}\c"
                        read -r newValue
                        
                        # Validate new value
                        validationPassed=true
                        
                        # Check if empty (and if it's a primary key)
                        if [[ -z "$newValue" ]]; then
                            if [[ "${colPKs[$colIdx]}" == "yes" ]]; then
                                echo -e "\n${RED}✗ Error: Primary Key cannot be empty!${CLEAR}"
                                validationPassed=false
                            else
                                newValue="null"
                            fi
                        fi
                        
                        # Validate data type: INTEGER
                        if [[ "$validationPassed" == true && "${colTypes[$colIdx]}" == "int" && "$newValue" != "null" ]]; then
                            if ! [[ "$newValue" =~ ^[0-9]+$ ]]; then
                                echo -e "\n${RED}✗ Error: Value must be a positive integer!${CLEAR}"
                                validationPassed=false
                            fi
                        fi
                        
                        # Validate data type: BOOLEAN
                        if [[ "$validationPassed" == true && "${colTypes[$colIdx]}" == "bool" && "$newValue" != "null" ]]; then
                            if ! [[ "$newValue" =~ ^(true|false)$ ]]; then
                                echo -e "\n${RED}✗ Error: Value must be 'true' or 'false'!${CLEAR}"
                                validationPassed=false
                            fi
                        fi
                        
                        # Validate PRIMARY KEY UNIQUENESS (if it's a PK and value changed)
                        if [[ "$validationPassed" == true && "${colPKs[$colIdx]}" == "yes" && "$newValue" != "${currentValues[$colIdx]}" ]]; then
                            # Check if new PK value already exists
                            pkExists=$(awk -F'|' -v col=$((colIdx+1)) -v val="$newValue" -v skipLine=$actualLineNum \
                                'NR>1 && NR!=skipLine && $col == val {print "found"}' "$current_db_path/$tableName")
                            
                            if [[ "$pkExists" == "found" ]]; then
                                echo -e "\n${RED}✗ Error: Primary Key value '$newValue' already exists!${CLEAR}"
                                validationPassed=false
                            fi
                        fi
                        
                        # If validation passed, update the cell
                        if [[ "$validationPassed" == true ]]; then
                            # Build new row with updated value
                            newRowData=""
                            for ((i=0; i<numCols; i++)); do
                                if [[ $i -eq $colIdx ]]; then
                                    # Use new value for this column
                                    if [[ $i -lt $((numCols - 1)) ]]; then
                                        newRowData+="$newValue|"
                                    else
                                        newRowData+="$newValue"
                                    fi
                                else
                                    # Keep existing value
                                    if [[ $i -lt $((numCols - 1)) ]]; then
                                        newRowData+="${currentValues[$i]}|"
                                    else
                                        newRowData+="${currentValues[$i]}"
                                    fi
                                fi
                            done
                            
                            # Replace the line in the file
                            sed -i "${actualLineNum}s/.*/$newRowData/" "$current_db_path/$tableName"
                            
                            # Show success message
                            echo -e "\n${GREEN}✓ Cell updated successfully!${CLEAR}"
                            
                            # Show updated row
                            echo -e "\n${BOLD}Updated Row Data:${CLEAR}"
                            echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                            echo -e "${BOLD}Before:${CLEAR} $currentRowData"
                            echo -e "${BOLD}After:${CLEAR}  $newRowData"
                            echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                            
                            # Show full updated table
                            echo -e "\n${BOLD}Complete Table:${CLEAR}"
                            echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                            cat "$current_db_path/$tableName"
                            echo -e "${BLUE_BOLD}=====================================${CLEAR}"
                        else
                            echo -e "\n${YELLOW}⚠ Update cancelled due to validation errors.${CLEAR}"
                        fi
                        
                        echo -e "\nPress any key to return to menu..."
                        read -rsn1
                        tput civis
                    fi
                fi
            fi
        fi
        ;;

    "DROP_TABLE")
        tput cnorm
        clear
        echo -e "${CYAN_BOLD}========================================${CLEAR}"
        echo -e "${CYAN_BOLD}            DROP TABLE                  ${CLEAR}"
        echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
        
        echo -e "${BOLD}Table Name: ${CLEAR}\c"
        read -r tableName
        
        if ! validate_table_exists "$tableName"; then
            echo -e "\nPress any key to continue..."
            read -rsn1
            tput civis
        else
            row_count=$(tail -n +2 "$current_db_path/$tableName" 2>/dev/null | wc -l)
            
            echo -e "\n${YELLOW}⚠ WARNING: Dropping table '$tableName'${CLEAR}"
            echo -e "  • Rows: ${CYAN}$row_count${CLEAR}"
            echo -e "  • This action cannot be undone!${CLEAR}\n"
            
            echo -e "${RED}${BOLD}Are you sure? (y/n): ${CLEAR}\c"
            read -rsn1 confirm
            echo ""
            
            if [[ "$confirm" == [Yy] ]]; then
                rm -f "$current_db_path/$tableName" "$current_db_path/.$tableName" 2>>./logs/.error.log
                
                if [[ $? -eq 0 ]]; then
                    echo -e "\n${GREEN}✓ Table '$tableName' dropped${CLEAR}"
                else
                    echo -e "\n${RED}✗ Error dropping table${CLEAR}"
                fi
            else
                echo -e "\n${CYAN}ℹ Operation cancelled${CLEAR}"
            fi
            
            echo -e "\nPress any key to continue..."
            read -rsn1
        fi
        tput civis
        ;;
esac