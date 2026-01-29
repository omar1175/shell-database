#!/bin/bash
# Hide cursor
tput civis

# Source external colors and configurations
source ./config/text.sh 2>> ./.error.log

# --- RESERVED KEYWORDS (SQL-like) ---
declare -a RESERVED_WORDS=(
    "select" "from" "where" "insert" "update" "delete" "drop" "create"
    "table" "database" "index" "view" "trigger" "procedure" "function"
    "alter" "add" "column" "constraint" "primary" "foreign" "key"
    "null" "not" "unique" "default" "check" "references" "cascade"
    "int" "integer" "varchar" "char" "text" "date" "time" "timestamp"
    "boolean" "bool" "float" "double" "decimal" "numeric"
)

# --- VALIDATION FUNCTIONS ---

# Validate identifier (database/table/column name)
validate_identifier() {
    local name="$1"
    local type="$2"  # "database", "table", or "column"
    
    # Check if empty
    if [[ -z "$name" ]]; then
        echo -e "${RED}✗ ${type^} name cannot be empty${CLEAR}"
        return 1
    fi
    
    # Check length (1-64 characters)
    if [[ ${#name} -lt 1 || ${#name} -gt 64 ]]; then
        echo -e "${RED}✗ ${type^} name must be between 1 and 64 characters${CLEAR}"
        return 1
    fi
    
    # Check starts with a letter
    if [[ ! "$name" =~ ^[a-zA-Z] ]]; then
        echo -e "${RED}✗ ${type^} name must start with a letter${CLEAR}"
        return 1
    fi
    
    # Check contains only letters, numbers, and underscores
    if [[ ! "$name" =~ ^[a-zA-Z][a-zA-Z0-9_]*$ ]]; then
        echo -e "${RED}✗ ${type^} name can only contain letters, numbers, and underscores${CLEAR}"
        return 1
    fi
    
    # Check not numeric-only (after first letter)
    if [[ "$name" =~ ^[a-zA-Z]$ ]]; then
        # Single letter is fine
        :
    elif [[ "${name:1}" =~ ^[0-9_]+$ ]]; then
        # Rest is only numbers/underscores - check if valid
        if [[ ! "${name:1}" =~ [a-zA-Z] ]]; then
            echo -e "${RED}✗ ${type^} name cannot be numeric-only (except first letter)${CLEAR}"
            return 1
        fi
    fi
    
    # Check not a reserved keyword (case-insensitive)
    local name_lower=$(echo "$name" | tr '[:upper:]' '[:lower:]')
    for keyword in "${RESERVED_WORDS[@]}"; do
        if [[ "$name_lower" == "$keyword" ]]; then
            echo -e "${RED}✗ '${name}' is a reserved keyword and cannot be used${CLEAR}"
            return 1
        fi
    done
    
    return 0
}

# Validate database doesn't already exist
validate_database_unique() {
    local db_name="$1"
    
    if [[ -d "./databases/$db_name" ]]; then
        echo -e "${RED}✗ Database '$db_name' already exists${CLEAR}"
        return 1
    fi
    
    return 0
}

# Validate database exists
validate_database_exists() {
    local db_name="$1"
    
    if [[ ! -d "./databases/$db_name" ]]; then
        echo -e "${RED}✗ Database '$db_name' does not exist${CLEAR}"
        return 1
    fi
    
    return 0
}

# Prevent path traversal attacks
validate_no_path_traversal() {
    local name="$1"
    
    if [[ "$name" =~ \.\. ]] || [[ "$name" =~ / ]] || [[ "$name" =~ \\ ]]; then
        echo -e "${RED}✗ Invalid name: path traversal detected${CLEAR}"
        return 1
    fi
    
    return 0
}

title=(
"\n${PURPLE_BOLD}         ╭───╮   ╭───╮   ╭───╮   ╭───╮"
"${PURPLE_BOLD}         │ O │   │ M │   │ A │   │ R │"
"${PURPLE_BOLD}         ╰─┬─╯   ╰─┬─╯   ╰─┬─╯   ╰─┬─╯"
"${PURPLE_BOLD}           │       │       │       │"
"${CYAN_BOLD}       ═════╧═══════╧═══════╧═══════╧═════"
"${CYAN_BOLD}                 ⚡  OMAR  ×  HANY  ⚡"
"${CYAN_BOLD}       ═════╤═══════╤═══════╤═══════╤═════"
"${GREEN_BOLD}            │       │       │       │"
"${GREEN_BOLD}          ╭─┴─╮   ╭─┴─╮   ╭─┴─╮   ╭─┴─╮"
"${GREEN_BOLD}          │ H │   │ A │   │ N │   │ Y │"
"${GREEN_BOLD}          ╰───╯   ╰───╯   ╰───╯   ╰───╯"
""
"${WHITE_BOLD}        ▸ Bash DBMS ▸ Terminal Crafted ▸"
)


# Menu Definitions
mainMenu=("------------------Main Menu------------------" "1- Select Database" "2- Create Database" "3- Drop Database" "4- Show Database" "5- Exit")
tableMenu=("------------------Tables Menu------------------" "1- Show Existing Tables" "2- Create New Table" "3- Insert Into Table" "4- Select From Table" "5- Delete From Table" "6- Update Cell" "7- Drop Table" "8- Back to Main Menu" "9- Exit")

# --- INITIAL SETUP ---
clear
for line in "${title[@]}"; do 
    echo -e "$line"
    sleep 0.05
done
sleep 0.3


echo -e "${CLEAR}\n${BOLD}Press any key to continue${CLEAR}"
read -rsn1 key
tput cnorm

# Create necessary directories with safe permissions
mkdir -p databases 2>> ./.error.log
chmod 755 databases 2>> ./.error.log
mkdir -p logs 2>> ./.error.log
chmod 755 logs 2>> ./.error.log

# State Management Variables
current_state="MAIN_MENU"
current_db_path=""

# --- MASTER LOOP ---
while true; do
    case $current_state in
        "MAIN_MENU")
            choice=1
            while true; do
                clear
                tput civis
                echo -e "${BOLD}${mainMenu[0]}${CLEAR}"
                for ((line=1; line<${#mainMenu[@]}; line++)); do
                    if [[ $line == $choice ]]; then 
                        echo -e "${GREEN}> ${mainMenu[$line]} ${CLEAR}"
                    else 
                        echo "${mainMenu[$line]}"
                    fi
                done
                
                read -rsn1 action
                if [[ $action == $'\x1b' ]]; then
                    read -rsn2 action
                    case $action in
                        "[A") ((choice--))
                              [[ $choice -lt 1 ]] && choice=$((${#mainMenu[@]} - 1)) ;;
                        "[B") ((choice++))
                              [[ $choice -ge ${#mainMenu[@]} ]] && choice=1 ;;
                    esac
                elif [[ $action == "" ]]; then
                    user_selection=$((choice - 1))
                    break
                fi
            done
            
            case $user_selection in
                0) current_state="SELECT_DB" ;;
                1) current_state="CREATE_DB" ;;
                2) current_state="DROP_DB" ;;
                3) current_state="SHOW_DB" ;;
                4) exit ;;
            esac
            ;;

        "SELECT_DB")
            tput cnorm
            clear
            echo -e "${CYAN_BOLD}========================================${CLEAR}"
            echo -e "${CYAN_BOLD}          SELECT DATABASE               ${CLEAR}"
            echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
            
            echo -e "${BOLD}Database Name: ${CLEAR}\c"
            read -r nameDB
            
            # Validation chain
            if validate_identifier "$nameDB" "database" && \
               validate_no_path_traversal "$nameDB" && \
               validate_database_exists "$nameDB"; then
                current_db_path="./databases/$nameDB"
                echo -e "\n${GREEN}✓ Connected to database '$nameDB'${CLEAR}"
                sleep 1
                current_state="TABLE_MENU"
            else
                echo -e "\nPress any key to return to Main Menu..."
                read -rsn1
                current_state="MAIN_MENU"
            fi
            tput civis
            ;;

        "CREATE_DB")
            tput cnorm
            clear
            echo -e "${CYAN_BOLD}========================================${CLEAR}"
            echo -e "${CYAN_BOLD}          CREATE DATABASE               ${CLEAR}"
            echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
            
            echo -e "${BOLD}Database Name: ${CLEAR}\c"
            read -r nameDB
            
            # Validation chain
            if validate_identifier "$nameDB" "database" && \
               validate_no_path_traversal "$nameDB" && \
               validate_database_unique "$nameDB"; then
                
                # Create database directory with atomic operation
                temp_dir="./databases/.temp_${nameDB}_$$"
                mkdir -p "$temp_dir" 2>>./logs/.error.log
                
                if [[ $? -eq 0 ]]; then
                    # Atomic rename
                    mv "$temp_dir" "./databases/$nameDB" 2>>./logs/.error.log
                    
                    if [[ $? -eq 0 ]]; then
                        # Set safe permissions
                        chmod 755 "./databases/$nameDB" 2>>./logs/.error.log
                        
                        echo -e "\n${GREEN}✓ Database '$nameDB' created successfully${CLEAR}"
                        sleep 1
                        current_db_path="./databases/$nameDB"
                        current_state="TABLE_MENU"
                    else
                        rm -rf "$temp_dir" 2>>./logs/.error.log
                        echo -e "\n${RED}✗ Error creating database${CLEAR}"
                        sleep 1
                        current_state="MAIN_MENU"
                    fi
                else
                    echo -e "\n${RED}✗ Error creating database${CLEAR}"
                    sleep 1
                    current_state="MAIN_MENU"
                fi
            else
                echo -e "\nPress any key to return to Main Menu..."
                read -rsn1
                current_state="MAIN_MENU"
            fi
            tput civis
            ;;

        "DROP_DB")
            tput cnorm
            clear
            echo -e "${CYAN_BOLD}========================================${CLEAR}"
            echo -e "${CYAN_BOLD}           DROP DATABASE                ${CLEAR}"
            echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
            
            echo -e "${BOLD}Database Name: ${CLEAR}\c"
            read -r nameDB
            
            # Validation chain
            if validate_identifier "$nameDB" "database" && \
               validate_no_path_traversal "$nameDB" && \
               validate_database_exists "$nameDB"; then
                
                # Show database info
                table_count=$(ls "./databases/$nameDB" 2>/dev/null | grep -v "^\." | wc -l)
                echo -e "\n${YELLOW}⚠ WARNING: This will permanently delete:${CLEAR}"
                echo -e "  • Database: ${CYAN}$nameDB${CLEAR}"
                echo -e "  • Tables: ${CYAN}$table_count${CLEAR}"
                echo -e "  • All data will be lost!${CLEAR}\n"
                
                echo -e "${RED}${BOLD}Are you sure? (y/n): ${CLEAR}\c"
                read -rsn1 ans
                echo ""
                
                if [[ $ans == [Yy] ]]; then
                    # Safe deletion with confirmation
                    rm -rf "./databases/$nameDB" 2>>./logs/.error.log
                    
                    if [[ $? -eq 0 ]]; then
                        echo -e "\n${GREEN}✓ Database '$nameDB' deleted successfully${CLEAR}"
                    else
                        echo -e "\n${RED}✗ Error deleting database${CLEAR}"
                    fi
                else
                    echo -e "\n${CYAN}ℹ Operation cancelled${CLEAR}"
                fi
            fi
            
            sleep 1
            current_state="MAIN_MENU"
            tput civis
            ;;

        "SHOW_DB")
            clear
            echo -e "${CYAN_BOLD}========================================${CLEAR}"
            echo -e "${CYAN_BOLD}        EXISTING DATABASES              ${CLEAR}"
            echo -e "${CYAN_BOLD}========================================${CLEAR}\n"
            
            # Get databases
            databases=($(ls ./databases 2>/dev/null))
            
            if [[ ${#databases[@]} -eq 0 ]]; then
                echo -e "${YELLOW}No databases found${CLEAR}"
            else
                printf "${BOLD}%-5s %-30s %-10s${CLEAR}\n" "No." "Database Name" "Tables"
                echo "----------------------------------------"
                
                counter=1
                for db in "${databases[@]}"; do
                    # Skip hidden files
                    [[ "$db" =~ ^\. ]] && continue
                    
                    # Count tables
                    table_count=$(ls "./databases/$db" 2>/dev/null | grep -v "^\." | wc -l)
                    printf "%-5s ${CYAN}%-30s${CLEAR} %-10s\n" "$counter" "$db" "$table_count"
                    ((counter++))
                done
            fi
            
            echo -e "\n${CYAN_BOLD}========================================${CLEAR}"
            echo -e "\nPress any key to go back..."
            read -rsn1
            current_state="MAIN_MENU"
            ;;

        "TABLE_MENU")
            choice=1
            while true; do
                clear
                tput civis
                echo -e "${BOLD}${tableMenu[0]}${CLEAR}"
                for ((line=1; line<${#tableMenu[@]}; line++)); do
                    if [[ $line == $choice ]]; then 
                        echo -e "${GREEN}> ${tableMenu[$line]} ${CLEAR}"
                    else 
                        echo "${tableMenu[$line]}"
                    fi
                done
                
                read -rsn1 action
                if [[ $action == $'\x1b' ]]; then
                    read -rsn2 action
                    case $action in
                        "[A") ((choice--))
                              [[ $choice -lt 1 ]] && choice=$((${#tableMenu[@]} - 1)) ;;
                        "[B") ((choice++))
                              [[ $choice -ge ${#tableMenu[@]} ]] && choice=1 ;;
                    esac
                elif [[ $action == "" ]]; then
                    user_selection=$((choice - 1))
                    break
                fi
            done
            
            # Coordination with table_module.sh
            case $user_selection in
                0) current_table_state="SHOW_TABLES"
                   source ./table_module.sh ;;
                1) current_table_state="CREATE_TABLE"
                   source ./table_module.sh ;;
                2) current_table_state="INSERT_TABLE"
                   source ./table_module.sh ;;
                3) current_table_state="SELECT_TABLE"
                   source ./table_module.sh ;;
                4) current_table_state="DELETE_ROW"
                   source ./table_module.sh ;;
                5) current_table_state="UPDATE_CELL"
                   source ./table_module.sh ;;
                6) current_table_state="DROP_TABLE"
                   source ./table_module.sh ;;
                7) current_state="MAIN_MENU" 
                   continue ;;
                8) exit ;;
            esac
            current_state="TABLE_MENU"
            ;;
    esac
done