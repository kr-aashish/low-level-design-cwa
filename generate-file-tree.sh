#!/bin/bash

# --- Function Definition ---

# This is a recursive function that generates the tree structure.
# Argument 1: The directory to process currently.
# Argument 2: The prefix string for indentation and tree lines.
# Argument 3: The path of the file to write the output to.
function generate_tree_recursive() {
    local current_dir="$1"
    local prefix="$2"
    local output_file="$3" # Use the passed output file path

    # Get a sorted list of all items (files and directories) in the current directory.
    # We explicitly prune the path of the output file itself to avoid errors.
    local items=()
    while IFS= read -r -d $'\0'; do
        items+=("$REPLY")
    done < <(find "$current_dir" -maxdepth 1 -mindepth 1 -not -path "$output_file" -print0 | sort -z)

    # Process each item found in the directory.
    for item_path in "${items[@]}"; do
        local item_name
        item_name=$(basename "$item_path")
        
        if [ -d "$item_path" ]; then
            # --- Handle Directories ---
            echo "${prefix}+-- ${item_name}" >> "$output_file"
            # Print the vertical connector line for the contents of this new directory
            echo "${prefix}|   |" >> "$output_file"
            # Make a recursive call, passing the output file path along
            generate_tree_recursive "$item_path" "${prefix}|   " "$output_file"

        elif [ -f "$item_path" ]; then
            # --- Handle Files ---
            echo "${prefix}+-- ${item_name}" >> "$output_file"
            
            # Define the prefix for the file's content lines
            local content_prefix="${prefix}|   |"
            
            # Print the vertical connector line for the file content
            echo "${content_prefix}   |" >> "$output_file"

            # Read the file line by line and print each line with the proper prefix
            while IFS= read -r line || [[ -n "$line" ]]; do
                # Note the extra spaces after the prefix to align the code
                echo "${content_prefix}   |   ${line}" >> "$output_file"
            done < "$item_path"
            
            # Add a blank line for spacing after the file's content is printed
            echo "" >> "$output_file"
        fi
    done
}


# --- Main Script Execution ---

# Check for an input directory argument from the command line ($1).
if [ -z "$1" ]; then
    # If no argument is provided, default to the current directory.
    SEARCH_DIR="."
    echo "No directory specified. Using current directory: $(pwd)"
else
    # If an argument is provided, check if it's a valid directory.
    if [ ! -d "$1" ]; then
        echo "Error: '$1' is not a valid directory."
        exit 1
    fi
    # Use the provided directory path.
    SEARCH_DIR="$1"
fi

# Get the base name of the directory to be scanned.
# If the search dir is '.', use the name of the current working directory.
if [[ "$SEARCH_DIR" == "." ]]; then
    dir_base_name=$(basename "$(pwd)")
else
    # Remove trailing slash if it exists, then get basename
    temp_path="${SEARCH_DIR%/}"
    dir_base_name=$(basename "$temp_path")
fi

# Define the output directory to be in the current location, named after the input directory.
OUTPUT_DIR="./${dir_base_name}_trees"

# Create the output directory.
# The -p flag ensures no error is thrown if the directory already exists.
mkdir -p "$OUTPUT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Could not create output directory '${OUTPUT_DIR}'."
    exit 1
fi

echo "Generating separate tree files in '${OUTPUT_DIR}'..."

# This initial loop finds all top-level directories in SEARCH_DIR to start the process.
# We explicitly prune the OUTPUT_DIR path to prevent the script from scanning its own output.
while IFS= read -r -d $'\0'; do
    top_dir_path="$REPLY"
    top_dir_name=$(basename "$top_dir_path")

    # Define the output file path to be inside the new output directory.
    # Replaces spaces with underscores for safer filenames.
    OUTPUT_FILE="${OUTPUT_DIR}/${top_dir_name// /_}.txt"
    
    echo "Creating tree for '${top_dir_name}' -> ${OUTPUT_FILE}"

    # Clear the output file for this specific directory to start fresh.
    > "$OUTPUT_FILE"

    # Start the recursive generation for this top-level directory's contents directly.
    # The initial prefix is empty so the tree starts at the root level in the file.
    generate_tree_recursive "$top_dir_path" "" "$OUTPUT_FILE"

done < <(find "$SEARCH_DIR" -path "$OUTPUT_DIR" -prune -o \( -maxdepth 1 -mindepth 1 -type d -print0 \))

echo "Done."
